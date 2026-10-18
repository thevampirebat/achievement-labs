import SwiftUI
import WidgetKit

struct LabsHomeEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}
struct LabsHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> LabsHomeEntry { LabsHomeEntry(date:Date(),snapshot:nil) }
    func getSnapshot(in context: Context,completion:@escaping(LabsHomeEntry)->Void) { completion(LabsHomeEntry(date:Date(),snapshot:WidgetSnapshotStore.read())) }
    func getTimeline(in context: Context,completion:@escaping(Timeline<LabsHomeEntry>)->Void) {
        let now=Date(),snapshot=WidgetSnapshotStore.read()
        var dates=[now]
        if let state=snapshot?.state {
            for date in [state.nextAction,state.spoofExpires,state.validUntil].compactMap({$0}) where date>now { dates.append(date.addingTimeInterval(1)) }
        }
        let entries=Array(Set(dates)).sorted().map { LabsHomeEntry(date:$0,snapshot:snapshot) }
        completion(Timeline(entries:entries,policy:.after(now.addingTimeInterval(900))))
    }
}
struct LabsHomeView: View {
    let entry: LabsHomeEntry
    @Environment(\.widgetFamily) var family
    private var state: LabsSessionAttributes.ContentState? { entry.snapshot?.state }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Image(systemName:"gamecontroller.fill").foregroundStyle(.green); Text("Achievement Labs").font(.headline); Spacer() }
            if let state {
                let stale=(state.validUntil ?? .distantPast)<entry.date
                if state.spoofStarted != nil {
                    HStack {
                        VStack(alignment:.leading,spacing:2) { Text("Spoofing").font(.caption).foregroundStyle(.green); Text(state.spoofGame ?? "Game").lineLimit(1).font(.caption) }
                        Spacer()
                        if let start=state.spoofStarted,let end=state.spoofExpires,entry.date<end {
                            Text(timerInterval:start...max(start,end),countsDown:false).monospacedDigit().font(.headline)
                        } else { Text("Check status").font(.caption) }
                    }
                }
                if state.queueRunning {
                    HStack {
                        VStack(alignment:.leading,spacing:2) { Text(state.queueGame ?? "Auto Unlock").font(.caption).foregroundStyle(.green); Text(state.nextAchievement ?? "Next achievement").font(.caption).lineLimit(family == .systemLarge ? 2 : 1) }
                        Spacer()
                        if let next=state.nextAction,entry.date<next {
                            Text(timerInterval:next.addingTimeInterval(-31_536_000)...next,countsDown:true).monospacedDigit().font(.headline).id(state.queueItemID ?? "")
                        } else { Text("Checking…").font(.caption) }
                    }
                    Text("\(state.queueHandled)/\(state.queueTotal) processed").font(.caption2).foregroundStyle(.secondary)
                }
                if !state.queueRunning && state.spoofStarted == nil { Text("Sessions paused").font(.subheadline) }
                if stale && entry.snapshot?.active == true { Text("Updates paused · open app to confirm").font(.caption2).foregroundStyle(.orange) }
            } else {
                Text("Open the app to share session status.").font(.caption)
                Text("Widget data needs App Groups support in the app's signing profile.").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength:0)
            HStack(spacing:16) {
                Link("Auto Unlock",destination:URL(string:"achievementlabs://queue")!)
                if state?.queueRunning == true { Link("Pause",destination:URL(string:"achievementlabs://queue/pause")!) }
                Link("Spoofing",destination:URL(string:"achievementlabs://spoof")!)
                if state?.spoofStarted != nil { Link("Stop",destination:URL(string:"achievementlabs://spoof/stop")!) }
            }.font(.caption.weight(.semibold)).foregroundStyle(.green)
        }.foregroundStyle(.white).containerBackground(.black,for:.widget).widgetURL(URL(string:"achievementlabs://home")!)
    }
}
struct LabsHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:WidgetSnapshotStore.kind,provider:LabsHomeProvider()) { LabsHomeView(entry:$0) }
            .configurationDisplayName("Labs sessions")
            .description("Spoofing time, next unlock and quick session controls. Controls open the app.")
            .supportedFamilies([.systemMedium,.systemLarge])
    }
}
@main struct LabsWidgets: WidgetBundle {
    var body: some Widget { LabsHomeWidget(); LabsSessionWidget() }
}
