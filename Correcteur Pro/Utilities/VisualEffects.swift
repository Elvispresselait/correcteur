//
//  VisualEffects.swift
//  Correcteur Pro
//
//  Helpers pour les effets visuels macOS (transparence, flou)
//

import SwiftUI
import AppKit

// MARK: - Visual Effect View (Verre dépoli)

/// Vue pour l'effet de flou macOS natif (NSVisualEffectView)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Window Transparency Helper

/// Configure la fenêtre pour être transparente
struct TransparentWindowHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = .clear
                window.isOpaque = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Convenience Modifiers

extension View {
    /// Applique un fond avec effet verre dépoli et dégradé superposé
    func frostedGlassBackground(
        gradient: LinearGradient,
        opacity: Double = 0.80,
        material: NSVisualEffectView.Material = .hudWindow
    ) -> some View {
        self.background(
            ZStack {
                TransparentWindowHelper()
                    .frame(width: 0, height: 0)

                VisualEffectBlur(material: material, blendingMode: .behindWindow)

                gradient
                    .opacity(opacity)
            }
            .ignoresSafeArea()
        )
    }
}
