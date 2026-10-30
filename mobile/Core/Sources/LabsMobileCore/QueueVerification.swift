import Foundation

public struct UnlockVerificationSnapshot: Equatable {
    public var achieved: Bool
    public var progress: String
    public init(achieved: Bool, progress: String) { self.achieved = achieved; self.progress = progress }
}
public enum QueueVerification {
    public static func watch(read: () async throws -> UnlockVerificationSnapshot?,
                             sleep: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds:$0) },
                             progress: (UnlockVerificationSnapshot) -> Void = { _ in }) async throws -> UnlockVerificationSnapshot {
        while true {
            let result = try await verify(read:read,sleep:sleep)
            if result.achieved { return result }
            progress(result)
            try Task.checkCancellation()
            try await sleep(30_000_000_000)
        }
    }
    public static func verify(read: () async throws -> UnlockVerificationSnapshot?,
                              sleep: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds:$0) }) async throws -> UnlockVerificationSnapshot {
        let deadline = Date().addingTimeInterval(45)
        var last = UnlockVerificationSnapshot(achieved:false,progress:"Xbox progress unavailable")
        for seconds in [0,2,4,8,12] {
            try Task.checkCancellation()
            if Date() >= deadline { break }
            if seconds > 0 { try await sleep(UInt64(seconds)*1_000_000_000) }
            try Task.checkCancellation()
            if let value = try await read() { last = value }
            try Task.checkCancellation()
            if last.achieved { return last }
        }
        return last
    }
}
