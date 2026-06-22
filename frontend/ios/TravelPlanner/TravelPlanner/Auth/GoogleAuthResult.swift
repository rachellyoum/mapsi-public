//
//  GoogleAuthResult.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

struct GoogleAuthResult {
    let uid: String
    let name: String
    let email: String
}

enum GoogleAuthServiceError: LocalizedError {
    case missingClientID
    case missingRootViewController
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Firebase client ID not found."
        case .missingRootViewController:
            return "Could not find root view controller."
        case .missingIDToken:
            return "Could not get Google ID token."
        }
    }
}

final class GoogleAuthService {
    @MainActor
    func signIn() async throws -> GoogleAuthResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw GoogleAuthServiceError.missingClientID
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            throw GoogleAuthServiceError.missingRootViewController
        }

        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw GoogleAuthServiceError.missingIDToken
        }

        let accessToken = signInResult.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        let authResult = try await Auth.auth().signIn(with: credential)

        return GoogleAuthResult(
            uid: authResult.user.uid,
            name: authResult.user.displayName ?? signInResult.user.profile?.name ?? "",
            email: authResult.user.email ?? signInResult.user.profile?.email ?? ""
        )
    }
}
