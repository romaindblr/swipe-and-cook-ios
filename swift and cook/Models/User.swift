//
//  User.swift
//  swift and cook
//
//  Created by Romain Doublier on 02/10/2026.
//

import Foundation

// MARK: - Requêtes d'Authentification

/// Modèle envoyé à l'API lors de la création de compte
struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
    let defaultServings: Int
    
    enum CodingKeys: String, CodingKey {
        case email, password
        case displayName = "display_name"
        case defaultServings = "default_servings"
    }
}

/// Modèle envoyé à l'API lors de la connexion
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// MARK: - Réponses d'Authentification

/// Réponse retournée par Express lors d'un Login ou Register réussi (Contient le JWT + Infos User)
struct AuthResponse: Decodable {
    let token: String
    let user: User
}

/// Structure représentant l'utilisateur connecté
struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let defaultServings: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case defaultServings = "default_servings"
    }
}

extension User {
    private static let cacheKey = "cachedUser"

    static func loadCached() -> User? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    static func saveCache(_ user: User?) {
        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }
}


// MARK: - Erreur API
/// Modèle pour intercepter et lire la clé {"error": "..."} renvoyée par le serveur Express
struct APIErrorResponse: Decodable {
    let error: String
}

enum AuthError: LocalizedError {
    case invalidURL
    case emailAlreadyExists
    case invalidCredentials
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL d'API invalide."
        case .emailAlreadyExists:
            return "Cet email est déjà utilisé."
        case .invalidCredentials:
            return "Email ou mot de passe incorrect."
        case .serverError(let message):
            return message
        }
    }
}
