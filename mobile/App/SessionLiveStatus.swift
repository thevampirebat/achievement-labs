import Foundation
import ActivityKit
@MainActor final class SessionLiveStatus {
    private var activity: Activity<LabsSessionAttributes>?
    init() {
        // A relaunched app has no running heartbeat worker. Never revive old work.
        for old in Activity<LabsSessionAttributes>.activities { Task { await old.end(nil,dismissalPolicy:.immediate) } }
    }
    func update(_ state: LabsSessionAttributes.ContentState, enabled: Bool) {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else { end(); return }
        let content = ActivityContent(state:state,staleDate:state.validUntil ?? Date(),relevanceScore:1)
        if activity == nil { activity = try? Activity.request(attributes:LabsSessionAttributes(),content:content,pushType:nil) }
        if let activity { Task { await activity.update(content) } }
    }
    func end() {
        guard let old = activity else { return }; activity = nil
        Task { await old.end(nil,dismissalPolicy:.immediate) }
    }
}

