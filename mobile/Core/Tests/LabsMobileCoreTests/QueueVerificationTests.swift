import XCTest
@testable import LabsMobileCore
final class QueueVerificationTests: XCTestCase {
 func testDelayedConfirmation() async throws {
  var reads=0
  let result=try await QueueVerification.verify(read:{reads += 1;return UnlockVerificationSnapshot(achieved:reads==3,progress:"69/25")},sleep:{_ in})
  XCTAssertTrue(result.achieved);XCTAssertEqual(reads,3)
 }
 func testIncompleteAndMissingAreBounded() async throws {
  var reads=0
  let result=try await QueueVerification.verify(read:{reads += 1;return UnlockVerificationSnapshot(achieved:false,progress:"69/25")},sleep:{_ in})
  XCTAssertFalse(result.achieved);XCTAssertEqual(reads,5)
  let missing=try await QueueVerification.verify(read:{nil},sleep:{_ in});XCTAssertFalse(missing.achieved)
 }
 func testAcceptedQueueCodableKeepsVerificationCheckpoint() throws {
  var item=QueueItem(game:try Game(["titleId":"7","name":"Game"]),achievement:try Achievement(["id":"1","name":"First"]),delay:120)
  for status in ["Accepted — verify progress","Verifying — accepted request","Unconfirmed — 5/25","Interrupted — refresh before retry","Submitting"] {
   item.status=status
   let restored=try JSONDecoder().decode(QueueItem.self,from:JSONEncoder().encode(item))
   XCTAssertEqual(QueuePolicy.next([restored],stopOnFailure:true),.verify(0));XCTAssertEqual(QueuePolicy.next([restored],stopOnFailure:false),.verify(0));XCTAssertFalse(QueuePolicy.terminal(status))
  }
 }
 func testCancellationAndReadFailure() async throws {
  let task=Task { try await QueueVerification.verify(read:{try Task.checkCancellation();throw CancellationError()},sleep:{_ in}) }
  task.cancel();do{_ = try await task.value;XCTFail()}catch is CancellationError{}
  do{_ = try await QueueVerification.verify(read:{throw LabsError.message("synthetic")},sleep:{_ in});XCTFail()}catch{}
 }
 func testWatchContinuesAfterInitialWindow() async throws {
  var reads=0;var updates=0
  let result=try await QueueVerification.watch(read:{reads += 1;return UnlockVerificationSnapshot(achieved:reads==7,progress:"25/25")},sleep:{_ in},progress:{_ in updates += 1})
  XCTAssertTrue(result.achieved);XCTAssertEqual(reads,7);XCTAssertEqual(updates,1)
 }
 func testWatchCanBeCancelledBetweenWindows() async throws {
  do { _ = try await QueueVerification.watch(read:{UnlockVerificationSnapshot(achieved:false,progress:"pending")},sleep:{ nanos in if nanos==30_000_000_000 { throw CancellationError() } });XCTFail() } catch is CancellationError {}
 }
}
