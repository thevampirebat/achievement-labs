import SwiftUI
import WidgetKit

struct LabsHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: HomeWidgetSnapshot?
}
struct LabsHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> LabsHomeEntry { .init(date:Date(),snapshot:.demo()) }
    func getSnapshot(in context: Context,completion:@escaping(LabsHomeEntry)->Void) {
        completion(.init(date:Date(),snapshot:context.isPreview ? .demo() : WidgetSnapshotStore.read()))
    }
    func getTimeline(in context: Context,completion:@escaping(Timeline<LabsHomeEntry>)->Void) {
        let now = Date(),snapshot = WidgetSnapshotStore.read()
        var dates = [now]
        if let snapshot {
            for date in [snapshot.nextAction,snapshot.spoofExpires,snapshot.validUntil].compactMap({ $0 }) where date > now { dates.append(date.addingTimeInterval(1)) }
        }
        completion(Timeline(entries:Array(Set(dates)).sorted().map { .init(date:$0,snapshot:snapshot) },policy:.after(now.addingTimeInterval(900))))
    }
}
struct LabsHomeView: View {
    let entry: LabsHomeEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let snapshot = entry.snapshot ?? .idle()
        let stale = snapshot.hasSession && !snapshot.isFresh(at:entry.date)
        HomeWidgetCard(large:family == .systemLarge,sharing:snapshot.sharingEnabled,hasData:entry.snapshot != nil,stale:stale,
                       spoofActive:snapshot.spoofStarted != nil,queueActive:snapshot.queueRunning,
                       spoofGame:snapshot.spoofGame,queueGame:snapshot.queueGame,achievement:snapshot.nextAchievement,
                       handled:snapshot.handled,total:snapshot.total,scheme:WidgetSnapshotStore.scheme,demo:snapshot.isDemo,
                       spoofTimer: {
                           if let start = snapshot.spoofStarted, let end = snapshot.spoofExpires, end > start {
                               Text(timerInterval:start...end,countsDown:false)
                           } else { Text("—") }
                       },unlockTimer: {
                           if let next = snapshot.nextAction, next > entry.date {
                               Text(timerInterval:next.addingTimeInterval(-31_536_000)...next,countsDown:true).id(next)
                           } else { Text("Checking…").font(.caption2) }
                       })
            .containerBackground(.black,for:.widget)
            .widgetURL(URL(string:WidgetSnapshotStore.scheme+"://home")!)
    }
}
struct LabsHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:WidgetSnapshotStore.kind,provider:LabsHomeProvider()) { LabsHomeView(entry:$0) }
            .configurationDisplayName("Labs Widget Test")
            .description("Spoofing and Auto Unlock status. Controls open the test app.")
            .supportedFamilies([.systemMedium,.systemLarge])
    }
}
