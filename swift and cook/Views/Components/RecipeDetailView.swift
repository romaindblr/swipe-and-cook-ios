//
//  RecipeDetailView.swift
//  swift and cook
//
//  Created by Romain Doublier on 26/09/2026.
//

import SwiftUI

struct RecipeDetailView: View {
    var recipe: Recipe
    let isFromFavorites: Bool
    let isFromSwipe: Bool
    let isFromCart: Bool
    let isFromSearch: Bool
    
    let init_number: Int
    let changeNumberOfPersons: Bool
    
    @EnvironmentObject var storageManager: StorageManager
    @Binding var numberOfPersons: Int
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    @State private var currentPersons: Int = 2
    @State private var showAddedToast = false
    @AppStorage("selectedLanguage") private var selectedLanguage = "fr"
    
    // 1. Initialiseur standard
    init(recipe: Recipe, numberOfPersons: Int = 2, isFromFavorites: Bool = false, isFromSwipe: Bool = false, isFromCart: Bool = false, isFromSearch: Bool = false) {
        self.recipe = recipe
        self.isFromFavorites = isFromFavorites
        self.isFromSwipe = isFromSwipe
        self.isFromCart = isFromCart
        self.isFromSearch = isFromSearch
        self.init_number = numberOfPersons
        self._numberOfPersons = .constant(numberOfPersons)
        self.changeNumberOfPersons = false
    }

    // 2. Initialiseur dynamique avec Binding
    init(recipe: Recipe, numberOfPersons: Binding<Int>, isFromFavorites: Bool = false, isFromSwipe: Bool = false, isFromCart: Bool = false, isFromSearch: Bool = false) {
        self.recipe = recipe
        self.isFromFavorites = isFromFavorites
        self.isFromSwipe = isFromSwipe
        self.isFromCart = isFromCart
        self.isFromSearch = isFromSearch
        self.init_number = numberOfPersons.wrappedValue
        self._numberOfPersons = numberOfPersons
        self.changeNumberOfPersons = false
    }
    
    var isLiked: Bool {
        storageManager.likedData.likedRecipes.contains(where: { $0.recipe.id == recipe.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image d'en-tête
                headerImage
                
                // Titre
                Text(recipe.localizedTitle)
                    .font(.largeTitle)
                    .bold()
                
                // Temps de préparation
                let prepTime = recipe.prepTime
                if  prepTime > 0 {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                        
                        if prepTime > 60 {
                            let hours = prepTime / 60
                            let minutes = prepTime % 60
                            Text(minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min")
                                .bold()
                        } else {
                            Text("\(prepTime) min")
                                .bold()
                        }
                    }
                    .font(.headline)
                }
                
                Divider()
                
                // Sélecteur de personnes
                personStepperSection
                
                // Bouton d'édition du panier
                if isFromCart && currentPersons != init_number {
                    Button {
                        storageManager.updateRecipePersons(
                                    for: recipe.id,
                                    newNumberOfPersons: currentPersons,
                                    token: jwtToken
                                )
                    } label: {
                        Label("Edit cart", systemImage: "pencil.line")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                // Bouton d'ajout au panier depuis la recherche ou les favoris
                if isFromFavorites || isFromSearch {
                    Button {
                        storageManager.addRecipe(recipe, numberOfPersons: currentPersons)
                        
                        withAnimation { showAddedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showAddedToast = false }
                        }
                    } label: {
                        Label("Add to cart", systemImage: "cart.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    if showAddedToast {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Added to cart (\(currentPersons) pers.)")
                            Spacer()
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                Divider()
                
                // Section Ingrédients
                ingredientsSection
                
                Divider()
                
                // Section Instructions
                instructionsSection
            }
            .padding()
        }
        .onAppear {
            currentPersons = numberOfPersons
        }
        .onChange(of: currentPersons) { _, newValue in
            numberOfPersons = newValue
        }
        .navigationTitle(recipe.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        if isLiked {
                            storageManager.unlikedRecipe(recipe, token: jwtToken)
                        } else {
                            storageManager.likedRecipe(recipe, token: jwtToken)
                        }
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .orange)
                        .font(.title3)
                }
            }
        }
    }
    
    // MARK: - Sous-vues extraites pour la compilation
    
    private var headerImage: some View {
        let isStandardRatio = isFromSwipe || UIDevice.current.userInterfaceIdiom != .pad
        let heightMultiplier: CGFloat = isStandardRatio ? 0.7 : 0.5
        let aspectRatioValue: CGFloat = 1 / heightMultiplier

        return GeometryReader { geometry in
            let imageWidth = geometry.size.width
            let imageHeight = imageWidth * heightMultiplier
            
            Image(recipe.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .cornerRadius(15)
        }
        .aspectRatio(aspectRatioValue, contentMode: .fit)
    }

    private var personStepperSection: some View {
        HStack {
            Text("For")
                .font(.title3)
                .bold()
            Spacer()
            Stepper("", value: $currentPersons, in: 1...20)
                .labelsHidden()
            Text("\(currentPersons) \(currentPersons > 1 ? Text("people") : Text("person"))")
                .bold()
                .foregroundStyle(.orange)
                .frame(width: 110, alignment: .trailing)
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.title2)
                .bold()
            
            ForEach(recipe.ingredients ?? []) { ingredient in
                IngredientDetailRow(ingredient: ingredient, persons: currentPersons)
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions")
                .font(.title2)
                .bold()
            
            let instructions = (selectedLanguage == "en" ? recipe.instructionsEn : recipe.instructionsFr)
            
            ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .bold()
                        .foregroundStyle(.orange)
                    Text(step)
                        .font(.body)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// Sous-vue dédiée au rendu d'un ingrédient (soulage le vérificateur de types)
struct IngredientDetailRow: View {
    let ingredient: Ingredient
    let persons: Int
    @AppStorage("selectedLanguage") private var selectedLanguage = "fr"

    var body: some View {
        let totalQuantity = ingredient.quantity * Double(persons)
        let name = selectedLanguage == "en" ? ingredient.nameEn : ingredient.nameFr
        
        HStack {
            Text("• \(name)")
            Spacer()
            if ingredient.unit == "g" {
                Text(totalQuantity >= 1000 ? "\(String(format: "%g", totalQuantity/1000)) kg" : "\(String(format: "%g", totalQuantity)) g")
                    .foregroundStyle(.secondary)
            }
            else if ingredient.unit == "ml" {
                Text(totalQuantity >= 1000 ? "\(String(format: "%g", totalQuantity/1000)) L" : "\(String(format: "%g", totalQuantity)) ml")
                    .foregroundStyle(.secondary)
            }
            else if ingredient.unit == "cl" {
                Text(totalQuantity >= 100 ? "\(String(format: "%g", totalQuantity/100)) L" : "\(String(format: "%g", totalQuantity)) cl")
                    .foregroundStyle(.secondary)
            }
            else {
                Text(totalQuantity <= 1 ? "\(String(format: "%g", totalQuantity)) \(ingredient.unit)" : "\(String(format: "%g", totalQuantity)) \(ingredient.units)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
