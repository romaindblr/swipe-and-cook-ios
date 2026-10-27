//
//  CartView.swift
//  swift and cook
//

import SwiftUI

struct CartView: View {
    @EnvironmentObject var storageManager: StorageManager
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    // 💡 On stocke le NOM de l'ingrédient (qui est stable) plutôt que l'UUID
    @State private var checkedIngredientNames: Set<String> = []
    @State private var showConfirmationAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // SECTION 1 : Recettes de la semaine
                Section("Recipes of the week") {
                    if storageManager.cartData.savedRecipes.isEmpty {
                        ContentUnavailableView(
                            "No recipe",
                            systemImage: "fork.knife",
                            description: Text("Swipe recipes to the right to add them here.")
                        )
                    } else {
                        ForEach(storageManager.cartData.savedRecipes) { savedItem in
                            NavigationLink(destination: RecipeDetailView(recipe: savedItem.recipe, numberOfPersons: savedItem.numberOfPersons, isFromCart: true)) {
                                HStack {
                                    // Image miniature
                                    Image(savedItem.recipe.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                        .clipped()
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(savedItem.recipe.localizedTitle)
                                            .font(.headline)
                                        Text("\(savedItem.numberOfPersons) \(savedItem.numberOfPersons > 1 ? Text("people") : Text("person"))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    let prepTime = savedItem.recipe.prepTime
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
                                    storageManager.removeRecipe(savedItem, token: jwtToken)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                        .tint(.red)
                                }
                            }
                        }
                    }
                }
                
                // SECTION 2 : Liste de courses avec coche et raye
                Section("Shopping list") {
                    let ingredients = storageManager.cartData.shoppingList
                    
                    if ingredients.isEmpty {
                        Text("Your shopping list is empty.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ingredients) { ingredient in
                            let key = ingredient.localizedingredientname
                            
                            IngredientRowView(
                                ingredient: ingredient,
                                isChecked: checkedIngredientNames.contains(key),
                                onToggle: {
                                    toggleCheck(for: key)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("My Cart")
            .toolbar {
                if !storageManager.cartData.savedRecipes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear all", role: .destructive) {
                            showConfirmationAlert = true
                        }
                        .alert("Are you sure?", isPresented: $showConfirmationAlert) {
                            Button("Empty", role: .destructive) {
                                showConfirmationAlert = false
                                withAnimation {
                                    storageManager.clearCart(token: jwtToken)
                                    checkedIngredientNames.removeAll()
                                }
                            }
                            Button("Cancel", role: .cancel) {
                                showConfirmationAlert = false
                            }
                        } message: {
                            Text("This action will remove all recipes from your cart.")
                        }
                    }
                }
            }
        }
        .task {
            guard !jwtToken.isEmpty else { return }
            await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromCart: true)
        }
        .refreshable {
            guard !jwtToken.isEmpty else { return }
            await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromCart: true)
        }
    }
    
    private func toggleCheck(for name: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if checkedIngredientNames.contains(name) {
                checkedIngredientNames.remove(name)
            } else {
                checkedIngredientNames.insert(name)
            }
        }
    }
}

// Sous-vue extraite pour le row
struct IngredientRowView: View {
    let ingredient: CartIngredient
    let isChecked: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? .orange : .gray)
            }
            .buttonStyle(.borderless)
            
            Text(ingredient.localizedingredientname)
                .strikethrough(isChecked, color: .secondary)
                .foregroundStyle(isChecked ? .secondary : .primary)
            
            Spacer()
            
            let totalQuantity = ingredient.totalQuantity
            
            if ingredient.unit == "g" {
                Text(totalQuantity >= 1000 ? "\(String(format: "%g", totalQuantity/1000)) kg" : "\(String(format: "%g", totalQuantity)) g")
                    .bold()
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundStyle(isChecked ? Color.secondary : Color.orange)
            }
            else if ingredient.unit == "ml" {
                Text(totalQuantity >= 1000 ? "\(String(format: "%g", totalQuantity/1000)) L" : "\(String(format: "%g", totalQuantity)) ml")
                    .bold()
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundStyle(isChecked ? Color.secondary : Color.orange)
            }
            else if ingredient.unit == "cl" {
                Text(totalQuantity >= 100 ? "\(String(format: "%g", totalQuantity/100)) L" : "\(String(format: "%g", totalQuantity)) cl")
                    .bold()
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundStyle(isChecked ? Color.secondary : Color.orange)
            }
            else {
                Text(totalQuantity <= 1 ? "\(String(format: "%g", totalQuantity)) \(ingredient.unit)" : "\(String(format: "%g", totalQuantity)) \(ingredient.units)")
                    .bold()
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundStyle(isChecked ? Color.secondary : Color.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
