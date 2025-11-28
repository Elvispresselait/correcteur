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
    let onImagePasted: (ClipboardResult) -> Void
    var onSend: (() -> Void)? = nil
    
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
                
                // Gérer Entrée pour envoyer le message
                if event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n" {
                    // Si Shift+Entrée, laisser passer pour créer une nouvelle ligne
                    if event.modifierFlags.contains(.shift) {
                        print("⌨️ [TextEditor] Shift+Entrée détecté : nouvelle ligne")
                        return event
                    }

                    // Si juste Entrée (sans Shift), envoyer le message
                    print("⌨️ [TextEditor] Entrée détecté : envoi du message")
                    if let onSend = self.parent.onSend {
                        DispatchQueue.main.async {
                            onSend()
                        }
                    }
                    return nil // Bloquer l'événement pour ne pas créer de nouvelle ligne
                }

                // Vérifier si c'est Cmd+V
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                    print("⌨️ [TextEditor] Cmd+V détecté!")
                    
                    // Vérifier le clipboard pour une image
                    // TEMPS 1 : Accepter toutes les images sans validation de taille
                    print("🔍 [TextEditor] Appel checkClipboardForImage (TEMPS 1: accepte toutes tailles)")
                    let result = ClipboardHelper.checkClipboardForImage(autoCompress: false) // Pas de compression ici, se fera après upload
                    
                    print("🔍 [TextEditor] Résultat: image=\(result.image != nil ? "présente" : "nil"), error=\(result.error?.localizedDescription ?? "nil")")
                    
                    if result.image != nil {
                        print("✅ [TextEditor] Image trouvée dans le clipboard, interception du paste")
                        if let mimeType = result.mimeType {
                            print("📄 [TextEditor] Type MIME: \(mimeType)")
                        }
                        if let sizeMB = result.sizeMB {
                            print("📊 [TextEditor] Taille: \(String(format: "%.2f", sizeMB)) MB")
                        }
                        
                        // TEMPS 1 : Accepter toutes les images, même si erreur imageTooLarge
                        // La compression se fera après upload (TEMPS 2)
                        DispatchQueue.main.async {
                            self.parent.onImagePasted(result)
                        }
                        
                        // Bloquer le paste texte si image trouvée (même si grande)
                        print("✅ [TextEditor] Image acceptée, blocage du paste texte")
                        return nil
                    } else {
                        print("📝 [TextEditor] Pas d'image, laisser TextEditor gérer le paste texte")
                        if let error = result.error {
                            // Ne bloquer que les erreurs non liées à la taille
                            if case .imageTooLarge = error {
                                print("ℹ️ [TextEditor] Image grande mais acceptée (TEMPS 1)")
                            } else {
                                print("⚠️ [TextEditor] Erreur: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // Laisser passer l'événement pour que TextEditor gère le texte
                    return event
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

