import SwiftUI
import PlamCore

/// Pixel artwork stays native and sharp in the app and exported progress cards.
struct PracticeTree: View {
    var days: [PracticeDay]
    var selected: Date? = nil
    var choose: ((Date) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: Date?
    private var leaves: [PracticeDay] { Array(days.suffix(56)) }
    private var artwork: PixelTreeArtwork { PixelTreeArtwork(days: days.count) }

    var body: some View {
        let art = artwork
        let positions = art.dayPositions(count: leaves.count)
        ZStack {
            Canvas { context, _ in
                let colors = colorScheme == .dark ? PixelTreeArtwork.nightColors : PixelTreeArtwork.colors
                for pixel in art.pixels {
                    context.fill(Path(art.rect(x: pixel.x, y: pixel.y)), with: .color(colors[pixel.tone]))
                }
            }.accessibilityHidden(true)
            ForEach(Array(leaves.enumerated()), id: \.element.id) { index, day in
                let point = positions[index]
                let active = hovered == day.date || selected == day.date
                Button { choose?(day.date) } label: {
                    // Small sunlit leaf clusters sit inside the canopy, on the same pixel grid.
                    Canvas { context, _ in
                        let light = active ? Color(red: 0.98, green: 0.88, blue: 0.54) : Color(red: 0.69, green: 0.83, blue: 0.53)
                        context.fill(Path(CGRect(x: 0, y: 0, width: art.unit, height: art.unit)), with: .color(light))
                        context.fill(Path(CGRect(x: art.unit, y: art.unit, width: art.unit, height: art.unit)), with: .color(light.opacity(active ? 1 : 0.55)))
                        if active { context.stroke(Path(CGRect(x: -2, y: -2, width: art.unit * 2 + 4, height: art.unit * 2 + 4)), with: .color(light), style: .init(lineWidth: 1, dash: [3, 2])) }
                    }.frame(width: art.unit * 2, height: art.unit * 2).contentShape(.rect)
                        .offset(y: active && !reduceMotion ? -2 : 0)
                }.buttonStyle(.plain).onHover { hovered = $0 ? day.date : nil }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: active)
                    .help(day.date.formatted(.dateTime.month(.abbreviated).day().year()) + " · \(day.count) practice answers")
                    .accessibilityLabel(day.date.formatted(.dateTime.month(.abbreviated).day()) + ", \(day.count) practice answers")
                    .position(point)
            }
        }.frame(width: 320, height: 265)
            .accessibilityElement(children: .contain).accessibilityLabel("Pixel learning tree, \(days.count) practice days")
    }
}

