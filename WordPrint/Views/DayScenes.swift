import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Time of day
// ─────────────────────────────────────────────────────────────────────────────

enum TimeOfDay: CaseIterable {
    case morning, afternoon, evening, night

    /// 5–11 morning, 12–16 afternoon, 17–20 evening, 21–4 night.
    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5...11:  return .morning
        case 12...16: return .afternoon
        case 17...20: return .evening
        default:      return .night
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> TimeOfDay {
        from(hour: calendar.component(.hour, from: date))
    }

    var greeting: String {
        switch self {
        case .morning:   return "Good morning!"
        case .afternoon: return "Good afternoon!"
        case .evening:   return "Good evening!"
        case .night:     return "Good evening!"
        }
    }

    var emoji: String {
        switch self {
        case .morning:   return "☀️"
        case .afternoon: return "🌤️"
        case .evening:   return "🌇"
        case .night:     return "🌙"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Scene description
// ─────────────────────────────────────────────────────────────────────────────

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

enum PropMotion { case still, bob, sway, drift }

struct SceneProp {
    let emoji: String
    let x: Double, y: Double          // centre, 0–1 of the scene
    let size: Double                  // fraction of scene width
    var motion: PropMotion = .still
}

enum SceneLayer {
    case hill(color: Color, x: Double, y: Double, width: Double, height: Double)
    case water(top: Double, color: Color)
}

struct CelestialBody {
    enum Kind { case sun, moon }
    let kind: Kind
    let x: Double, y: Double, size: Double
}

struct DayScene: Identifiable {
    let id: String
    let period: TimeOfDay
    let sky: [Color]
    var body: CelestialBody?
    var clouds = false
    var stars = false
    let layers: [SceneLayer]
    let props: [SceneProp]
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - The ten pictures
// ─────────────────────────────────────────────────────────────────────────────

enum SceneCatalog {
    static let all: [DayScene] = [
        // ── Morning ──
        DayScene(
            id: "sunrise-hills", period: .morning,
            sky: [rgb(0.55, 0.75, 0.95), rgb(0.99, 0.62, 0.45), rgb(0.99, 0.80, 0.55)],
            body: CelestialBody(kind: .sun, x: 0.5, y: 0.52, size: 0.30),
            clouds: true,
            layers: [
                .hill(color: rgb(0.40, 0.72, 0.42), x: 0.25, y: 1.0, width: 1.3, height: 0.7),
                .hill(color: rgb(0.25, 0.58, 0.32), x: 0.80, y: 1.05, width: 1.2, height: 0.6),
            ],
            props: [
                SceneProp(emoji: "🐦", x: 0.22, y: 0.22, size: 0.09, motion: .bob),
                SceneProp(emoji: "🦋", x: 0.72, y: 0.58, size: 0.08, motion: .drift),
                SceneProp(emoji: "🌻", x: 0.12, y: 0.88, size: 0.12, motion: .sway),
                SceneProp(emoji: "🌻", x: 0.88, y: 0.90, size: 0.10, motion: .sway),
            ]),
        DayScene(
            id: "coffee-garden", period: .morning,
            sky: [rgb(0.62, 0.84, 0.98), rgb(1.0, 0.95, 0.75)],
            body: CelestialBody(kind: .sun, x: 0.18, y: 0.22, size: 0.18),
            clouds: true,
            layers: [
                .hill(color: rgb(0.55, 0.80, 0.45), x: 0.5, y: 1.05, width: 1.6, height: 0.55),
            ],
            props: [
                SceneProp(emoji: "🏡", x: 0.75, y: 0.62, size: 0.20),
                SceneProp(emoji: "☕", x: 0.28, y: 0.78, size: 0.13, motion: .bob),
                SceneProp(emoji: "🌷", x: 0.10, y: 0.90, size: 0.10, motion: .sway),
                SceneProp(emoji: "🌷", x: 0.50, y: 0.92, size: 0.10, motion: .sway),
                SceneProp(emoji: "🐝", x: 0.45, y: 0.50, size: 0.07, motion: .drift),
            ]),
        DayScene(
            id: "morning-ride", period: .morning,
            sky: [rgb(0.80, 0.90, 1.0), rgb(1.0, 0.86, 0.80)],
            body: CelestialBody(kind: .sun, x: 0.80, y: 0.25, size: 0.20),
            clouds: true,
            layers: [
                .hill(color: rgb(0.50, 0.78, 0.50), x: 0.3, y: 1.0, width: 1.5, height: 0.6),
                .hill(color: rgb(0.35, 0.65, 0.40), x: 0.9, y: 1.05, width: 1.1, height: 0.5),
            ],
            props: [
                SceneProp(emoji: "🚲", x: 0.50, y: 0.76, size: 0.16, motion: .bob),
                SceneProp(emoji: "🌳", x: 0.12, y: 0.70, size: 0.18),
                SceneProp(emoji: "🌳", x: 0.88, y: 0.74, size: 0.15),
                SceneProp(emoji: "🐦", x: 0.35, y: 0.25, size: 0.08, motion: .bob),
            ]),

        // ── Afternoon ──
        DayScene(
            id: "beach-day", period: .afternoon,
            sky: [rgb(0.30, 0.70, 0.98), rgb(0.75, 0.92, 1.0)],
            body: CelestialBody(kind: .sun, x: 0.78, y: 0.20, size: 0.20),
            clouds: true,
            layers: [
                .water(top: 0.55, color: rgb(0.10, 0.60, 0.85)),
                .hill(color: rgb(0.98, 0.88, 0.60), x: 0.5, y: 1.12, width: 1.8, height: 0.45),
            ],
            props: [
                SceneProp(emoji: "🏄", x: 0.30, y: 0.60, size: 0.14, motion: .bob),
                SceneProp(emoji: "⛱️", x: 0.75, y: 0.80, size: 0.16),
                SceneProp(emoji: "🐚", x: 0.15, y: 0.90, size: 0.08),
                SceneProp(emoji: "🦀", x: 0.50, y: 0.92, size: 0.08, motion: .drift),
            ]),
        DayScene(
            id: "kite-meadow", period: .afternoon,
            sky: [rgb(0.35, 0.70, 0.98), rgb(0.70, 0.88, 1.0)],
            body: CelestialBody(kind: .sun, x: 0.15, y: 0.18, size: 0.16),
            clouds: true,
            layers: [
                .hill(color: rgb(0.45, 0.78, 0.38), x: 0.35, y: 1.0, width: 1.5, height: 0.6),
                .hill(color: rgb(0.30, 0.65, 0.32), x: 0.9, y: 1.08, width: 1.2, height: 0.5),
            ],
            props: [
                SceneProp(emoji: "🪁", x: 0.62, y: 0.28, size: 0.14, motion: .sway),
                SceneProp(emoji: "🐕", x: 0.42, y: 0.78, size: 0.13, motion: .bob),
                SceneProp(emoji: "🌼", x: 0.12, y: 0.88, size: 0.09, motion: .sway),
                SceneProp(emoji: "🌼", x: 0.86, y: 0.88, size: 0.09, motion: .sway),
            ]),
        DayScene(
            id: "picnic-park", period: .afternoon,
            sky: [rgb(0.55, 0.80, 0.98), rgb(0.95, 0.98, 1.0)],
            body: CelestialBody(kind: .sun, x: 0.50, y: 0.16, size: 0.16),
            clouds: true,
            layers: [
                .hill(color: rgb(0.50, 0.80, 0.45), x: 0.5, y: 1.0, width: 1.7, height: 0.7),
                .water(top: 0.80, color: rgb(0.35, 0.70, 0.90)),
            ],
            props: [
                SceneProp(emoji: "🌳", x: 0.15, y: 0.55, size: 0.22),
                SceneProp(emoji: "🧺", x: 0.45, y: 0.64, size: 0.13),
                SceneProp(emoji: "🍉", x: 0.60, y: 0.66, size: 0.09),
                SceneProp(emoji: "🦆", x: 0.72, y: 0.90, size: 0.10, motion: .bob),
                SceneProp(emoji: "🦆", x: 0.84, y: 0.93, size: 0.07, motion: .bob),
            ]),

        // ── Evening ──
        DayScene(
            id: "sunset-lake", period: .evening,
            sky: [rgb(0.35, 0.25, 0.60), rgb(0.95, 0.45, 0.45), rgb(1.0, 0.72, 0.35)],
            body: CelestialBody(kind: .sun, x: 0.5, y: 0.50, size: 0.26),
            clouds: true,
            layers: [
                .hill(color: rgb(0.28, 0.20, 0.45), x: 0.2, y: 0.62, width: 1.0, height: 0.22),
                .water(top: 0.58, color: rgb(0.85, 0.40, 0.45)),
            ],
            props: [
                SceneProp(emoji: "⛵", x: 0.30, y: 0.68, size: 0.13, motion: .bob),
                SceneProp(emoji: "🦢", x: 0.72, y: 0.82, size: 0.10, motion: .bob),
                SceneProp(emoji: "🌴", x: 0.90, y: 0.55, size: 0.18, motion: .sway),
            ]),
        DayScene(
            id: "cozy-dusk", period: .evening,
            sky: [rgb(0.20, 0.18, 0.50), rgb(0.70, 0.40, 0.65), rgb(0.98, 0.65, 0.55)],
            body: nil,
            clouds: true, stars: true,
            layers: [
                .hill(color: rgb(0.25, 0.22, 0.45), x: 0.3, y: 1.0, width: 1.5, height: 0.6),
                .hill(color: rgb(0.17, 0.15, 0.35), x: 0.9, y: 1.05, width: 1.2, height: 0.5),
            ],
            props: [
                SceneProp(emoji: "🏡", x: 0.30, y: 0.72, size: 0.20),
                SceneProp(emoji: "🏮", x: 0.55, y: 0.80, size: 0.09, motion: .sway),
                SceneProp(emoji: "🌳", x: 0.85, y: 0.70, size: 0.16),
                SceneProp(emoji: "🦇", x: 0.65, y: 0.25, size: 0.08, motion: .drift),
            ]),

        // ── Night ──
        DayScene(
            id: "moon-and-owl", period: .night,
            sky: [rgb(0.05, 0.08, 0.25), rgb(0.15, 0.18, 0.45)],
            body: CelestialBody(kind: .moon, x: 0.75, y: 0.27, size: 0.22),
            stars: true,
            layers: [
                .hill(color: rgb(0.10, 0.18, 0.30), x: 0.3, y: 1.0, width: 1.5, height: 0.5),
                .hill(color: rgb(0.06, 0.12, 0.22), x: 0.9, y: 1.05, width: 1.2, height: 0.4),
            ],
            props: [
                SceneProp(emoji: "🦉", x: 0.25, y: 0.62, size: 0.16, motion: .bob),
                SceneProp(emoji: "🌲", x: 0.10, y: 0.76, size: 0.15),
                SceneProp(emoji: "🌲", x: 0.88, y: 0.78, size: 0.13),
                SceneProp(emoji: "✨", x: 0.45, y: 0.30, size: 0.07, motion: .bob),
            ]),
        DayScene(
            id: "starry-camp", period: .night,
            sky: [rgb(0.03, 0.05, 0.18), rgb(0.20, 0.12, 0.40)],
            body: CelestialBody(kind: .moon, x: 0.18, y: 0.22, size: 0.14),
            stars: true,
            layers: [
                .hill(color: rgb(0.08, 0.14, 0.24), x: 0.5, y: 1.05, width: 1.7, height: 0.5),
            ],
            props: [
                SceneProp(emoji: "🏕️", x: 0.40, y: 0.74, size: 0.22),
                SceneProp(emoji: "🔥", x: 0.62, y: 0.82, size: 0.10, motion: .bob),
                SceneProp(emoji: "🌠", x: 0.70, y: 0.20, size: 0.12, motion: .drift),
                SceneProp(emoji: "🦊", x: 0.85, y: 0.84, size: 0.09),
            ]),
    ]

    static func scenes(for period: TimeOfDay) -> [DayScene] {
        all.filter { $0.period == period }
    }

    /// A scene for the current time of day, avoiding the one just shown so the
    /// picture changes each visit.
    static func pick(for date: Date = .now,
                     excluding lastID: String? = nil,
                     using generator: inout some RandomNumberGenerator) -> DayScene {
        let options = scenes(for: .from(date: date))
        let fresh = options.filter { $0.id != lastID }
        return (fresh.isEmpty ? options : fresh).randomElement(using: &generator) ?? all[0]
    }

    static func pick(for date: Date = .now, excluding lastID: String? = nil) -> DayScene {
        var rng = SystemRandomNumberGenerator()
        return pick(for: date, excluding: lastID, using: &rng)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Drawing
// ─────────────────────────────────────────────────────────────────────────────

struct DaySceneView: View {
    let scene: DayScene
    /// Off = a still picture (cheaper to draw, used while recording).
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(colors: scene.sky, startPoint: .top, endPoint: .bottom)

                if scene.stars { stars(w: w, h: h) }
                if let body = scene.body { celestial(body, w: w, h: h) }
                if scene.clouds { clouds(w: w, h: h) }

                ForEach(Array(scene.layers.enumerated()), id: \.offset) { _, layer in
                    switch layer {
                    case let .hill(color, x, y, width, height):
                        Ellipse()
                            .fill(color)
                            .frame(width: w * width, height: h * height)
                            .position(x: w * x, y: h * y)
                    case let .water(top, color):
                        water(top: top, color: color, w: w, h: h)
                    }
                }

                ForEach(Array(scene.props.enumerated()), id: \.offset) { index, prop in
                    propView(prop, index: index, w: w, h: h)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityHidden(true)   // decorative; the greeting text carries the meaning
        .onAppear { animating = animated && !reduceMotion }
        .onChange(of: reduceMotion) { _, reduced in animating = animated && !reduced }
    }

    // MARK: Pieces

    private func celestial(_ body: CelestialBody, w: Double, h: Double) -> some View {
        let d = w * body.size
        return Group {
            switch body.kind {
            case .sun:
                Circle()
                    .fill(rgb(1.0, 0.88, 0.30))
                    .frame(width: d, height: d)
                    .shadow(color: rgb(1.0, 0.75, 0.10).opacity(0.7), radius: 18)
            case .moon:
                ZStack {
                    Circle().fill(rgb(0.97, 0.96, 0.85))
                    Circle().fill(rgb(0.85, 0.84, 0.72)).frame(width: d * 0.22).offset(x: -d * 0.2, y: -d * 0.1)
                    Circle().fill(rgb(0.85, 0.84, 0.72)).frame(width: d * 0.14).offset(x: d * 0.18, y: d * 0.15)
                    Circle().fill(rgb(0.85, 0.84, 0.72)).frame(width: d * 0.10).offset(x: d * 0.05, y: -d * 0.25)
                }
                .frame(width: d, height: d)
                .shadow(color: .white.opacity(0.45), radius: 16)
            }
        }
        .position(x: w * body.x, y: h * body.y)
    }

    private func clouds(w: Double, h: Double) -> some View {
        let dim = scene.period == .night || scene.period == .evening
        let tint = dim ? Color.white.opacity(0.25) : Color.white.opacity(0.8)
        return ZStack {
            CloudShape().fill(tint)
                .frame(width: w * 0.28, height: w * 0.09)
                .position(x: w * 0.22, y: h * 0.16)
                .offset(x: animating ? w * 0.03 : -w * 0.03)
                .animation(drift(duration: 7), value: animating)
            CloudShape().fill(tint.opacity(0.8))
                .frame(width: w * 0.20, height: w * 0.065)
                .position(x: w * 0.60, y: h * 0.10)
                .offset(x: animating ? -w * 0.03 : w * 0.03)
                .animation(drift(duration: 9), value: animating)
        }
    }

    private func stars(w: Double, h: Double) -> some View {
        ForEach(0..<24, id: \.self) { i in
            // Fixed pseudo-random positions so the sky is stable between redraws.
            let fx = (sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let fy = (sin(Double(i) * 78.233) * 12543.2731).truncatingRemainder(dividingBy: 1)
            Circle()
                .fill(.white)
                .frame(width: i % 3 == 0 ? 4 : 2.5, height: i % 3 == 0 ? 4 : 2.5)
                .position(x: w * abs(fx), y: h * 0.55 * abs(fy))
                .opacity(animating ? (i % 2 == 0 ? 1.0 : 0.35) : 0.8)
                .animation(.easeInOut(duration: 1.2 + Double(i % 5) * 0.3).repeatForever(autoreverses: true), value: animating)
        }
    }

    private func water(top: Double, color: Color, w: Double, h: Double) -> some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .frame(width: w, height: h * (1 - top))
                .position(x: w / 2, y: h * (1 + top) / 2)
            ForEach(0..<6, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: w * 0.12, height: 2.5)
                    .position(x: w * (0.12 + 0.16 * Double(i)),
                              y: h * (top + (1 - top) * (0.25 + 0.2 * Double(i % 3))))
                    .opacity(animating ? 0.7 : 0.2)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: animating)
            }
        }
    }

    private func propView(_ prop: SceneProp, index: Int, w: Double, h: Double) -> some View {
        let angle: Double = prop.motion == .sway ? (animating ? 7 : -7) : 0
        let dx: Double = prop.motion == .drift ? (animating ? w * 0.04 : -w * 0.04) : 0
        let dy: Double = switch prop.motion {
        case .bob:   animating ? -h * 0.03 : h * 0.01
        case .drift: animating ? -h * 0.02 : h * 0.02
        default:     0
        }
        return Text(prop.emoji)
            .font(.system(size: w * prop.size))
            .rotationEffect(.degrees(angle))
            .offset(x: dx, y: dy)
            .position(x: w * prop.x, y: h * prop.y)
            .animation(prop.motion == .still ? nil : drift(duration: 1.6 + Double(index) * 0.35), value: animating)
    }

    private func drift(duration: Double) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

// Simple cloud silhouette from overlapping ellipses
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.addEllipse(in: CGRect(x: w*0.05, y: h*0.25, width: w*0.50, height: h*0.75))
        p.addEllipse(in: CGRect(x: w*0.30, y: h*0.05, width: w*0.40, height: h*0.70))
        p.addEllipse(in: CGRect(x: w*0.55, y: h*0.30, width: w*0.40, height: h*0.65))
        p.addRect(CGRect(x: w*0.05, y: h*0.55, width: w*0.90, height: h*0.45))
        return p
    }
}
