//
//  NSImage+ContentDetection.swift
//  Correcteur Pro
//
//  Détection intelligente du type de contenu d'une image
//

import AppKit
import CoreImage

// MARK: - Image Content Types

/// Type de contenu détecté dans l'image
enum ImageContentType {
    case text        // Capture d'écran avec texte (compression agressive)
    case photo       // Photo avec détails (compression modérée)
    case mixed       // Mixte texte + images (compression modérée)
    case unknown     // Inconnu (compression conservatrice)

    var description: String {
        switch self {
        case .text: return "Text/Screenshot"
        case .photo: return "Photo"
        case .mixed: return "Mixed"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Compression Profiles

/// Profil de compression adapté au type de contenu
struct CompressionProfile {
    let maxDimension: CGFloat
    let jpegQuality: CGFloat
    let maxSizeMB: Double
    let name: String

    var description: String {
        return "\(name): \(Int(maxDimension))px, Q\(String(format: "%.1f", jpegQuality)), \(String(format: "%.1f", maxSizeMB))MB"
    }
}

// MARK: - NSImage Extension

extension NSImage {

    // MARK: - Content Detection

    /// Détecte le type de contenu de l'image
    /// - Returns: Type de contenu détecté
    func detectContentType() -> ImageContentType {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("⚠️ [Detection] Cannot convert to CGImage, assuming unknown")
            return .unknown
        }

        let width = cgImage.width
        let height = cgImage.height

        print("🔍 [Detection] Analyzing image \(width)x\(height)...")

        // 1. Vérifier les métadonnées (si c'est une capture d'écran macOS)
        if isScreenshot() {
            print("✅ [Detection] Detected as screenshot (metadata)")
            return .text
        }

        // 2. Analyser les propriétés de l'image
        let colorComplexity = analyzeColorComplexity(cgImage)
        let contrastRatio = analyzeContrast(cgImage)
        let uniformity = analyzeUniformity(cgImage)

        print("📊 [Detection] ColorComplexity: \(String(format: "%.2f", colorComplexity))")
        print("📊 [Detection] ContrastRatio: \(String(format: "%.2f", contrastRatio))")
        print("📊 [Detection] Uniformity: \(String(format: "%.2f", uniformity))")

        // 3. Heuristiques pour détecter le type

        // Texte/Screenshot : peu de couleurs, contraste élevé, zones uniformes
        if colorComplexity < 0.3 && contrastRatio > 0.6 && uniformity > 0.5 {
            print("✅ [Detection] Detected as TEXT (low colors, high contrast)")
            return .text
        }

        // Photo : beaucoup de couleurs, faible uniformité
        if colorComplexity > 0.6 && uniformity < 0.3 {
            print("✅ [Detection] Detected as PHOTO (many colors, low uniformity)")
            return .photo
        }

        // Mixte : entre les deux
        if colorComplexity > 0.3 && colorComplexity < 0.6 {
            print("✅ [Detection] Detected as MIXED (medium complexity)")
            return .mixed
        }

        print("⚠️ [Detection] Detected as UNKNOWN (fallback)")
        return .unknown
    }

    // MARK: - Analysis Methods

    /// Vérifie si l'image est une capture d'écran macOS
    private func isScreenshot() -> Bool {
        // Vérifier les propriétés TIFF pour détecter une capture d'écran
        guard let tiffData = self.tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return false
        }

        // Chercher des indices de capture d'écran
        // (Note: Cette méthode est basique, Vision Framework serait plus précis)
        if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiHeight = properties[kCGImagePropertyDPIHeight as String] as? Double {
            // Les captures d'écran macOS ont souvent 144 DPI (Retina) ou 72 DPI
            return (dpiWidth == 144.0 && dpiHeight == 144.0) || (dpiWidth == 72.0 && dpiHeight == 72.0)
        }

        return false
    }

    /// Analyse la complexité des couleurs (0.0 = peu de couleurs, 1.0 = beaucoup)
    private func analyzeColorComplexity(_ cgImage: CGImage) -> Double {
        // Échantillonner l'image pour compter les couleurs uniques
        let sampleSize = 100 // Échantillonner tous les 100 pixels pour performance

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.5 // Valeur par défaut si échec
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height

        var colorSet = Set<Int>()
        var sampleCount = 0

        for y in stride(from: 0, to: height, by: sampleSize) {
            for x in stride(from: 0, to: width, by: sampleSize) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel

                if pixelIndex + 2 < CFDataGetLength(data) {
                    let r = pixelData[pixelIndex]
                    let g = pixelData[pixelIndex + 1]
                    let b = pixelData[pixelIndex + 2]

                    // Quantifier la couleur pour réduire bruit
                    let quantized = (Int(r / 32) << 10) | (Int(g / 32) << 5) | Int(b / 32)
                    colorSet.insert(quantized)
                    sampleCount += 1
                }
            }
        }

        let uniqueColors = Double(colorSet.count)
        let maxExpectedColors = Double(sampleCount) * 0.5 // 50% des échantillons max

        return min(1.0, uniqueColors / maxExpectedColors)
    }

