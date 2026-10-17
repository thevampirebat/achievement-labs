import SwiftUI
import UniformTypeIdentifiers
import LabsMobileCore

struct SyncSettings: View {
    @EnvironmentObject var m: MobileModel
    @State private var pcSync = false
    var body: some View {
        Group {
            Section("Library") { Toggle("Refresh on opening and sign-in",isOn:$m.autoRefreshLibrary) }
            Section("Event data sync") {
                Toggle("Sync new event games automatically",isOn:$m.autoSyncEvents)
                Button("Sync event data now") { Task { await m.syncEvents() } }.disabled(m.eventsSyncing || m.running)
                Text(m.eventSyncStatus).font(.caption).foregroundStyle(.secondary)
                Text("The public feed checks the original repo hourly. New validated titles are marked Testing. Existing mappings and edition fixes are retained.").font(.caption2).foregroundStyle(.secondary)
            }
            Section("App updates") {
                Toggle("Check for updates on opening",isOn:$m.checkMobileUpdates)
                Toggle("Notify about new versions",isOn:$m.notifyMobileUpdates).onChange(of:m.notifyMobileUpdates) { _,enabled in if enabled { Task { await m.requestNotifications() } } }
                Button("Check for updates now") { Task { await m.checkForMobileUpdates() } }.disabled(m.updateChecking)
                Text(m.updateStatus).font(.caption).foregroundStyle(.secondary)
                if let update = m.availableUpdate { Link("Open iOS " + update.version + " download",destination:update.page) }
                Text("Checks run while the app is open. Download the IPA and sign/install through Signulous; this app cannot replace its own installed build.").font(.caption2).foregroundStyle(.secondary)
            }
            Section("PC sync") {
                Button("Import encrypted PC sign-in",systemImage:"desktopcomputer") { pcSync = true }.disabled(m.busy || m.running || m.presenceRunning)
                Text("In the matching PC build, open Settings → iPhone / iPad sync. Export the encrypted file and pairing key, then import them here within 10 minutes.").font(.caption2).foregroundStyle(.secondary)
            }
        }.sheet(isPresented:$pcSync) { PCSyncView() }
    }
}
struct PCSyncView: View {
    @EnvironmentObject var m: MobileModel
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var file: Data?
    @State private var key = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Encrypted transfer") {
                    Button(file == nil ? "Choose .labslink file" : "Choose another file") { importing = true }
                    SecureField("Pairing key from PC",text:$key).textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Verify PC account") {
                        guard let data = file else { return }; let value = key; file = nil; key = ""
                        Task { await m.preparePCTransfer(data,key:value) }
                    }.disabled(file == nil || key.isEmpty || m.busy)
                    Text(m.pcSyncStatus).font(.caption).foregroundStyle(.secondary)
                }
                if let imported = m.pendingPCAccount {
                    Section("Verified account") {
                        Text(imported.gamertag).font(.headline)
                        Button("Connect this PC account") { m.usePCTransfer(eventOnly:false) }
                        if m.account?.xuid == imported.xuid, !imported.eventToken.isEmpty { Button("Import event token only") { m.usePCTransfer(eventOnly:true) } }
                        Text("Connecting imports current authorization and the event token. Microsoft renewal credentials remain on PC. Event-only import preserves your remembered mobile sign-in.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.disabled(m.running || m.presenceRunning)
            .navigationTitle("PC sync").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Done") { m.pendingPCAccount = nil; key = ""; file = nil; dismiss() }.disabled(m.busy) } }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.data,.json],allowsMultipleSelection:false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0 <= 128*1024 else { throw LabsError.message("Transfer file is too large.") }
                    file = try Data(contentsOf:url); m.pcSyncStatus = "File selected. Enter its separate pairing key."
                } catch { m.pcSyncStatus = error.localizedDescription }
            }
        }.onDisappear { key = ""; file = nil; m.pendingPCAccount = nil }
    }
}
