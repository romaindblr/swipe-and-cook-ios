//
//  TermsOfUseView.swift
//  swift and cook
//
//  Created by Romain Doublier on 06/10/2026.
//

import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Group {
                    Text("Terms of Service")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Last updated: October 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                }
                
                Group {
                    Text("1. Acceptance of Terms")
                        .font(.headline)
                    Text("By accessing or using Swift & Cook, you agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the application.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Group {
                    Text("2. User Accounts")
                        .font(.headline)
                    Text("You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to notify us immediately of any unauthorized use.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Group {
                    Text("3. Content & Recipes")
                        .font(.headline)
                    Text("All recipes, images, and nutritional information provided in the app are for informational and educational purposes only. Ingredient measurements and cooking times are estimations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Group {
                    Text("4. Data & Offline Sync")
                        .font(.headline)
                    Text("Your preferences, favorites, and cart contents are stored locally on your device and synchronized with our secure backend when connected. We strive to maintain continuous availability but do not guarantee uninterrupted service.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Group {
                    Text("5. Limitation of Liability")
                        .font(.headline)
                    Text("Swift & Cook shall not be liable for any indirect, incidental, or consequential damages resulting from your use or inability to use the service.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TermsOfUseView()
    }
}
