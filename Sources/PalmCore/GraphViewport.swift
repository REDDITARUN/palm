import Foundation

/// World-to-view transform shared by all graph input paths.
public struct GraphViewport {
    public var scale: Double = 1
    public var pan: CGPoint = .zero
    public init() {}
    public func project(_ point: CGPoint, center: CGPoint) -> CGPoint { .init(x: center.x + point.x * scale + pan.x, y: center.y + point.y * scale + pan.y) }
    public func unproject(_ point: CGPoint, center: CGPoint) -> CGPoint { .init(x: (point.x - center.x - pan.x) / scale, y: (point.y - center.y - pan.y) / scale) }
    public mutating func zoom(_ factor: Double, at point: CGPoint, center: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        let next = min(3, max(0.25, scale * factor)), ratio = next / scale
        pan.x = point.x - center.x - (point.x - center.x - pan.x) * ratio
        pan.y = point.y - center.y - (point.y - center.y - pan.y) * ratio
        scale = next
    }
}
