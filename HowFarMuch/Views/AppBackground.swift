import SwiftUI

/// The shared dark gradient behind every screen.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.05, blue: 0.10),
                Color(red: 0.06, green: 0.10, blue: 0.20),
                Color(red: 0.10, green: 0.06, blue: 0.22),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
