import SwiftUI
import LabsMobileCore

@main struct AchievementLabsApp: App {
    @StateObject private var model = MobileModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabView(selection: $model.selectedTab) {
                LibraryView().tabItem { Label("Library", systemImage: "books.vertical") }.tag(0)
                QueueView().tabItem { Label("Auto Unlock", systemImage: "list.bullet.rectangle") }.tag(1)
                PresenceView().tabItem { Label("Title Presence", systemImage: "gamecontroller") }.tag(2)
                SettingsView().tabItem { Label("Settings", systemImage: "gear") }.tag(3)
            }
            .environmentObject(model).tint(.green).preferredColorScheme(.dark)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.busy { ProgressView(model.status).font(.caption).padding(8).frame(maxWidth: .infinity).background(.ultraThinMaterial) }
            }
            .alert("Achievement Labs", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
            .onChange(of: phase) { _, value in if value == .active { model.active() } else { model.background() } }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var m: MobileModel
    @State private var search = ""
    @AppStorage("librarySort") private var sort = "Last played"
    var visible: [Game] {
        let filtered = m.games.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.contains(search) }
        return filtered.sorted { a,b in
            if sort == "Last played", a.lastPlayed != b.lastPlayed { return a.lastPlayed > b.lastPlayed }
            let ascending = a.name.localizedStandardCompare(b.name) == .orderedAscending
            return sort == "Z–A" ? !ascending : ascending
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(m.account.map { "\($0.gamertag) · \(m.games.count) games" } ?? "Connect your account in Settings.").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Sort", selection: $sort) { ForEach(["Last played", "A–Z", "Z–A"], id: \.self) { Text($0) } }
                }
                ForEach(visible) { game in
                    NavigationLink(value: game) {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: game.image)) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "gamecontroller").frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.06)) }.frame(width: 48,height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(game.name).font(.headline).lineLimit(2)
                                Text(game.platforms.joined(separator: " / ")).font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    Text("\(game.unlocked) / \(game.total > 0 ? String(game.total) : "?") achievements")
                                    if m.showMythic && (game.complete || m.baseCompleted.contains(game.id)) { Image(systemName: "star.circle.fill").foregroundStyle(.green).accessibilityLabel("Base game complete") }
                                }.font(.caption)
                                Text("Title ID: \(game.id)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }.listRowBackground(m.highlightCompleted && game.complete ? Color.green.opacity(0.18) : Color.clear)
                }
            }
            .navigationTitle("Achievement Labs")
            .navigationDestination(for: Game.self) { AchievementView(game: $0) }
            .searchable(text: $search, prompt: "Game name or Title ID")
            .refreshable { await m.refreshGames() }
            .toolbar { Button { Task { await m.refreshGames() } } label: { Image(systemName: "arrow.clockwise") }.disabled(m.account == nil || m.busy).accessibilityLabel("Refresh library") }
            .overlay { if m.games.isEmpty && !m.busy { ContentUnavailableView("Your Xbox library", systemImage: "gamecontroller", description: Text(m.account == nil ? "Open Settings to connect your account." : "Pull down or tap Refresh to load your games.")) } }
        }
    }
}

