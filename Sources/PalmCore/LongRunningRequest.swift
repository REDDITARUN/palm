import Foundation

/// Network silence is bounded, but active streaming has no short total-duration cap.
public enum LongRunningRequest {
    public static let silenceLimit: TimeInterval = 30 * 60
    public static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = silenceLimit
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        return URLSession(configuration: configuration)
    }()
}
