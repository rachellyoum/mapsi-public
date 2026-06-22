
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct AppUser {
    let id: String
    let name: String
    let email: String
    let notificationsEnabled: Bool
    let avatarColorIndex: Int?   
    
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? "User"
        self.email = data["email"] as? String ?? ""
        self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
        self.avatarColorIndex = data["avatarColorIndex"] as? Int   // 🔥 추가
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var user: AppUser?
    
    
    @Published var tempName: String = ""
    @Published var tempEmail: String = ""
    @Published var tempPassword: String = ""
    @Published var tempConfirmPassword: String = ""
    
    @Published var showSuccessMessage = false
    @Published var successMessage = ""
    
    private var listener: ListenerRegistration?
    
    // MARK: LISTENER
    
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        listener?.remove()
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let data = snap?.data() else { return }
                let fetchedUser = AppUser(id: uid, data: data)
                self?.user = fetchedUser
                self?.tempName = fetchedUser.name
                self?.tempEmail = fetchedUser.email
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: NOTIFICATION
    
    func toggleNotifications(_ isEnabled: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(["notificationsEnabled": isEnabled])
    }
    
    
    func updateNameOnly() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData([
                "name": tempName
            ]) { [weak self] error in
                
                guard let self = self else { return }
                
                if error == nil {
                    Task { @MainActor in
                        self.successMessage = "Name successfully updated."
                        self.showSuccessMessage = true
                    }
                }
            }
    }
    
    func updatePasswordOnly() {
        guard let user = Auth.auth().currentUser else { return }
        
        if !tempPassword.isEmpty,
           tempPassword == tempConfirmPassword {
            
            user.updatePassword(to: tempPassword) { error in
                if error == nil {
                    self.successMessage = "Password successfully updated."
                    self.showSuccessMessage = true
                    self.tempPassword = ""
                    self.tempConfirmPassword = ""
                }
            }
        }
    }
    // MARK: OTHER ACTIONS
    
    func savedTripsTapped() {
        print("Saved trips tapped")
    }
    
    func helpTapped() {
        print("Help tapped")
    }
    func editProfile() {
        print("edit profile tapped")
    }
    
    // MARK: SIGN OUT
    
    func signOut(completion: @escaping (Bool) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(true)
        } catch {
            completion(false)
        }
    }
    
    // MARK: DELETE ACCOUNT
    
    func deleteAccount(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        let uid = currentUser.uid
        
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .delete()
        
        currentUser.delete { error in
            completion(error == nil)
        }
    }
    func ensureAvatarColorExists() { //fix
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let ref = Firestore.firestore().collection("users").document(uid)

        ref.getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            // 이미 있으면 패스
            if data["avatarColorIndex"] != nil { return }

            // 없으면 기본값 넣기 (랜덤 or 0)
            let defaultIndex = Int.random(in: 0..<AvatarPalette.colors.count)

            ref.updateData([
                "avatarColorIndex": defaultIndex
            ])
        }
    }
    func updateAvatarColor(_ index: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData([
                "avatarColorIndex": index
            ])
    }
}
