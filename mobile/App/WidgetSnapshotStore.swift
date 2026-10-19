import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let kind = "LabsHomeSessionsTest"
    static var group: String { Bundle.main.object(forInfoDictionaryKey:"LabsWidgetAppGroup") as? String ?? "" }
    static var scheme: String { Bundle.main.object(forInfoDictionaryKey:"LabsWidgetURLScheme") as? String ?? "achievementlabs-widgettest" }
    static var url: URL? {
        guard group.hasPrefix("group.") else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:group)?.appendingPathComponent("session-widget.json")
    }
    static var available: Bool { url != nil }
    static func read() -> HomeWidgetSnapshot? {
        guard let url, let size = try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize, size <= 32768,
              let data = try? Data(contentsOf:url) else { return nil }
        return try? JSONDecoder().decode(HomeWidgetSnapshot.self,from:data)
    }
    private static var lastReload = Date.distantPast
    private static var lastSnapshot: HomeWidgetSnapshot?
    @discardableResult static func write(_ snapshot: HomeWidgetSnapshot,force: Bool = false) -> Bool {
        guard let url, let data = try? JSONEncoder().encode(snapshot), data.count <= 32768 else { return false }
        do {
            try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            let changed = lastSnapshot?.nextAction != snapshot.nextAction || lastSnapshot?.queueRunning != snapshot.queueRunning || lastSnapshot?.spoofStarted != snapshot.spoofStarted || lastSnapshot?.handled != snapshot.handled || lastSnapshot?.total != snapshot.total || lastSnapshot?.sharingEnabled != snapshot.sharingEnabled || lastSnapshot?.isDemo != snapshot.isDemo || lastSnapshot?.spoofGame != snapshot.spoofGame || lastSnapshot?.queueGame != snapshot.queueGame || lastSnapshot?.nextAchievement != snapshot.nextAchievement
            if force || changed || Date().timeIntervalSince(lastReload) >= 60 {
                WidgetCenter.shared.reloadTimelines(ofKind:kind); lastReload = Date()
            }
            lastSnapshot = snapshot
            return true
        } catch { return false }
    }
    static func clear() { _ = write(.idle(enabled:false),force:true) }
}