    /// Analyse le ratio de contraste (0.0 = faible, 1.0 = élevé)
    private func analyzeContrast(_ cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let sampleSize = 100

        var minBrightness: Double = 255.0
        var maxBrightness: Double = 0.0

        for y in stride(from: 0, to: height, by: sampleSize) {
            for x in stride(from: 0, to: width, by: sampleSize) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel

                if pixelIndex + 2 < CFDataGetLength(data) {
                    let r = Double(pixelData[pixelIndex])
                    let g = Double(pixelData[pixelIndex + 1])
                    let b = Double(pixelData[pixelIndex + 2])

                    // Luminosité perçue
                    let brightness = 0.299 * r + 0.587 * g + 0.114 * b

                    minBrightness = min(minBrightness, brightness)
                    maxBrightness = max(maxBrightness, brightness)
                }
            }
        }

        let contrastRatio = (maxBrightness - minBrightness) / 255.0
        return contrastRatio
    }

    /// Analyse l'uniformité (0.0 = varié, 1.0 = uniforme)
    private func analyzeUniformity(_ cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            return 0.5
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        let sampleSize = 100

        var lightPixels = 0
        var darkPixels = 0
        var totalSamples = 0

        for y in stride(from: 0, to: height, by: sampleSize) {
            for x in stride(from: 0, to: width, by: sampleSize) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel

                if pixelIndex + 2 < CFDataGetLength(data) {
                    let r = Double(pixelData[pixelIndex])
                    let g = Double(pixelData[pixelIndex + 1])
                    let b = Double(pixelData[pixelIndex + 2])

                    let brightness = 0.299 * r + 0.587 * g + 0.114 * b

                    if brightness > 200 {
                        lightPixels += 1
                    } else if brightness < 55 {
                        darkPixels += 1
                    }

                    totalSamples += 1
                }
            }
        }

        // Plus il y a de pixels très clairs ou très foncés, plus c'est uniforme (typique du texte)
        let uniformPixels = Double(lightPixels + darkPixels)
        let uniformity = uniformPixels / Double(totalSamples)

        return uniformity
    }

    // MARK: - Compression Profiles

    /// Retourne le profil de compression optimal selon le type de contenu et la qualité
    /// - Parameters:
    ///   - contentType: Type de contenu détecté
    ///   - quality: Niveau de qualité souhaité
    /// - Returns: Profil de compression adapté
    static func compressionProfile(for contentType: ImageContentType,
                                  quality: CompressionQuality) -> CompressionProfile {
        switch (contentType, quality) {
        // TEXT - Compression agressive
        case (.text, .high):
            return CompressionProfile(maxDimension: 1024, jpegQuality: 0.4, maxSizeMB: 0.5, name: "Text-High")
        case (.text, .medium):
            return CompressionProfile(maxDimension: 1280, jpegQuality: 0.5, maxSizeMB: 0.8, name: "Text-Medium")
        case (.text, .low):
            return CompressionProfile(maxDimension: 1600, jpegQuality: 0.6, maxSizeMB: 1.5, name: "Text-Low")
        case (.text, .none):
            return CompressionProfile(maxDimension: 2048, jpegQuality: 0.7, maxSizeMB: 5.0, name: "Text-None")

        // PHOTO - Compression modérée
        case (.photo, .high):
            return CompressionProfile(maxDimension: 1600, jpegQuality: 0.6, maxSizeMB: 1.5, name: "Photo-High")
        case (.photo, .medium):
            return CompressionProfile(maxDimension: 1920, jpegQuality: 0.7, maxSizeMB: 2.5, name: "Photo-Medium")
        case (.photo, .low):
            return CompressionProfile(maxDimension: 2048, jpegQuality: 0.8, maxSizeMB: 4.0, name: "Photo-Low")
        case (.photo, .none):
            return CompressionProfile(maxDimension: 3840, jpegQuality: 0.9, maxSizeMB: 10.0, name: "Photo-None")

        // MIXED - Entre les deux
        case (.mixed, .high):
            return CompressionProfile(maxDimension: 1280, jpegQuality: 0.5, maxSizeMB: 1.0, name: "Mixed-High")
        case (.mixed, .medium):
            return CompressionProfile(maxDimension: 1600, jpegQuality: 0.6, maxSizeMB: 1.8, name: "Mixed-Medium")
        case (.mixed, .low):
            return CompressionProfile(maxDimension: 1920, jpegQuality: 0.7, maxSizeMB: 3.0, name: "Mixed-Low")
        case (.mixed, .none):
            return CompressionProfile(maxDimension: 2560, jpegQuality: 0.8, maxSizeMB: 8.0, name: "Mixed-None")

        // UNKNOWN - Conservatif
        case (.unknown, .high):
            return CompressionProfile(maxDimension: 1600, jpegQuality: 0.6, maxSizeMB: 1.5, name: "Unknown-High")
        case (.unknown, .medium):
            return CompressionProfile(maxDimension: 1920, jpegQuality: 0.7, maxSizeMB: 2.5, name: "Unknown-Medium")
        case (.unknown, .low):
            return CompressionProfile(maxDimension: 2048, jpegQuality: 0.8, maxSizeMB: 4.0, name: "Unknown-Low")
        case (.unknown, .none):
            return CompressionProfile(maxDimension: 3840, jpegQuality: 0.9, maxSizeMB: 10.0, name: "Unknown-None")
        }
    }
}
