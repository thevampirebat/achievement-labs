import AppKit
import Foundation

// Native production component, with fixed sample clocks only for the picture.
@MainActor func sampleCard(large: Bool,stale: Bool = false,longNames: Bool = false) -> some View {
    HomeWidgetCard(large:large,sharing:true,hasData:true,stale:stale,spoofActive:true,queueActive:true,
        spoofGame:longNames ? "Dishonored: Definitive Edition — Complete Collection" : "The Evil Within",
        queueGame:longNames ? "A very long game: Complete Collection" : "The Evil Within",
        achievement:longNames ? "An achievement name that must wrap without overlapping the next-unlock clock" : "Master of Horror",
        handled:3,total:12,scheme:"achievementlabs-widgettest",
        spoofTimer:{ Text("37:04") },unlockTimer:{ Text("2:08") })
        .padding(16).frame(width:338,height:large ? 354 : 158)
        .background(.black,in:RoundedRectangle(cornerRadius:23)).environment(\.colorScheme,.dark)
}
@MainActor func writePreview<V: View>(_ view: V,name: String) throws {
    let renderer = ImageRenderer(content:view); renderer.scale = 2
    guard let cg = renderer.cgImage else { throw NSError(domain:"Widget preview",code:1) }
    let bitmap = NSBitmapImageRep(cgImage:cg)
    guard let png = bitmap.representation(using:.png,properties:[:]) else { throw NSError(domain:"Widget preview",code:2) }
    try png.write(to:URL(fileURLWithPath:"mobile/home-widget-previews/"+name+".png"))
}
try MainActor.assumeIsolated {
    try writePreview(sampleCard(large:false),name:"widget-medium")
    try writePreview(sampleCard(large:true),name:"widget-large")
    try writePreview(sampleCard(large:false,stale:true),name:"widget-stale")
    try writePreview(sampleCard(large:false,longNames:true),name:"widget-long-names")
    let picture = VStack(alignment:.leading,spacing:22) {
        VStack(alignment:.leading,spacing:6) {
            Text("Achievement Labs").font(.system(size:30,weight:.bold))
            Text("Home Screen widget test · sample data").font(.subheadline).foregroundStyle(.secondary)
        }
        HStack(alignment:.top,spacing:24) {
            VStack(alignment:.leading,spacing:10) {
                Text("MEDIUM").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                sampleCard(large:false)
                Text("When updates stop").font(.caption).foregroundStyle(.secondary).padding(.top,8)
                sampleCard(large:false,stale:true)
            }
            VStack(alignment:.leading,spacing:10) {
                Text("LARGE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                sampleCard(large:true)
            }
        }
        Text("Both timers have their own space. Controls open the app.\nShown from the production SwiftUI component; iOS margins may vary.")
            .font(.caption).foregroundStyle(.secondary)
    }.padding(28).background(Color(white:0.075)).foregroundStyle(.white).environment(\.colorScheme,.dark)
    try writePreview(picture,name:"AchievementLabs-Widget-Preview")
}
