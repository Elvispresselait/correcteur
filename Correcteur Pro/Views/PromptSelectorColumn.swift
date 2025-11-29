//
//  PromptSelectorColumn.swift
//  Correcteur Pro
//
//  Colonne de sélection des prompts système avec mode responsive
//

import SwiftUI

struct PromptSelectorColumn: View {
    @ObservedObject var viewModel: ChatViewModel

    /// Seuil de largeur pour passer en mode compact (icônes seulement)
    private let compactThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactThreshold

            VStack(spacing: 4) {
                ForEach(SystemPromptType.allCases) { promptType in
                    PromptButton(
                        promptType: promptType,
                        isSelected: viewModel.promptType == promptType,
                        isCompact: isCompact
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.promptType = promptType
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, isCompact ? 4 : 8)
        }
        .frame(minWidth: 50, maxWidth: 180)
        .background(Color.black.opacity(0.2))
    }
}

struct PromptButton: View {
    let promptType: SystemPromptType
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(promptType.icon)
                    .font(.system(size: isCompact ? 20 : 16))

                if !isCompact {
                    Text(promptType.shortName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)

                    Spacer()
                }
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        .help(promptType.rawValue)
    }
}

#Preview("Large") {
    PromptSelectorColumn(viewModel: ChatViewModel.preview)
        .frame(width: 150, height: 300)
        .background(Color(hex: "0C1F3C"))
}

#Preview("Compact") {
    PromptSelectorColumn(viewModel: ChatViewModel.preview)
        .frame(width: 60, height: 300)
        .background(Color(hex: "0C1F3C"))
}
