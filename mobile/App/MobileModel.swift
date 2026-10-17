import SwiftUI
import LabsMobileCore
import UserNotifications
import UIKit
import WebKit

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
    @Published var eventsSyncing = false
    @Published var eventSyncStatus = "Bundled catalogue loaded."
    @Published var updateChecking = false
    @Published var updateStatus = "No update check yet."
    @Published var availableUpdate: MobileRelease?
    @Published var pendingPCEventOnly = false
    @Published var pendingPCAccount: Account?
    private var pendingPCExpiry: Date?
    @Published var pcSyncStatus = "Import an encrypted transfer exported from the PC app."
    @AppStorage("autoSyncEvents") var autoSyncEvents = true
    @AppStorage("checkMobileUpdates") var checkMobileUpdates = true
    @AppStorage("notifyMobileUpdates") var notifyMobileUpdates = true
    @AppStorage("autoRefreshLibrary") var autoRefreshLibrary = true
    private var lifecycleRunning = false
    private var lastLibraryRefresh = Date.distantPast
    private var lastEventsCheck = Date.distantPast
    private var lastUpdateCheck = Date.distantPast
    @Published var refreshingSignIn = false
    @Published var sessionStatus = ""
    @Published var spoofDiagnostics = ""
    @AppStorage("launchPage") var launchPage = 4
    @AppStorage("rememberSignIn") var rememberSignIn = true
    @AppStorage("signInBrowser") var signInBrowser = "In app"
    private var renewalTask: Task<Account,Error>?
    @Published var spoofStatus = "No heartbeat sent."
    @Published var playedHours: [String:Double] = [:]
    @Published var titleDetails: [String:Game] = [:]
    @Published var checkedCompletion = Set<String>()
    @Published var scanningCompletion = false
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
            if !rememberSignIn { try SecureStore.remove() }
            if rememberSignIn, let data = try SecureStore.read() { account = try JSONDecoder().decode(Account.self, from: data); status = "Saved account loaded. Refresh the library to verify authorization."; loadQueue(); loadCompletion() }
        } catch { self.error = "Could not load protected account or queue storage." }
        if catalogue == nil { error = "Bundled catalogue could not be read. Event actions remain unavailable." }
        else if FileManager.default.fileExists(atPath:directory.appendingPathComponent("synced-events.json").path) {
            do { try catalogue?.loadCache(directory.appendingPathComponent("synced-events.json")); eventSyncStatus = "Cached synced event data loaded." }
            catch { eventSyncStatus = "Synced cache could not be validated. Bundled data retained." }
        }
        selectedTab = account == nil ? 4 : ([0,1,2,3,4].contains(launchPage) ? launchPage : 4)
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-preview=") }) { configurePreview(String(argument.dropFirst("--ui-preview=".count))) }
        #endif
    }
    private func saveAccount(_ input: Account) throws {
        var next = input
        if rememberSignIn { try SecureStore.save(JSONEncoder().encode(next)) }
        else { next.refreshToken = nil; try SecureStore.remove() }
        account = next
    }
    private func authorizedAccount(force: Bool = false) async throws -> Account {
        if let renewalTask { return try await renewalTask.value }
        guard let current = account else { throw LabsError.message("Connect your Xbox account first.") }
        guard force || current.needsRefresh() else { return current }
        guard rememberSignIn, current.refreshToken?.isEmpty == false, let profile = current.loginProfile.flatMap(LoginProfile.init(rawValue:)) else {
            if force || current.needsRefresh() { throw LabsError.message("Sign in once with Remember sign-in enabled to renew this session.") }; return current
        }
        let version = generation; refreshingSignIn = true; sessionStatus = "Renewing remembered sign-in…"
        let task = Task { @MainActor [self] () async throws -> Account in
            defer { renewalTask = nil; refreshingSignIn = false }
            do {
                let next = try await BrowserLogin(profile:profile).refresh(current) { rotated in
                    guard version == self.generation, self.account?.xuid == current.xuid, self.rememberSignIn else { throw CancellationError() }
                    var saved = rotated; saved.eventToken = self.account?.eventToken ?? rotated.eventToken
                    try self.saveAccount(saved)
                }
                guard version == generation, account?.xuid == current.xuid else { throw CancellationError() }
                var saved = next; saved.eventToken = account?.eventToken ?? next.eventToken
                try saveAccount(saved); sessionStatus = "Remembered sign-in renewed."; return saved
            } catch {
                sessionStatus = "Could not renew sign-in. A browser sign-in may be needed."; throw error
            }
        }
        renewalTask = task
        return try await task.value
    }
    /// Only read operations may be repeated after a 401; unlocks and failed heartbeats are never replayed here.
    private func readWithAccount<T>(_ operation: (Account) async throws -> T) async throws -> T {
        let current = try await authorizedAccount()
        do { return try await operation(current) }
        catch let error as XboxHTTPFailure where error.status == 401 && current.refreshToken?.isEmpty == false && rememberSignIn {
            let refreshed = try await authorizedAccount(force:true)
            return try await operation(refreshed)
        }
    }
    func renewSignIn() async {
        guard !busy, !running, !presenceRunning else { return }; busy = true; defer { busy = false }
        do { _ = try await authorizedAccount(force:true); status = "Sign-in renewed. No achievement or heartbeat request was sent." }
        catch { self.error = error.localizedDescription }
    }
    func updateRememberSignIn() async {
        guard !refreshingSignIn else { return }
        do {
            if let current = account { try saveAccount(current) } else if !rememberSignIn { try SecureStore.remove() }
            if !rememberSignIn { await clearMicrosoftCookies(); sessionStatus = "Sign-in will be forgotten when the app closes." }
            else { sessionStatus = account?.refreshToken == nil ? "Sign in once to enable automatic renewal." : "Sign-in is remembered on this device." }
        } catch { self.error = error.localizedDescription }
    }
    private func clearMicrosoftCookies() async {
        let store = WKWebsiteDataStore.default(); let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes:types)
        let microsoft = records.filter { record in
            ["live.com","microsoft.com","microsoftonline.com","msauth.net","msftauth.net"].contains { record.displayName == $0 || record.displayName.hasSuffix("." + $0) }
        }
        await store.removeData(ofTypes:types,for:microsoft)
    }
    func connect(_ token: String) async {
        guard !busy, !refreshingSignIn, !running, !presenceRunning else { return }; busy = true; defer { busy = false }
        browserLogin = nil; browserPending = false
        let version = generation
        do {
            var next = try await api.connect(token)
            guard version == generation else { return }
            if next.xuid == account?.xuid { next.eventToken = account?.eventToken ?? "" }
            try saveAccount(next); sessionStatus = rememberSignIn && next.refreshToken != nil ? "Sign-in remembered with automatic renewal." : "Session saved; browser sign-in may be needed when it expires."; generation = UUID(); games = []; rows = []; selectedGame = nil; baseCompleted = []; rowResults = [:]; queue = []; titleDetails = [:]; playedHours = [:]; referenceInfo = ""; loadQueue(); loadCompletion()
            status = "Connected as \(next.gamertag)."
            Task { await maintainOnOpen(forceLibrary:true) }
        } catch { self.error = error.localizedDescription }
    }
    @Published var browserPending = false
    private var browserLogin: BrowserLogin?
    func beginBrowserLogin() -> URL? {
        guard !busy, !refreshingSignIn, !running, !presenceRunning else { return nil }
        let login = BrowserLogin(profile:LoginProfile(rawValue:loginProfile) ?? .desktop); browserLogin = login; browserPending = true
        return login.startURL
    }
    func cancelBrowserLogin() { guard !busy else { return }; browserLogin = nil; browserPending = false }
    func finishBrowserLogin(_ redirect: String) async {
        guard let login = browserLogin, !busy, !refreshingSignIn, !running, !presenceRunning else { return }
        busy = true; defer { busy = false; browserPending = false; browserLogin = nil; Task { await maintainOnOpen(forceLibrary:true) } }
        do {
            var next = try await login.complete(redirect)
            if next.xuid == account?.xuid { next.eventToken = account?.eventToken ?? "" }
            try saveAccount(next); sessionStatus = rememberSignIn && next.refreshToken != nil ? "Sign-in remembered with automatic renewal." : "Session saved; browser sign-in may be needed when it expires."; generation = UUID(); games = []; rows = []; selectedGame = nil; baseCompleted = []; rowResults = [:]; queue = []; titleDetails = [:]; playedHours = [:]; referenceInfo = ""; loadQueue(); loadCompletion()
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
        browserLogin = nil; browserPending = false; generation = UUID(); renewalTask?.cancel()
        pauseQueue(); if let queueTask { await queueTask.value }; await stopPresence(); generation = UUID()
        do { try SecureStore.remove(); await clearMicrosoftCookies(); account = nil; games = []; rows = []; queue = []; selectedGame = nil; baseCompleted = []; checkedCompletion = []; savedTotals = [:]; titleDetails = [:]; playedHours = [:]; status = "Disconnected." }
        catch { self.error = "Could not remove the Keychain session." }
    }
    func refreshGames() async {
        guard let account, !busy else { return }; busy = true; defer { busy = false }; let version = generation
        status = "Downloading library…"
        do { let loaded = try await readWithAccount { try await api.games($0) }; guard version == generation else { return }; games = loaded.map(withTotal)
            do { let credentials = self.account ?? account
                var profile = try await api.connect(credentials.authorization)
                guard profile.xuid == credentials.xuid else { throw LabsError.message("Profile identity changed.") }
                profile.eventToken = credentials.eventToken; profile.loginProfile = credentials.loginProfile; profile.refreshToken = credentials.refreshToken; profile.authorizationExpiresAt = credentials.authorizationExpiresAt; try saveAccount(profile) }
            catch { status = "Library loaded; profile details could not refresh." }
            lastLibraryRefresh = Date(); status = "Loaded \(loaded.count) titles." }
        catch { self.error = error.localizedDescription; status = "Refresh failed; previous library retained." }
    }
    func load(_ game: Game) async {
        guard let account, !busy else { return }; busy = true; defer { busy = false }; let version = generation
        do {
            var loaded = try await readWithAccount { try await api.achievements(game,account:$0) }
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
        do { let active = try await authorizedAccount(); try await send(row, game: game, account: active); rowResults[row.id] = "Request accepted; refresh to verify progress." }
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
                    let current = try await self.readWithAccount { try await self.api.achievements(item.game,account:$0) }
                    guard var row = current.first(where: { $0.id == item.achievement.id }), row.name == item.achievement.name else { throw LabsError.message("Achievement metadata changed; rebuild this queue item.") }
                    row.eventBased = current.contains(where: \.eventBased)
                    if row.unlocked { self.queue[index].status = "Already unlocked"; self.saveQueue(); continue }
                    self.nextAction = Date().addingTimeInterval(item.delay)
                    try await Task.sleep(nanoseconds: UInt64(max(0,min(item.delay,31_536_000)) * 1_000_000_000))
                    try Task.checkCancellation()
                    self.queue[index].status = "Submitting"
                    guard self.saveQueue() else { throw LabsError.message("Queue could not be saved; action was not sent.") }
                    let active = try await self.authorizedAccount(); try Task.checkCancellation(); try await self.send(row, game: item.game, account: active)
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
                let loaded = try await readWithAccount { try await api.achievements(game,account:$0) }
                for row in loaded where row.unlocked { completed.insert(game.id + "/" + row.id) }
            }
            queue.removeAll { completed.contains($0.id) }; saveQueue(); status = "Removed achievements confirmed unlocked by Xbox."
        } catch { self.error = error.localizedDescription }
    }
    func startPresence(_ title: String) {
        guard let account, presenceTask == nil, !presenceStopping, foreground, JSON.numeric(title) else { return }
        presenceTitle = title; presenceRunning = true; spoofDiagnostics = ""; spoofStatus = "Sending heartbeat…"
        presenceTask = Task { [weak self] in
            guard let self else { return }
            defer { self.presenceStarted = nil; self.presenceRunning = false; self.presenceTask = nil; UIApplication.shared.isIdleTimerDisabled = self.running }
            do {
                let active = try await self.authorizedAccount(); try Task.checkCancellation(); try await self.api.presence(title, account: active); self.presenceStarted = Date(); self.spoofStatus = "Heartbeat accepted. Xbox-recorded playtime can update later."; UIApplication.shared.isIdleTimerDisabled = true
                while !Task.isCancelled { try await Task.sleep(nanoseconds: 240_000_000_000); try Task.checkCancellation(); let active = try await self.authorizedAccount(); try Task.checkCancellation(); try await self.api.presence(title, account: active); self.spoofStatus = "Heartbeat accepted at " + Date().formatted(date:.omitted,time:.standard) }
            } catch is CancellationError { }
            catch {
                if Task.isCancelled { return }
                self.spoofStatus = error.localizedDescription
                if let failure = error as? XboxHTTPFailure {
                    self.spoofDiagnostics = "Title spoofing · " + Date().formatted(date:.numeric,time:.standard) + "\nTitle ID: " + title + "\nSign-in profile: " + (self.account?.loginProfile ?? "Manual / previous beta") + "\n" + failure.diagnostic
                    if failure.status == 403 {
                        do {
                            let current = self.account ?? account
                            let profile = try await self.api.connect(current.authorization)
                            self.spoofDiagnostics += profile.xuid == current.xuid ? "\nIndependent profile check: accepted for the same account.\nThe refusal is specific to heartbeat access; no heartbeat retry was sent." : "\nIndependent profile check: identity mismatch."
                        } catch let probe as XboxHTTPFailure { self.spoofDiagnostics += "\nIndependent profile check: HTTP \(probe.status)." }
                        catch { self.spoofDiagnostics += "\nIndependent profile check: unavailable." }
                    }
                }
                var guidance = ""
                if let failure = error as? XboxHTTPFailure, failure.status == 403, self.account?.loginProfile != "PC transfer" {
                    guidance = "\nUse Settings → Scan PC QR and import the full Sign-in + event token QR. Event-token-only sync does not change heartbeat authorization."
                }
                self.error = "Title spoofing stopped: \(error.localizedDescription)" + guidance
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
    func active() { foreground = true; Task { await maintainOnOpen() } }
    func requestNotifications() async { do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]) } catch { self.error = error.localizedDescription } }
    private func notify(_ title: String, body: String) async {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    func gameForTitle(_ id: String) -> Game? {
        if var game = games.first(where: { $0.id == id }) {
            if game.image.isEmpty { game.image = titleDetails[id]?.image ?? "" }
            return game
        }
        return titleDetails[id]
    }
    func hasMythic(_ game: Game) -> Bool { catalogue?.isHub(game) != true && (baseCompleted.contains(game.id) || game.complete) }
    var mythicCount: Int { games.filter(hasMythic).count }
    var libraryAchievements: Int { games.reduce(0) { $0 + $1.unlocked } }
    func lookupTitle(_ id: String) async {
        guard let account, JSON.numeric(id) else { return }; let version = generation
        if let game = gameForTitle(id), !game.image.isEmpty { titleDetails[id] = game; return }
        do { let game = try await readWithAccount { try await api.game(id,account:$0) }; guard !Task.isCancelled, version == generation else { return }; titleDetails[id] = withTotal(game) }
        catch { /* Keep typed IDs usable when title lookup is unavailable. */ }
    }
    func readPlaytime(_ title: String) async {
        guard let account, JSON.numeric(title) else { return }; let version = generation
        do { if let minutes = try await readWithAccount({ try await api.playedMinutes(title,account:$0) }), version == generation, !Task.isCancelled { playedHours[title] = minutes / 60 } }
        catch { /* Missing playtime is displayed as unavailable, never zero. */ }
    }
    func buildTimingQueue() async {
        guard let account, !busy, !running, JSON.numeric(queueTitle) else { return }
        busy = true; defer { busy = false }; let version = generation; let title = queueTitle
        status = "Reading reference profile and achievement times…"
        do {
            let game: Game
            if let known = gameForTitle(title) { game = known } else { game = try await readWithAccount { try await api.game(title,account:$0) } }
            let reference = try await readWithAccount { try await api.profile(gamertag:referenceGamertag,account:$0) }
            let dated = try await readWithAccount { try await api.achievements(game,account:$0,xuid:reference.xuid) }
            var own = try await readWithAccount { try await api.achievements(game,account:$0) }
            if own.contains(where: \.eventBased) { for i in own.indices { own[i].eventBased = true } }
            let plan = try TimingPlan.build(game:game,own:own,reference:dated,gamertag:reference.gamertag) { unavailable($0,game:game) == nil }
            guard version == generation else { return }
            guard !plan.items.isEmpty else { throw LabsError.message("No matching locked achievements with available actions were found. Existing queue retained.") }
            queue.removeAll { $0.game.id == title }; queue += plan.items; titleDetails[title] = game
            referenceInfo = "\(reference.gamertag) · \(plan.items.count) queued · \(plan.skipped) skipped"
            rememberCompletion(own,game:game); saveQueue(); status = "Timing queue loaded. Review delays, then start when ready."
        } catch { self.error = error.localizedDescription; status = "Timing import failed; review the existing queue." }
    }
    func maintainOnOpen(forceLibrary: Bool = false) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-preview=") || $0 == "--storage-self-test" || $0 == "--web-callback-self-test" }) { return }
        #endif
        guard foreground, !running, !presenceRunning else { return }
        if lifecycleRunning {
            if forceLibrary, autoRefreshLibrary, account != nil, !busy { await refreshGames() }
            return
        }
        lifecycleRunning = true; defer { lifecycleRunning = false }
        if autoRefreshLibrary, account != nil, !busy, forceLibrary || Date().timeIntervalSince(lastLibraryRefresh) > 60 { await refreshGames() }
        if autoSyncEvents, Date().timeIntervalSince(lastEventsCheck) > 3600 { await syncEvents() }
        if checkMobileUpdates, Date().timeIntervalSince(lastUpdateCheck) > 86400 { await checkForMobileUpdates() }
    }
    func syncEvents() async {
        guard !eventsSyncing, !running else { return }; eventsSyncing = true; defer { eventsSyncing = false }
        eventSyncStatus = "Downloading the validated upstream event feed…"
        do {
            let feed = try await PublicSync().events()
            guard let catalogue else { throw LabsError.message("Bundled catalogue is unavailable.") }
            let added = try catalogue.merge(feed,cache:directory.appendingPathComponent("synced-events.json"))
            lastEventsCheck = Date(); eventSyncStatus = "\(feed.upstreamRelease) · \(added) new titles added · checked " + Date().formatted(date:.abbreviated,time:.shortened)
        } catch { eventSyncStatus = error.localizedDescription + " Existing mappings retained." }
    }
    func checkForMobileUpdates() async {
        guard !updateChecking else { return }; updateChecking = true; defer { updateChecking = false }
        updateStatus = "Checking published iOS releases…"
        do {
            let latest = try await PublicSync().release(); lastUpdateCheck = Date()
            let current = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.6.0"
            if let latest, MobileRelease.newer(latest.version,than:current) {
                availableUpdate = latest; updateStatus = "iOS \(latest.version) is available. Sign and install its IPA through Signulous."
                if notifyMobileUpdates, UserDefaults.standard.string(forKey:"lastNotifiedMobileVersion") != latest.version {
                    await notify("Achievement Labs update",body:"iOS \(latest.version) is available. Open Settings to download it.")
                    UserDefaults.standard.set(latest.version,forKey:"lastNotifiedMobileVersion")
                }
            } else { availableUpdate = nil; updateStatus = latest == nil ? "No published iOS release found yet. Windows releases are ignored." : "iOS \(current) is up to date." }
        } catch { updateStatus = error.localizedDescription }
    }
    func preparePCTransfer(_ data: Data, key: String) async {
        guard !busy, !running, !presenceRunning else { return }; busy = true; defer { busy = false }
        pendingPCAccount = nil; pendingPCEventOnly = false; pcSyncStatus = "Verifying the transferred Xbox account…"
        do {
            let transfer = try PCTransfer.open(data,key:key)
            let authorization: String
            if transfer.eventOnly {
                guard account?.xuid == transfer.xuid else { throw LabsError.message("Sign in to the same Xbox account on iOS before importing this event-token-only QR.") }
                authorization = try await authorizedAccount().authorization
            } else { authorization = transfer.authorization }
            var verified = try await api.connect(authorization)
            guard verified.xuid == transfer.xuid else { throw LabsError.message("The transferred authorization belongs to a different account.") }
            verified.eventToken = transfer.eventToken.isEmpty ? "" : try Tokens.normalize(transfer.eventToken,event:true)
            verified.authorizationExpiresAt = transfer.authorizationExpiresAt.flatMap(ServiceDates.parse)
            pendingPCEventOnly = transfer.eventOnly
            verified.loginProfile = "PC transfer"; pendingPCAccount = verified; pendingPCExpiry = Date(timeIntervalSince1970:Double(transfer.expiresAt))
            pcSyncStatus = transfer.eventOnly ? "Verified \(verified.gamertag). Import the event token to your existing mobile sign-in." : "Verified \(verified.gamertag). Choose whether to connect this account or import only its event token."
        } catch { pcSyncStatus = error.localizedDescription }
    }
    func usePCTransfer(eventOnly: Bool) {
        guard let imported = pendingPCAccount, !busy, !running, !presenceRunning else { return }
        do {
            guard let pendingPCExpiry, pendingPCExpiry > Date() else { pendingPCAccount = nil; throw LabsError.message("The transfer expired. Export a fresh file from PC.") }
            guard !pendingPCEventOnly || eventOnly else { throw LabsError.message("This QR contains only an event token. Choose Import event token only.") }
            if eventOnly {
                guard var current = account, current.xuid == imported.xuid else { throw LabsError.message("Event-only sync requires the same Xbox account on both devices.") }
                guard !imported.eventToken.isEmpty else { throw LabsError.message("The PC transfer contains no event token.") }
                current.eventToken = imported.eventToken; try saveAccount(current)
            } else {
                try saveAccount(imported); generation = UUID(); games = []; rows = []; queue = []; selectedGame = nil; titleDetails = [:]; playedHours = [:]; loadQueue(); loadCompletion()
                Task { await maintainOnOpen(forceLibrary:true) }
            }
            pendingPCAccount = nil; pcSyncStatus = eventOnly ? "Event token imported; remembered mobile sign-in retained." : "PC account imported. Renewal credentials remain on PC; sync again when this authorization expires."
        } catch { pcSyncStatus = error.localizedDescription }
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
        selectedTab = page == "queue" ? 1 : page == "spoof" ? 2 : page.hasPrefix("settings") ? 3 : page == "home" ? 4 : 0
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
        guard let account, !busy, !running else { return }; busy = true; scanningCompletion = true; defer { busy = false; scanningCompletion = false }; let version = generation
        let pending = games.filter { !checkedCompletion.contains($0.id) }
        var failures = 0
        for (n,game) in pending.enumerated() {
            guard scanningCompletion, foreground, version == generation, !Task.isCancelled else { break }
            status = "Completion scan \(n+1)/\(pending.count) · \(game.name)"
            do {
                let loaded = try await readWithAccount { try await api.achievements(game,account:$0) }; rememberCompletion(loaded,game:game)
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
