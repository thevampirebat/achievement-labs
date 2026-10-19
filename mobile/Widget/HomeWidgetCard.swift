import SwiftUI

/// Shared by WidgetKit and the native preview renderer.
struct HomeWidgetCard<SpoofTimer: View, UnlockTimer: View>: View {
    let large: Bool
    let sharing: Bool
    let hasData: Bool
    let stale: Bool
    let spoofActive: Bool
    let queueActive: Bool
    let spoofGame: String
    let queueGame: String
    let achievement: String
    let handled: Int
    let total: Int
    let scheme: String
    var demo = false
    @ViewBuilder let spoofTimer: () -> SpoofTimer
    @ViewBuilder let unlockTimer: () -> UnlockTimer

    var body: some View {
        VStack(alignment:.leading,spacing:large ? 12 : 4) {
            HStack(spacing:6) {
                Image(systemName:"gamecontroller.fill").foregroundStyle(.green)
                Text(stale && !large ? "Updates paused · open app" : (demo ? "Achievement Labs · DEMO" : "Achievement Labs")).font(.system(size:14,weight:.semibold))
                Spacer(minLength:2)
                Circle().fill(stale ? Color.orange : (spoofActive || queueActive ? .green : .gray)).frame(width:6,height:6)
            }
            if !hasData || !sharing {
                Spacer(minLength:0)
                Text(sharing ? "Open the test app to share session status." : "Widget sharing is off").font(.subheadline)
                if large { Text("Enable sharing in Settings → App. The app and widget need matching App Group profiles.").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength:0)
            } else {
                sessionRow(label:"Title Spoofing",name:spoofGame.isEmpty ? "No game selected" : spoofGame,
                           detail:nil,active:spoofActive,timerLabel:"Elapsed",timer:spoofTimer)
                sessionRow(label:"Auto Unlock",name:queueGame.isEmpty ? "No queue running" : queueGame,
                           detail:achievement,active:queueActive,timerLabel:"Next unlock",timer:unlockTimer)
                if large {
                    HStack { Text("Queue progress"); Spacer(); Text("\(handled) / \(total) processed").monospacedDigit() }.font(.caption).foregroundStyle(.secondary)
                    ProgressView(value:Double(min(handled,total)),total:Double(max(1,total))).tint(.green)
                    Text(stale ? "Updates paused. Open the app to confirm status." : "Session timers · refresh Xbox to confirm unlocks.")
                        .font(.caption2).foregroundStyle(stale ? Color.orange : Color.secondary)
                    Spacer(minLength:0)
                }
            }
            HStack(spacing:large ? 16 : 10) {
                Link(destination:URL(string:scheme+"://queue")!) { Label(large ? "Auto Unlock" : "Queue",systemImage:"list.bullet") }
                if queueActive && !stale { Link("Pause",destination:URL(string:scheme+"://queue/pause")!) }
                Spacer(minLength:0)
                Link(destination:URL(string:scheme+"://spoof")!) { Label("Spoofing",systemImage:"gamecontroller") }
                if spoofActive && !stale { Link("Stop",destination:URL(string:scheme+"://spoof/stop")!) }
            }.font(.system(size:large ? 12 : 10,weight:.semibold)).foregroundStyle(.green).lineLimit(1)
        }.foregroundStyle(.white)
    }
    private func sessionRow<Timer: View>(label: String,name: String,detail: String?,active: Bool,timerLabel: String,@ViewBuilder timer: () -> Timer) -> some View {
        HStack(spacing:8) {
            VStack(alignment:.leading,spacing:2) {
                Text(!large && detail != nil ? label + " · " + name : label).lineLimit(1).font(.system(size:10,weight:.semibold)).foregroundStyle(active && !stale ? Color.green : Color.secondary)
                Text(!large ? (detail.flatMap { $0.isEmpty ? nil : $0 } ?? name) : name).font(.system(size:large ? 13 : 11,weight:.medium)).lineLimit(1).truncationMode(.tail)
                if large, let detail, !detail.isEmpty { Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            }.frame(maxWidth:.infinity,alignment:.leading)
            VStack(alignment:.trailing,spacing:2) {
                Text(timerLabel).font(.system(size:9)).foregroundStyle(.secondary)
                if stale && active { Text("Check app").font(.caption2) }
                else if active { timer().font(.system(size:large ? 23 : 19,weight:.semibold,design:.rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65) }
                else { Text("Paused").font(.caption2).foregroundStyle(.secondary) }
            }.frame(width:large ? 108 : 82,alignment:.trailing)
        }.padding(large ? 10 : 4).background {
            RoundedRectangle(cornerRadius:10).fill(active && !stale ? Color.green.opacity(0.065) : Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius:10).stroke(active && !stale ? Color.green.opacity(0.65) : Color.white.opacity(0.08),lineWidth:1))
        }
    }
}
