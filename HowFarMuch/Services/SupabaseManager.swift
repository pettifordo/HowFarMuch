import Foundation
import Supabase
import Observation

/// Owns the shared Supabase client and tracks the signed-in user.
@MainActor
@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    private(set) var currentUserID: UUID?

    var isSignedIn: Bool { currentUserID != nil }

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    /// Restore any existing session and keep `currentUserID` in sync.
    func start() async {
        currentUserID = try? await client.auth.session.user.id
        for await (_, session) in client.auth.authStateChanges {
            currentUserID = session?.user.id
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentUserID = nil
    }
}
