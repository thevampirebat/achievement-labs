import Foundation
import ActivityKit
struct LabsSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spoofStarted: Date?
        var queueHandled: Int
        var queueTotal: Int
        var queueRunning: Bool
        var nextAction: Date?
    }
}
