import XCTest
@testable import LabsMobileCore

final class ServiceRefinementTests: XCTestCase {
    func testSpoofingUsesDesktopContract() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [LoginProtocol.self]
        let session = URLSession(configuration:config); defer { session.invalidateAndCancel(); LoginProtocol.handler = nil }
        LoginProtocol.handler = { request in
            XCTAssertEqual(request.url?.host,"presence-heartbeat.xboxlive.com")
            XCTAssertEqual(request.url?.path,"/users/xuid(42)/devices/current/")
            XCTAssertEqual(request.value(forHTTPHeaderField:"x-xbl-contract-version"),"3")
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating:0,count:4096)
                while stream.hasBytesAvailable { let n = stream.read(&buffer,maxLength:buffer.count); if n <= 0 { break }; body.append(contentsOf:buffer.prefix(n)) }
            }
            if request.httpMethod == "POST" {
                let json = try JSON.object(body); let title = (json["titles"] as! [[String:Any]])[0]
                XCTAssertEqual(title["id"] as? String,"7"); XCTAssertEqual(title["expiration"] as? Int,600)
                XCTAssertEqual(title["state"] as? String,"active"); XCTAssertEqual(title["sandbox"] as? String,"RETAIL")
            } else { XCTAssertEqual(request.httpMethod,"DELETE"); XCTAssertTrue(body.isEmpty) }
            return Data()
        }
        let api = XboxService(session:session); let account = Account(authorization:"synthetic",xuid:"42",gamertag:"Test")
        try await api.presence("7",account:account); try await api.presence(nil,account:account)
    }
    func testReferenceReadUsesOwnAuthorizationAndReferenceXuid() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [LoginProtocol.self]
        let session = URLSession(configuration:config); defer { session.invalidateAndCancel(); LoginProtocol.handler = nil }
        LoginProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"synthetic-own")
            XCTAssertTrue(request.url!.path.contains("xuid(99)"))
            return try JSON.data(["achievements":[["id":"1","name":"Test","progressState":"Achieved","progression":["timeUnlocked":"2026-01-01T00:00:00Z"]]]])
        }
        let rows = try await XboxService(session:session).achievements(try Game(["titleId":"7"]),account:Account(authorization:"synthetic-own",xuid:"42",gamertag:"Test"),xuid:"99")
        XCTAssertNotNil(rows.first?.unlockedAt)
    }
}
