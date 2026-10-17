import SwiftUI
import LabsMobileCore
import UserNotifications
import UIKit

final class NotificationPresentation: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresentation()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
}

@MainActor final class MobileModel: ObservableObject {
    @Published private(set) var account: Account?
    @Published var games: [Game] = []
    @Published var rows: [Achievement] = []
    @Published var selectedGame: Game?
    @Published var queue: [QueueItem] = []
    @Published var status = "Connect an Xbox account in Settings."
    @Published var busy = false
    @Published var running = false
    @Published var presenceTitle = ""
    @Published var presenceStarted: Date?
    @Published var presenceRunning = false
    @Published var nextAction: Date?
    @Published var rowResults: [String: String] = [:]
    @Published var baseCompleted = Set<String>()
    @Published var selectedTab = 0
    @Published var error: String?
    @AppStorage("queueDelay") var queueDelay = 60.0
    @AppStorage("stopOnFailure") var stopOnFailure = true
    @AppStorage("stopOnPresenceFailure") var stopOnPresenceFailure = true
    @AppStorage("notifyCompletion") var notifyCompletion = true
    @AppStorage("notifyPresenceFailure") var notifyPresenceFailure = true
    @AppStorage("showMythic") var showMythic = true
    @AppStorage("highlightCompleted") var highlightCompleted = true
    @Published var queueTitle = ""
    @Published var referenceGamertag = ""
    @Published var referenceInfo = ""
    @Published var spoofStatus = "No heartbeat sent."
    @Published var playedHours: [String:Double] = [:]
    @Published var titleDetails: [String:Game] = [:]
    @Published var checkedCompletion = Set<String>()
    @AppStorage("loginProfile") var loginProfile = LoginProfile.desktop.rawValue
    private var savedTotals: [String:Int] = [:]
    let api: XboxService = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-preview=") }) {
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PreviewOfflineProtocol.self]
            return XboxService(session:URLSession(configuration:config))
        }
        #endif
        return XboxService()
    }()
    let catalogue: Catalogue?
    private var generation = UUID()
    private var queueTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var foreground = true
    private var presenceStopping = false
    private let directory: URL
    private var queueURL: URL? { account.map { directory.appendingPathComponent("queue-\($0.xuid).json") } }
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresentation.shared
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AchievementLabs", isDirectory: true)
        catalogue = Bundle.main.resourceURL.map { try? Catalogue(folder: $0.appendingPathComponent("Catalogue")) } ?? nil
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--storage-self-test") {
            do {
                guard try SecureStore.read() == nil else { throw LabsError.message("Synthetic storage check requires an empty simulator Keychain.") }
                let fixture = Data("synthetic-storage-fixture".utf8)
                try SecureStore.save(fixture)
                guard try SecureStore.read() == fixture else { throw LabsError.message("Synthetic storage read did not match.") }
                try SecureStore.remove()
                guard try SecureStore.read() == nil else { throw LabsError.message("Synthetic storage delete failed.") }
            } catch { fatalError("Synthetic Keychain check failed: \(error.localizedDescription)") }
        }
        #endif
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try SecureStore.read() { account = try JSONDecoder().decode(Account.self, from: data); status = "Saved account loaded. Refresh the library to verify authorization."; loadQueue(); loadCompletion() }
        } catch { self.error = "Could not load protected account or queue storage." }
        if catalogue == nil { error = "Bundled catalogue could not be read. Event actions remain unavailable." }
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-preview=") }) { configurePreview(String(argument.dropFirst("--ui-preview=".count))) }
        #endif
    }
    private func saveAccount(_ next: Account) throws { try SecureStore.save(JSONEncoder().encode(next)); account = next }
    func connect(_ token: String) async {
        guard !busy, !running, presenceStarted == nil else { return }; busy = true; defer { busy = false }
        browserLogin = nil; browserPending = false
        let version = generation
        do {
            var next = try await api.connect(token)
            guard version == generation else { return }
            if next.xuid == account?.xuid { next.eventToken = account?.eventToken ?? "" }
            try saveAccount(next); generation = UUID(); games = []; rows = []; selectedGame = nil; baseCompleted = []; rowResults = [:]; queue = []; titleDetails = [:]; playedHours = [:]; referenceInfo = ""; loadQueue(); loadCompletion()
            status = "Connected as \(next.gamertag)."
        } catch { self.error = error.localizedDescription }
    }
    @Published var browserPending = false
    private var browserLogin: BrowserLogin?
    func beginBrowserLogin() -> URL? {
        guard !busy, !running, presenceStarted == nil else { return nil }
        let login = BrowserLogin(profile:LoginProfile(rawValue:loginProfile) ?? .desktop); browserLogin = login; browserPending = true
        return login.startURL
    }
    func cancelBrowserLogin() { guard !busy else { return }; browserLogin = nil; browserPending = false }
    func finishBrowserLogin(_ redirect: String) async {
        guard let login = browserLogin, !busy, !running, presenceStarted == nil else { return }
        busy = true; defer { busy = false; browserPending = false; browserLogin = nil }
        do {
            var next = try await login.complete(redirect)
            if next.xuid == account?.xuid { next.eventToken = account?.eventToken ?? "" }
            try saveAccount(next); generation = UUID(); games = []; rows = []; selectedGame = nil; baseCompleted = []; rowResults = [:]; queue = []; titleDetails = [:]; playedHours = [:]; referenceInfo = ""; loadQueue(); loadCompletion()
            status = "Connected as \(next.gamertag). Refresh the library."
        } catch { self.error = error.localizedDescription }
    }
    func saveEventToken(_ input: String) {
        guard var current = account, !running, !busy else { return }
        do { current.eventToken = try Tokens.normalize(input, event: true); try saveAccount(current); status = "Event token saved in this device's Keychain." }
        catch { self.error = error.localizedDescription }
    }
    func removeEventToken() { guard var current = account, !running, !busy else { return }; current.eventToken = ""; do { try saveAccount(current) } catch { self.error = error.localizedDescription } }
    func disconnect() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        browserLogin = nil; browserPending = false
        pauseQueue(); if let queueTask { await queueTask.value }; await stopPresence(); generation = UUID()
        do { try SecureStore.remove(); account = nil; games = []; rows = []; queue = []; selectedGame = nil; baseCompleted = []; checkedCompletion = []; savedTotals = [:]; titleDetails = [:]; playedHours = [:]; status = "Disconnected." }
        catch { self.error = "Could not remove the Keychain session." }
    }
    func refreshGames() async {
        guard let account, !busy else { return }; busy = true; defer { busy = false }; let version = generation
        status = "Downloading library…"
        do { let loaded = try await api.games(account); guard version == generation else { return }; games = loaded.map(withTotal)
            do { var profile = try await api.connect(account.authorization); profile.eventToken = account.eventToken; profile.loginProfile = account.loginProfile; try saveAccount(profile) }
            catch { status = "Library loaded; profile details could not refresh." }
            status = "Loaded \(loaded.count) titles." }
        catch { self.error = error.localizedDescription; status = "Refresh failed; previous library retained." }
    }
    func load(_ game: Game) async {
        guard let account, !busy else { return }; busy = true; defer { busy = false }; let version = generation
        do {
            var loaded = try await api.achievements(game, account: account)
            if loaded.contains(where: \.eventBased) { for i in loaded.indices { loaded[i].eventBased = true } }
            guard version == generation else { return }
            rows = loaded; selectedGame = game; rowResults = [:]
            rememberCompletion(loaded, game:game)
            // Never overwrite valid legacy/library progress with an empty response.
            if !loaded.isEmpty, (!game.legacy || loaded.filter(\.unlocked).count >= game.unlocked), let i = games.firstIndex(where: { $0.id == game.id }) { games[i].unlocked = loaded.filter(\.unlocked).count; games[i].total = loaded.count }
            status = "Loaded \(loaded.count) achievements."
        } catch { self.error = error.localizedDescription }
    }
    func unavailable(_ row: Achievement, game: Game) -> String? {
        if game.legacy { return "Xbox 360/GFWL achievements are read-only on mobile." }
        if row.eventBased {
            guard let catalogue else { return "Event catalogue unavailable." }
            do { guard try catalogue.recipes(game.id).recipes[row.id] != nil else { return "No mapped mobile event data." } }
            catch { return error.localizedDescription }
            if account?.eventToken.isEmpty != false { return "Save a current event token in Settings." }
        } else if UUID(uuidString: row.serviceConfigID) == nil { return "Missing service configuration." }
        return nil
    }
    private func send(_ row: Achievement, game: Game, account: Account) async throws {
        guard foreground else { throw CancellationError() }
        if let reason = unavailable(row, game: game) { throw LabsError.message(reason) }
        if row.eventBased {
            guard let catalogue else { throw LabsError.message("Catalogue unavailable.") }
            let bodies = try catalogue.payloads(title: game.id, achievement: row.id, xuid: account.xuid)
            for body in bodies { try Task.checkCancellation(); try await api.sendEvent(body, account: account) }
        } else { try await api.titleUnlock(row, game: game, account: account) }
    }
    func unlock(_ row: Achievement, game: Game) async {
        guard let account, !busy, !running else { return }; busy = true; defer { busy = false }
        do { try await send(row, game: game, account: account); rowResults[row.id] = "Request accepted; refresh to verify progress." }
        catch { rowResults[row.id] = error.localizedDescription; self.error = error.localizedDescription }
    }
    func enqueue(_ selected: [Achievement], game: Game) {
        guard !running else { return }; queueTitle = game.id; titleDetails[game.id] = game
        for row in selected where unavailable(row, game: game) == nil {
            if !queue.contains(where: { $0.game.id == game.id && $0.achievement.id == row.id }) { queue.append(QueueItem(game: game, achievement: row, delay: max(0, min(queueDelay, 86400)))) }
        }
        saveQueue(); selectedTab = 1
    }
    @discardableResult func saveQueue() -> Bool {
        guard let url = queueURL else { return false }
        do { try JSONEncoder().encode(queue).write(to: url, options: [.atomic, .completeFileProtection]); return true }
        catch { self.error = "Could not save queue changes."; queueTask?.cancel(); return false }
    }
    private func loadQueue() {
        guard let url = queueURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            queue = try JSONDecoder().decode([QueueItem].self, from: Data(contentsOf: url))
            for i in queue.indices {
                if !queue[i].delay.isFinite || queue[i].delay < 0 || queue[i].delay > 31_536_000 { throw LabsError.message("Invalid saved delay.") }
            }
            queueTitle = queue.first?.game.id ?? ""
            for i in queue.indices where queue[i].status == "Submitting" { queue[i].status = "Interrupted — refresh before retrying" }
        } catch { self.error = "The saved queue could not be read." }
    }
    func startQueue() {
        guard let account, foreground, !running, !busy, queue.contains(where: { $0.status == "Waiting" }) else { return }
        running = true; let version = generation
        queueTask = Task { [weak self] in
            guard let self else { return }
            defer { self.running = false; self.nextAction = nil; self.queueTask = nil; UIApplication.shared.isIdleTimerDisabled = self.presenceStarted != nil }
            UIApplication.shared.isIdleTimerDisabled = true
            while let index = self.queue.firstIndex(where: { $0.status == "Waiting" }) {
                if Task.isCancelled || !self.foreground || version != self.generation { break }
                let item = self.queue[index]
                do {
                    // Re-read current account progress and event metadata before each action.
                    let current = try await self.api.achievements(item.game, account: account)
                    guard var row = current.first(where: { $0.id == item.achievement.id }), row.name == item.achievement.name else { throw LabsError.message("Achievement metadata changed; rebuild this queue item.") }
                    row.eventBased = current.contains(where: \.eventBased)
                    if row.unlocked { self.queue[index].status = "Already unlocked"; self.saveQueue(); continue }
                    self.nextAction = Date().addingTimeInterval(item.delay)
                    try await Task.sleep(nanoseconds: UInt64(max(0,min(item.delay,31_536_000)) * 1_000_000_000))
                    try Task.checkCancellation()
                    self.queue[index].status = "Submitting"
                    guard self.saveQueue() else { throw LabsError.message("Queue could not be saved; action was not sent.") }
                    try await self.send(row, game: item.game, account: account)
                    self.queue[index].status = "Accepted — verify progress"; self.saveQueue()
                } catch is CancellationError {
                    if self.queue[index].status == "Submitting" { self.queue[index].status = "Interrupted — refresh before retrying" }; self.saveQueue(); break
                } catch {
                    if Task.isCancelled {
                        if self.queue[index].status == "Submitting" { self.queue[index].status = "Interrupted — refresh before retrying" }
                        self.saveQueue(); break
                    }
                    self.queue[index].status = "Failed: \(error.localizedDescription)"; self.saveQueue()
                    if self.stopOnFailure { break }
                }
            }
            if !Task.isCancelled && !self.queue.contains(where: { $0.status == "Waiting" || $0.status.hasPrefix("Failed") || $0.status.hasPrefix("Interrupted") }) {
                self.status = "Queue finished. Accepted requests still need progress verification."
                if self.notifyCompletion { await self.notify("Auto unlock finished", body: "Refresh achievements to verify accepted requests.") }
            }
        }
    }
    func pauseQueue() { queueTask?.cancel(); nextAction = nil; status = "Queue paused. Saved items can be reviewed before resuming." }
    func removeCompleted() async {
        guard let account, !running, !busy else { return }; busy = true; defer { busy = false }
        do {
            var completed = Set<String>()
            for game in Dictionary(grouping: queue, by: { $0.game.id }).values.compactMap({ $0.first?.game }) {
                let loaded = try await api.achievements(game, account: account)
                for row in loaded where row.unlocked { completed.insert(game.id + "/" + row.id) }
            }
            queue.removeAll { completed.contains($0.id) }; saveQueue(); status = "Removed achievements confirmed unlocked by Xbox."
        } catch { self.error = error.localizedDescription }
    }
    func startPresence(_ title: String) {
        guard let account, presenceTask == nil, !presenceStopping, foreground, JSON.numeric(title) else { return }
        presenceTitle = title; presenceRunning = true; spoofStatus = "Sending heartbeat…"
        presenceTask = Task { [weak self] in
            guard let self else { return }
            defer { self.presenceStarted = nil; self.presenceRunning = false; self.presenceTask = nil; UIApplication.shared.isIdleTimerDisabled = self.running }
            do {
                try await self.api.presence(title, account: account); self.presenceStarted = Date(); self.spoofStatus = "Heartbeat accepted. Xbox-recorded playtime can update later."; UIApplication.shared.isIdleTimerDisabled = true
                while !Task.isCancelled { try await Task.sleep(nanoseconds: 240_000_000_000); try Task.checkCancellation(); try await self.api.presence(title, account: account); self.spoofStatus = "Heartbeat accepted at " + Date().formatted(date:.omitted,time:.standard) }
            } catch is CancellationError { }
            catch {
                if Task.isCancelled { return }
                self.spoofStatus = error.localizedDescription
                self.error = "Title spoofing stopped: \(error.localizedDescription)"
                if self.stopOnPresenceFailure { self.pauseQueue() }
                if self.notifyPresenceFailure { await self.notify("Title spoofing stopped", body: "Open Achievement Labs to review the heartbeat error.") }
            }
        }
    }
    func stopPresence() async {
        guard !presenceStopping, presenceTask != nil || presenceStarted != nil else { return }
        presenceStopping = true; defer { presenceStopping = false }
        presenceTask?.cancel(); if let presenceTask { await presenceTask.value }
        spoofStatus = "Stopped locally."
        if let account { do { try await api.presence(nil, account: account) } catch { self.error = "Presence stopped locally; Xbox stop request failed: \(error.localizedDescription)" } }
    }
    func background() {
        foreground = false; pauseQueue(); presenceTask?.cancel()
        if let account, presenceStarted != nil { Task { try? await api.presence(nil, account: account) } }
        status = "Paused while the app is inactive. Review and resume when you return."
    }
    func active() { foreground = true }
    func requestNotifications() async { do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]) } catch { self.error = error.localizedDescription } }
    private func notify(_ title: String, body: String) async {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func gameForTitle(_ id: String) -> Game? { titleDetails[id] ?? games.first { $0.id == id } }
    func hasMythic(_ game: Game) -> Bool { catalogue?.isHub(game) != true && (baseCompleted.contains(game.id) || game.complete) }
    var mythicCount: Int { games.filter(hasMythic).count }
    var libraryAchievements: Int { games.reduce(0) { $0 + $1.unlocked } }
    func lookupTitle(_ id: String) async {
        guard let account, JSON.numeric(id) else { return }; let version = generation
        if let game = gameForTitle(id), !game.image.isEmpty { titleDetails[id] = game; return }
        do { let game = try await api.game(id,account:account); guard !Task.isCancelled, version == generation else { return }; titleDetails[id] = withTotal(game) }
        catch { /* Keep typed IDs usable when title lookup is unavailable. */ }
    }
    func readPlaytime(_ title: String) async {
        guard let account, JSON.numeric(title) else { return }; let version = generation
        do { if let minutes = try await api.playedMinutes(title,account:account), version == generation, !Task.isCancelled { playedHours[title] = minutes / 60 } }
        catch { /* Missing playtime is displayed as unavailable, never zero. */ }
    }
    func buildTimingQueue() async {
        guard let account, !busy, !running, JSON.numeric(queueTitle) else { return }
        busy = true; defer { busy = false }; let version = generation; let title = queueTitle
        status = "Reading reference profile and achievement times…"
        do {
            let game: Game
            if let known = gameForTitle(title) { game = known } else { game = try await api.game(title,account:account) }
            let reference = try await api.profile(gamertag:referenceGamertag,account:account)
            let dated = try await api.achievements(game,account:account,xuid:reference.xuid)
            var own = try await api.achievements(game,account:account)
            if own.contains(where: \.eventBased) { for i in own.indices { own[i].eventBased = true } }
            let plan = try TimingPlan.build(game:game,own:own,reference:dated,gamertag:reference.gamertag) { unavailable($0,game:game) == nil }
            guard version == generation else { return }
            guard !plan.items.isEmpty else { throw LabsError.message("No matching locked achievements with available actions were found. Existing queue retained.") }
            queue.removeAll { $0.game.id == title }; queue += plan.items; titleDetails[title] = game
            referenceInfo = "\(reference.gamertag) · \(plan.items.count) queued · \(plan.skipped) skipped"
            rememberCompletion(own,game:game); saveQueue(); status = "Timing queue loaded. Review delays, then start when ready."
        } catch { self.error = error.localizedDescription; status = "Timing import failed; review the existing queue." }
    }
    #if DEBUG
    private func configurePreview(_ page: String) {
        account = Account(authorization:"synthetic-offline",xuid:"0",gamertag:"Preview profile")
        account?.gamerscore = "12,345"
        let first = try! Game(["titleId":"7","name":"Example completed game","devices":["XboxOne","XboxSeries"],"achievement":["currentAchievements":50,"totalAchievements":50]])
        let second = try! Game(["titleId":"8","name":"A longer example game title for layout checks","devices":["PC","XboxOne"],"achievement":["currentAchievements":24,"totalAchievements":80]])
        games = [first,second]; baseCompleted = [first.id]; titleDetails = [first.id:first,second.id:second]
        queueTitle = second.id; presenceTitle = second.id; referenceGamertag = "Reference profile"
        let row = try! Achievement(["id":"1","name":"First steps","lockedDescription":"Complete the first mission.","serviceConfigId":"00000000-0000-0000-0000-000000000001","gamerscore":20])
        queue = [QueueItem(game:second,achievement:row,delay:120)]
        referenceInfo = "Reference profile · 1 queued · 2 skipped"; status = "Timing queue loaded. Review delays, then start when ready."
        spoofStatus = "No heartbeat sent."; playedHours[second.id] = 12.5
        selectedTab = page == "queue" ? 1 : page == "spoof" ? 2 : page == "settings" ? 3 : 0
    }
    #endif
    private struct CompletionCache: Codable { var mythic: Set<String>; var checked: Set<String>; var totals: [String:Int] }
    private var completionURL: URL? { account.map { directory.appendingPathComponent("completion-\($0.xuid).json") } }
    private func loadCompletion() {
        baseCompleted = []; checkedCompletion = []; savedTotals = [:]
        guard let url = completionURL, let data = try? Data(contentsOf:url), let saved = try? JSONDecoder().decode(CompletionCache.self,from:data) else { return }
        baseCompleted = saved.mythic; checkedCompletion = saved.checked; savedTotals = saved.totals
    }
    private func rememberCompletion(_ loaded: [Achievement], game: Game) {
        guard !loaded.isEmpty, !game.legacy || loaded.filter(\.unlocked).count >= game.unlocked else { return }
        checkedCompletion.insert(game.id); savedTotals[game.id] = loaded.count
        if catalogue?.baseComplete(loaded,game:game) == true { baseCompleted.insert(game.id) }
        guard let url = completionURL else { return }
        do { try JSONEncoder().encode(CompletionCache(mythic:baseCompleted,checked:checkedCompletion,totals:savedTotals)).write(to:url,options:[.atomic,.completeFileProtection]) }
        catch { self.error = "Could not save completion indicators." }
    }
    private func withTotal(_ input: Game) -> Game {
        var game = catalogue?.applyingTotal(input) ?? input
        if game.total <= 0, let total = savedTotals[game.id], total >= game.unlocked { game.total = total }
        return game
    }
    func scanCompletion() async {
        guard let account, !busy, !running else { return }; busy = true; defer { busy = false }; let version = generation
        let pending = games.filter { !checkedCompletion.contains($0.id) }
        var failures = 0
        for (n,game) in pending.enumerated() {
            guard foreground, version == generation, !Task.isCancelled else { break }
            status = "Completion scan \(n+1)/\(pending.count) · \(game.name)"
            do {
                let loaded = try await api.achievements(game,account:account); rememberCompletion(loaded,game:game)
                if !loaded.isEmpty, (!game.legacy || loaded.filter(\.unlocked).count >= game.unlocked), let i = games.firstIndex(where: { $0.id == game.id }) { games[i].total = loaded.count; games[i].unlocked = loaded.filter(\.unlocked).count }
            } catch { failures += 1; if error.localizedDescription.contains("429") { break } }
            try? await Task.sleep(nanoseconds:300_000_000)
        }
        status = "Completion checked for \(checkedCompletion.count) titles · \(failures) failed this scan. Unchecked titles can be scanned again."
    }

}

#if DEBUG
/// Screenshot fixtures cannot make network requests, even if a UI task runs.
private final class PreviewOfflineProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self,didFailWithError:URLError(.cancelled)) }
    override func stopLoading() {}
}
#endif
