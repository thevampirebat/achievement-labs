import XCTest
@testable import LabsMobileCore
final class PublicSyncTests: XCTestCase {
    func testEncryptedTransferCompatibilityAndExpiry() throws {
        let data = Data(#"{"schemaVersion":1,"nonce":"AAECAwQFBgcICQoL","ciphertext":"PCCleK2Ar3rbJOX42IYWT7nnqxaIDjYYGl3HsS9LLJBgZdqUwLN74hXQFoLmpRIathssvnTmg6ICphgqI5CMgIRUow66sgRNPjHcC4H7WodT76dATEErUqW/0v9WwJn19slr1Z8ysXTqdFvGIRYMGswCDN/B6Qf/NY8+v+eVL3qZaDf2hPvpMn2VIM5PszajQp2MW3Bp4yP+Ops2jvDTgOb78mg=","tag":"zpeo91arlKCe4Kg2CWIRkA=="}"#.utf8)
        let key = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
        let transfer = try PCTransfer.open(data,key:key,now:Date(timeIntervalSince1970:100))
        XCTAssertEqual(transfer.xuid,"42"); XCTAssertEqual(transfer.eventToken,"x:XBL3.0 x=123;synthetic-event")
        XCTAssertThrowsError(try PCTransfer.open(data,key:key,now:Date(timeIntervalSince1970:701)))
        XCTAssertThrowsError(try PCTransfer.open(data,key:String(repeating:"A",count:43),now:Date(timeIntervalSince1970:100)))
        var corrupted = try JSON.object(data); corrupted["tag"] = Data(repeating:0,count:16).base64EncodedString()
        XCTAssertThrowsError(try PCTransfer.open(JSON.data(corrupted),key:key,now:Date(timeIntervalSince1970:100)))
    }
    func testMobileReleaseFilteringAndNumericVersion() throws {
        XCTAssertTrue(MobileRelease.newer("0.10.0",than:"0.9.9")); XCTAssertFalse(MobileRelease.newer("0.3.0",than:"0.3.0"))
        let releases: [[String:Any]] = [
          ["draft":false,"html_url":"https://github.com/thevampirebat/achievement-labs/releases/tag/v9.0.0","assets":[["name":"AchievementLabs.exe"]]],
          ["draft":false,"html_url":"https://github.com/thevampirebat/achievement-labs/releases/tag/ios-v0.4.0","assets":[["name":"AchievementLabs-iOS-0.4.0-UNSIGNED.ipa","browser_download_url":"https://github.com/thevampirebat/achievement-labs/releases/download/ios-v0.4.0/AchievementLabs-iOS-0.4.0-UNSIGNED.ipa"]]]
        ]
        XCTAssertEqual(try MobileRelease.latest(JSON.data(releases))?.version,"0.4.0")
        var invalid = releases[1]; invalid["html_url"] = "https://example.com/releases/tag/x"
        XCTAssertNil(try MobileRelease.latest(JSON.data([invalid])))
    }
    func testFeedCannotOverwriteBundledAndRetainsCacheOnBadIdentity() throws {
        guard let path = ProcessInfo.processInfo.environment["LABS_CATALOGUE"] else { throw XCTSkip("Generated catalogue required") }
        let c = try Catalogue(folder:URL(fileURLWithPath:path))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true); defer { try? FileManager.default.removeItem(at:folder) }
        let cache = folder.appendingPathComponent("events.json")
        let requests = MobileRecipes(recipes:["1":[[Replacement(target:"REPLACEID",value:"1")]]])
        let remote = SyncedTitle(template:#"{"data":{"baseData":{"titleId":"999999999","serviceConfigId":"00000000-0000-0000-0000-000000000001","id":REPLACEID}}}"#,recipes:requests)
        let feed = EventFeed(schemaVersion:1,upstreamRelease:"v1.0.8",archiveSHA256:String(repeating:"a",count:64),generatedAt:ISO8601DateFormatter().string(from:Date()),titles:["999999999":remote,"572802557":remote])
        let old = c.index["572802557"]!.count
        XCTAssertEqual(try c.merge(feed,cache:cache),1); XCTAssertEqual(c.index["572802557"]?.count,old)
        XCTAssertFalse(try c.payloads(title:"999999999",achievement:"1",xuid:"0").isEmpty)
        let before = try Data(contentsOf:cache)
        let invalid = EventFeed(schemaVersion:1,upstreamRelease:"v1.0.8",archiveSHA256:String(repeating:"b",count:64),generatedAt:feed.generatedAt,titles:["888888888":remote])
        XCTAssertThrowsError(try c.merge(invalid,cache:cache)); XCTAssertEqual(try Data(contentsOf:cache),before)
        let restored = try Catalogue(folder:URL(fileURLWithPath:path)); try restored.loadCache(cache)
        XCTAssertNotNil(restored.index["999999999"])
        let local = c.index.first { $0.key != "999999999" && $0.value.reason == nil }!.key
        let id = try c.recipes(local).recipes.keys.first!
        _ = try c.payloads(title:local,achievement:id,xuid:"0")
        _ = try c.payloads(title:"999999999",achievement:"1",xuid:"0")
        XCTAssertNoThrow(try c.payloads(title:local,achievement:id,xuid:"0"))
    }
}
