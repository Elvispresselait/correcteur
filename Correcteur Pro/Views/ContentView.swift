//
//  ContentView.swift
//  Correcteur Pro
//
//  Vue principale de l'application avec sidebar et zone de chat
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isSidebarVisible: Bool = true
    @State private var inputText: String = ""
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: "020815"),
            Color(hex: "07152C"),
            Color(hex: "0F2D4F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        SidebarView(viewModel: viewModel)
                            .frame(width: 230)
                            .transition(.move(edge: .leading))
                    }
                    
                    ChatView(
                        viewModel: viewModel,
                        isSidebarVisible: $isSidebarVisible,
                        inputText: $inputText
                    )
                }
                .padding(0)
                .background(
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)
                )
            }
        }
    }
}


#Preview("Application complète") {
    ContentView()
        .frame(width: 600, height: 700)
        .previewDisplayName("Correcteur Pro - Vue principale")
}

#Preview("Mode portrait") {
    ContentView()
        .frame(width: 400, height: 700)
        .previewDisplayName("Mode portrait (400x700)")
}

#Preview("Mode large") {
    ContentView()
        .frame(width: 800, height: 900)
        .previewDisplayName("Mode large (800x900)")
}

