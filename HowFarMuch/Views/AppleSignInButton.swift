import SwiftUI
import AuthenticationServices
import CryptoKit

/// Native Sign in with Apple → Supabase session (via signInWithIdToken).
struct AppleSignInButton: View {
    var onSignedIn: () -> Void = {}
    var onError: (String) -> Void = { _ in }

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = Self.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName]
            request.nonce = Self.sha256(nonce)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .clipShape(Capsule())
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // User cancellation is not an error worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                onError(error.localizedDescription)
            }
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                onError("Couldn't read the Apple sign-in token.")
                return
            }
            Task {
                do {
                    try await SupabaseManager.shared.client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                    )
                    onSignedIn()
                } catch {
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Nonce helpers (Apple requires a hashed nonce; Supabase the raw one)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
