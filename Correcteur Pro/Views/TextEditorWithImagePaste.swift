//
//  TextEditorWithImagePaste.swift
//  Correcteur Pro
//
//  Wrapper NSViewRepresentable pour intercepter Cmd+V et détecter les images
//

import SwiftUI
import AppKit

struct TextEditorWithImagePaste: NSViewRepresentable {
    @Binding var text: String
    let onImagePasted: (NSImage) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.insertionPointColor = NSColor(hex: "5C9DFF")
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.white.withAlphaComponent(0.2),
            .foregroundColor: NSColor.white
        ]
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        // Stocker la référence au textView dans le coordinator
        context.coordinator.textView = textView
        
        // Configurer le delegate pour intercepter les événements
        textView.delegate = context.coordinator
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Mettre à jour le texte seulement si différent (évite les boucles)
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorWithImagePaste
        weak var textView: NSTextView?
        var eventMonitor: Any?
        
        init(_ parent: TextEditorWithImagePaste) {
            self.parent = parent
            super.init()
            setupEventMonitor()
        }
        
        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        
        func setupEventMonitor() {
            // Monitorer les événements clavier globalement
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self = self,
                      let textView = self.textView,
                      textView.window?.firstResponder === textView else {
                    return event // Pas notre textView, laisser passer
                }
                
                // Vérifier si c'est Cmd+V
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                    print("⌨️ [TextEditor] Cmd+V détecté!")
                    
                    // Vérifier le clipboard pour une image
                    if let image = ClipboardHelper.checkClipboardForImage() {
                        print("✅ [TextEditor] Image trouvée dans le clipboard, interception du paste")
                        
                        // Ajouter l'image
                        DispatchQueue.main.async {
                            self.parent.onImagePasted(image)
                        }
                        
                        // Bloquer le paste texte
                        return nil
                    } else {
                        print("📝 [TextEditor] Pas d'image, laisser TextEditor gérer le paste texte")
                        // Laisser passer l'événement pour que TextEditor gère le texte
                        return event
                    }
                }
                
                return event
            }
        }
        
        // NSTextViewDelegate : détecter les changements de texte
        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
        }
    }
}

