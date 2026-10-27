//
//  APIService.swift
//  swift and cook
//
//  Created by Romain Doublier on 02/10/2026.
//

import Foundation

struct CartItemPayload: Encodable {
    let recipeId: UUID
    let numberOfPersons: Int
}

private struct UpdateServingsBody: Encodable {
    let defaultServings: Int

    enum CodingKeys: String, CodingKey {
        case defaultServings = "default_servings"
    }
}

private struct AddCartBody: Encodable {
    let items: [CartItemPayload]
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://hosted-childrens-copyrighted-reasons.trycloudflare.com/api"

    //MARK: ---RECIPE---
    func fetchRecipes(recipeID: String? = nil, tag: String? = nil, search: String? = nil, random: Bool = false, limit: Int? = nil) async throws -> [Recipe] {
        var components = URLComponents(string: "\(baseURL)/recipes")
        var queryItems: [URLQueryItem] = []

        if let recipeID = recipeID {
            queryItems.append(URLQueryItem(name: "recipeID", value: recipeID))
        }
        if let tag = tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if random {
            queryItems.append(URLQueryItem(name: "random", value: "true"))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([Recipe].self, from: data)
    }
    
    func fetchRecipeDetail(id: UUID) async throws -> Recipe {
        guard let url = URL(string: "\(baseURL)/recipes/\(id.uuidString)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Recipe.self, from: data)
    }
    
    //MARK: ---CART---
    func fetchCart(token: String) async throws -> [SavedRecipe] {
        guard let url = URL(string: "\(baseURL)/users/cart") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 💡 Décodage direct du tableau [SavedRecipe], exactement comme pour les favoris !
        let decoder = JSONDecoder()
        return try decoder.decode([SavedRecipe].self, from: data)
    }
    
    func addCart(items: [CartItemPayload], token: String) async throws {
        guard !items.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/users/cart/add") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AddCartBody(items: items))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
            print("Erreur ajout panier backend: \(errorJson)")
            throw URLError(.badServerResponse)
        }
    }
    
    func removeCart(recipeIds: [UUID], token: String) async throws {
        guard !recipeIds.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/users/cart/remove") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: [String]] = ["recipeIds": recipeIds.map { $0.uuidString }]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
            print("Erreur suppression batch backend: \(errorJson)")
            throw URLError(.badServerResponse)
        }
    }
    
    func clearCart(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/users/cart/clear") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    //MARK: ---Favorites---
    func fetchFavorites(token: String) async throws -> [Recipe] {
        guard let url = URL(string: "\(baseURL)/users/favorites") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print(" Status Code GET favorites: \(httpResponse.statusCode)")
            
            // Si ce n'est pas 200, on affiche la réponse du serveur Express
            if httpResponse.statusCode != 200 {
                let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
                print(" Serveur Reponse: \(errorJson)")
                throw URLError(.badServerResponse)
            }
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Recipe].self, from: data)
    }
    
    func addFavorites(recipeIds: [UUID], token: String) async throws {
        guard let url = URL(string: "\(baseURL)/users/favorites/add") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: [String]] = ["recipeIds": recipeIds.map { $0.uuidString }]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print(" Status Code POST batch: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
                print(" Serveur Reponse Batch: \(errorJson)")
                throw URLError(.badServerResponse)
            }
        }
    }
    
    func removeFavorites(recipeIds: [UUID], token: String) async throws {
        guard !recipeIds.isEmpty else { return }
        guard let url = URL(string: "\(baseURL)/users/favorites/remove") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: [String]] = ["recipeIds": recipeIds.map { $0.uuidString }]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
            print("Erreur suppression batch backend: \(errorJson)")
            throw URLError(.badServerResponse)
        }
    }
    
    //MARK: ---USER---
    func registerUser(_ body: RegisterRequest) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/users/register") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encodage automatique grâce au paramètre body (RegisterRequest)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Réponse réseau invalide")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        case 409:
            throw AuthError.emailAlreadyExists
        default:
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AuthError.serverError(apiError.error)
            }
            throw AuthError.serverError("Erreur serveur (\(httpResponse.statusCode))")
        }
    }
    
    /// Connexion d'un utilisateur existant
    func loginUser(_ body: LoginRequest) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/users/login") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encodage automatique du body (LoginRequest: email + password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Réponse réseau invalide")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Décodage de la réponse { token: "...", user: { ... } }
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        case 401:
            // Identifiants incorrects (email non trouvé ou mauvais mot de passe)
            throw AuthError.invalidCredentials
        default:
            // Tente de décoder le message d'erreur JSON renvoyé par Express
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AuthError.serverError(apiError.error)
            }
            throw AuthError.serverError("Erreur serveur (\(httpResponse.statusCode))")
        }
    }
    
    /// Récupère les données de l'utilisateur connecté via son token JWT
    func fetchCurrentUser(token: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/me") else { throw AuthError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)   // hors-ligne : URLError

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.serverError("Réponse réseau invalide")
        }
        switch http.statusCode {
        case 200: return try JSONDecoder().decode(User.self, from: data)
        case 401, 403: throw AuthError.invalidCredentials      // seul cas = vraie déconnexion
        default: throw AuthError.serverError("Erreur serveur (\(http.statusCode))")
        }
    }
    
    /// Met à jour le nombre de personnes par défaut et renvoie l'utilisateur à jour
    func updateDefaultServings(_ servings: Int, token: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/users/me") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UpdateServingsBody(defaultServings: servings))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorJson = String(data: data, encoding: .utf8) ?? "Inconnu"
            print("Erreur mise à jour servings: \(errorJson)")
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(User.self, from: data)
    }
}


extension APIService {
    
    /// Synchronise l'ensemble des données utilisateur (Profil, Favoris, Panier)
    /// - Parameter token: Token JWT de l'utilisateur connecté
    /// - Returns: L'objet User mis à jour, ou nil si hors-ligne/non connecté
    @discardableResult
    func syncData(token: String, storageManager: StorageManager, fromContent: Bool = false, fromFavorite: Bool = false, fromCart: Bool = false) async -> User? {
        guard !token.isEmpty else { return nil }
        
        do {
            if fromContent{
                let user = try await fetchCurrentUser(token: token)
                return user
            }
            if fromFavorite{
                await storageManager.syncFavoritesFromBackend(token: token)
            }
            if fromCart {
                await storageManager.syncCartFromBackend(token: token)
            }
            return nil
        } catch {
            return nil
        }
    }
}

enum SessionResult {
    case valid(User)
    case expired      // le serveur a refusé le token
    case offline      // impossible de savoir : on garde la session
}

extension APIService {
    func checkSession(token: String) async -> SessionResult {
        guard !token.isEmpty else { return .expired }
        do {
            return .valid(try await fetchCurrentUser(token: token))
        } catch AuthError.invalidCredentials {
            return .expired
        } catch {
            return .offline
        }
    }
}
