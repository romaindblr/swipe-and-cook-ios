//
//  StorageManager.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import SwiftUI
import Combine

@MainActor
class StorageManager: ObservableObject {
    @Published var cartData: CartData = CartData() {
        didSet { saveCartToJSON() }
    }
    
    @Published var likedData: LikedData = LikedData() {
        didSet { saveLikedToJSON() }
    }
    
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    private var pending = PendingStore() { didSet { savePending() } }
    private let pendingFileName = "saved_pending.json"
    enum PendingAction: String, Codable { case add, remove }

    private struct PendingStore: Codable {
        var liked: [UUID: PendingAction] = [:]
        var cart: [UUID: PendingAction] = [:]
    }
    
    private var pendingLiked: [UUID: PendingAction] {
        get { pending.liked }
        set { pending.liked = newValue }
    }

    private var pendingCart: [UUID: PendingAction] {
        get { pending.cart }
        set { pending.cart = newValue }
    }

    private func ids(in pending: [UUID: PendingAction], for action: PendingAction) -> [UUID] {
        pending.filter { $0.value == action }.map(\.key)
    }
    
    private let cartFileName = "saved_cart.json"
    private let likedFileName = "saved_liked.json"
    
    init() {
        loadAllFromJSON()
        loadPending()
    }
    
