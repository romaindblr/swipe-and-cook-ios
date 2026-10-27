//
//  AccountView.swift
//  swift and cook
//
//  Created by Romain Doublier on 29/09/2026.
//

import SwiftUI

private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    return "\(version)"
}

enum AuthMode: String, CaseIterable {
    case login = "Log In"
    case register = "Sign Up"

    var localizedKey: LocalizedStringKey {
        switch self {
        case .login: return "Log In"
        case .register: return "Sign Up"
        }
    }
}

struct AccountView: View {
    // MARK: - AppStorage & Persistence
    @AppStorage("isNotificationsEnabled") private var isNotificationsEnabled = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "fr"
    @AppStorage("jwtToken") private var jwtToken: String = ""
    @EnvironmentObject var storageManager: StorageManager
    
    // MARK: - Etats de la vue
    @Binding var currentUser: User?
    @Binding var connecter: Bool
    @State private var connexionView = false
    @State private var authMode: AuthMode = .login
    @State var userServings = 2
    @State private var showConfirmationAlert = false
    
    
    // MARK: - Champs du Formulaire
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var servings: String = "2"
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var checkPassword: String = ""
    
    // MARK: - Etats de controle UX
    @State private var showPassword = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Section Profil
                Section {
                    if connecter, let user = currentUser {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundStyle(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName ?? "Utilisateur")
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            connexionView.toggle()
                        } label: {
                            HStack {
                                Label("Log in or create account", systemImage: "person.crop.circle.badge.plus")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                
                // MARK: - Section Preferences
                Section("Preferences") {
                    Toggle(isOn: $isNotificationsEnabled) {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                    
                    Picker(selection: $selectedLanguage) {
                        Text("Français").tag("fr")
                        Text("English").tag("en")
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    
                    if connecter {
                        HStack {
                            Label {
                                Text("Default Servings")
                            } icon: {
                            Image(systemName: "person.2")
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Stepper(value: $userServings, in: 1...20) {}
                            Spacer()
                            Text("\(userServings)")
                        }
                    }
                }
                
                // MARK: - Section Informations
                Section("Information") {
                    NavigationLink(destination: HelpAndSupportView()) {
                        Label("Help and support", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: TermsOfUseView()) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    
                    HStack {
                        Label("App version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section Deconnexion
                if connecter {
                    Section {
                        Button(role: .destructive) {
                            showConfirmationAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                        .alert("Are you sure?", isPresented: $showConfirmationAlert) {
                            Button("Log out", role: .destructive) {
                                showConfirmationAlert = false
                                logout()
                            }
                            Button("Cancel", role: .cancel) {
                                showConfirmationAlert = false
                            }
                        } message: {
                            Text("This action will sign you out")
                        }
                    }
                }
            }
            .onAppear {
                if let defaultServings = currentUser?.defaultServings {
                    userServings = defaultServings
                }
            }
            .onChange(of: currentUser) { _, _ in
                if let defaultServings = currentUser?.defaultServings {
                    userServings = defaultServings
                }
            }
            .task(id: userServings) {
                guard connecter, !jwtToken.isEmpty,
                      let current = currentUser?.defaultServings,
                      current != userServings else { return }

                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }

                do {
                    currentUser = try await APIService.shared.updateDefaultServings(userServings, token: jwtToken)
                } catch {
                    print("❌ updateDefaultServings :", error)
                    userServings = current
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Account")
            // MARK: - Sheet Authentification
            .sheet(isPresented: $connexionView) {
                NavigationStack {
                    Form {
                        Section {
                            Picker("Auth Mode", selection: $authMode) {
                                ForEach(AuthMode.allCases, id: \.self) { mode in
                                    Text(mode.localizedKey).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .onChange(of: authMode) { _, _ in
                                errorMessage = nil
                            }
                        }
                        
                        if authMode == .register {
                            Section("Personal Information") {
                                TextField("First Name", text: $firstName)
                                TextField("Last Name", text: $lastName)
                                
                                HStack {
                                    Text("Default Servings")
                                    Spacer()
                                    TextField("2", text: $servings)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 50)
                                }
                            }
                        }
                        
                        Section("Credentials") {
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            HStack {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if authMode == .register {
                                SecureField("Confirm Password", text: $checkPassword)
                                if  password != checkPassword && checkPassword != "" {
                                    Text("The passwords doesn't match.")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        if let errorMessage {
                            Section {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        // Bouton principal d'action
                        Section {
                            Button {
                                handleAuthentication()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isLoading {
                                        ProgressView()
                                    } else {
                                        Text(authMode == .login ? "Log In" : "Create Account")
                                            .fontWeight(.bold)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(!isFormValid || isLoading)
                            .tint(.orange)
                        }
                    }
                    .navigationTitle(authMode == .login ? "Welcome Back" : "New Account")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                connexionView = false
                            }
                        }
                    }
                }
                .presentationDetents(authMode == .login ? [.medium] : [.large])
            }
        }
    }
    
    // MARK: - Validation du Formulaire
    private var isFormValid: Bool {
        if authMode == .login {
            return !email.isEmpty && !password.isEmpty && email.contains("@")
        } else {
            return !firstName.isEmpty &&
                   !lastName.isEmpty &&
                   !email.isEmpty && email.contains("@") &&
                   !password.isEmpty &&
                   password == checkPassword
        }
    }
    
    // MARK: - Appel Reseau API
    private func handleAuthentication() {
        errorMessage = nil
        
        if authMode == .register && password != checkPassword {
            errorMessage = "Les mots de passe ne correspondent pas."
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response: AuthResponse
                
                if authMode == .login {
                    let body = LoginRequest(email: email, password: password)
                    response = try await APIService.shared.loginUser(body)
                } else {
                    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    let body = RegisterRequest(
                        email: email,
                        password: password,
                        displayName: fullName,
                        defaultServings: Int(servings) ?? 2
                    )
                    response = try await APIService.shared.registerUser(body)
                }
                
                await MainActor.run {
                    self.jwtToken = response.token
                    self.currentUser = response.user
                    self.isLoading = false
                    withAnimation {
                        self.connecter = true
                        self.connexionView = false
                    }
                    // Nettoyage des mots de passe
                    self.password = ""
                    self.checkPassword = ""
                }
            } catch let error as AuthError {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Une erreur réseau s'est produite."
                }
            }
        }
    }
    
    // MARK: - Deconnexion
    private func logout() {
        withAnimation {
            connecter = false
            currentUser = nil
            jwtToken = ""
            password = ""
            checkPassword = ""
            errorMessage = nil
            storageManager.clearAllData()
        }
    }
}

#Preview {
    AccountView(
        currentUser: .constant(nil),
        connecter: .constant(false)
    )
}
