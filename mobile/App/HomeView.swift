import SwiftUI
struct HomeView: View {
    @EnvironmentObject var m: MobileModel
    @State private var sync = false
    @State private var embeddedLogin: SignInPage?
    @State private var safariPending = false
    @State private var redirect = ""
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Achievement Labs",systemImage:"trophy.fill").font(.title2.bold()).foregroundStyle(.green)
                    if let account = m.account { Text("Signed in as \(account.gamertag)").foregroundStyle(.secondary) }
                    else { Text("Connect your Xbox account to get started.").foregroundStyle(.secondary) }
                }
                Section("Connect") {
                    Button { if let url = m.beginBrowserLogin() {
                        if m.signInBrowser == "Safari" { safariPending = true; openURL(url) }
                        else { embeddedLogin = SignInPage(url:url) }
                    } } label: { Label("Sign in with Microsoft",systemImage:"person.crop.circle.badge.checkmark") }.disabled(m.busy || m.running || m.presenceRunning)
                    Button { sync = true } label: { Label("Sync from PC",systemImage:"qrcode.viewfinder") }.disabled(m.busy || m.running || m.presenceRunning)
                    Text("Scan the codes from the mobile icon in the PC app, or use normal Microsoft sign-in.").font(.caption).foregroundStyle(.secondary)
                }
                if safariPending {
                    Section("Finish Safari sign-in") {
                        SecureField("Paste the final Microsoft redirect URL",text:$redirect).textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Complete sign-in") { let value = redirect; redirect = ""; Task { await m.finishBrowserLogin(value); if m.account != nil { safariPending = false } } }.disabled(redirect.isEmpty || m.busy)
                    }
                }
                if m.account != nil {
                    Section {
                        Button("Open library",systemImage:"books.vertical") { m.selectedTab = 0 }
                        Button("Auto Unlock",systemImage:"list.bullet.rectangle") { m.selectedTab = 1 }
                        Button("Title Spoofing",systemImage:"gamecontroller") { m.selectedTab = 2 }
                    }
                }
                Section { Button("Settings and launch page",systemImage:"gear") { m.selectedTab = 3 } }
            }.navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$sync) { PCSyncView() }
            .sheet(item:$embeddedLogin) { page in
                EmbeddedSignIn(url:page.url,onComplete: { value in
                    embeddedLogin = nil; Task { await m.finishBrowserLogin(value) }
                },onCancel: { embeddedLogin = nil; m.cancelBrowserLogin() },remember:m.rememberSignIn).interactiveDismissDisabled()
            }
        }
    }
}
