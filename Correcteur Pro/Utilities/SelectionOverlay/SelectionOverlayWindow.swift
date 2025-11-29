//
//  SelectionOverlayWindow.swift
//  Correcteur Pro
//
//  Fenêtre fullscreen transparente pour la sélection de zone d'écran
//

import Cocoa
import SwiftUI

/// Fenêtre fullscreen transparente qui couvre tous les écrans
class SelectionOverlayWindow: NSWindow {

    // MARK: - Properties

    /// Callback appelé quand l'utilisateur a terminé la sélection
    var onSelectionComplete: ((NSRect) -> Void)?

    /// Callback appelé quand l'utilisateur annule (Échap)
    var onCancel: (() -> Void)?

    private var overlayView: SelectionOverlayView?

    // MARK: - Initialization

    init() {
        // Calculer le frame pour couvrir tous les écrans
        let combinedFrame = NSScreen.screens.reduce(NSRect.zero) { result, screen in
            return result.union(screen.frame)
        }

        super.init(
            contentRect: combinedFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        setupWindow()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        // Configuration de la fenêtre
        self.level = .screenSaver // Au-dessus de tout
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false

        // Créer la vue SwiftUI
        let overlayView = SelectionOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.onSelectionComplete?(rect)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.close()
            }
        )

        self.overlayView = overlayView

        // Intégrer la vue SwiftUI dans NSWindow
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        self.contentView = hostingView
    }

    // MARK: - Public Methods

    /// Affiche la fenêtre de sélection
    func show() {
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Cacher le curseur par défaut et afficher une croix
        NSCursor.crosshair.set()

        print("✅ [SelectionOverlay] Fenêtre de sélection affichée")
    }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        // Échap pour annuler
        if event.keyCode == 53 { // Escape key
            onCancel?()
            close()
        }
    }

    override func close() {
        // Restaurer le curseur normal
        NSCursor.arrow.set()
        super.close()
        print("✅ [SelectionOverlay] Fenêtre de sélection fermée")
    }
}
