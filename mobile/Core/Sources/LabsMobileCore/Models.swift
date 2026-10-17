import Foundation

public enum LabsError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
public struct Account: Codable, Equatable {
    public var authorization: String
    public var xuid: String
    public var gamertag: String
    public var eventToken: String
    public init(authorization: String, xuid: String, gamertag: String, eventToken: String = "") {
        self.authorization = authorization; self.xuid = xuid; self.gamertag = gamertag; self.eventToken = eventToken
    }
}
public struct Game: Codable, Identifiable, Hashable {
    public var id: String; public var name: String; public var platforms: [String]
    public var unlocked: Int; public var total: Int; public var image: String; public var lastPlayed: String
    public var legacy: Bool { platforms.contains { ["Xbox360", "GFWL"].contains($0) } }
    public var complete: Bool { total > 0 && unlocked == total }
    public init(_ j: [String: Any]) throws {
        id = try JSON.requiredID(j, "titleId"); name = JSON.string(j["name"]); platforms = j["devices"] as? [String] ?? []
        let a = j["achievement"] as? [String: Any] ?? [:]
        unlocked = (a["currentAchievements"] as? Int) ?? 0; total = (a["totalAchievements"] as? Int) ?? 0
        image = JSON.string(j["displayImage"]); lastPlayed = JSON.string((j["titleHistory"] as? [String: Any])?["lastTimePlayed"])
    }
}
public struct Achievement: Codable, Identifiable, Hashable {
    public var id: String; public var name: String; public var detail: String; public var unlocked: Bool
    public var serviceConfigID: String; public var eventBased: Bool; public var score: String
    public init(_ j: [String: Any], legacy: Bool = false) throws {
        id = try JSON.requiredID(j, "id"); name = JSON.string(j["name"])
        detail = JSON.string(j["description"]); if detail.isEmpty { detail = JSON.string(j["lockedDescription"]) }
        unlocked = legacy ? (j["unlocked"] as? Bool ?? false) : JSON.string(j["progressState"]).lowercased() == "achieved"
        serviceConfigID = JSON.string(j["serviceConfigId"])
        let p = j["progression"] as? [String: Any] ?? [:]
        eventBased = (p["requirements"] as? [[String: Any]] ?? []).contains {
            let s = JSON.string($0["id"]); return !s.isEmpty && s != "00000000-0000-0000-0000-000000000000"
        }
        score = JSON.string(j["gamerscore"])
        if score.isEmpty { score = (j["rewards"] as? [[String: Any]] ?? []).first(where: { JSON.string($0["type"]).lowercased() == "gamerscore" }).map { JSON.string($0["value"]) } ?? "" }
    }
}
public struct QueueItem: Codable, Identifiable {
    public var id: String { game.id + "/" + achievement.id }
    public var game: Game; public var achievement: Achievement; public var delay: Double; public var status: String
    public init(game: Game, achievement: Achievement, delay: Double) { self.game = game; self.achievement = achievement; self.delay = delay; status = "Waiting" }
}
public enum JSON {
    public static func string(_ v: Any?) -> String { if let s = v as? String { return s }; if let n = v as? NSNumber { return n.stringValue }; return "" }
    public static func numeric(_ s: String) -> Bool { !s.isEmpty && s.utf8.allSatisfy { (48...57).contains($0) } }
    public static func requiredID(_ j: [String: Any], _ key: String) throws -> String {
        let s = string(j[key]); guard numeric(s) else { throw LabsError.message("The service returned an invalid identifier.") }; return s
    }
    public static func object(_ data: Data) throws -> [String: Any] {
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LabsError.message("Unexpected service response.") }; return j
    }
    public static func data(_ j: Any) throws -> Data { try JSONSerialization.data(withJSONObject: j, options: [.sortedKeys]) }
}
public enum Tokens {
    public static func normalize(_ input: String, event: Bool) throws -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = value.range(of: #"(?:tickets\s*:\s*)?"1"\s*=\s*"([^"]+)""#, options: .regularExpression) {
            let match = String(value[r]); if let start = match.range(of: #"=\s*""#, options: .regularExpression) { value = String(match[start.upperBound...].dropLast()) }
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if value.lowercased().hasPrefix("x:xbl3.0 ") { value = String(value.dropFirst(2)) }
        guard value.range(of: #"(?i)^XBL3\.0\s+x=[^;\s]+;[^\s\x00-\x1F\x7F]+$"#, options: .regularExpression) != nil,
              !value.contains("\"") else { throw LabsError.message("Paste the complete Xbox token, including XBL3.0 x=…;…") }
        try validateExpiry(value)
        return (event ? "x:" : "") + value
    }
    public static func validateExpiry(_ value: String) throws {
        let jwt = value.split(separator: ";").last.map(String.init) ?? ""
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return } // Encrypted event tokens have five segments; Xbox checks them.
        var b = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b += String(repeating: "=", count: (4 - b.count % 4) % 4)
        guard let d = Data(base64Encoded: b), let j = try? JSON.object(d), let exp = j["exp"] as? Double else { return }
        guard exp > Date().timeIntervalSince1970 + 60 else { throw LabsError.message("This token has expired. Paste a current token.") }
    }
}
