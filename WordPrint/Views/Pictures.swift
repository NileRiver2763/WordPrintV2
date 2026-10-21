import SwiftUI

// Calm, flat-style illustrations of everyday adult scenes, used for the
// "describe this picture" question. Each is drawn on a 100 × 75 grid.

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Drawing primitives
// ─────────────────────────────────────────────────────────────────────────────

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

private enum Pal {
    static let cream      = rgb(0.95, 0.91, 0.82)
    static let wall       = rgb(0.90, 0.84, 0.74)
    static let sage       = rgb(0.62, 0.74, 0.62)
    static let dusty      = rgb(0.45, 0.58, 0.72)
    static let terracotta = rgb(0.80, 0.50, 0.40)
    static let mustard    = rgb(0.88, 0.72, 0.36)
    static let plum       = rgb(0.58, 0.42, 0.55)
    static let wood       = rgb(0.58, 0.40, 0.28)
    static let lightWood  = rgb(0.76, 0.58, 0.40)
    static let floor      = rgb(0.68, 0.55, 0.43)
    static let sky        = rgb(0.76, 0.88, 0.95)
    static let grass      = rgb(0.55, 0.72, 0.48)
    static let leaf       = rgb(0.32, 0.52, 0.38)
    static let water      = rgb(0.58, 0.76, 0.84)
    static let sand       = rgb(0.90, 0.82, 0.64)
    static let white      = rgb(0.98, 0.97, 0.94)
    static let grey       = rgb(0.72, 0.72, 0.74)
    static let dark       = rgb(0.30, 0.30, 0.34)
    static let brick      = rgb(0.76, 0.46, 0.38)
    static let yellow     = rgb(0.98, 0.88, 0.50)
    static let skinLight  = rgb(0.95, 0.80, 0.68)
    static let skinMid    = rgb(0.80, 0.60, 0.45)
    static let skinDeep   = rgb(0.58, 0.40, 0.30)
    static let greyHair   = rgb(0.84, 0.84, 0.86)
    static let darkHair   = rgb(0.30, 0.22, 0.18)
}

enum Arms { case down, forward, up }

struct Ink {
    enum Op {
        case rect(CGRect, Color, Double)
        case ellipse(CGRect, Color)
        case ring(CGRect, Double, Color)
        case poly([CGPoint], Color)
        case line(CGPoint, CGPoint, Double, Color)
        case text(String, CGPoint, Double, Color)
    }
    var ops: [Op] = []

    mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Color, r: Double = 0) {
        ops.append(.rect(CGRect(x: x, y: y, width: w, height: h), c, r))
    }
    mutating func oval(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: Color) {
        ops.append(.ellipse(CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), c))
    }
    mutating func ring(_ cx: Double, _ cy: Double, _ r: Double, _ w: Double, _ c: Color) {
        ops.append(.ring(CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2), w, c))
    }
    mutating func poly(_ pts: [(Double, Double)], _ c: Color) {
        ops.append(.poly(pts.map { CGPoint(x: $0.0, y: $0.1) }, c))
    }
    mutating func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ w: Double = 0.8, _ c: Color) {
        ops.append(.line(CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2), w, c))
    }
    mutating func text(_ s: String, _ x: Double, _ y: Double, size: Double, _ c: Color) {
        ops.append(.text(s, CGPoint(x: x, y: y), size, c))
    }

    /// A simple standing or seated person. (x, y) is where the feet meet the floor.
    mutating func person(_ x: Double, _ y: Double, scale s: Double = 1,
                         top: Color, bottom: Color = Pal.dark, skin: Color = Pal.skinLight, hair: Color = Pal.greyHair,
                         sitting: Bool = false, arms: Arms = .down, facing f: Double = 1, hat: Color? = nil) {
        let hip = sitting ? y - 9 * s : y - 9 * s          // top of legs
        // legs
        if sitting {
            rect(x - 1.4 * s + (f < 0 ? -8 * s : 0), hip - 0.2 * s, 9.4 * s, 2.8 * s, bottom, r: 1.2 * s)   // thighs
            rect(x + f * 8 * s - 1.4 * s, hip, 2.8 * s, 9 * s, bottom, r: 1 * s)                              // shins
        } else {
            rect(x - 3 * s, hip, 2.8 * s, 9 * s, bottom, r: 1 * s)
            rect(x + 0.2 * s, hip, 2.8 * s, 9 * s, bottom, r: 1 * s)
        }
        // torso
        rect(x - 3.6 * s, hip - 11.5 * s, 7.2 * s, 12 * s, top, r: 2.6 * s)
        // arms
        let sx = x + f * 2.6 * s, sy = hip - 9.5 * s
        switch arms {
        case .down:    line(sx, sy, sx + f * 1.5 * s, sy + 8 * s, 2.3 * s, top)
        case .forward: line(sx, sy, sx + f * 8 * s, sy + 3 * s, 2.3 * s, top)
        case .up:      line(sx, sy, sx + f * 5 * s, sy - 7 * s, 2.3 * s, top)
        }
        // head and hair
        let hy = hip - 15.5 * s
        oval(x, hy, 3.1 * s, 3.3 * s, skin)
        oval(x - f * 0.3 * s, hy - 1.6 * s, 3.3 * s, 2.2 * s, hair)
        if let hat {
            oval(x, hy - 2.6 * s, 4.6 * s, 1.1 * s, hat)
            oval(x, hy - 3.4 * s, 2.7 * s, 1.8 * s, hat)
        }
    }
}

