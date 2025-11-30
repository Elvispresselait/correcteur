//
//  SelectionOverlayView.swift
//  Correcteur Pro
//
//  Vue SwiftUI pour dessiner le rectangle de sélection
//

import SwiftUI

struct SelectionOverlayView: View {

    // MARK: - Properties

    let onSelectionComplete: (NSRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var isDragging = false

    // MARK: - Computed Properties

    /// Rectangle de sélection actuel
    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else {
            return nil
        }

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Dimensions affichées
    private var dimensionsText: String {
        guard let rect = selectionRect else { return "" }
        return "\(Int(rect.width)) × \(Int(rect.height))"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Fond semi-transparent
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Rectangle de sélection
            if let rect = selectionRect {
                ZStack(alignment: .topLeading) {
                    // Zone sélectionnée (transparente)
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // Bordure du rectangle
                    Rectangle()
                        .strokeBorder(Color.blue, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // Affichage des dimensions
                    if rect.width > 50 && rect.height > 50 {
                        Text(dimensionsText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.blue)
                            .cornerRadius(4)
                            .position(x: rect.midX, y: rect.minY - 15)
                    }
                }
            }

            // Instructions
            if !isDragging && startPoint == nil {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.white)

                    Text("Cliquez et glissez pour sélectionner une zone")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)

                    Text("Appuyez sur Échap pour annuler")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        // Premier clic
                        startPoint = value.location
                        isDragging = true
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    guard let rect = selectionRect else {
                        // Clic sans drag = annuler
                        onCancel()
                        return
                    }

                    // Vérifier que la zone n'est pas trop petite
                    if rect.width < 10 || rect.height < 10 {
                        print("⚠️ [SelectionOverlay] Zone trop petite, annulation")
                        startPoint = nil
                        currentPoint = nil
                        isDragging = false
                        return
                    }

                    // Convertir les coordonnées SwiftUI vers NSRect (origine en bas à gauche)
                    // La fenêtre overlay couvre tous les écrans (frame combiné)
                    let combinedFrame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }

                    // SwiftUI: origine en haut à gauche du frame combiné
                    // NSRect: origine en bas à gauche du système de coordonnées global
                    let nsRect = NSRect(
                        x: combinedFrame.origin.x + rect.minX,
                        y: combinedFrame.maxY - rect.maxY,
                        width: rect.width,
                        height: rect.height
                    )

                    print("✅ [SelectionOverlay] Sélection terminée: \(nsRect) (combined: \(combinedFrame))")
                    onSelectionComplete(nsRect)
                }
        )
    }
}
