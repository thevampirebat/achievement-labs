import Foundation
import WidgetKit

/// Only display state is shared. Authentication and event tokens never leave the app vault.
struct WidgetSnapshot: Codable {
    var state: LabsSessionAttributes.ContentState?
    var active: Bool
    var updated: Date
}
enum WidgetSnapshotStore {
    static let group = "group.org.achievementlabs.mobile"
    static let kind = "LabsHomeSessions"
    static var url: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:group)?.appendingPathComponent("session-widget.json") }
    static var available: Bool { url != nil }
    static func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf:url), data.count <= 32768 else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self,from:data)
    }
    static func write(_ state: LabsSessionAttributes.ContentState?,active:Bool) {
        guard let url, let data = try? JSONEncoder().encode(WidgetSnapshot(state:state,active:active,updated:Date())) else { return }
        do { try data.write(to:url,options:.atomic); WidgetCenter.shared.reloadTimelines(ofKind:kind) } catch { }
    }
}
