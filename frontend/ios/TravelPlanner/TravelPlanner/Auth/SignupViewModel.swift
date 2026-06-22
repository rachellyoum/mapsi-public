import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var userName: String = ""
    @Published var confirmPwd: String = ""

    @Published var showError: Bool = false
    @Published var errorMsg: String = ""
    @Published var isLoading: Bool = false

    private let googleAuthService = GoogleAuthService()

    func signUp(completion: @escaping (Bool) -> Void) {
        errorMsg = ""
        showError = false

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cp = confirmPwd.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            errorMsg = "Please enter your name."
            showError = true
            completion(false)
            return
        }
        guard !e.isEmpty else {
            errorMsg = "Please enter your email."
            showError = true
            completion(false)
            return
        }
        guard !p.isEmpty else {
            errorMsg = "Please enter your password."
            showError = true
            completion(false)
            return
        }
        guard p.count >= 6 else {
            errorMsg = "Password must be at least 6 characters."
            showError = true
            completion(false)
            return
        }
        guard cp == p else {
            errorMsg = "Passwords do not match."
            showError = true
            completion(false)
            return
        }

        isLoading = true
        print("creating user with:", e)

        Auth.auth().createUser(withEmail: e, password: p) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error = error as NSError? {
                    if let code = AuthErrorCode(rawValue: error.code) {
                        switch code {
                        case .emailAlreadyInUse:
                            self.errorMsg = "This email is already in use. Please sign in."
                        case .invalidEmail:
                            self.errorMsg = "Invalid email format."
                        default:
                            self.errorMsg = error.localizedDescription
                        }
                    } else {
                        self.errorMsg = error.localizedDescription
                    }
                    self.showError = true
                    completion(false)
                    return
                }

                guard let user = result?.user else {
                    self.errorMsg = "Failed to create user."
                    self.showError = true
                    completion(false)
                    return
                }

                let uid = user.uid
                let db = Firestore.firestore()

                db.collection("users").document(uid).setData([
                    "email": e,
                    "name": name,
                    "createdAt": Timestamp(),
                    "notificationsEnabled": true,
                    "profileImageURL": ""
                ], merge: true) { [weak self] err in
                    guard let self else { return }

                    if let err {
                        self.errorMsg = "Failed to save profile: \(err.localizedDescription)"
                        self.showError = true
                        completion(false)
                        return
                    }

                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = name
                    changeRequest.commitChanges { [weak self] err in
                        guard let self else { return }

                        if let err {
                            print("displayName commit error:", err.localizedDescription)
                        }

                        Task { @MainActor in
                            completion(true)
                        }
                    }
                }
            }
        }
    }

    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        errorMsg = ""
        showError = false
        isLoading = true

        Task {
            do {
                let result = try await googleAuthService.signIn()
                try await createGoogleUserDocumentIfNeeded(result: result)

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
}
