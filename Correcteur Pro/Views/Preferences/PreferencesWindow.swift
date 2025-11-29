//
//  PreferencesWindow.swift
//  Correcteur Pro
//
//  Fenêtre de préférences avec onglets (style macOS natif)
//

import SwiftUI

struct PreferencesWindow: View {

    // MARK: - Properties

    @ObservedObject var prefsManager = PreferencesManager.shared
    @State private var selectedTab: PreferenceTab = .capture

    // MARK: - Tabs Definition

    enum PreferenceTab: String, CaseIterable {
        case capture = "Capture"
        case interface = "Interface"
        case api = "API"
        case conversations = "Conversations"

        var icon: String {
            switch self {
            case .capture: return "camera.fill"
            case .interface: return "paintpalette.fill"
            case .api: return "network"
            case .conversations: return "bubble.left.and.bubble.right.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar avec onglets (style macOS)
            HStack(spacing: 16) {
                ForEach(PreferenceTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24))
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Contenu de l'onglet sélectionné
            Group {
                switch selectedTab {
                case .capture:
                    CapturePreferencesView()
                case .interface:
                    InterfacePreferencesView()
                case .api:
                    APIPreferencesView()
                case .conversations:
                    ConversationsPreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    PreferencesWindow()
}
