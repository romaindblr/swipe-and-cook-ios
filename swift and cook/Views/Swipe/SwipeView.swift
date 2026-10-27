//
//  SwipeView.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import SwiftUI

// Structure englobante pour donner un ID unique à chaque carte de la pile
struct SwipeItem: Identifiable {
    let id = UUID()
    let recipe: Recipe
}

struct SwipeView: View {
    @Binding var currentUser: User?
    
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    // 1. La liste des cartes affichées
    @State private var items: [SwipeItem] = []
    
    @State private var offset = CGSize.zero
    @State private var selectedRecipeForPersons: Recipe?
    
    @State private var SwipenumberOfPersons = 2
    @EnvironmentObject var storageManager: StorageManager

    @State private var informationRecipe: Recipe?
    @State private var detailedRecipe: Recipe?
    @State private var isLoading = false

    /// Charge 10 recettes aléatoires depuis le serveur Express
    private func loadRandomRecipes() {
        Task {
            do {
                let fetchedRecipes = try await APIService.shared.fetchRecipes(random: true, limit: 10)
                let newItems = fetchedRecipes.map { SwipeItem(recipe: $0) }
                await MainActor.run {
                    self.items.insert(contentsOf: newItems, at: 0)
                }
            } catch {
                print("Erreur de chargement des recettes : \(error)")
            }
        }
    }
    
    private func getRecipe(recipeId: UUID) async -> Recipe? {
        try? await APIService.shared.fetchRecipeDetail(id: recipeId)
    }

    /// Supprime la carte courante et recharge les recettes si le stock descend à 2 ou moins
    private func removeRecipeAndCheckCount(recipeId: UUID? = nil) {
        if let id = recipeId {
            items.removeAll { $0.recipe.id == id }
        } else if !items.isEmpty {
            items.removeLast()
        }
        
        if items.count <= 2 {
            loadRandomRecipes()
        }
    }

