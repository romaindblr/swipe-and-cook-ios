//
//  Recipe.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import Foundation

struct Ingredient: Codable, Identifiable {
    let id: UUID
    let idRecipe: UUID
    let nameFr: String
    let nameEn: String
    let quantityString: String // Si la DB renvoie une chaîne
    let unit: String
    let units: String
    
    // Propriété calculée pour obtenir un Double facilement
    var quantity: Double {
        Double(quantityString) ?? 0.0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case idRecipe = "recipe_id"
        case nameFr = "name_fr"
        case nameEn = "name_en"
        case quantityString = "quantity"
        case unit
        case units
    }
}

extension Ingredient {
    /// Renvoie automatiquement le titre adapté à la langue du système
    var localizedingredientname: String {
        // Lit directement la langue enregistrée via AppStorage (défaut "fr")
        let selectedLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "fr"
        return selectedLang == "en" ? nameEn : nameFr
    }
}

struct Recipe: Codable, Identifiable {
    let id: UUID
    let titleEn: String
    let titleFr: String
    let imageName: String
    let prepTime: Int
    let instructionsEn: [String]
    let instructionsFr: [String]
    let tags: [String]
    let createdAt: String
    let ingredients: [Ingredient]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case titleEn = "title_en"
        case titleFr = "title_fr"
        case imageName = "image_name"
        case prepTime = "prep_time"
        case instructionsEn = "instructions_en"
        case instructionsFr = "instructions_fr"
        case tags
        case createdAt = "created_at"
        case ingredients
    }
}

extension Recipe {
    /// Renvoie automatiquement le titre adapté à la langue du système
    var localizedTitle: String {
        // Lit directement la langue enregistrée via AppStorage (défaut "fr")
        let selectedLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "fr"
        return selectedLang == "en" ? titleEn : titleFr
    }
    
    var localizedInstructions: [String] {
        let selectedLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "fr"
        return selectedLang == "en" ? instructionsEn : instructionsFr
    }
}

struct SavedRecipe: Identifiable, Codable {
    let recipe: Recipe
    var numberOfPersons: Int

    // Identifiant stable = id de la recette (unique par user dans user_cart)
    var id: UUID { recipe.id }
}

extension SavedRecipe {
    enum CodingKeys: String, CodingKey {
        case numberOfPersons = "number_of_persons"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.numberOfPersons = try container.decodeIfPresent(Int.self, forKey: .numberOfPersons) ?? 2
        self.recipe = try Recipe(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numberOfPersons, forKey: .numberOfPersons)
        try recipe.encode(to: encoder) // même format "à plat" que celui renvoyé par l'API
    }
}

struct CartIngredient: Identifiable, Codable {
    var id = UUID()
    let idRecipe: UUID
    let nameEn: String
    let nameFr: String
    var totalQuantity: Double
    let unit: String
    let units: String
}

extension CartIngredient {
    /// Renvoie automatiquement le titre adapté à la langue du système
    var localizedingredientname: String {
        let selectedLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "fr"
        return selectedLang == "en" ? nameEn : nameFr
    }
}

struct LikedRecipe: Identifiable, Codable {
    var id = UUID()
    let recipe: Recipe
}

struct CartData: Codable {
    var savedRecipes: [SavedRecipe] = []
    
    var shoppingList: [CartIngredient] {
        // Clé unique : identifiant de l'ingrédient (nameEn + unit)
        var grouped: [String: (idRecipe: UUID, nameEn: String, nameFr: String, quantity: Double, unit: String, units: String)] = [:]
        
        for saved in savedRecipes {
            for ing in saved.recipe.ingredients ?? [] {
                let totalForRecipe = ing.quantity * Double(saved.numberOfPersons)
                let key = "\(ing.nameEn)_\(ing.unit)"
                
                if let current = grouped[key] {
                    grouped[key] = (ing.idRecipe, ing.nameEn, ing.nameFr, current.quantity + totalForRecipe, ing.unit, ing.units)
                } else {
                    grouped[key] = (ing.idRecipe,ing.nameEn, ing.nameFr, totalForRecipe, ing.unit, ing.units)
                }
            }
        }
        
        return grouped.map { _, details in
            CartIngredient(
                idRecipe: details.idRecipe,
                nameEn: details.nameEn,
                nameFr: details.nameFr,
                totalQuantity: details.quantity,
                unit: details.unit,
                units: details.units
            )
        }
        .sorted { lhs, rhs in
            if lhs.idRecipe != rhs.idRecipe {
                return lhs.idRecipe.uuidString < rhs.idRecipe.uuidString
            }
            return lhs.localizedingredientname < rhs.localizedingredientname
        }
    }
}

struct LikedData: Codable {
    var likedRecipes: [LikedRecipe] = []
    
    var sortedRecipes: [LikedRecipe] {
            likedRecipes.sorted {
                $0.recipe.localizedTitle.localizedCaseInsensitiveCompare($1.recipe.localizedTitle) == .orderedAscending
            }
        }
}

