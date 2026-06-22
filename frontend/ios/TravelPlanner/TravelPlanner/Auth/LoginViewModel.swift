//
//  LoginViewModel.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-02-26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var userName: String = ""
    @Published var confirmPwd: String = ""

    @Published var showError: Bool = false
    @Published var errorMsg = ""
    @Published var isLoading: Bool = false
    @Published var rememberMe: Bool = false

    private let savedEmailKey = "savedEmail"
    private let rememberMeKey = "rememberMe"

    init() {
        rememberMe = UserDefaults.standard.bool(forKey: rememberMeKey)
        
        if rememberMe {
            email = UserDefaults.standard.string(forKey: savedEmailKey) ?? ""
        }
    }

    func saveRememberMe() {
        UserDefaults.standard.set(rememberMe, forKey: rememberMeKey)
        
        if rememberMe {
            UserDefaults.standard.set(email, forKey: savedEmailKey)
        } else {
            UserDefaults.standard.removeObject(forKey: savedEmailKey)
        }
    }

    // MARK: - Sign in
    func login(completion: @escaping (Bool) -> Void) {
        errorMsg = ""
        showError = false
        isLoading = true

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedEmail.isEmpty && trimmedPassword.isEmpty {
            errorMsg = "Please enter your email and password."
            showError = true
            isLoading = false
            completion(false)
            return
        }

        if trimmedEmail.isEmpty {
            errorMsg = "Please enter your email."
            showError = true
            isLoading = false
            completion(false)
            return
        }

        if trimmedPassword.isEmpty {
            errorMsg = "Please enter your password."
            showError = true
            isLoading = false
            completion(false)
            return
        }

        Auth.auth().signIn(withEmail: trimmedEmail, password: trimmedPassword) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error = error as NSError? {
                    print("AUTH domain:", error.domain)
                    print("AUTH code:", error.code)
                    print("AUTH message:", error.localizedDescription)
                    if let code = AuthErrorCode(rawValue: error.code) {
                        print("AuthErrorCode:", code)
                    }

                    self.errorMsg = error.localizedDescription
                    self.showError = true
                    completion(false)
                    return
                }

                print("AUTH success")
                print("UID:", result?.user.uid ?? "nil")

                // 로그인 성공 직후 토큰 확인용
                result?.user.getIDToken(completion: { token, tokenError in
                    if let tokenError = tokenError {
                        print("Failed to get ID token:", tokenError.localizedDescription)
                    } else {
                    }
                })
                self.saveRememberMe()
                completion(true)
            }
        }
    }
    private let googleAuthService = GoogleAuthService()

    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        errorMsg = ""
        showError = false
        isLoading = true

        Task {
            do {
                let result = try await googleAuthService.signIn()
                try await createGoogleUserDocumentIfNeeded(result: result)
                
                self.saveRememberMe()
                isLoading = false
                completion(true)
            } catch {
                isLoading = false
                errorMsg = error.localizedDescription
                showError = true
                completion(false)
            }
        }
    }

    private func createGoogleUserDocumentIfNeeded(result: GoogleAuthResult) async throws {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(result.uid)
        let snapshot = try await ref.getDocument()

        let safeName = result.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "User"
            : result.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if snapshot.exists {
            try await ref.setData([
                "email": result.email,
                "name": safeName
            ], merge: true)
        } else {
            try await ref.setData([
                "email": result.email,
                "name": safeName,
                "createdAt": Timestamp(),
                "notificationsEnabled": true,
                "profileImageURL": ""
            ], merge: true)
        }

        if let user = Auth.auth().currentUser, user.displayName != safeName {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = safeName
            try await changeRequest.commitChanges()
        }
    }

    // MARK: - Current User Info
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Fetch Firebase ID Token
    func fetchIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw LoginError.notLoggedIn
        }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    // MARK: - Sign out
    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMsg = error.localizedDescription
            showError = true
        }
    }
}

enum LoginError: LocalizedError {
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "User is not logged in."
        }
    }
}
