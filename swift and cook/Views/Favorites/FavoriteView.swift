//
//  FavoriteView.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import SwiftUI

struct FavoriteView: View {
    @Binding var currentUser: User?
    @Binding var connecter: Bool
    
    @State private var numberOfPersons = 2
    
    @EnvironmentObject var storageManager: StorageManager
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("My favorite recipes") {
                    if storageManager.likedData.likedRecipes.isEmpty {
                        ContentUnavailableView(
                            "No recipe",
                            systemImage: "fork.knife",
                            description: Text("Like recipes to add them here.")
                        )
                    } else {
                        ForEach(storageManager.likedData.sortedRecipes, id: \.recipe.id) { likedItem in
                            NavigationLink(destination: RecipeDetailView(recipe: likedItem.recipe, numberOfPersons: numberOfPersons, isFromFavorites: true)) {
                                HStack(spacing: 12) {
                                    // Image miniature
                                    Image(likedItem.recipe.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                        .clipped()
                                    
                                    // Titre
                                    Text(likedItem.recipe.localizedTitle)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Temps de préparation
                                    let prepTime = likedItem.recipe.prepTime
                                    if prepTime > 0 {
                                        Label("\(prepTime) min", systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    storageManager.unlikedRecipe(likedItem.recipe, token: jwtToken)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                        .tint(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
        }
        .onAppear {
            if let servings = currentUser?.defaultServings {
                numberOfPersons = servings
            } else {
                numberOfPersons = 2
            }
        }
        .task {
            guard !jwtToken.isEmpty else { return }
            await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromFavorite: true)
        }
        .refreshable {
            guard !jwtToken.isEmpty else { return }
            await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromFavorite: true)
        }
    }
}

#Preview {
    FavoriteView(currentUser: .constant(nil), connecter: .constant(false))
        .environmentObject(StorageManager())
}
