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
                PresenceView().tabItem { Label("Title Spoofing", systemImage: "gamecontroller") }.tag(2)
                SettingsView().tabItem { Label("Settings", systemImage: "gear") }.tag(3)
            }
            .environmentObject(model).tint(.green).preferredColorScheme(.dark)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.busy { ProgressView(model.status).font(.caption).padding(8).frame(maxWidth: .infinity).background(.ultraThinMaterial) }
            }
            .overlay {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--web-callback-self-test") { CallbackCaptureTestView() }
                #endif
            }
            .alert("Achievement Labs", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
            .task { await model.maintainOnOpen() }
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
            let comparison = a.name.localizedStandardCompare(b.name)
            if comparison == .orderedSame { return a.id.localizedStandardCompare(b.id) == .orderedAscending }
            return sort == "Z–A" ? comparison == .orderedDescending : comparison == .orderedAscending
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileTile()
                    Picker("Sort", selection: $sort) { ForEach(["Last played", "A–Z", "Z–A"], id: \.self) { Text($0) } }.font(.subheadline)
                }
                Section {
                    ForEach(visible) { game in
                        NavigationLink(value:game) { LibraryGameRow(game:game) }
                            .listRowInsets(EdgeInsets(top:7,leading:14,bottom:7,trailing:14))
                            .listRowBackground(m.highlightCompleted && game.complete ? Color.green.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                            .swipeActions(edge:.trailing) {
                                Button("Spoof") { m.presenceTitle = game.id; m.titleDetails[game.id] = game; m.selectedTab = 2 }.tint(.green)
                                Button("Auto Unlock") { m.queueTitle = game.id; m.titleDetails[game.id] = game; m.selectedTab = 1 }.tint(.blue)
                            }
                    }
                }
            }
            .listSectionSpacing(.compact).navigationTitle("Library").navigationBarTitleDisplayMode(.inline)
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
                GameHeader(game:m.gameForTitle(game.id) ?? game)
                if let status = m.catalogue?.index[game.id] { Text("Event data: \(status.classification) · \(status.count) mobile mappings").font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button("Auto Unlock") { m.queueTitle = game.id; m.titleDetails[game.id] = game; if !selected.isEmpty { m.enqueue(m.rows.filter { selected.contains($0.id) }, game:game) }; m.selectedTab = 1 }
                    Spacer()
                    Button("Title Spoofing") { m.presenceTitle = game.id; m.titleDetails[game.id] = game; m.selectedTab = 2 }
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
    @State private var options = false
    var body: some View {
        NavigationStack {
            List {
                Section("Timing source") {
                    TextField("Reference gamertag",text:$m.referenceGamertag).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go).onSubmit { build() }.disabled(m.running || m.busy)
                    TextField("Title ID",text:$m.queueTitle).keyboardType(.numbersAndPunctuation).submitLabel(.go).onSubmit { build() }.disabled(m.running || m.busy)
                    if let game = m.gameForTitle(m.queueTitle) { GameHeader(game:game) }
                    Button("Build timing queue",systemImage:"clock.arrow.circlepath") { build() }.disabled(m.running || m.busy || m.account == nil || m.referenceGamertag.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !JSON.numeric(m.queueTitle))
                    if !m.referenceInfo.isEmpty { Text(m.referenceInfo).font(.caption).foregroundStyle(.secondary) }
                    Text("Uses intervals between the reference profile’s visible unlocks. Review the queue before starting; it does not copy past dates.").font(.caption2).foregroundStyle(.secondary)
                }
                Section("Queue") {
                    VStack(alignment:.leading,spacing:8) {
                        HStack { Label(m.running ? "Running" : "Paused",systemImage:m.running ? "play.fill" : "pause.fill"); Spacer(); Text("\(m.queue.count) items").foregroundStyle(.secondary) }.font(.subheadline)
                        Text(m.status).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        TimelineView(.periodic(from:.now,by:1)) { timeline in
                            VStack(alignment:.leading,spacing:3) {
                                if let next = m.nextAction { HStack { Text("Next action"); Spacer(); Text(next,style:.timer).monospacedDigit() } }
                                let remaining = remaining(at:timeline.date)
                                if remaining > 0 { Text("Estimated finish: " + timeline.date.addingTimeInterval(remaining).formatted(date:.abbreviated,time:.shortened)).foregroundStyle(.secondary) }
                            }.font(.caption)
                        }
                        HStack {
                            Button(m.running ? "Pause" : "Start / Resume",systemImage:m.running ? "pause.fill" : "play.fill") { if m.running { m.pauseQueue() } else { m.startQueue() } }.disabled(m.account == nil || m.busy || m.queue.isEmpty)
                            Spacer()
                            Button("Remove completed") { Task { await m.removeCompleted() } }.disabled(m.running || m.busy)
                        }.font(.subheadline).buttonStyle(.borderless)
                    }.padding(.vertical,2)
                }
                if m.presenceRunning || m.presenceStarted != nil { Section("Title Spoofing") { SpoofSummary() } }
                Section {
                    DisclosureGroup("Queue options",isExpanded:$options) {
                        Toggle("Stop on failure",isOn:$m.stopOnFailure)
                        Toggle("Stop if spoofing fails",isOn:$m.stopOnPresenceFailure)
                        Toggle("Notify on completion",isOn:$m.notifyCompletion)
                        Stepper("New item: \(Int(m.queueDelay)) sec",value:$m.queueDelay,in:0...86400,step:5)
                        Button("Save queue delays") { m.saveQueue() }.disabled(m.running)
                        Text("Queues pause when you leave the app. Refresh achievements to verify accepted requests.").font(.caption2).foregroundStyle(.secondary)
                    }
                }.font(.subheadline)
                Section("Achievements") {
                    ForEach(m.queue.indices,id: \.self) { i in
                        QueueRow(index:i)
                    }
                    if m.queue.isEmpty { Text("Build a timing queue above, or select achievements from Library.").font(.caption).foregroundStyle(.secondary) }
                }
            }.listSectionSpacing(.compact).navigationTitle("Auto Unlock").navigationBarTitleDisplayMode(.inline)
            .task(id:m.queueTitle) { do { try await Task.sleep(nanoseconds:400_000_000); try Task.checkCancellation(); await m.lookupTitle(m.queueTitle) } catch {} }
        }
    }
    private func build() { Task { await m.buildTimingQueue() } }
    private func remaining(at date: Date) -> Double {
        var value = m.queue.filter { $0.status == "Waiting" }.reduce(0) { $0 + $1.delay }
        if let next = m.nextAction, let first = m.queue.first(where: { $0.status == "Waiting" }) { value = value - first.delay + max(0,next.timeIntervalSince(date)) }
        return value
    }
}
struct QueueRow: View {
    @EnvironmentObject var m: MobileModel
    let index: Int
    var body: some View {
        if m.queue.indices.contains(index) {
            let item = m.queue[index]
            VStack(alignment:.leading,spacing:6) {
                HStack(spacing:8) {
                    GameArt(url:item.game.image,size:30)
                    VStack(alignment:.leading,spacing:2) { Text(item.achievement.name).font(.subheadline.weight(.semibold)); Text(item.game.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
                Text(item.status).font(.caption2).foregroundStyle(item.status == "Already unlocked" ? .green : .secondary)
                if let source = item.referenceGamertag, let date = item.referenceDate { Text(source + " · " + date.formatted(date:.abbreviated,time:.shortened)).font(.caption2).foregroundStyle(.secondary) }
                HStack {
                    Text("Delay (minutes)").font(.caption)
                    TextField("Minutes",value:Binding(get: { m.queue[index].delay / 60 },set: { if $0.isFinite { m.queue[index].delay = max(0,min($0*60,31_536_000)) } }),format:.number.precision(.fractionLength(0...2))).keyboardType(.decimalPad).multilineTextAlignment(.trailing).disabled(m.running)
                }
                HStack {
                    if item.status != "Waiting" { Button("Reset") { m.queue[index].status = "Waiting"; m.saveQueue() }.disabled(m.running) }
                    Spacer(); Button("Remove",role:.destructive) { m.queue.remove(at:index); m.saveQueue() }.disabled(m.running || m.busy)
                }.font(.caption).buttonStyle(.borderless)
            }.padding(.vertical,2)
        }
    }
}
struct PresenceView: View {
    @EnvironmentObject var m: MobileModel
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title ID",text:$m.presenceTitle).keyboardType(.numbersAndPunctuation).submitLabel(.done).onSubmit { Task { await m.lookupTitle(m.presenceTitle) } }.disabled(m.presenceRunning)
                    if let game = m.gameForTitle(m.presenceTitle) { GameHeader(game:game) }
                    if let start = m.presenceStarted { LabeledContent("Session elapsed") { Text(start,style:.timer).monospacedDigit() } }
                    if let hours = m.playedHours[m.presenceTitle] { LabeledContent("Xbox-recorded playtime",value:String(format:"%.2f hours",hours)).font(.caption) }
                    HStack {
                        Button("Start spoofing",systemImage:"play.fill") { m.startPresence(m.presenceTitle) }.disabled(m.account == nil || m.presenceRunning || m.busy || !JSON.numeric(m.presenceTitle))
                        Spacer()
                        Button("Stop",systemImage:"stop.fill",role:.destructive) { Task { await m.stopPresence() } }.disabled(!m.presenceRunning)
                    }.buttonStyle(.borderless)
                    Text(m.spoofStatus).font(.caption).foregroundStyle(.secondary)
                }
                if !m.spoofDiagnostics.isEmpty {
                    Section("Spoofing diagnostics") {
                        Text(m.spoofDiagnostics).font(.caption.monospaced()).textSelection(.enabled)
                        Button("Copy diagnostics",systemImage:"doc.on.doc") { UIPasteboard.general.string = m.spoofDiagnostics }
                        Text("Includes status, profile choice and server codes. Authorization and event tokens are excluded.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Notify if spoofing stops",isOn:$m.notifyPresenceFailure)
                    Button("Refresh Xbox playtime") { Task { await m.readPlaytime(m.presenceTitle) } }.disabled(m.account == nil || !JSON.numeric(m.presenceTitle))
                    Text("Runs alongside Auto Unlock while this app is active. The session timer and Xbox-recorded playtime are separate; Xbox may update recorded time later.").font(.caption2).foregroundStyle(.secondary)
                }.font(.subheadline)
            }.listSectionSpacing(.compact).navigationTitle("Title Spoofing").navigationBarTitleDisplayMode(.inline)
            .task(id:m.presenceTitle) { do { try await Task.sleep(nanoseconds:400_000_000); try Task.checkCancellation(); await m.lookupTitle(m.presenceTitle); await m.readPlaytime(m.presenceTitle) } catch {} }
        }
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var signInURL = ""
    @State private var embeddedLogin: SignInPage?
    @State private var advanced = false
    @EnvironmentObject var m: MobileModel
    @State private var authorization = ""
    @State private var eventToken = ""
    @State private var reveal = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Xbox account") {
                    Text(m.account?.gamertag ?? "Not connected")
                    if let profile = m.account?.loginProfile { Text("Current session: " + profile).font(.caption).foregroundStyle(.secondary) }
                    Picker("Sign-in profile",selection:$m.loginProfile) { ForEach(LoginProfile.allCases) { Text($0.rawValue).tag($0.rawValue) } }.disabled(m.busy || m.running || m.presenceRunning)
                    Text("Profile changes apply when you sign in again.").font(.caption2).foregroundStyle(.secondary)
                    Toggle("Remember sign-in",isOn:$m.rememberSignIn).disabled(m.busy || m.refreshingSignIn || m.running || m.presenceRunning).onChange(of:m.rememberSignIn) { _,_ in Task { await m.updateRememberSignIn() } }
                    Picker("Sign-in browser",selection:$m.signInBrowser) { Text("In app").tag("In app"); Text("Safari").tag("Safari") }.disabled(m.busy || m.refreshingSignIn)
                    Button("Sign in with Microsoft",systemImage:"person.crop.circle.badge.checkmark") {
                        if let url = m.beginBrowserLogin() {
                            if m.signInBrowser == "Safari" { advanced = true; signInURL = ""; openURL(url) }
                            else { embeddedLogin = SignInPage(url:url) }
                        }
                    }.disabled(m.busy || m.refreshingSignIn || m.running || m.presenceRunning)
                    if !m.sessionStatus.isEmpty { Text(m.sessionStatus).font(.caption).foregroundStyle(.secondary) }
                    if m.account?.refreshToken != nil && m.rememberSignIn { Button("Renew remembered sign-in") { Task { await m.renewSignIn() } }.disabled(m.busy || m.refreshingSignIn || m.running || m.presenceRunning) }
                    Text("Remembering stores renewal credentials in this device’s Keychain, not your password. Sign in once after this update to enable renewal. For incorrect password suggestions in the webpage, try Safari or choose your Microsoft account from Passwords.").font(.caption2).foregroundStyle(.secondary)
                    DisclosureGroup("Safari / manual sign-in",isExpanded:$advanced) {
                    Button("Sign in using Safari") { if let url = m.beginBrowserLogin() { signInURL = ""; openURL(url) } }.disabled(m.busy || m.running || m.presenceRunning)
                    if m.browserPending {
                        Text("Sign in in the browser. On the final page, copy the entire address from the address bar, return here and paste it below. The final page may be blank. Never share this URL.").font(.caption)
                        SecureField("Paste final sign-in URL", text: $signInURL).textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Finish browser sign-in") { let value = signInURL; signInURL = ""; Task { await m.finishBrowserLogin(value) } }.disabled(signInURL.isEmpty || m.busy)
                        Button("Cancel sign-in", role: .cancel) { signInURL = ""; m.cancelBrowserLogin() }.disabled(m.busy)
                    }
                    SecureField("Paste Xbox authorization",text: $authorization).textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Connect account") { Task { await m.connect(authorization); authorization = "" } }.disabled(authorization.isEmpty || m.busy || m.running || m.presenceRunning)
                    Text("Use the full Xbox authorization starting XBL3.0 x=…;… . The account is checked with Xbox before saving. Manual authorization is an advanced alternative to browser sign-in. The event token below is separate from account authorization.").font(.caption).foregroundStyle(.secondary)
                    }
                    if m.account != nil { Button("Disconnect",role: .destructive) { Task { await m.disconnect() } }.disabled(m.busy) }
                }
                Section("Event token") {
                    if reveal { TextField("Paste event token",text: $eventToken).textInputAutocapitalization(.never).autocorrectionDisabled() } else { SecureField("Paste event token",text: $eventToken).textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled() }
                    Toggle("Show token", isOn: $reveal)
                    Button("Save event token") { m.saveEventToken(eventToken); eventToken = m.account?.eventToken ?? "" }.disabled(m.account == nil || eventToken.isEmpty || m.running || m.busy)
                    Button("Remove event token",role: .destructive) { m.removeEventToken(); eventToken = "" }.disabled(m.account == nil || m.running || m.busy)
                    Text("Stored in the iOS Keychain for this device. Changing accounts clears the previous account's event token from the active session. Retrieval from other apps is not available.").font(.caption).foregroundStyle(.secondary)
                }
                SyncSettings()
                Section("Appearance") { Toggle("Show Mythic for base completion", isOn: $m.showMythic); Toggle("Highlight 100% completed games", isOn: $m.highlightCompleted) }
                Section("Completion indicators") {
                    Text("Mythic is the same local base-completion marker as desktop. The profile count includes verified base completions and titles with every achievement unlocked; it can increase after scanning.").font(.caption).foregroundStyle(.secondary)
                    Text("Checked \(m.checkedCompletion.count) of \(m.games.count) titles").font(.caption)
                    Button("Scan unchecked titles, one at a time") { Task { await m.scanCompletion() } }.disabled(m.account == nil || m.busy || m.running || m.games.isEmpty)
                    if m.scanningCompletion { Button("Stop after current title",role:.destructive) { m.scanningCompletion = false } }
                    Text(m.status).font(.caption2).foregroundStyle(.secondary)
                }
                Section("Notifications") { Button("Allow notifications") { Task { await m.requestNotifications() } } }
                Section("Mobile beta") {
                    Text("Standalone iPhone and iPad app · 0.3.0").font(.headline)
                    Text("Bundled event data: fork v1.0.8-fork.1. Event actions use only deterministic recipes that passed mobile checks. Unsupported edition routing remains disabled. Live Xbox behaviour needs device testing. Windows-specific tools and automatic catalogue updates are not included in this first beta.").font(.caption).foregroundStyle(.secondary)
                    Text("App identifier: " + (Bundle.main.bundleIdentifier ?? "Unknown")).font(.caption2).textSelection(.enabled)
                    Link("Project on GitHub",destination: URL(string:"https://github.com/thevampirebat/achievement-labs")!)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .sheet(item:$embeddedLogin) { page in
                EmbeddedSignIn(url:page.url, onComplete: { redirect in
                    embeddedLogin = nil
                    Task { await m.finishBrowserLogin(redirect) }
                }, onCancel: { embeddedLogin = nil; m.cancelBrowserLogin() }, remember:m.rememberSignIn)
                .interactiveDismissDisabled()
            }
            .onAppear { eventToken = m.account?.eventToken ?? "" }
            .onChange(of:m.account?.eventToken) { _,value in eventToken = value ?? "" }
            .onChange(of: m.account?.xuid) { _, _ in eventToken = m.account?.eventToken ?? "" }
        }
    }
}
