import Foundation
import Security
final class TrustProbe: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            var error: CFError?
            let valid = SecTrustEvaluateWithError(trust,&error)
            print("TRUST \(challenge.protectionSpace.host) valid=\(valid) reason=\(error.map { CFErrorCopyDescription($0) as String } ?? "none")")
            if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
                for (i,cert) in chain.enumerated() { print("CERT \(challenge.protectionSpace.host) \(i) \((SecCertificateCopyData(cert) as Data).base64EncodedString())") }
            }
        }
        completionHandler(.performDefaultHandling,nil)
    }
}
// Unauthenticated HEAD probes only. No user accounts, event tokens or event data.
let session = URLSession(configuration:.ephemeral,delegate:TrustProbe(),delegateQueue:nil)
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