struct Picture: Identifiable {
    let id: String
    let ops: [Ink.Op]
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - The ten pictures
// ─────────────────────────────────────────────────────────────────────────────

enum PictureCatalog {
    static let all: [Picture] = [
        kitchen, parkBench, garden, livingRoom, market,
        lakeside, familyDinner, busStop, porch, bakery,
    ].enumerated().map { Picture(id: ids[$0.offset], ops: $0.element.ops) }

    static let ids = ["kitchen", "park-bench", "garden", "living-room", "market",
                      "lakeside", "family-dinner", "bus-stop", "porch", "bakery"]

    static func picture(id: String) -> Picture? { all.first { $0.id == id } }

    // MARK: Kitchen — one person cooking, one reading
    private static var kitchen: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.wall)
        k.rect(0, 55, 100, 20, Pal.floor)
        // window with curtains
        k.rect(62, 9, 24, 22, Pal.white)
        k.rect(64, 11, 20, 18, Pal.sky)
        k.oval(70, 25, 6, 3, Pal.grass); k.oval(80, 26, 7, 3, Pal.leaf)
        k.line(74, 11, 74, 29, 0.8, Pal.white); k.line(64, 20, 84, 20, 0.8, Pal.white)
        k.rect(58, 8, 6, 26, Pal.sage, r: 1); k.rect(84, 8, 6, 26, Pal.sage, r: 1)
        // clock and shelf
        k.oval(40, 13, 5, 5, Pal.white); k.ring(40, 13, 5, 0.8, Pal.dark)
        k.line(40, 13, 40, 9.5, 0.7, Pal.dark); k.line(40, 13, 43, 14, 0.7, Pal.dark)
        k.rect(6, 20, 30, 1.8, Pal.wood)
        for (i, c) in [Pal.terracotta, Pal.mustard, Pal.dusty, Pal.sage].enumerated() {
            k.rect(8 + Double(i) * 7, 14.5, 5, 5.5, c, r: 1)
        }
        // woman cooking at the stove
        k.person(28, 57, top: Pal.terracotta, bottom: Pal.dusty, skin: Pal.skinLight, hair: Pal.greyHair, arms: .forward, facing: -1)
        k.rect(3, 40, 30, 17, Pal.lightWood); k.rect(2, 38, 32, 3, Pal.white)
        k.rect(8, 31, 11, 8, Pal.grey, r: 1); k.rect(6.5, 33, 2.5, 1.2, Pal.grey); k.rect(18.5, 33, 2.5, 1.2, Pal.grey)
        for dx in [0.0, 3, 6] { k.line(11 + dx, 29, 12 + dx, 24, 0.7, rgb(0.85, 0.85, 0.88)) }
        k.oval(26, 35.5, 3, 2.5, Pal.dusty); k.rect(28, 33, 3, 0.8, Pal.dusty)     // kettle
        // table, chairs, man reading
        k.rect(56, 62, 3, 2, Pal.wood)
        k.person(76, 62, top: Pal.dusty, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, arms: .forward, facing: -1)
        k.rect(80, 43, 3, 19, Pal.wood); k.rect(81, 51, 9, 2, Pal.wood)             // chair back
        k.rect(48, 47, 36, 3, Pal.lightWood); k.rect(51, 50, 3, 12, Pal.wood); k.rect(78, 50, 3, 12, Pal.wood)
        k.rect(66, 38, 8, 11, Pal.white, r: 0.6); k.line(68, 41, 72, 41, 0.5, Pal.grey); k.line(68, 43, 72, 43, 0.5, Pal.grey)
        k.oval(56, 46, 2.2, 1.2, Pal.white); k.oval(60, 45.4, 1.8, 1.4, Pal.terracotta) // plate, cup
        return k
    }

    // MARK: Park bench — a couple resting, a walker with a dog
    private static var parkBench: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.sky)
        k.oval(24, 10, 9, 3, Pal.white); k.oval(72, 14, 11, 3.4, Pal.white)
        k.rect(0, 38, 100, 37, Pal.grass)
        k.poly([(34, 75), (46, 38), (56, 38), (80, 75)], Pal.sand)
        k.oval(84, 50, 14, 5, Pal.water)
        k.oval(80, 50, 2, 1.2, Pal.white); k.oval(88, 51, 2, 1.2, Pal.white)
        k.rect(12, 18, 4, 24, Pal.wood); k.oval(14, 15, 13, 11, Pal.leaf); k.oval(22, 20, 8, 7, Pal.grass)
        k.rect(47.4, 22, 1.2, 20, Pal.dark); k.oval(48, 21, 2.6, 2.6, Pal.yellow)
        // bench with the couple
        k.person(41, 60, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, facing: 1)
        k.person(51, 60, top: Pal.mustard, bottom: Pal.dusty, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, facing: 1)
        k.rect(32, 44, 28, 2, Pal.wood); k.rect(32, 52, 28, 2.5, Pal.lightWood)
        k.rect(34, 54, 2, 7, Pal.wood); k.rect(56, 54, 2, 7, Pal.wood)
        // walker and dog
        k.person(80, 70, top: Pal.plum, bottom: Pal.dark, skin: Pal.skinDeep, hair: Pal.darkHair, arms: .forward, facing: -1, hat: Pal.terracotta)
        k.line(72, 66, 67, 69, 0.4, Pal.dark)
        k.oval(64, 68, 4.2, 2.4, Pal.lightWood); k.oval(60, 66.6, 2, 1.7, Pal.lightWood)
        k.line(62, 70, 62, 73, 1, Pal.wood); k.line(66, 70, 66, 73, 1, Pal.wood); k.line(68, 67, 70, 65.5, 1, Pal.lightWood)
        return k
    }

    // MARK: Garden — watering flowers, wheelbarrow
    private static var garden: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.sky)
        k.oval(88, 10, 6, 6, Pal.yellow)
        k.rect(0, 36, 100, 39, Pal.grass)
        k.rect(68, 20, 26, 26, Pal.lightWood); k.poly([(66, 21), (81, 10), (96, 21)], Pal.brick)
        k.rect(76, 30, 8, 16, Pal.wood); k.rect(70, 25, 5, 5, Pal.sky)
        for i in 0..<20 { k.rect(Double(i) * 5 + 1, 44, 3, 9, Pal.white, r: 0.6) }
        k.rect(0, 46, 100, 1.2, Pal.white); k.rect(0, 50, 100, 1.2, Pal.white)
        k.rect(6, 58, 52, 8, rgb(0.50, 0.36, 0.28), r: 1.5)
        let colors = [Pal.terracotta, Pal.mustard, Pal.plum, Pal.white, Pal.dusty]
        for i in 0..<10 {
            let fx = 9 + Double(i) * 5, h = 5 + Double(i % 3) * 2
            k.line(fx, 59, fx, 59 - h, 0.7, Pal.leaf)
            k.oval(fx, 59 - h, 1.8, 1.8, colors[i % colors.count])
        }
        k.oval(12, 22, 11, 10, Pal.leaf); k.rect(11, 28, 2.6, 14, Pal.wood)
        // woman watering
        k.person(34, 56, top: Pal.sage, bottom: Pal.dusty, skin: Pal.skinLight, hair: Pal.greyHair, arms: .forward, facing: 1, hat: Pal.mustard)
        k.rect(42, 40, 6, 4.5, Pal.dusty, r: 1); k.line(48, 41, 53, 44, 1, Pal.dusty)
        for i in 0..<4 { k.line(53.5 + Double(i) * 1.2, 44.5, 54.5 + Double(i) * 1.2, 51, 0.4, Pal.water) }
        // man with wheelbarrow
        k.person(76, 72, top: Pal.terracotta, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, arms: .forward, facing: -1)
        k.poly([(54, 63), (70, 63), (66, 70), (58, 70)], Pal.dusty); k.ring(60, 71, 2.4, 1, Pal.dark)
        k.oval(60, 62, 5, 1.6, Pal.leaf)
        // birdbath
        k.rect(84, 52, 2, 9, Pal.grey); k.oval(85, 51.5, 5, 1.6, Pal.grey); k.oval(87, 49.2, 1.7, 1.4, Pal.dusty)
        return k
    }

    // MARK: Living room — radio, knitting
    private static var livingRoom: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.wall)
        k.rect(0, 56, 100, 19, Pal.floor)
        k.oval(50, 66, 34, 6, Pal.terracotta); k.oval(50, 66, 26, 4, Pal.cream)
        // bookshelf
        k.rect(46, 6, 30, 30, Pal.wood)
        for row in 0..<3 {
            let y = 8 + Double(row) * 9.5
            k.rect(47.5, y, 27, 8.2, Pal.lightWood)
            for b in 0..<8 { k.rect(48.5 + Double(b) * 3.2, y + 0.8 + Double(b % 2), 2.5, 6.4 - Double(b % 2), [Pal.dusty, Pal.terracotta, Pal.mustard, Pal.sage][b % 4]) }
        }
        // pictures and clock
        k.rect(8, 10, 12, 14, Pal.wood); k.rect(9.5, 11.5, 9, 11, Pal.sky); k.oval(14, 20, 4.5, 2.5, Pal.grass)
        k.rect(24, 8, 10, 8, Pal.wood); k.rect(25.2, 9.2, 7.6, 5.6, Pal.sand)
        // sofa with the woman knitting
        k.rect(6, 34, 36, 22, Pal.dusty, r: 3); k.rect(4, 42, 6, 15, Pal.dusty, r: 2.5); k.rect(38, 42, 6, 15, Pal.dusty, r: 2.5)
        k.person(24, 58, top: Pal.mustard, bottom: Pal.plum, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, arms: .forward, facing: 1)
        k.oval(34, 50.5, 2.6, 2.6, Pal.terracotta); k.line(33, 49, 28, 46, 0.5, Pal.terracotta)
        // armchair, man, radio
        k.rect(64, 38, 20, 20, Pal.plum, r: 3)
        k.person(74, 58, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, facing: 1)
        k.rect(86, 44, 11, 2, Pal.wood); k.rect(87, 46, 1.6, 12, Pal.wood); k.rect(94.4, 46, 1.6, 12, Pal.wood)
        k.rect(87.5, 37, 8.5, 7, Pal.lightWood, r: 1); k.oval(90, 40.5, 1.6, 1.6, Pal.dark); k.line(92.5, 38.5, 95, 38.5, 0.5, Pal.dark); k.line(92.5, 40.5, 95, 40.5, 0.5, Pal.dark)
        k.line(95, 37, 97, 31, 0.4, Pal.dark)
        // lamp
        k.rect(0.8, 22, 1.2, 34, Pal.dark); k.poly([(-3, 22), (5, 22), (3, 14), (-1, 14)], Pal.yellow)
        return k
    }

    // MARK: Market — fruit stall, customer with basket
    private static var market: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.sky)
        k.rect(0, 52, 100, 23, Pal.sand)
        k.rect(70, 14, 28, 40, Pal.brick); k.rect(75, 20, 7, 8, Pal.sky); k.rect(86, 20, 7, 8, Pal.sky)
        k.person(32, 60, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, arms: .forward, facing: 1)
        // stall
        for i in 0..<8 { k.rect(8 + Double(i) * 10, 16, 10, 10, i % 2 == 0 ? Pal.terracotta : Pal.white) }
        k.poly([(8, 26), (88, 26), (88, 28), (8, 28)], Pal.dark.opacity(0.18))
        k.rect(10, 28, 1.6, 26, Pal.wood); k.rect(86, 28, 1.6, 26, Pal.wood)
        k.rect(8, 44, 80, 12, Pal.lightWood); k.rect(8, 43, 80, 2, Pal.wood)
        let fruit = [Pal.terracotta, Pal.mustard, Pal.leaf, Pal.plum]
        for crate in 0..<4 {
            let cx = 14 + Double(crate) * 18
            k.rect(cx, 38, 14, 6, Pal.wood, r: 0.8)
            for f in 0..<4 { k.oval(cx + 2.5 + Double(f) * 3, 37.5, 1.7, 1.7, fruit[(crate + f) % 4]) }
        }
        k.line(48, 26, 48, 31, 0.5, Pal.dark); k.oval(48, 33, 3, 2, Pal.grey)       // hanging scale
        // customer with a basket
        k.person(64, 72, scale: 1.1, top: Pal.plum, bottom: Pal.dusty, skin: Pal.skinLight, hair: Pal.greyHair, arms: .forward, facing: -1, hat: Pal.cream)
        k.oval(55, 62, 3.6, 2.6, Pal.lightWood)
        // bicycle
        k.ring(86, 68, 5, 0.9, Pal.dark); k.ring(98, 68, 5, 0.9, Pal.dark)
        k.line(86, 68, 91, 62, 0.9, Pal.dusty); k.line(91, 62, 98, 68, 0.9, Pal.dusty); k.line(91, 62, 95, 62, 0.9, Pal.dusty)
        return k
    }

    // MARK: Lakeside — fishing and a picnic blanket
    private static var lakeside: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, rgb(0.84, 0.91, 0.95))
        k.oval(80, 14, 6, 6, Pal.yellow)
        k.poly([(0, 36), (22, 22), (46, 36)], rgb(0.66, 0.76, 0.70)); k.poly([(30, 36), (62, 18), (100, 36)], rgb(0.58, 0.70, 0.62))
        k.rect(0, 34, 100, 41, Pal.water)
        for i in 0..<6 { k.line(8 + Double(i) * 16, 42 + Double(i % 3) * 6, 15 + Double(i) * 16, 42 + Double(i % 3) * 6, 0.5, Pal.white) }
        k.rect(0, 62, 100, 13, Pal.grass)
        // jetty and fisherman
        k.rect(0, 50, 52, 3, Pal.lightWood); for x in [6.0, 24, 44] { k.rect(x, 53, 2, 10, Pal.wood) }
        k.person(30, 50, top: Pal.dusty, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, arms: .forward, facing: 1, hat: Pal.mustard)
        k.line(38, 41, 66, 33, 0.5, Pal.dark); k.line(66, 33, 66, 44, 0.3, Pal.dark); k.oval(66, 44.6, 1, 1, Pal.terracotta)
        // rowing boat
        k.poly([(70, 52), (92, 52), (88, 57), (74, 57)], Pal.terracotta)
        k.person(80, 54, scale: 0.8, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, facing: 1)
        // picnic blanket and woman
        k.poly([(8, 70), (36, 70), (40, 74.5), (4, 74.5)], Pal.terracotta); k.poly([(14, 70), (18, 70), (16, 74.5), (12, 74.5)], Pal.white)
        k.person(22, 72, top: Pal.plum, bottom: Pal.dusty, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, facing: 1, hat: Pal.cream)
        k.rect(33, 66.5, 2.4, 5, Pal.dusty, r: 0.8); k.oval(31, 71, 1.6, 1, Pal.white)
        for x in [92.0, 95, 98] { k.line(x, 62, x + 0.6, 52, 0.6, Pal.leaf) }
        return k
    }

    // MARK: Family dinner — four people, one raising a glass
    private static var familyDinner: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, rgb(0.88, 0.80, 0.68))
        k.rect(0, 58, 100, 17, Pal.floor)
        k.rect(10, 8, 22, 20, Pal.white); k.rect(12, 10, 18, 16, rgb(0.50, 0.58, 0.78)); k.oval(26, 14, 2.6, 2.6, Pal.yellow)
        k.oval(80, 14, 6, 6, Pal.white); k.ring(80, 14, 6, 1, Pal.wood); k.line(80, 14, 80, 10, 0.7, Pal.dark); k.line(80, 14, 83, 15, 0.7, Pal.dark)
        k.line(50, 0, 50, 17, 0.6, Pal.dark); k.poly([(43, 24), (57, 24), (53, 17), (47, 17)], Pal.mustard)
        // four people
        k.person(24, 66, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, facing: 1)
        k.person(40, 66, top: Pal.terracotta, bottom: Pal.dark, skin: Pal.skinLight, hair: Pal.darkHair, sitting: true, arms: .up, facing: 1)
        k.person(62, 66, top: Pal.dusty, bottom: Pal.dark, skin: Pal.skinDeep, hair: Pal.darkHair, sitting: true, facing: -1)
        k.person(78, 66, top: Pal.plum, bottom: Pal.dark, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, arms: .forward, facing: -1)
        // table
        k.rect(10, 47, 80, 4, Pal.white); k.rect(10, 51, 80, 8, Pal.cream); k.rect(14, 59, 3, 14, Pal.wood); k.rect(83, 59, 3, 14, Pal.wood)
        k.oval(50, 45.6, 7, 1.8, Pal.white); k.oval(50, 44.4, 5, 1.8, Pal.terracotta)
        k.rect(34, 41, 1.6, 5, Pal.white); k.oval(34.8, 40, 0.8, 1.2, Pal.yellow)
        k.rect(68, 41, 1.6, 5, Pal.white); k.oval(68.8, 40, 0.8, 1.2, Pal.yellow)
        for x in [22.0, 30, 70, 80] { k.oval(x, 46, 2.6, 1, Pal.white) }
        k.rect(87, 42, 3, 5, Pal.sand, r: 0.8)
        return k
    }

    // MARK: Bus stop — waiting, a bus arriving, a shop
    private static var busStop: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, Pal.sky)
        k.rect(0, 12, 38, 42, Pal.brick); k.rect(5, 17, 28, 7, Pal.white)
        k.text("BAKERY", 19, 20.5, size: 4.4, Pal.brick)
        k.rect(5, 28, 14, 14, Pal.sky); k.rect(23, 30, 8, 24, Pal.wood)
        k.rect(0, 54, 100, 7, rgb(0.84, 0.82, 0.78)); k.rect(0, 61, 100, 14, Pal.dark.opacity(0.85))
        for i in 0..<6 { k.rect(Double(i) * 18 + 4, 68, 9, 1.2, Pal.white) }
        // bus
        k.rect(52, 36, 46, 24, Pal.mustard, r: 3); k.rect(52, 52, 46, 2, Pal.terracotta)
        for i in 0..<4 { k.rect(55 + Double(i) * 10, 40, 8, 8, Pal.sky, r: 1) }
        k.rect(88, 40, 8, 14, Pal.sky, r: 1)
        k.oval(62, 61, 4.2, 4.2, Pal.dark); k.oval(86, 61, 4.2, 4.2, Pal.dark)
        k.oval(60, 44, 2, 2, Pal.skinLight); k.oval(70, 44, 2, 2, Pal.skinMid)      // passengers
        // stop sign and people
        k.rect(43, 30, 1.4, 26, Pal.dark); k.oval(43.7, 29, 4, 4, Pal.dusty); k.text("BUS", 43.7, 29, size: 2.6, Pal.white)
        k.rect(8, 50, 22, 2, Pal.wood); k.rect(9, 52, 2, 5, Pal.wood); k.rect(27, 52, 2, 5, Pal.wood)
        k.person(36, 58, top: Pal.sage, bottom: Pal.dusty, skin: Pal.skinLight, hair: Pal.greyHair, arms: .forward, facing: 1)
        k.rect(42, 50, 4, 5, Pal.terracotta, r: 0.8)                                // shopping bag
        k.person(15, 58, top: Pal.plum, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, arms: .forward, facing: 1)
        k.rect(21, 44, 6, 8, Pal.white, r: 0.5)                                    // newspaper
        k.rect(95, 44, 4, 12, Pal.dusty, r: 1)                                     // post box
        return k
    }

    // MARK: Porch at dusk — tea for two
    private static var porch: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 22, rgb(0.55, 0.60, 0.78)); k.rect(0, 22, 100, 18, rgb(0.93, 0.72, 0.62)); k.rect(0, 40, 100, 35, rgb(0.97, 0.84, 0.66))
        k.oval(78, 38, 7, 7, Pal.yellow)
        k.poly([(0, 44), (14, 34), (28, 44)], rgb(0.38, 0.45, 0.50)); k.poly([(60, 44), (80, 32), (100, 44)], rgb(0.38, 0.45, 0.50))
        k.rect(0, 2, 44, 52, rgb(0.86, 0.80, 0.72)); k.rect(14, 12, 14, 42, Pal.wood); k.oval(25, 34, 1, 1, Pal.mustard)
        k.rect(4, 14, 8, 12, rgb(0.98, 0.88, 0.58)); k.rect(32, 14, 8, 12, rgb(0.98, 0.88, 0.58))
        k.rect(0, 54, 100, 21, Pal.lightWood); for i in 0..<8 { k.line(0, 56 + Double(i) * 2.6, 100, 56 + Double(i) * 2.6, 0.3, Pal.wood) }
        k.rect(0, 46, 100, 1.6, Pal.white); for i in 0..<26 { k.rect(Double(i) * 4 + 1, 47, 1.2, 7, Pal.white) }
        k.line(60, 0, 60, 14, 0.5, Pal.dark); k.rect(57.5, 14, 5, 6, Pal.yellow, r: 1)
        // two rocking chairs and people
        k.person(56, 70, top: Pal.terracotta, bottom: Pal.dark, skin: Pal.skinLight, hair: Pal.greyHair, sitting: true, arms: .forward, facing: 1)
        k.person(84, 70, top: Pal.sage, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.greyHair, sitting: true, arms: .forward, facing: -1)
        k.line(46, 70, 64, 73, 1, Pal.wood); k.line(76, 73, 94, 70, 1, Pal.wood)
        k.rect(50, 46, 2, 22, Pal.wood); k.rect(88, 46, 2, 22, Pal.wood)
        // tea table
        k.rect(66, 59, 12, 2, Pal.wood); k.rect(71, 61, 2, 10, Pal.wood)
        k.oval(72, 57.6, 3, 2, Pal.white); k.rect(75, 56.6, 2.5, 0.8, Pal.white); k.oval(68.4, 58, 1.4, 1, Pal.white)
        // flower pots
        for x in [6.0, 18] { k.rect(x, 62, 7, 7, Pal.terracotta, r: 1); k.oval(x + 3.5, 60, 3.6, 3, Pal.leaf); k.oval(x + 3.5, 58, 1.4, 1.4, Pal.plum) }
        return k
    }

    // MARK: Bakery — baker and a customer
    private static var bakery: Ink {
        var k = Ink()
        k.rect(0, 0, 100, 75, rgb(0.93, 0.89, 0.80))
        for r in 0..<6 { for c in 0..<10 { k.rect(Double(c) * 10 + 0.5, Double(r) * 6 + 0.5, 9, 5, rgb(0.96, 0.94, 0.88)) } }
        k.rect(0, 58, 100, 17, Pal.floor)
        // shelves with loaves
        for row in 0..<2 {
            let y = 14 + Double(row) * 14
            k.rect(6, y + 8, 44, 1.8, Pal.wood)
            for i in 0..<5 { k.oval(12 + Double(i) * 8, y + 6, 3.6, 2.3, Pal.lightWood); k.line(10.6 + Double(i) * 8, y + 4.8, 11.8 + Double(i) * 8, y + 7, 0.3, Pal.wood) }
        }
        k.oval(72, 14, 6, 6, Pal.white); k.ring(72, 14, 6, 1, Pal.wood); k.line(72, 14, 72, 10, 0.7, Pal.dark); k.line(72, 14, 75, 14.5, 0.7, Pal.dark)
        k.rect(58, 4, 28, 4, Pal.terracotta, r: 1); k.text("FRESH BREAD", 72, 6.2, size: 2.8, Pal.white)
        // baker
        k.person(30, 62, scale: 1.1, top: Pal.white, bottom: Pal.dark, skin: Pal.skinMid, hair: Pal.darkHair, arms: .forward, facing: 1, hat: Pal.white)
        // counter
        k.rect(4, 46, 60, 14, Pal.wood); k.rect(4, 40, 60, 7, Pal.sky.opacity(0.6)); k.rect(3, 38.5, 62, 2, Pal.lightWood)
        for i in 0..<6 { k.oval(10 + Double(i) * 9, 44, 2.8, 1.8, i % 2 == 0 ? Pal.mustard : Pal.terracotta) }
        k.rect(50, 34, 8, 4.5, Pal.grey, r: 0.8)                                  // till
        // customer with a bag
        k.person(80, 70, scale: 1.1, top: Pal.dusty, bottom: Pal.plum, skin: Pal.skinLight, hair: Pal.greyHair, arms: .forward, facing: -1)
        k.rect(66, 58, 5, 7, Pal.cream, r: 0.8); k.line(67, 58, 70, 58, 0.5, Pal.wood)
        // baguette basket
        k.rect(88, 54, 9, 14, Pal.lightWood, r: 1)
        for i in 0..<3 { k.line(90 + Double(i) * 2.6, 53, 91 + Double(i) * 2.6, 44, 1.8, Pal.mustard) }
        return k
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Drawing
// ─────────────────────────────────────────────────────────────────────────────

struct PictureView: View {
    let picture: Picture

    var body: some View {
        Canvas { ctx, size in
            let u = size.width / 100
            for op in picture.ops {
                switch op {
                case let .rect(r, c, rad):
                    let rr = CGRect(x: r.minX * u, y: r.minY * u, width: r.width * u, height: r.height * u)
                    ctx.fill(Path(roundedRect: rr, cornerRadius: rad * u), with: .color(c))
                case let .ellipse(r, c):
                    ctx.fill(Path(ellipseIn: CGRect(x: r.minX * u, y: r.minY * u, width: r.width * u, height: r.height * u)), with: .color(c))
                case let .ring(r, w, c):
                    ctx.stroke(Path(ellipseIn: CGRect(x: r.minX * u, y: r.minY * u, width: r.width * u, height: r.height * u)),
                               with: .color(c), lineWidth: w * u)
                case let .poly(pts, c):
                    var p = Path()
                    for (i, pt) in pts.enumerated() {
                        let q = CGPoint(x: pt.x * u, y: pt.y * u)
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                    p.closeSubpath()
                    ctx.fill(p, with: .color(c))
                case let .line(a, b, w, c):
                    var p = Path()
                    p.move(to: CGPoint(x: a.x * u, y: a.y * u))
                    p.addLine(to: CGPoint(x: b.x * u, y: b.y * u))
                    ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w * u, lineCap: .round))
                case let .text(s, pt, size, c):
                    ctx.draw(Text(s).font(.system(size: size * u, weight: .bold, design: .rounded)).foregroundColor(c),
                             at: CGPoint(x: pt.x * u, y: pt.y * u))
                }
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Picture to describe")
    }
}
