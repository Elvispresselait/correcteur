//
//  APILogger.swift
//  Correcteur Pro
//
//  Système de logging pour les appels API dans des fichiers
//

import Foundation

/// Niveaux de log
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Logger pour les appels API OpenAI
final class APILogger {
    private static let logDirectoryName = "api_logs"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Chemin vers le dossier de logs
    private static var logDirectory: URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logsDir = appSupport.appendingPathComponent("Correcteur Pro", isDirectory: true)
            .appendingPathComponent(logDirectoryName, isDirectory: true)
        
        // Créer le dossier s'il n'existe pas
        if !fileManager.fileExists(atPath: logsDir.path) {
            try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }
        
        return logsDir
    }
    
    /// Chemin vers le fichier de log du jour
    private static var todayLogFile: URL? {
        guard let logDir = logDirectory else { return nil }
        let fileName = "api_\(fileDateFormatter.string(from: Date())).log"
        return logDir.appendingPathComponent(fileName)
    }
    
    /// Écrire un log dans le fichier
    /// - Parameters:
    ///   - level: Niveau de log
    ///   - message: Message à logger
    ///   - service: Service qui log (ex: "OpenAIService")
    static func log(level: LogLevel, message: String, service: String = "API") {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] \(level.emoji) [\(service)] \(level.rawValue): \(message)\n"
        
        // Afficher dans la console aussi
        print(logLine.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Écrire dans le fichier
        guard let logFile = todayLogFile else {
            print("⚠️ [APILogger] Impossible de créer le fichier de log")
            return
        }
        
        // Créer le fichier s'il n'existe pas
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        // Écrire dans le fichier
        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
            fileHandle.seekToEndOfFile()
            if let data = logLine.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            // Si FileHandle échoue, essayer d'écrire directement
            if let data = logLine.data(using: .utf8) {
                try? data.append(to: logFile)
            }
        }
    }
    
    /// Logger une requête API
    /// - Parameters:
    ///   - endpoint: Endpoint appelé
    ///   - method: Méthode HTTP
    ///   - headers: Headers (masquer la clé API)
    ///   - body: Body de la requête (optionnel)
    static func logRequest(endpoint: String, method: String = "POST", headers: [String: String]? = nil, body: [String: Any]? = nil) {
        var logMessage = "📡 Requête \(method) à \(endpoint)\n"
        
        if let headers = headers {
            logMessage += "   Headers:\n"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                if key.lowercased() == "authorization" {
                    // Masquer la clé API
                    let masked = String(value.prefix(20)) + "..."
                    logMessage += "     \(key): \(masked)\n"
                } else {
                    logMessage += "     \(key): \(value)\n"
                }
            }
        }
        
        if let body = body {
            logMessage += "   Body:\n"
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // Masquer la clé API dans le body si présente
                let sanitized = jsonString.replacingOccurrences(of: #"sk-[^"]+"#, with: "sk-***", options: .regularExpression)
                logMessage += "     \(sanitized)\n"
            }
        }
        
        log(level: .info, message: logMessage, service: "OpenAIService")
    }
    
    /// Logger une réponse API
    /// - Parameters:
    ///   - statusCode: Code de statut HTTP
    ///   - responseTime: Temps de réponse en secondes
    ///   - tokens: Nombre de tokens utilisés (optionnel)
    ///   - responsePreview: Aperçu de la réponse (optionnel)
    static func logResponse(statusCode: Int, responseTime: TimeInterval, tokens: (prompt: Int, completion: Int, total: Int)? = nil, responsePreview: String? = nil) {
        var logMessage = "📥 Réponse \(statusCode) reçue en \(String(format: "%.2f", responseTime))s\n"
        
        if let tokens = tokens {
            logMessage += "   Tokens: Prompt=\(tokens.prompt), Completion=\(tokens.completion), Total=\(tokens.total)\n"
        }
        
        if let preview = responsePreview {
            logMessage += "   Aperçu: \(preview.prefix(200))...\n"
        }
        
        let level: LogLevel = statusCode >= 200 && statusCode < 300 ? .info : .error
        log(level: level, message: logMessage, service: "OpenAIService")
    }
    
    /// Logger une erreur
    /// - Parameters:
    ///   - error: Erreur à logger
    ///   - context: Contexte supplémentaire
    static func logError(_ error: Error, context: String? = nil) {
        var message = "Erreur: \(error.localizedDescription)"
        if let context = context {
            message += " | Contexte: \(context)"
        }
        log(level: .error, message: message, service: "OpenAIService")
    }
    
    /// Obtenir le chemin vers le dossier de logs
    static func getLogDirectoryPath() -> String? {
        return logDirectory?.path
    }
    
    /// Lister les fichiers de logs disponibles
    static func listLogFiles() -> [URL] {
        guard let logDir = logDirectory else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
    }
    
    /// Supprimer les logs plus anciens que X jours
    /// - Parameter days: Nombre de jours à conserver
    static func cleanOldLogs(olderThanDays days: Int = 7) {
        guard let logDir = logDirectory else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
        
        for file in files where file.pathExtension == "log" {
            if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
               let creationDate = attributes.creationDate,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
                log(level: .info, message: "Fichier de log supprimé: \(file.lastPathComponent)", service: "APILogger")
            }
        }
    }
}

// Extension pour ajouter des données à un fichier
extension Data {
    func append(to url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url, options: .atomic)
        }
    }
}

