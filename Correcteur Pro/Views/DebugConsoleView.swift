//
//  DebugConsoleView.swift
//  Correcteur Pro
//
//  Console de debug intégrée pour afficher les logs en temps réel
//

import SwiftUI

struct DebugConsoleView: View {
    // Utiliser @ObservedObject car DebugLogger.shared est un singleton existant
    @ObservedObject private var logger = DebugLogger.shared
    @State private var autoScroll = true
    @State private var filterText = ""

    var filteredMessages: [LogMessage] {
        if filterText.isEmpty {
            return logger.messages
        }
        return logger.messages.filter { message in
            message.message.localizedCaseInsensitiveContains(filterText) ||
            message.category.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🐛 Console de Debug")
                    .font(.headline)

                // DIAGNOSTIC: Afficher le nombre de messages
                Text("(\(logger.messages.count) messages chargés)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Filtre
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filtrer...", text: $filterText)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                // Clear button
                Button(action: {
                    logger.clear()
                }) {
                    Label("Effacer", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Export button
                Button(action: {
                    exportLogs()
                }) {
                    Label("Exporter", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Close button
                Button(action: {
                    logger.toggleConsole()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.05))

            Divider()

            // Logs list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredMessages) { message in
                            LogRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.9))
                .onChange(of: logger.messages.count) {
                    if autoScroll, let lastMessage = filteredMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text("\(filteredMessages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !filterText.isEmpty {
                    Text("Filtré de \(logger.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.05))
        }
        .frame(height: 300)
    }

    private func exportLogs() {
        let logs = logger.exportLogs()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logs, forType: .string)

        logger.log("📋 [Debug] Logs copiés dans le presse-papiers", category: "System")
    }
}

struct LogRow: View {
    let message: LogMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(message.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            // Category badge
            Text(message.category)
                .font(.system(.caption2, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(categoryColor(for: message.category).opacity(0.2))
                .foregroundColor(categoryColor(for: message.category))
                .cornerRadius(4)

            // Message
            Text(message.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Compression": return .blue
        case "API": return .green
        case "Capture": return .orange
        case "Error": return .red
        case "System": return .purple
        default: return .gray
        }
    }
}

#Preview {
    DebugConsoleView()
        .frame(width: 800)
        .onAppear {
            DebugLogger.shared.isEnabled = true
            DebugLogger.shared.log("🎯 [Intelligent Compression] Starting compression with quality: high", category: "Compression")
            DebugLogger.shared.log("🔍 [Intelligent Compression] Content type detected: Text/Screenshot", category: "Compression")
            DebugLogger.shared.log("📋 [Intelligent Compression] Using profile: Text-High: 1024px, Q0.4, 0.5MB", category: "Compression")
            DebugLogger.shared.log("✅ [Intelligent Compression] Final size: 0.42 MB", category: "Compression")
            DebugLogger.shared.log("📤 [API] Sending request to OpenAI...", category: "API")
            DebugLogger.shared.log("✅ [API] Response received (200 OK)", category: "API")
            DebugLogger.shared.log("❌ [Error] Something went wrong", category: "Error")
        }
}