struct AchievementView: View {
    @EnvironmentObject var m: MobileModel
    let game: Game
    @State private var search = ""
    @State private var selected = Set<String>()
    @State private var filter = "All"
    @State private var sort = "Name"
    @State private var expanded: [String: Bool] = [:]
    var loaded: Bool { m.selectedGame?.id == game.id }
    var visible: [Achievement] {
        guard loaded else { return [] }
        return m.rows.filter { (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search)) && (filter == "All" || ($0.unlocked ? filter == "Unlocked" : filter == "Locked")) }.sorted {
            sort == "ID" ? ($0.id.localizedStandardCompare($1.id) == .orderedAscending) : ($0.name.localizedStandardCompare($1.name) == .orderedAscending)
        }
    }
    var groupNames: [String] {
        let preferred = m.catalogue?.groups(game) ?? ["Achievements"]
        let actual = Set(visible.map { m.catalogue?.group($0, game: game) ?? "Achievements" })
        return preferred.filter(actual.contains)
    }
    var body: some View {
        List {
            Section {
                Text(game.name).font(.title2).textSelection(.enabled)
                Text("Title ID: \(game.id)").font(.caption).textSelection(.enabled)
                if loaded { Label("\(m.rows.filter(\.unlocked).count) / \(m.rows.count) achievements", systemImage: m.showMythic && m.baseCompleted.contains(game.id) ? "star.circle.fill" : "trophy").foregroundStyle(.green) }
                if let status = m.catalogue?.index[game.id] { Text("Event data: \(status.classification) · \(status.count) mobile mappings").font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button("Open Auto Unlock") { m.enqueue(m.rows.filter { selected.contains($0.id) }, game: game); m.selectedTab = 1 }
                    Spacer()
                    Button("Open Title Presence") { m.presenceTitle = game.id; m.selectedTab = 2 }
                }.buttonStyle(.bordered).font(.caption)
            }
            Section {
                Picker("Show", selection: $filter) { ForEach(["All","Locked","Unlocked"],id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Picker("Sort", selection: $sort) { Text("Name").tag("Name"); Text("ID").tag("ID") }
                HStack {
                    Button("Select visible") { for row in visible where m.unavailable(row, game: game) == nil { selected.insert(row.id) } }
                    Spacer(); Button("Clear") { selected = [] }
                }.font(.caption)
                Button("Add \(selected.count) to queue") { m.enqueue(m.rows.filter { selected.contains($0.id) }, game: game) }.disabled(selected.isEmpty || m.running)
            }
            ForEach(groupNames, id: \.self) { group in
                Section {
                    DisclosureGroup(isExpanded: Binding(get: { expanded[group] ?? true }, set: { expanded[group] = $0 })) {
                        ForEach(visible.filter { (m.catalogue?.group($0, game: game) ?? "Achievements") == group }) { row in
                            VStack(alignment: .leading,spacing: 8) {
                                HStack(alignment: .top) {
                                    Button { if selected.contains(row.id) { selected.remove(row.id) } else { selected.insert(row.id) } } label: { Image(systemName: selected.contains(row.id) ? "checkmark.square.fill" : "square").font(.title3) }.disabled(m.running || m.unavailable(row, game: game) != nil).accessibilityLabel("Select \(row.name)")
                                    VStack(alignment: .leading,spacing: 5) { Text(row.name).font(.headline); Text(row.detail).font(.caption).foregroundStyle(.secondary) }
                                    Spacer(minLength: 6)
                                    if row.unlocked { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Unlocked") }
                                }
                                HStack { Text("ID \(row.id) · \(row.score)G").font(.caption2).foregroundStyle(.secondary); Spacer(); Button(row.unlocked ? "Retry" : "Unlock") { Task { await m.unlock(row, game: game) } }.buttonStyle(.bordered).disabled(m.busy || m.running || m.unavailable(row, game: game) != nil) }
                                if let reason = m.unavailable(row, game: game) { Text(reason).font(.caption2).foregroundStyle(.secondary) }
                                if let result = m.rowResults[row.id] { Text(result).font(.caption).foregroundStyle(.orange) }
                            }.padding(.vertical,6)
                        }
                    } label: { Text(group).foregroundStyle(.green).font(.headline) }
                }
            }
        }
        .navigationTitle("Achievements").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search achievements")
        .task(id: game.id) { await m.load(game) }
        .refreshable { await m.load(game) }
        .toolbar { Button { Task { await m.load(game) } } label: { Image(systemName: "arrow.clockwise") }.disabled(m.busy).accessibilityLabel("Refresh achievements") }
    }
}

struct QueueView: View {
    @EnvironmentObject var m: MobileModel
    var body: some View {
        NavigationStack {
            List {
                Section("Queue status") {
                    Label(m.running ? "Running in foreground" : "Paused", systemImage: m.running ? "play.fill" : "pause.fill")
                    Text(m.status).font(.caption).foregroundStyle(.secondary)
                    if let next = m.nextAction { HStack { Text("Next action"); Spacer(); Text(next, style: .timer).monospacedDigit() } }
                    if let start = m.presenceStarted { HStack { Text("Presence · \(m.presenceTitle)"); Spacer(); Text(start, style: .timer).monospacedDigit() }.font(.caption).foregroundStyle(.green) }
                    HStack { Button(m.running ? "Pause" : "Start / Resume") { if m.running { m.pauseQueue() } else { m.startQueue() } }.disabled(m.account == nil || m.busy); Spacer(); Button("Remove completed") { Task { await m.removeCompleted() } }.disabled(m.running || m.busy) }
                    Text("Queues pause when you leave the app. Accepted requests are not proof of an unlock; refresh to verify.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Options") {
                    Toggle("Stop on failure", isOn: $m.stopOnFailure)
                    Toggle("Stop if title presence fails", isOn: $m.stopOnPresenceFailure)
                    Toggle("Notify when queue completes", isOn: $m.notifyCompletion)
                    Stepper("New item delay: \(Int(m.queueDelay)) seconds", value: $m.queueDelay, in: 0...86400, step: 5)
                    Button("Save queue delays") { m.saveQueue() }.disabled(m.running)
                }
                Section("Achievements") {
                    ForEach(m.queue.indices, id: \.self) { i in
                        VStack(alignment: .leading,spacing: 7) {
                            Text(m.queue[i].achievement.name).font(.headline)
                            Text(m.queue[i].game.name).font(.caption).foregroundStyle(.secondary)
                            Text(m.queue[i].status).font(.caption).foregroundStyle(m.queue[i].status == "Already unlocked" ? .green : .secondary)
                            Stepper("Delay: \(Int(m.queue[i].delay)) seconds", value: $m.queue[i].delay, in: 0...86400, step: 5).disabled(m.running)
                            HStack {
                                if m.queue[i].status != "Waiting" { Button("Reset to waiting") { m.queue[i].status = "Waiting"; m.saveQueue() }.disabled(m.running) }
                                Spacer(); Button("Remove", role: .destructive) { m.queue.remove(at: i); m.saveQueue() }.disabled(m.running || m.busy)
                            }.font(.caption)
                        }.padding(.vertical,4)
                    }
                }
            }.navigationTitle("Auto Unlock")
        }
    }
}

struct PresenceView: View {
    @EnvironmentObject var m: MobileModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Title presence") {
                    TextField("Title ID", text: $m.presenceTitle).keyboardType(.numberPad).disabled(m.presenceStarted != nil)
                    if let start = m.presenceStarted { LabeledContent("Session elapsed") { Text(start, style: .timer).monospacedDigit() } }
                    Button("Start presence") { m.startPresence(m.presenceTitle) }.disabled(m.account == nil || m.presenceStarted != nil || !JSON.numeric(m.presenceTitle))
                    Button("Stop presence",role: .destructive) { Task { await m.stopPresence() } }.disabled(m.presenceStarted == nil)
                    Text("Works alongside the auto unlocker while the app is active. This is session elapsed time, not Xbox-recorded playtime. Backgrounding pauses it; the last server heartbeat can take time to expire.").font(.caption).foregroundStyle(.secondary)
                }
                Section { Toggle("Notify if presence stops", isOn: $m.notifyPresenceFailure) }
            }.navigationTitle("Title Presence")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var m: MobileModel
    @State private var authorization = ""
    @State private var eventToken = ""
    @State private var reveal = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Xbox account") {
                    Text(m.account?.gamertag ?? "Not connected")
                    SecureField("Paste Xbox authorization",text: $authorization).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Connect account") { Task { await m.connect(authorization); authorization = "" } }.disabled(authorization.isEmpty || m.busy || m.running || m.presenceStarted != nil)
                    Text("Use the full Xbox authorization starting XBL3.0 x=…;… . The account is checked with Xbox before saving. This first mobile beta uses manual tokens; Microsoft browser sign-in is not implemented yet.").font(.caption).foregroundStyle(.secondary)
                    if m.account != nil { Button("Disconnect",role: .destructive) { Task { await m.disconnect() } }.disabled(m.busy) }
                }
                Section("Event token") {
                    if reveal { TextField("Paste event token",text: $eventToken).textInputAutocapitalization(.never).autocorrectionDisabled() } else { SecureField("Paste event token",text: $eventToken).textInputAutocapitalization(.never).autocorrectionDisabled() }
                    Toggle("Show token", isOn: $reveal)
                    Button("Save event token") { m.saveEventToken(eventToken); eventToken = m.account?.eventToken ?? "" }.disabled(m.account == nil || eventToken.isEmpty || m.running || m.busy)
                    Button("Remove event token",role: .destructive) { m.removeEventToken(); eventToken = "" }.disabled(m.account == nil || m.running || m.busy)
                    Text("Stored in the iOS Keychain for this device. Changing accounts clears the previous account's event token from the active session. Retrieval from other apps is not available.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Appearance") { Toggle("Show base-game completion star", isOn: $m.showMythic); Toggle("Highlight 100% completed games", isOn: $m.highlightCompleted) }
                Section("Notifications") { Button("Allow notifications") { Task { await m.requestNotifications() } } }
                Section("Mobile beta") {
                    Text("Standalone iPhone and iPad app · 0.1.0").font(.headline)
                    Text("Bundled event data: fork v1.0.8-fork.1. Event actions use only deterministic recipes that passed mobile checks. Unsupported edition routing remains disabled. Live Xbox behaviour needs device testing. Windows-specific tools and automatic catalogue updates are not included in this first beta.").font(.caption).foregroundStyle(.secondary)
                    Link("Project on GitHub",destination: URL(string:"https://github.com/thevampirebat/achievement-labs")!)
                }
            }.navigationTitle("Settings")
            .onAppear { eventToken = m.account?.eventToken ?? "" }
            .onChange(of: m.account?.xuid) { _, _ in eventToken = m.account?.eventToken ?? "" }
        }
    }
}
