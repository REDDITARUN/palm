import SwiftUI
import AppKit
import PlamCore

struct GraphCanvasNode: Equatable {
    var node: KnowledgeNode
    var point: CGPoint
    var color: NSColor
}

/// Camera and pointer state stay in AppKit: dragging does not rebuild the SwiftUI inspector.
struct GraphNavigationSurface: NSViewRepresentable {
    var nodes: [GraphCanvasNode]
    var links: [KnowledgeLink]
    var selected: String?
    var command: String
    var commandID: UUID
    var select: (String?) -> Void
    var open: (KnowledgeNode) -> Void
    func makeNSView(context: Context) -> NavigationView { NavigationView() }
    func updateNSView(_ view: NavigationView, context: Context) {
        view.select = select; view.open = open
        view.update(nodes: nodes, links: links, selected: selected)
        if view.commandID != commandID {
            view.commandID = commandID
            switch command { case "in": view.zoom(1.25, at: view.center); case "out": view.zoom(0.8, at: view.center); default: view.fit() }
        }
    }
    final class NavigationView: NSView {
        var select: ((String?) -> Void)?
        var open: ((KnowledgeNode) -> Void)?
        var commandID: UUID?
        private var nodes: [GraphCanvasNode] = []
        private var links: [KnowledgeLink] = []
        private var positions: [String: CGPoint] = [:]
        private var adjacency: [String: Set<String>] = [:]
        private var selected: String?
        private var hovered: String?
        private var viewport = GraphViewport()
        private var scale: Double { get { viewport.scale } set { viewport.scale = newValue } }
        private var pan: CGPoint { get { viewport.pan } set { viewport.pan = newValue } }
        private var last: CGPoint?
        private var down: CGPoint?
        private var dragged = false
        private var draggedID: String?
        private var tracking: NSTrackingArea?
        private var labelRects: [String: CGRect] = [:]
        var center: CGPoint { .init(x: bounds.midX, y: bounds.midY) }
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect); wantsLayer = true
            setAccessibilityRole(.group); setAccessibilityLabel("Knowledge graph. Drag empty space to pan, drag a dot to arrange it, pinch to zoom. Arrow keys pan; plus and minus zoom; zero fits the graph.")
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func update(nodes newNodes: [GraphCanvasNode], links newLinks: [KnowledgeLink], selected newSelection: String?) {
            let changed = nodes != newNodes || links != newLinks
            let idsChanged = nodes.map(\.node.id) != newNodes.map(\.node.id)
            if changed {
                let prior = Dictionary(uniqueKeysWithValues: nodes.map { ($0.node.id, $0.point) })
                nodes = newNodes; links = newLinks
                positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.node.id, prior[$0.node.id] == $0.point ? positions[$0.node.id] ?? $0.point : $0.point) })
                adjacency = [:]
                for link in links { adjacency[link.source, default: []].insert(link.target); adjacency[link.target, default: []].insert(link.source) }
                if idsChanged { hovered = nil; fit() }
            }
            if changed || selected != newSelection { selected = newSelection; needsDisplay = true; updateAccessibility() }
        }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited], owner: self)
            addTrackingArea(area); tracking = area
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
        private func screen(_ id: String) -> CGPoint { let p = positions[id] ?? .zero; return .init(x: center.x + p.x * scale + pan.x, y: center.y + p.y * scale + pan.y) }
        private func radius(_ node: KnowledgeNode) -> Double { node.kind == "Course" ? 12 : min(10, 6 + sqrt(Double(adjacency[node.id]?.count ?? 0))) }
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let active = hovered ?? selected
            let neighborhood = active.map { (adjacency[$0] ?? []).union([$0]) }
            let ids = Set(nodes.map(\.node.id))
            for link in links where ids.contains(link.source) && ids.contains(link.target) {
                let strong = link.source == active || link.target == active
                NSColor.secondaryLabelColor.withAlphaComponent(strong ? 0.55 : active == nil ? 0.16 : 0.045).setStroke()
                let path = NSBezierPath(); path.move(to: screen(link.source)); path.line(to: screen(link.target)); path.lineWidth = strong ? 1.5 : 0.8; path.stroke()
            }
            labelRects = [:]
            // Selected and hovered labels render last and win label hit testing.
            let ordered = nodes.filter { $0.node.id != active } + nodes.filter { $0.node.id == active }
            for item in ordered {
                let id = item.node.id, point = screen(id), r = radius(item.node)
                let isActive = id == active, faded = neighborhood.map { !$0.contains(id) } ?? false
                if isActive { item.color.withAlphaComponent(0.13).setFill(); NSBezierPath(ovalIn: CGRect(x: point.x-r-6, y: point.y-r-6, width: (r+6)*2, height: (r+6)*2)).fill() }
                item.color.withAlphaComponent(faded ? 0.35 : 0.95).setFill()
                NSBezierPath(ovalIn: CGRect(x: point.x-r, y: point.y-r, width: r*2, height: r*2)).fill()
                if scale >= 0.75 || isActive || item.node.kind == "Course" {
                    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: isActive || item.node.kind == "Course" ? 12 : 11, weight: isActive ? .medium : .regular), .foregroundColor: NSColor.labelColor.withAlphaComponent(faded ? 0.40 : isActive ? 1 : 0.7), .paragraphStyle: paragraph]
                    let width = min(156, ceil((item.node.title as NSString).size(withAttributes: attrs).width) + 8)
                    let rect = CGRect(x: point.x-width/2, y: point.y+r+9, width: width, height: 32)
                    if isActive { NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill(); NSBezierPath(roundedRect: rect.insetBy(dx: -4, dy: -3), xRadius: 4, yRadius: 4).fill() }
                    (item.node.title as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs)
                    labelRects[id] = rect
                }
            }
        }
        private func hit(_ point: CGPoint) -> String? {
            // Dots have priority over labels; no oversized invisible rectangles overlap neighboring dots.
            let nearest = nodes.min { a, b in distance(point, screen(a.node.id)) < distance(point, screen(b.node.id)) }
            if let nearest, distance(point, screen(nearest.node.id)) <= radius(nearest.node) + 6 { return nearest.node.id }
            if let active = hovered ?? selected, labelRects[active]?.contains(point) == true { return active }
            return nodes.filter { labelRects[$0.node.id]?.contains(point) == true }.min { distance(point, screen($0.node.id)) < distance(point, screen($1.node.id)) }?.node.id
        }
        private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x-b.x, a.y-b.y) }
        override func mouseMoved(with event: NSEvent) {
            let next = hit(convert(event.locationInWindow, from: nil))
            if hovered != next { hovered = next; needsDisplay = true }
            (next == nil ? NSCursor.openHand : NSCursor.pointingHand).set()
        }
        override func mouseExited(with event: NSEvent) { hovered = nil; needsDisplay = true }
        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            let point = convert(event.locationInWindow, from: nil)
            last = point; down = point; dragged = false; draggedID = hit(point)
            if event.clickCount == 2, let item = nodes.first(where: { $0.node.id == draggedID }) { open?(item.node) }
        }
        override func mouseDragged(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            guard let last, let down else { return }
            if !dragged && distance(point, down) < 4 { return }
            let origin = dragged ? last : down; dragged = true
            let dx = point.x-origin.x, dy = point.y-origin.y
            if let id = draggedID, let position = positions[id] { positions[id] = .init(x: position.x+dx/scale, y: position.y+dy/scale) }
            else { pan.x += dx; pan.y += dy }
            self.last = point; NSCursor.closedHand.set(); needsDisplay = true
        }
        override func mouseUp(with event: NSEvent) {
            if !dragged && event.clickCount == 1 { select?(draggedID) }
            last = nil; down = nil; draggedID = nil; updateAccessibility(); NSCursor.openHand.set()
        }
        override func scrollWheel(with event: NSEvent) {
            if !event.hasPreciseScrollingDeltas || event.modifierFlags.contains(.command) { zoom(exp(Double(event.scrollingDeltaY) * 0.025), at: convert(event.locationInWindow, from: nil)) }
            else { pan.x += event.scrollingDeltaX; pan.y += event.scrollingDeltaY; needsDisplay = true }
        }
        override func magnify(with event: NSEvent) { zoom(1 + event.magnification, at: convert(event.locationInWindow, from: nil)) }
        func zoom(_ factor: Double, at point: CGPoint) {
            viewport.zoom(factor, at: point, center: center)
            needsDisplay = true; updateAccessibility()
        }
        func fit() {
            let points = Array(positions.values); guard !points.isEmpty, bounds.width > 0 else { return }
            let minX = points.map(\.x).min()!, maxX = points.map(\.x).max()!, minY = points.map(\.y).min()!, maxY = points.map(\.y).max()!
            scale = min(1.35, max(0.25, min((bounds.width-180)/max(260,maxX-minX), (bounds.height-180)/max(230,maxY-minY))))
            pan = .init(x: -(minX+maxX)/2*scale, y: -(minY+maxY)/2*scale-15); needsDisplay = true; updateAccessibility()
        }
        override func setFrameSize(_ newSize: NSSize) { let wasEmpty = bounds.isEmpty; super.setFrameSize(newSize); if wasEmpty { fit() } }
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: pan.x += 35; case 124: pan.x -= 35; case 125: pan.y -= 35; case 126: pan.y += 35
            default:
                switch event.charactersIgnoringModifiers { case "+", "=": zoom(1.25, at: center); case "-": zoom(0.8, at: center); case "0": fit(); case "\r": if let item = nodes.first(where: { $0.node.id == selected }) { open?(item.node) }; default: super.keyDown(with: event) }
            }
            needsDisplay = true
        }
        private func updateAccessibility() {
            setAccessibilityChildren(nodes.map { item in
                let element = GraphAccessibleNode()
                element.setAccessibilityRole(.button); element.setAccessibilityEnabled(true); element.setAccessibilityLabel(item.node.title + ", " + item.node.kind)
                element.setAccessibilityParent(self)
                let point = screen(item.node.id)
                element.setAccessibilityFrameInParentSpace(CGRect(x: point.x-16, y: bounds.height-point.y-16, width: 32, height: 32))
                element.action = { [weak self] in self?.select?(item.node.id) }
                return element
            })
        }
    }
}
private final class GraphAccessibleNode: NSAccessibilityElement {
    var action: (() -> Void)?
    override func accessibilityPerformPress() -> Bool { action?(); return true }
}
