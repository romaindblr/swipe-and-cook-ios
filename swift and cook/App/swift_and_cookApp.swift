//
//  swift_and_cookApp.swift
//  swift and cook
//
//  Created by Romain Doublier on 25/09/2026.
//

import SwiftUI

@main
struct swift_and_cookApp: App {
    @StateObject private var storageManager = StorageManager()
    // On écoute le même clé stockée par le Picker
    @AppStorage("selectedLanguage") private var selectedLanguage = "fr"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storageManager)
                // 👈 C'est cette ligne qui force toute l'app à changer de langue instantanément
                .environment(\.locale, Locale(identifier: selectedLanguage))
                .id(selectedLanguage)
        }
    }
}
