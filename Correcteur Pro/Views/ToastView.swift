//
//  ToastView.swift
//  Correcteur Pro
//
//  Composant pour afficher des messages temporaires (toast)
//

import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toast {
                VStack {
                    ToastView(
                        message: toast.message,
                        icon: toast.icon,
                        color: toast.color,
                        isVisible: .constant(true)
                    )
                    .padding(.top, 20)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toast != nil)
            }
        }
    }
}

struct ToastMessage: Equatable {
    let message: String
    let icon: String
    let color: Color
    let duration: TimeInterval
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.message == rhs.message && lhs.icon == rhs.icon
    }
    
    static func success(_ message: String) -> ToastMessage {
        ToastMessage(message: message, icon: "checkmark.circle.fill", color: Color(hex: "4CAF50"), duration: 2.0)
    }
    
    static func error(_ message: String) -> ToastMessage {
        ToastMessage(message: message, icon: "exclamationmark.triangle.fill", color: Color(hex: "F44336"), duration: 3.0)
    }
    
    static func warning(_ message: String) -> ToastMessage {
        ToastMessage(message: message, icon: "exclamationmark.circle.fill", color: Color(hex: "FF9800"), duration: 2.5)
    }
    
    static func info(_ message: String) -> ToastMessage {
        ToastMessage(message: message, icon: "info.circle.fill", color: Color(hex: "2196F3"), duration: 2.0)
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

