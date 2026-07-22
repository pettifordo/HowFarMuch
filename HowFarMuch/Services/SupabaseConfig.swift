import Foundation

/// Supabase project connection. The publishable (anon) key is safe to embed —
/// data access is guarded server-side by Row-Level Security, not by hiding this.
enum SupabaseConfig {
    static let url = URL(string: "https://jwnygbbbspiakhwpgbvo.supabase.co")!
    static let anonKey = "sb_publishable__J7A-0gs4QWsB7k5NHoYnA_T-4QV-EL"
}
