//
//  SearchView.swift
//  swift and cook
//
//  Created by Romain Doublier on 28/09/2026.
//

import SwiftUI

struct SearchView: View {
    @Binding var currentUser: User?
    
    @State private var numberOfPersons = 2
    
    @State private var searchText = ""
    @State private var searchResults: [Recipe] = []
    @State private var isLoading = false
    @EnvironmentObject var storageManager: StorageManager
    
    private func performSearch(query: String) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        Task {
            do {
                // 1. Recherche initiale des recettes
                let basicRecipes = try await APIService.shared.fetchRecipes(search: cleanQuery)
                
                // 2. Chargement en parallèle du détail (avec ingrédients) de chaque recette
                let fullRecipes = try await withThrowingTaskGroup(of: Recipe.self) { group in
                    for recipe in basicRecipes {
                        group.addTask {
                            // Si les ingrédients sont déjà là, on la garde, sinon on va chercher le détail
                            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                                return recipe
                            } else {
                                return try await APIService.shared.fetchRecipeDetail(id: recipe.id)
                            }
                        }
                    }
                    
                    var detailedList: [Recipe] = []
                    for try await detailedRecipe in group {
                        detailedList.append(detailedRecipe)
                    }
                    return detailedList
                }
                
                await MainActor.run {
                    self.searchResults = fullRecipes
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors de la recherche et du chargement des détails : \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.isLoading = false
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Search for a recipe",
                            systemImage: "magnifyingglass",
                            description: Text("Type in the name of a dish or tag to find what you're looking for.")
                        )
                    }
                    .padding(.vertical, 50)
                } else if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Searching...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                .scaleEffect(1.5)
                                .id(UUID())
                            Spacer()
                        }
                        .padding(.vertical, 30)
                    }
                } else if searchResults.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    Section {
                        ForEach(searchResults) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe, numberOfPersons: numberOfPersons, isFromSearch: true)) {
                                HStack(spacing: 15) {
                                    // Miniature de la recette
                                    Image(recipe.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 65, height: 65)
                                        .clipped()
                                        .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(recipe.localizedTitle)
                                            .font(.headline)
                                        
                                        let prepTime = recipe.prepTime
                                        if prepTime > 0 {
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundStyle(.orange)
                                                Text("\(prepTime) min")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Ex: Spaghetti, Tacos, Fast...")
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
        }
        .onAppear {
            if let servings = currentUser?.defaultServings {
                numberOfPersons = servings
            } else {
                numberOfPersons = 2
            }
        }
    }
}

#Preview {
    SearchView(currentUser: .constant(nil))
        .environmentObject(StorageManager())
}