private struct PixelTreeArtwork {
    struct Pixel { var x: Int; var y: Int; var tone: Int }
    let days: Int
    let unit: CGFloat = 7
    private var growth: Double { min(1, Double(max(0, days)) / 28) }
    // A crown develops only after the first week of practice.
    private var radius: Double { days == 0 ? 3 : 7 + floor(growth * 6) }
    private var crownY: Double { days == 0 ? 24 : 18 - floor(growth * 4) }
    static let colors: [Color] = [
        Color(red: 0.88, green: 0.91, blue: 0.86), // ground
        Color(red: 0.36, green: 0.30, blue: 0.23), // bark shade
        Color(red: 0.53, green: 0.43, blue: 0.30), // bark
        Color(red: 0.68, green: 0.57, blue: 0.38), // bark light
        Color(red: 0.19, green: 0.36, blue: 0.28), // canopy shade
        Color(red: 0.27, green: 0.46, blue: 0.32),
        Color(red: 0.38, green: 0.58, blue: 0.37),
        Color(red: 0.52, green: 0.69, blue: 0.43),
        Color(red: 0.64, green: 0.77, blue: 0.50)
    ]
    static let nightColors: [Color] = [Color(red: 0.17, green: 0.21, blue: 0.18)] + Array(colors.dropFirst())
    func rect(x: Int, y: Int) -> CGRect { .init(x: 48 + CGFloat(x) * unit, y: 15 + CGFloat(y) * unit, width: unit, height: unit) }
    private func inCrown(_ x: Int, _ y: Int) -> Bool {
        let px = Double(x) - 16, py = Double(y) - crownY, r = radius
        // Overlapping lobes create an asymmetrical, stepped oak silhouette.
        let lobes: [(Double, Double, Double, Double)] = [(-r * 0.40, -r * 0.18, r * 0.65, r * 0.58), (r * 0.18, -r * 0.50, r * 0.63, r * 0.53), (r * 0.55, -r * 0.02, r * 0.55, r * 0.56), (-r * 0.38, r * 0.37, r * 0.64, r * 0.48), (r * 0.20, r * 0.40, r * 0.67, r * 0.45)]
        return lobes.contains { cx, cy, rx, ry in pow((px - cx) / rx, 2) + pow((py - cy) / ry, 2) <= 1 }
    }
    var pixels: [Pixel] {
        var result: [Pixel] = []
        if days < 7 {
            for x in 12...20 { result.append(.init(x: x, y: 30, tone: 0)) }
            if days == 0 { return result + [.init(x: 16, y: 29, tone: 2), .init(x: 17, y: 29, tone: 3)] }
            let top = days <= 2 ? 25 : days <= 4 ? 22 : 19
            for y in top...29 { result.append(.init(x: 16, y: y, tone: 5)) }
            for (index, leaf) in earlyLeaves.prefix(days).enumerated() {
                result.append(.init(x: index % 2 == 0 ? 15 : 17, y: leaf.1 + 1, tone: 5))
                for (dx, dy) in [(0,0), (1,0), (0,1), (1,1), (index % 2 == 0 ? -1 : 2,0)] {
                    result.append(.init(x: leaf.0 + dx, y: leaf.1 + dy, tone: dy == 0 ? 7 : 5))
                }
            }
            return result
        }
        // A few grounded pixels, with no floating ornaments or frame.
        for x in 10...22 { result.append(.init(x: x, y: 30, tone: 0)) }
        for x in 12...20 { result.append(.init(x: x, y: 31, tone: 0)) }
        let top = Int(crownY), trunkWidth = days < 7 ? 2 : 3
        for y in top...29 {
            for x in 15..<(15 + trunkWidth) { result.append(.init(x: x, y: y, tone: x == 15 ? 3 : x == 16 ? 2 : 1)) }
        }
        result += [Pixel(x: 14, y: 29, tone: 2), Pixel(x: 18, y: 29, tone: 1)]
        if days > 3 {
            for step in 0...4 {
                result.append(.init(x: 15 - step, y: Int(crownY) + 8 - step, tone: 2))
                result.append(.init(x: 17 + step, y: Int(crownY) + 6 - step, tone: 1))
            }
        }
        for y in 0..<29 { for x in 0..<32 where inCrown(x, y) {
            let height = (Double(y) - crownY) / radius
            let light = Double(x - 16) / radius * 0.28 + height
            var tone = light < -0.48 ? 8 : light < -0.04 ? 7 : light < 0.42 ? 6 : 5
            if !inCrown(x, y + 1) { tone = 4 }
            // Sparse, aligned texture avoids a noisy random-pixel appearance.
            if (x * 3 + y * 5) % 13 == 0 && tone > 5 { tone -= 1 }
            if height > 0.1 && (x + y * 2) % 17 == 0 { tone = 4 }
            result.append(.init(x: x, y: y, tone: tone))
        } }
        return result
    }
    private var earlyLeaves: [(Int, Int)] { [(13,25), (17,24), (13,22), (18,21), (12,19), (17,18)] }
    func dayPositions(count: Int) -> [CGPoint] {
        if days < 7 { return earlyLeaves.prefix(count).map { x, y in let r = rect(x: x, y: y); return CGPoint(x: r.minX + unit, y: r.minY + unit) } }
        guard count > 0 else { return [] }
        var candidates: [(Int, Int)] = []
        for y in stride(from: 1, to: 28, by: 2) { for x in stride(from: 2, to: 31, by: 2) {
            if inCrown(x, y) && inCrown(x + 1, y) && inCrown(x, y + 1) && inCrown(x + 1, y + 1) { candidates.append((x, y)) }
        } }
        // Spread day markers across the crown, keeping their native hit areas disjoint.
        var chosen: [(Int, Int)] = []
        var distances = candidates.map { p in -Double((p.0 - 14) * (p.0 - 14)) - pow(Double(p.1) - crownY + radius * 0.35, 2) }
        while chosen.count < count && !candidates.isEmpty {
            let next = distances.indices.max { distances[$0] < distances[$1] }!
            let point = candidates.remove(at: next); distances.remove(at: next)
            if chosen.isEmpty { distances = Array(repeating: .infinity, count: candidates.count) }
            chosen.append(point)
            for i in candidates.indices {
                let dx = candidates[i].0 - point.0, dy = candidates[i].1 - point.1
                distances[i] = min(distances[i], Double(dx * dx + dy * dy))
            }
        }
        return chosen.map { x, y in let r = rect(x: x, y: y); return CGPoint(x: r.minX + unit, y: r.minY + unit) }
    }
}
