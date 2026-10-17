import XCTest
@testable import LabsMobileCore
final class BackgroundQueueTests: XCTestCase {
    func testCancelledLateGrantCannotReviveResumedQueue() {
        var lease = BackgroundQueueLease()
        let cancelled = lease.request(total:2)
        XCTAssertTrue(lease.finish(cancelled))
        let resumed = lease.request(total:3)
        XCTAssertFalse(lease.grant(cancelled)); XCTAssertFalse(lease.granted)
        XCTAssertTrue(lease.grant(resumed)); XCTAssertFalse(lease.grant(resumed))
        XCTAssertFalse(lease.finish(cancelled)); XCTAssertTrue(lease.granted)
        XCTAssertTrue(lease.finish(resumed)); XCTAssertFalse(lease.grant(resumed))
    }
    func testForegroundProgressCarriesIntoGrantAndIsBounded() {
        var lease = BackgroundQueueLease(); let token = lease.request(total:2)
        lease.advance(); XCTAssertEqual(lease.completed,1)
        XCTAssertTrue(lease.grant(token)); XCTAssertEqual(lease.completed,1)
        lease.advance(); lease.advance(); XCTAssertEqual(lease.completed,2)
        lease.finish(token); lease.advance(); XCTAssertEqual(lease.completed,2)
    }
}
