import SwiftUI
import WidgetKit
import ActivityKit

@main struct LabsSessionWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for:LabsSessionAttributes.self) { context in
            VStack(alignment:.leading,spacing:8) {
                Text("Achievement Labs").font(.headline)
                if context.isStale { Text("Status needs refreshing · open app").font(.caption) }
                else {
                    if let start = context.state.spoofStarted { HStack { Label("Spoofing",systemImage:"gamecontroller.fill"); Spacer(); Text(start,style:.timer).monospacedDigit() } }
                    if context.state.queueRunning { Text("Queue: \(context.state.queueHandled)/\(context.state.queueTotal) handled").font(.caption) }
                    Text("Accepted requests need Xbox verification.").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Labs",systemImage:"gamecontroller.fill").foregroundStyle(.green) }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale, let start = context.state.spoofStarted { Text(start,style:.timer).monospacedDigit().frame(width:80) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale { Text("Status needs refreshing · open app").font(.caption) }
                    else if context.state.queueRunning { Text("Queue \(context.state.queueHandled)/\(context.state.queueTotal) handled · verify Xbox progress").font(.caption) }
                    else { Text("Title spoofing · extended audio session").font(.caption) }
                }
            } compactLeading: { Image(systemName:"gamecontroller.fill").foregroundStyle(.green) }
            compactTrailing: {
                if !context.isStale, let start = context.state.spoofStarted { Text(start,style:.timer).monospacedDigit().frame(width:60) }
                else { Image(systemName:"pause.fill") }
            } minimal: { Image(systemName:"gamecontroller.fill").foregroundStyle(.green) }
            .keylineTint(.green)
        }
    }
}
