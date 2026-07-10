import SwiftUI

/// The How Far/Much mark: a winding route with waypoints and an arrowhead,
/// drawn in the brand cyan→lime gradient. Scales with its frame.
struct LogoMarkView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let route = Path { p in
                p.move(to: CGPoint(x: 0.12 * w, y: 0.88 * h))
                p.addCurve(
                    to: CGPoint(x: 0.52 * w, y: 0.50 * h),
                    control1: CGPoint(x: 0.42 * w, y: 0.92 * h),
                    control2: CGPoint(x: 0.24 * w, y: 0.52 * h)
                )
                p.addCurve(
                    to: CGPoint(x: 0.86 * w, y: 0.16 * h),
                    control1: CGPoint(x: 0.80 * w, y: 0.48 * h),
                    control2: CGPoint(x: 0.62 * w, y: 0.14 * h)
                )
            }
            let gradient = LinearGradient(
                colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            ZStack {
                route.stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: 0.09 * w, lineCap: .round)
                )
                // Start waypoint
                Circle()
                    .fill(.cyan)
                    .frame(width: 0.16 * w, height: 0.16 * w)
                    .position(x: 0.12 * w, y: 0.88 * h)
                // Arrowhead at the end of the route
                ArrowheadShape()
                    .fill(Color(red: 0.6, green: 0.95, blue: 0.3))
                    .frame(width: 0.26 * w, height: 0.26 * w)
                    .position(x: 0.90 * w, y: 0.12 * h)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ArrowheadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + 0.15 * rect.width, y: rect.minY + 0.45 * rect.height))
        p.addLine(to: CGPoint(x: rect.minX + 0.45 * rect.width, y: rect.minY + 0.55 * rect.height))
        p.addLine(to: CGPoint(x: rect.minX + 0.55 * rect.width, y: rect.maxY - 0.15 * rect.height))
        p.closeSubpath()
        return p
    }
}

/// Wordmark used in the dashboard header.
struct LogoHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            LogoMarkView()
                .frame(width: 44, height: 44)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.07, green: 0.09, blue: 0.16))
                )
            VStack(alignment: .leading, spacing: 0) {
                (Text("How Far")
                    .foregroundStyle(.white)
                + Text("/Much")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Text("your workouts, added up")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LogoHeaderView().padding()
    }
}
