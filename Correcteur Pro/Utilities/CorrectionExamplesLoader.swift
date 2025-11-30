//
//  CorrectionExamplesLoader.swift
//  Correcteur Pro
//
//  Charge les exemples de correction pour le few-shot learning
//

import Foundation

/// Structure pour les règles de formatage
struct CorrectionRule: Codable {
    let id: String
    let name: String
    let description: String
    let format: String
}

/// Structure pour un exemple individuel
struct CorrectionExample: Codable {
    let category: String
    let input: String
    let output: String
    let explanation: String
}

/// Structure pour un exemple de texte complet
struct FullTextExample: Codable {
    let description: String
    let input: String
    let output: String
}

/// Structure principale du fichier JSON
struct CorrectionExamplesData: Codable {
    let version: String
    let description: String
    let rules: [CorrectionRule]
    let examples: [CorrectionExample]
    let fullTextExamples: [FullTextExample]

    enum CodingKeys: String, CodingKey {
        case version, description, rules, examples
        case fullTextExamples = "full_text_examples"
    }
}

/// Charge et gère les exemples de correction pour le few-shot learning
final class CorrectionExamplesLoader {

    /// Instance partagée (singleton)
    static let shared = CorrectionExamplesLoader()

    /// Données chargées depuis le JSON
    private var data: CorrectionExamplesData?

    private init() {
        loadExamples()
    }

    /// Charge les exemples depuis le fichier JSON
    private func loadExamples() {
        guard let url = Bundle.main.url(forResource: "correction_examples", withExtension: "json") else {
            print("⚠️ [CorrectionExamplesLoader] Fichier correction_examples.json introuvable dans le bundle")
            return
        }

        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            data = try decoder.decode(CorrectionExamplesData.self, from: jsonData)
            print("✅ [CorrectionExamplesLoader] \(data?.examples.count ?? 0) exemples chargés")
        } catch {
            print("❌ [CorrectionExamplesLoader] Erreur de parsing JSON: \(error)")
        }
    }

    /// Retourne tous les exemples
    var allExamples: [CorrectionExample] {
        return data?.examples ?? []
    }

    /// Retourne toutes les règles
    var allRules: [CorrectionRule] {
        return data?.rules ?? []
    }

    /// Retourne tous les exemples de texte complet
    var allFullTextExamples: [FullTextExample] {
        return data?.fullTextExamples ?? []
    }

    /// Retourne un sous-ensemble d'exemples aléatoires
    /// - Parameter count: Nombre d'exemples à retourner
    /// - Returns: Liste d'exemples aléatoires
    func getRandomExamples(count: Int) -> [CorrectionExample] {
        guard let examples = data?.examples, !examples.isEmpty else { return [] }
        return Array(examples.shuffled().prefix(count))
    }

    /// Retourne des exemples variés (un de chaque catégorie principale)
    /// - Parameter maxCount: Nombre maximum d'exemples
    /// - Returns: Liste d'exemples diversifiés
    func getDiverseExamples(maxCount: Int = 8) -> [CorrectionExample] {
        guard let examples = data?.examples, !examples.isEmpty else { return [] }

        // Grouper par catégorie
        var byCategory: [String: [CorrectionExample]] = [:]
        for example in examples {
            byCategory[example.category, default: []].append(example)
        }

        // Prendre un exemple de chaque catégorie
        var result: [CorrectionExample] = []
        for (_, categoryExamples) in byCategory {
            if let example = categoryExamples.randomElement() {
                result.append(example)
            }
            if result.count >= maxCount { break }
        }

        return Array(result.shuffled().prefix(maxCount))
    }

    /// Génère une section d'exemples formatée pour le prompt
    /// - Parameter count: Nombre d'exemples à inclure
    /// - Returns: Texte formaté avec les exemples
    func generateExamplesSection(count: Int = 6) -> String {
        let examples = getDiverseExamples(maxCount: count)
        guard !examples.isEmpty else { return "" }

        var section = "\n\n## EXEMPLES DE CORRECTIONS\n\n"

        for (index, example) in examples.enumerated() {
            section += "### Exemple \(index + 1) - \(example.category)\n"
            section += "**Entrée :** \(example.input)\n"
            section += "**Sortie :** \(example.output)\n\n"
        }

        // Ajouter un exemple de texte complet si disponible
        if let fullExample = data?.fullTextExamples.randomElement() {
            section += "### Exemple de texte complet\n"
            section += "**Entrée :**\n\(fullExample.input)\n\n"
            section += "**Sortie :**\n\(fullExample.output)\n"
        }

        return section
    }

    /// Génère le prompt complet avec exemples intégrés
    /// - Parameter basePrompt: Le prompt de base
    /// - Parameter exampleCount: Nombre d'exemples à ajouter
    /// - Returns: Prompt enrichi avec exemples
    func enrichPromptWithExamples(_ basePrompt: String, exampleCount: Int = 6) -> String {
        let examplesSection = generateExamplesSection(count: exampleCount)
        return basePrompt + examplesSection
    }
}
