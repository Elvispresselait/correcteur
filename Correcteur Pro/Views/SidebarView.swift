//
//  SidebarView.swift
//  Correcteur Pro
//
//  Barre latérale avec liste des conversations
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onToggleSidebar: (() -> Void)? = nil
    
    @State private var isHoveringNewChat = false
    
    private let sidebarGradient = LinearGradient(
        colors: [
            Color(hex: "04122A"),
            Color(hex: "061B37"),
            Color(hex: "082248")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: viewModel.createNewConversation) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Nouveau chat")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isHoveringNewChat ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .onHover { hovering in
                isHoveringNewChat = hovering
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.conversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: viewModel.selectedConversationID == conversation.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectConversation(conversation)
                            onToggleSidebar?()
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteConversation(conversation)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(sidebarGradient)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            
            Text(conversation.titre)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(rowStroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var rowBackground: Color {
        if isSelected { return Color.white.opacity(0.18) }
        if isHovering { return Color.white.opacity(0.08) }
        return Color.white.opacity(0.02)
    }
    
    private var rowStroke: Color {
        if isSelected { return Color.white.opacity(0.18) }
        if isHovering { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.04)
    }
}

#Preview("Sidebar - Liste de conversations") {
    SidebarPreviewContainer()
    .frame(width: 200, height: 700)
}

#Preview("Sidebar - Conversation sélectionnée") {
    SidebarSelectedPreviewContainer()
    .frame(width: 200, height: 700)
}

private struct SidebarPreviewContainer: View {
    @StateObject private var viewModel = ChatViewModel.preview
    
    var body: some View {
        SidebarView(viewModel: viewModel)
    }
}

private struct SidebarSelectedPreviewContainer: View {
    @StateObject private var viewModel: ChatViewModel
    
    init() {
        let vm = ChatViewModel.preview
        if let second = vm.conversations.dropFirst().first {
            vm.selectConversation(second)
        }
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        SidebarView(viewModel: viewModel)
    }
}

#Preview("ConversationRow - État sélectionné") {
    ConversationRow(
        conversation: Conversation(titre: "Correction de texte sélectionnée"),
        isSelected: true
    )
    .frame(width: 200, height: 50)
    .background(Color(hex: "F7F7F8"))
}

#Preview("ConversationRow - État normal") {
    ConversationRow(
        conversation: Conversation(titre: "Traduction document"),
        isSelected: false
    )
    .frame(width: 200, height: 50)
    .background(Color(hex: "F7F7F8"))
}

