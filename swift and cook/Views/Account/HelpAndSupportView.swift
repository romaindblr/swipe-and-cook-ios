//
//  HelpAndSupportView.swift
//  swift and cook
//
//  Created by Romain Doublier on 06/10/2026.
//

import SwiftUI

struct FAQItem: Identifiable {
    let id = UUID()
    let question: LocalizedStringKey
    let answer: LocalizedStringKey
}

struct HelpAndSupportView: View {
    @State private var expandedQuestionID: UUID? = nil
    
    // FAQ Dataa
    private let faqList: [FAQItem] = [
        FAQItem(
            question: "How does offline synchronization work?",
            answer: "All your recipes, favorites, and shopping list items are stored locally on your device. When you get back online, changes sync automatically with your account."
        ),
        FAQItem(
            question: "How do I change default servings?",
            answer: "Go to your Account tab under 'Preferences' to update your default servings. This will automatically adjust recipe ingredient quantities for you."
        ),
        FAQItem(
            question: "Can I use the app without creating an account?",
            answer: "Yes! You can browse recipes, manage favorites, and build shopping lists offline. Creating an account enables multi-device cloud synchronization."
        ),
        FAQItem(
            question: "How do I clear my shopping cart?",
            answer: "Open the Cart tab and swipe left on any recipe or ingredient to remove it, or use the clear button at the top right of the cart."
        )
    ]
    
    var body: some View {
        List {
            // Section FAQ
            Section("Frequently Asked Questions") {
                ForEach(faqList) { item in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedQuestionID == item.id },
                            set: { isExpanded in
                                withAnimation {
                                    expandedQuestionID = isExpanded ? item.id : nil
                                }
                            }
                        )
                    ) {
                        Text(item.answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } label: {
                        Text(item.question)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Section Contact Support
            Section("Contact Us") {
                Link(destination: URL(string: "mailto:support@swiftandcook.com")!) {
                    HStack {
                        Label("Email Support", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Link(destination: URL(string: "https://www.swiftandcook.com")!) {
                    HStack {
                        Label("Visit Website", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HelpAndSupportView()
    }
}
