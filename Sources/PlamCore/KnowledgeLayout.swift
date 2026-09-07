import Foundation

public enum KnowledgeLayout {
    public static func neighborhood(_ root: String, depth: Int, links: [KnowledgeLink]) -> Set<String> {
        var visited: Set<String> = [root], frontier = visited
        for _ in 0..<max(0, min(depth, 4)) {
            let next = Set(links.filter { frontier.contains($0.source) || frontier.contains($0.target) }.flatMap { [$0.source, $0.target] }).subtracting(visited)
            visited.formUnion(next); frontier = next
        }
        return visited
    }
    /// A deterministic, bounded spring layout. UI pan/zoom never reruns the simulation.
    public static func positions(nodes: [KnowledgeNode], links: [KnowledgeLink]) -> [String: CGPoint] {
        let nodes = nodes.sorted { $0.id < $1.id }, count = nodes.count
        guard count > 0 else { return [:] }
        let ids = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        let edges = links.compactMap { edge -> (Int, Int)? in guard let a = ids[edge.source], let b = ids[edge.target], a != b else { return nil }; return (a, b) }
        var positions = nodes.indices.map { i in let angle = Double(i) * 2.399963; let r = sqrt(Double(i + 1) / Double(count)) * max(170, sqrt(Double(count)) * 48); return CGPoint(x: cos(angle) * r, y: sin(angle) * r) }
        var velocity = Array(repeating: CGPoint.zero, count: count)
        for step in 0..<200 {
            var forces = positions.map { CGPoint(x: -$0.x * 0.008, y: -$0.y * 0.008) }
            for a in 0..<count { for b in (a + 1)..<count {
                let dx = positions[a].x - positions[b].x, dy = positions[a].y - positions[b].y
                let distance = max(1, hypot(dx, dy)); let repulsion = 3600 / (distance * distance) + max(0, 96 - distance) * 0.045
                let x = dx / distance * repulsion, y = dy / distance * repulsion
                forces[a].x += x; forces[a].y += y; forces[b].x -= x; forces[b].y -= y
            } }
            for (a, b) in edges {
                let dx = positions[b].x - positions[a].x, dy = positions[b].y - positions[a].y, distance = max(1, hypot(dx, dy))
                let strength = (distance - 150) * 0.018, x = dx / distance * strength, y = dy / distance * strength
                forces[a].x += x; forces[a].y += y; forces[b].x -= x; forces[b].y -= y
            }
            let cooling = max(0.12, 1 - Double(step) / 210)
            for i in nodes.indices {
                velocity[i].x = (velocity[i].x + forces[i].x) * 0.78; velocity[i].y = (velocity[i].y + forces[i].y) * 0.78
                positions[i].x += max(-12, min(12, velocity[i].x)) * cooling; positions[i].y += max(-12, min(12, velocity[i].y)) * cooling
            }
        }
        // Pack disconnected components separately; unrelated courses must not visually interweave.
        var adjacency = Array(repeating: Set<Int>(), count: count)
        for (a, b) in edges { adjacency[a].insert(b); adjacency[b].insert(a) }
        var remaining = Set(nodes.indices), groups: [[Int]] = []
        while let root = remaining.min() {
            var group = [root], cursor = 0; remaining.remove(root)
            while cursor < group.count {
                for neighbor in adjacency[group[cursor]].sorted() where remaining.contains(neighbor) { remaining.remove(neighbor); group.append(neighbor) }
                cursor += 1
            }
            groups.append(group)
        }
        if groups.count > 1 {
            let bounds = groups.map { group -> CGRect in
                let xs = group.map { positions[$0].x }, ys = group.map { positions[$0].y }
                return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            }
            let columns = Int(ceil(sqrt(Double(groups.count))))
            let cellWidth = max(180, bounds.map(\.width).max()! + 180)
            let cellHeight = max(150, bounds.map(\.height).max()! + 130)
            for (index, group) in groups.enumerated() {
                for member in group { positions[member].x += Double(index % columns) * cellWidth - bounds[index].midX; positions[member].y += Double(index / columns) * cellHeight - bounds[index].midY }
            }
        }
        return Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, positions[$0.offset]) })
    }
}
