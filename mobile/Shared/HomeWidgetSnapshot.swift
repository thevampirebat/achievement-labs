import Foundation

/// A display-only allowlist. No account identifiers, credentials, event payloads or tokens.
struct HomeWidgetSnapshot: Codable, Equatable {
    var updatedAt: Date
    var validUntil: Date
    var sharingEnabled: Bool
    var spoofStarted: Date?
    var spoofExpires: Date?
    var spoofGame: String
    var queueRunning: Bool
    var nextAction: Date?
    var queueGame: String
    var nextAchievement: String
    var handled: Int
    var total: Int
    var isDemo = false
    var hasSession: Bool { spoofStarted != nil || queueRunning }
    func isFresh(at date: Date) -> Bool { sharingEnabled && date <= validUntil }
    static func idle(at now: Date = Date(),enabled: Bool = true) -> Self {
        .init(updatedAt:now,validUntil:now,sharingEnabled:enabled,spoofGame:"",queueRunning:false,queueGame:"",nextAchievement:"",handled:0,total:0)
    }
    static func demo(at now: Date = Date()) -> Self {
        .init(updatedAt:now,validUntil:now.addingTimeInterval(600),sharingEnabled:true,
              spoofStarted:now.addingTimeInterval(-2224),spoofExpires:now.addingTimeInterval(600),spoofGame:"The Evil Within",
              queueRunning:true,nextAction:now.addingTimeInterval(128),queueGame:"The Evil Within",nextAchievement:"Master of Horror",handled:3,total:12,isDemo:true)
    }
}