    var body: some View {
        VStack {
            Image("logoHeader")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            Spacer()
            
            if isLoading && items.isEmpty {
                ProgressView("Loading recipe...")
            } else if !items.isEmpty {
                // 📏 Le GeometryReader va calculer la taille de l'écran disponible
                GeometryReader { geometry in
                    let currentWidth = geometry.size.width
                    let isLandscape = currentWidth > geometry.size.height
                    let cardWidth = isLandscape ? min(currentWidth * 0.8, 600 / 1.7) : min(currentWidth * 0.85, 512)
                    let cardHeight = cardWidth * 1.7
                    let scaleFactor = cardWidth / 300.0
                    
                    ZStack {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let isTopCard = index == items.count - 1
                            let recipe = item.recipe
                            
                            VStack(spacing: 20 * scaleFactor) {
                                Text(recipe.localizedTitle)
                                    .font(.system(size: 24 * scaleFactor, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 15 * scaleFactor)
                                    .padding(.horizontal, 10 * scaleFactor)
                                
                                Image(recipe.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: cardHeight * 0.70)
                                    .frame(width: cardWidth * 0.90)
                                    .clipped()
                                    .cornerRadius(15 * scaleFactor)
                                    .padding(.horizontal, 15 * scaleFactor)
                                    .onTapGesture {
                                        informationRecipe = recipe
                                    }
                                
                                HStack (alignment: .firstTextBaseline) {
                                    
                                    Spacer()
                                    
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20 * scaleFactor))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("Swipe left or right")
                                        .font(.system(size: 15 * scaleFactor))
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 15 * scaleFactor)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "heart.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 20 * scaleFactor))
                                    
                                    Spacer()
                                    
                                }
                                .frame(width: cardWidth)
                                
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(20 * scaleFactor)
                            .shadow(color: Color.black.opacity(0.15), radius: 10 * scaleFactor, x: 0, y: 5 * scaleFactor)
                            .offset(x: isTopCard ? offset.width : 0)
                            .rotationEffect(.degrees(isTopCard ? Double(offset.width / 15) : 0))
                            .gesture(
                                isTopCard ?
                                DragGesture()
                                    .onChanged { gesture in
                                        offset = gesture.translation
                                    }
                                    .onEnded { gesture in
                                        if gesture.translation.width > 100 {
                                            selectedRecipeForPersons = recipe
                                            offset = .zero
                                        } else if gesture.translation.width < -100 {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                offset.width = -500
                                            }
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                removeRecipeAndCheckCount(recipeId: recipe.id)
                                                offset = .zero
                                            }
                                        } else {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                            }
                                        }
                                    }
                                : nil
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "No more recipes!",
                    systemImage: "sparkles",
                    description: Text("You've swiped through everything.")
                )
            }
        }
        .onAppear {
            if let servings = currentUser?.defaultServings {
                SwipenumberOfPersons = servings
            } else {
                SwipenumberOfPersons = 2
            }
        }
        .task {
            if items.isEmpty {
                isLoading = true
                loadRandomRecipes()
                isLoading = false
            }
        }
        .padding()
        .sheet(item: $selectedRecipeForPersons) { recipe in
            let isLiked = storageManager.likedData.likedRecipes.contains(where: { $0.recipe.id == recipe.id })
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let scaleFactor: CGFloat = isPad ? 1.4 : 1.0
            
            let fullRecipe = detailedRecipe ?? recipe
            
            VStack(spacing: 20 * scaleFactor) {
                Text("For how many people ?")
                    .font(.system(size: 20 * scaleFactor, weight: .bold))
                
                HStack {
                    // SwiftUI détecte automatiquement "person" et "people" dans Localizable
                    if SwipenumberOfPersons > 1 {
                        Text("\(SwipenumberOfPersons) people")
                    } else {
                        Text("\(SwipenumberOfPersons) person")
                    }
                    
                    Spacer()
                    
                    Stepper("", value: $SwipenumberOfPersons, in: 1...20)
                        .labelsHidden()
                }
                .font(.system(size: 17 * scaleFactor))
                .padding(.horizontal, 40 * scaleFactor)
                
                HStack(spacing: 15 * scaleFactor) {
                    Button("Add to cart") {
                        storageManager.addRecipe(fullRecipe, numberOfPersons: SwipenumberOfPersons, token: jwtToken)
                        removeRecipeAndCheckCount(recipeId: fullRecipe.id)
                        selectedRecipeForPersons = nil
                    }
                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button {
                        if isLiked {
                            storageManager.unlikedRecipe(fullRecipe, token: jwtToken)
                        } else {
                            storageManager.likedRecipe(fullRecipe, token: jwtToken)
                        }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20 * scaleFactor))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isLiked ? Color.red : Color.orange)
                }
            }
            .padding(.vertical, 20 * scaleFactor)
            .presentationDetents(isPad ? [.height(350)] : [.height(250)])
            .presentationDragIndicator(.visible)
            .task {
                do {
                    self.detailedRecipe = try await APIService.shared.fetchRecipeDetail(id: recipe.id)
                } catch {
                    print("Erreur de récupération : \(error)")
                }
            }
        }
        .sheet(item: $informationRecipe) { recipeSummary in
            NavigationStack {
                Group {
                    if let fullRecipe = detailedRecipe {
                        RecipeDetailView(recipe: fullRecipe, numberOfPersons: $SwipenumberOfPersons, isFromSwipe: true)
                    } else {
                        ProgressView("Loading recipe...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(1.5)
                            .id(UUID())
                    }
                }
            }
            .task {
                do {
                    self.detailedRecipe = try await APIService.shared.fetchRecipeDetail(id: recipeSummary.id)
                } catch {
                    print("Erreur de récupération : \(error)")
                }
            }
            .onDisappear {
                // Réinitialise pour la prochaine ouverture
                detailedRecipe = nil
            }
            .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.fraction(0.9)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: currentUser) { oldUser, newUser in
            if let servings = newUser?.defaultServings {
                SwipenumberOfPersons = servings
            } else {
                SwipenumberOfPersons = 2
            }
        }
    }
}

#Preview {
    SwipeView(currentUser: .constant(nil))
        .environmentObject(StorageManager())
}