    private func getFileURL(for fileName: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    //MARK: --- SAUVEGARDE & CHARGEMENT ---
    private func savePending() {
        do {
            let data = try JSONEncoder().encode(pending)
            try data.write(to: getFileURL(for: pendingFileName), options: [.atomic, .completeFileProtection])
        } catch {
            print("Erreur sauvegarde pending : \(error)")
        }
    }

    private func loadPending() {
        let url = getFileURL(for: pendingFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PendingStore.self, from: data) {
            pending = decoded
        }
    }
    
    private func saveCartToJSON() {
        do {
            let data = try JSONEncoder().encode(cartData)
            try data.write(to: getFileURL(for: cartFileName), options: [.atomic, .completeFileProtection])
        } catch {
            print("Erreur sauvegarde panier : \(error.localizedDescription)")
        }
    }
    
    private func saveLikedToJSON() {
        do {
            let data = try JSONEncoder().encode(likedData)
            try data.write(to: getFileURL(for: likedFileName), options: [.atomic, .completeFileProtection])
        } catch {
            print("Erreur sauvegarde favoris : \(error.localizedDescription)")
        }
    }
    
    private func loadAllFromJSON() {
        // Chargement du panier
        let cartURL = getFileURL(for: cartFileName)
        if FileManager.default.fileExists(atPath: cartURL.path) {
            if let data = try? Data(contentsOf: cartURL),
               let decoded = try? JSONDecoder().decode(CartData.self, from: data) {
                cartData = decoded
            }
        }
        
        // Chargement des favoris
        let likedURL = getFileURL(for: likedFileName)
        if FileManager.default.fileExists(atPath: likedURL.path) {
            if let data = try? Data(contentsOf: likedURL),
               let decoded = try? JSONDecoder().decode(LikedData.self, from: data) {
                likedData = decoded
            }
        }
    }
    
    func fetchFullRecipe(_ recipe: Recipe) async throws -> Recipe {
        return try await APIService.shared.fetchRecipeDetail(id: recipe.id)
    }
    
    //MARK: --- ACTIONS PANIER ---
    func syncCartFromBackend(token: String) async {
        guard !token.isEmpty, jwtToken == token else { return }

        let toAdd = ids(in: pendingCart, for: .add)
        if !toAdd.isEmpty {
            let items = toAdd.compactMap { id in
                cartData.savedRecipes.first(where: { $0.recipe.id == id }).map {
                    CartItemPayload(recipeId: id, numberOfPersons: $0.numberOfPersons)
                }
            }
            do {
                try await APIService.shared.addCart(items: items, token: token)
                for id in toAdd where pendingCart[id] == .add { pendingCart[id] = nil }
            } catch {
                print("Purge ajouts panier impossible : \(error)")
            }
        }

        let toRemove = ids(in: pendingCart, for: .remove)
        if !toRemove.isEmpty {
            do {
                try await APIService.shared.removeCart(recipeIds: toRemove, token: token)
                for id in toRemove where pendingCart[id] == .remove { pendingCart[id] = nil }
            } catch {
                print("Purge suppressions panier impossible : \(error)")
            }
        }

        do {
            let fetched = try await APIService.shared.fetchCart(token: token)
            guard jwtToken == token else { return }
            let fetchedIDs = Set(fetched.map { $0.recipe.id })

            for item in fetched {
                let id = item.recipe.id
                if pendingCart[id] == .remove { continue }

                if let index = cartData.savedRecipes.firstIndex(where: { $0.recipe.id == id }) {
                    if pendingCart[id] != .add {
                        cartData.savedRecipes[index].numberOfPersons = item.numberOfPersons
                    }
                } else {
                    addRecipe(item.recipe, numberOfPersons: item.numberOfPersons, fromSync: true)
                }
            }

            cartData.savedRecipes.removeAll {
                !fetchedIDs.contains($0.recipe.id) && pendingCart[$0.recipe.id] != .add
            }
        } catch {
            print("Erreur sync panier : \(error)")
        }
    }

    func addRecipe(_ recipe: Recipe, numberOfPersons: Int, token: String? = nil, fromSync: Bool = false) {
        if let index = cartData.savedRecipes.firstIndex(where: { $0.recipe.id == recipe.id }) {
            cartData.savedRecipes[index].numberOfPersons = numberOfPersons
        } else {
            cartData.savedRecipes.append(SavedRecipe(recipe: recipe, numberOfPersons: numberOfPersons))
        }

        guard !fromSync else { return }
        pendingCart[recipe.id] = .add

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.addCart(
                    items: [CartItemPayload(recipeId: recipe.id, numberOfPersons: numberOfPersons)],
                    token: token
                )
                if pendingCart[recipe.id] == .add { pendingCart[recipe.id] = nil }
            } catch {
                print("Cart sync failed: \(error)")
            }
        }
    }

    func removeRecipe(_ savedRecipe: SavedRecipe, token: String? = nil, fromSync: Bool = false) {
        let id = savedRecipe.recipe.id
        cartData.savedRecipes.removeAll { $0.recipe.id == id }

        guard !fromSync else { return }
        pendingCart[id] = .remove

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.removeCart(recipeIds: [id], token: token)
                if pendingCart[id] == .remove { pendingCart[id] = nil }
            } catch {
                print("Cart sync failed: \(error)")
            }
        }
    }

    func updateRecipePersons(for recipeID: UUID, newNumberOfPersons: Int, token: String? = nil) {
        guard newNumberOfPersons >= 1,
              let index = cartData.savedRecipes.firstIndex(where: { $0.recipe.id == recipeID }) else { return }

        cartData.savedRecipes[index].numberOfPersons = newNumberOfPersons
        pendingCart[recipeID] = .add

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.addCart(
                    items: [CartItemPayload(recipeId: recipeID, numberOfPersons: newNumberOfPersons)],
                    token: token
                )
                if pendingCart[recipeID] == .add { pendingCart[recipeID] = nil }
            } catch {
                print("Cart sync failed: \(error)")
            }
        }
    }

    func clearCart(token: String? = nil) {
        let ids = cartData.savedRecipes.map { $0.recipe.id }
        cartData = CartData()
        pendingCart = Dictionary(uniqueKeysWithValues: ids.map { ($0, PendingAction.remove) })

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.clearCart(token: token)
                pendingCart = [:]
            } catch {
                print("Cart sync failed: \(error)")
            }
        }
    }

    func clearAllData() {
        cartData = CartData()
        likedData = LikedData()
        pending = PendingStore()
    }
    
    //MARK: --- ACTIONS FAVORIS ---
    func syncFavoritesFromBackend(token: String) async {
        guard !token.isEmpty, jwtToken == token else { return }

        let toAdd = ids(in: pendingLiked, for: .add)
        if !toAdd.isEmpty {
            do {
                try await APIService.shared.addFavorites(recipeIds: toAdd, token: token)
                // On ne purge que ce qui n'a pas changé pendant la requête
                for id in toAdd where pendingLiked[id] == .add { pendingLiked[id] = nil }
            } catch {
                print("Purge ajouts favoris impossible : \(error)")
            }
        }

        let toRemove = ids(in: pendingLiked, for: .remove)
        if !toRemove.isEmpty {
            do {
                try await APIService.shared.removeFavorites(recipeIds: toRemove, token: token)
                for id in toRemove where pendingLiked[id] == .remove { pendingLiked[id] = nil }
            } catch {
                print("Purge suppressions favoris impossible : \(error)")
            }
        }

        do {
            let fetched = try await APIService.shared.fetchFavorites(token: token)
            guard jwtToken == token else { return }   // déconnecté pendant la requête
            let fetchedIDs = Set(fetched.map { $0.id })

            for recipe in fetched
            where !likedData.likedRecipes.contains(where: { $0.recipe.id == recipe.id })
                && pendingLiked[recipe.id] != .remove {
                likedRecipe(recipe, fromSync: true)
            }

            likedData.likedRecipes.removeAll {
                !fetchedIDs.contains($0.recipe.id) && pendingLiked[$0.recipe.id] != .add
            }
        } catch {
            print("Erreur sync favoris : \(error)")
        }
    }

    func likedRecipe(_ recipe: Recipe, token: String? = nil, fromSync: Bool = false) {
        guard !likedData.likedRecipes.contains(where: { $0.recipe.id == recipe.id }) else { return }
        likedData.likedRecipes.append(LikedRecipe(recipe: recipe))

        guard !fromSync else { return }
        pendingLiked[recipe.id] = .add

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.addFavorites(recipeIds: [recipe.id], token: token)
                if pendingLiked[recipe.id] == .add { pendingLiked[recipe.id] = nil }
            } catch {
                print("Fav sync failed: \(error)")
            }
        }
    }

    func unlikedRecipe(_ recipe: Recipe, token: String? = nil, fromSync: Bool = false) {
        likedData.likedRecipes.removeAll { $0.recipe.id == recipe.id }

        guard !fromSync else { return }
        pendingLiked[recipe.id] = .remove

        guard let token, !token.isEmpty else { return }
        Task {
            do {
                try await APIService.shared.removeFavorites(recipeIds: [recipe.id], token: token)
                if pendingLiked[recipe.id] == .remove { pendingLiked[recipe.id] = nil }
            } catch {
                print("Fav sync failed: \(error)")
            }
        }
    }
}
