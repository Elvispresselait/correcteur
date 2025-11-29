//
//  DebugLogger.swift
//  Correcteur Pro
//
//  Logger centralisé pour capturer tous les logs de l'application
//  Architecture: Singleton pattern with ObservableObject for SwiftUI reactivity
//

import Foundation
import Combine
import os.log

/// Niveau de sévérité du log (console de debug)
enum DebugLogLevel: Int, Comparable, CaseIterable {
    case debug = 0    // Informations de débogage détaillées
    case info = 1     // Informations générales
    case warning = 2  // Avertissements
    case error = 3    // Erreurs
    case critical = 4 // Erreurs critiques

    static func < (lhs: DebugLogLevel, rhs: DebugLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var icon: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// Message de log avec métadonnées enrichies
struct LogMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let category: String
    let level: DebugLogLevel
    let file: String
    let function: String
    let line: Int

    init(
        timestamp: Date = Date(),
        message: String,
        category: String,
        level: DebugLogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.timestamp = timestamp
        self.message = message
        self.category = category
        self.level = level
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var emoji: String {
        // Priorité : niveau > contenu du message
        if level >= .error { return level.icon }
        if message.contains("✅") { return "✅" }
        if message.contains("❌") { return "❌" }
        if message.contains("⚠️") { return "⚠️" }
        if message.contains("🔍") { return "🔍" }
        if message.contains("🎯") { return "🎯" }
        if message.contains("📋") { return "📋" }
        if message.contains("📊") { return "📊" }
        if message.contains("🧪") { return "🧪" }
        return level.icon
    }

    /// Représentation complète pour debugging
    var fullDescription: String {
        "[\(formattedTimestamp)] [\(level.icon) \(category)] \(message) (\(file):\(line))"
    }
}

/// Gestionnaire de logs centralisé (Singleton)
/// Thread-safe avec @Published pour réactivité SwiftUI
@MainActor
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published private(set) var messages: [LogMessage] = []
    @Published var isEnabled: Bool = false
    @Published var minLogLevel: DebugLogLevel = .debug // Filtrer par niveau

    private let maxMessages = 500
    private let osLog = OSLog(subsystem: "com.correcteurpro", category: "DebugLogger")

    private init() {
        // Charger les préférences
        isEnabled = UserDefaults.standard.bool(forKey: "debugConsoleEnabled")

        // Log initial pour vérifier que le logger fonctionne
        if isEnabled {
            let initMessage = LogMessage(
                message: "🟢 DebugLogger initialisé",
                category: "System",
                level: .info
            )
            messages.append(initMessage)
            os_log("DebugLogger initialized", log: osLog, type: .info)
        }
    }

    /// Active ou désactive la console
    func toggleConsole() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "debugConsoleEnabled")

        let message = isEnabled ? "🟢 Console de debug activée" : "🔴 Console de debug désactivée"
        log(message, category: "System", level: .info)
    }

    /// Ajoute un message de log avec niveau de sévérité
    func log(
        _ message: String,
        category: String = "General",
        level: DebugLogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Créer le log immédiatement
        let logMessage = LogMessage(
            timestamp: Date(),
            message: message,
            category: category,
            level: level,
            file: file,
            function: function,
            line: line
        )

        // Toujours logger dans la console système via os_log
        let osLogType: OSLogType = switch level {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        case .critical: .fault
        }
        os_log("%{public}@", log: osLog, type: osLogType, message)

        // Ajouter directement au tableau (nous sommes déjà sur MainActor)
        // Filtrer par niveau minimum
        guard level >= minLogLevel else { return }

        messages.append(logMessage)

        // Limiter le nombre de messages (FIFO)
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }

        // Toujours imprimer pour compatibilité
        let levelIcon = switch level {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .warning: "⚠️"
        case .error: "❌"
        case .critical: "🚨"
        }
        print("[\(levelIcon)] \(message)")
    }

    /// Efface tous les logs
    func clear() {
        messages.removeAll()
        log("🗑️ Logs effacés", category: "System", level: .info)
    }

    /// Exporte les logs en texte avec métadonnées complètes
    func exportLogs(includeMetadata: Bool = false) -> String {
        if includeMetadata {
            return messages.map { $0.fullDescription }.joined(separator: "\n")
        } else {
            return messages.map { log in
                "[\(log.formattedTimestamp)] \(log.message)"
            }.joined(separator: "\n")
        }
    }

    /// Statistiques des logs
    var stats: LogStats {
        let grouped = Dictionary(grouping: messages, by: { $0.level })
        return LogStats(
            total: messages.count,
            debug: grouped[DebugLogLevel.debug]?.count ?? 0,
            info: grouped[DebugLogLevel.info]?.count ?? 0,
            warning: grouped[DebugLogLevel.warning]?.count ?? 0,
            error: grouped[DebugLogLevel.error]?.count ?? 0,
            critical: grouped[DebugLogLevel.critical]?.count ?? 0
        )
    }
}

/// Statistiques des logs
struct LogStats {
    let total: Int
    let debug: Int
    let info: Int
    let warning: Int
    let error: Int
    let critical: Int

    var hasErrors: Bool { error > 0 || critical > 0 }
    var hasWarnings: Bool { warning > 0 }
}

/// Extension pour faciliter l'utilisation dans tout le code
extension DebugLogger {
    // Méthodes de commodité avec niveaux appropriés
    func logDebug(_ message: String, category: String = "General") {
        log(message, category: category, level: .debug)
    }

    func logInfo(_ message: String, category: String = "General") {
        log(message, category: category, level: .info)
    }

    func logWarning(_ message: String, category: String = "General") {
        log(message, category: category, level: .warning)
    }

    func logError(_ message: String, category: String = "Error") {
        log(message, category: category, level: .error)
    }

    func logCritical(_ message: String, category: String = "Critical") {
        log(message, category: category, level: .critical)
    }

    // Catégories spécifiques (rétrocompatibilité)
    func logCompression(_ message: String) {
        log(message, category: "Compression", level: .info)
    }

    func logAPI(_ message: String) {
        log(message, category: "API", level: .info)
    }

    func logCapture(_ message: String) {
        log(message, category: "Capture", level: .info)
    }
}
