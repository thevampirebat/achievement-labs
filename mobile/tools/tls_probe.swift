import Foundation
// Unauthenticated HEAD probes only. No user accounts, event tokens or event data.
let session = URLSession(configuration:.ephemeral)
let group = DispatchGroup()
for host in ["mobile.events.data.microsoft.com","v20.events.data.microsoft.com","achievements.xboxlive.com","presence-heartbeat.xboxlive.com"] {
    group.enter(); var request = URLRequest(url:URL(string:"https://"+host+(host.contains("events.data") ? "/OneCollector/1.0/" : "/"))!)
    request.httpMethod = "HEAD"; request.timeoutInterval = 15
    session.dataTask(with:request) { _,response,error in
        if let error { let e=error as NSError; let underlying=e.userInfo[NSUnderlyingErrorKey] as? NSError; print("\(host): \(e.domain) \(e.code), underlying \(underlying?.domain ?? "none") \(underlying?.code ?? 0)") }
        else { print("\(host): TLS accepted, HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)") }
        group.leave()
    }.resume()
}
_ = group.wait(timeout:.now()+25)
session.invalidateAndCancel()
