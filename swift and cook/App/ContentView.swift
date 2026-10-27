//
//  ContentView.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("jwtToken") private var jwtToken: String = ""
    
    // États globaux de l'utilisateur partagés dans l'application
    @State private var currentUser: User? = nil
    @State private var isConnected = false
    
    @StateObject private var storageManager = StorageManager()
    
    var body: some View {
        TabView {
            SwipeView(currentUser: $currentUser)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            SearchView(currentUser: $currentUser)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            CartView()
                .tabItem {
                    Label("Cart", systemImage: "cart")
                }
            
            FavoriteView(currentUser: $currentUser, connecter: $isConnected)
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
            
            AccountView(currentUser: $currentUser, connecter: $isConnected)
                .tabItem {
                    Label("Account", systemImage: "person")
                }
        }
        .environmentObject(storageManager)
        .tint(.orange)
        .task {
            guard !jwtToken.isEmpty else { return }

            // Hors-ligne ou non, on restaure la session locale tout de suite
            currentUser = User.loadCached()
            withAnimation { isConnected = true }

            switch await APIService.shared.checkSession(token: jwtToken) {
            case .valid(let user):
                currentUser = user
                User.saveCache(user)
            case .expired:                       // le serveur a répondu 401/403
                withAnimation { isConnected = false }
                currentUser = nil
                jwtToken = ""
                User.saveCache(nil)
                storageManager.clearAllData()
            case .offline:
                break                            // on reste connecté avec les données locales
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !jwtToken.isEmpty else { return }
            Task {
                await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromCart: true)
                await APIService.shared.syncData(token: jwtToken, storageManager: storageManager, fromFavorite: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
