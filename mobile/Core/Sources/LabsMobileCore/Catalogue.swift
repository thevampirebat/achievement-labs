import Foundation

public struct MappingStatus: Codable {
    public var count: Int; public var classification: String; public var reason: String?
}
public struct Replacement: Codable { public let target: String; public let value: String }
public struct MobileRecipes: Codable { public let recipes: [String: [[Replacement]]] }
public struct PackDocument: Codable {
    public let schemaVersion: Int; public let titles: [PackTitle]
}
public struct PackTitle: Codable {
    public let titleId: String; public let platforms: [String]; public let packs: [Pack]
}
public struct Pack: Codable {
    public let name: String; public let kind: String; public let achievements: [PackAchievement]
}
public struct PackAchievement: Codable { public let id: String; public let name: String }

public final class Catalogue {
    public let index: [String: MappingStatus]
    private let folder: URL
    private let packs: [PackTitle]
    public init(folder: URL) throws {
        self.folder = folder
        index = try JSONDecoder().decode([String: MappingStatus].self, from: Data(contentsOf: folder.appendingPathComponent("MobileIndex.json")))
        packs = try ["achievement-packs.json", "achievement-hubs.json"].flatMap {
            try JSONDecoder().decode(PackDocument.self, from: Data(contentsOf: folder.appendingPathComponent($0))).titles
        }
    }
    public func recipes(_ title: String) throws -> MobileRecipes {
        guard JSON.numeric(title), let status = index[title], status.reason == nil else { throw LabsError.message(index[title]?.reason ?? "No mobile event data is available for this title.") }
        return try JSONDecoder().decode(MobileRecipes.self, from: Data(contentsOf: folder.appendingPathComponent("Events/\(title).mapping.json")))
    }
    public func payloads(title: String, achievement: String, xuid: String) throws -> [String] {
        let mapping = try recipes(title)
        let template = try String(contentsOf: folder.appendingPathComponent("Events/\(title).json"), encoding: .utf8)
        guard let requests = mapping.recipes[achievement] else { throw LabsError.message("No verified mobile mapping for this achievement.") }
        return try Self.build(template: template, requests: requests, title: title, xuid: xuid)
    }
    public static func build(template: String, requests: [[Replacement]], title: String, xuid: String, date: Date = Date()) throws -> [String] {
        guard JSON.numeric(title), JSON.numeric(xuid), !requests.isEmpty, requests.count <= 1000 else { throw LabsError.message("Invalid mapping identity or request count.") }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: date); let session = UUID().uuidString.lowercased()
        return try requests.enumerated().map { n, operations in
            var body = template
            guard !operations.isEmpty else { throw LabsError.message("Empty mapping.") }
            for op in operations {
                guard !op.target.isEmpty, body.contains(op.target) else { throw LabsError.message("Mapping target does not match the template.") }
                body = body.replacingOccurrences(of: op.target, with: op.value)
            }
            for (target, value) in ["REPLACESEQ":String(Int64(date.timeIntervalSince1970 * 1000) + Int64(n)), "REPLACETIME":stamp, "REPLACEXUID":xuid, "REPLACESESSIONGUID":session] { body = body.replacingOccurrences(of: target, with: value) }
            guard body.range(of: "REPLACE[A-Z0-9_]+", options: .regularExpression) == nil else { throw LabsError.message("Unresolved event placeholder.") }
            let j = try JSON.object(Data(body.utf8)); let data = j["data"] as? [String: Any] ?? [:]; let base = data["baseData"] as? [String: Any] ?? [:]
            guard JSON.string(base["titleId"]) == title, UUID(uuidString: JSON.string(base["serviceConfigId"])) != nil else { throw LabsError.message("Event title or service identity does not match.") }
            return body
        }
    }
    private func definition(_ game: Game) -> PackTitle? { packs.first { $0.titleId == game.id && !$0.platforms.filter(game.platforms.contains).isEmpty } }
    public static func normalized(_ name: String) -> String { name.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(String.init).joined() }
    public func group(_ achievement: Achievement, game: Game) -> String {
        guard let title = definition(game) else { return "Achievements" }
        return title.packs.first { $0.achievements.contains { $0.id == achievement.id && Self.normalized($0.name) == Self.normalized(achievement.name) } }?.name ?? "Unclassified"
    }
    public func groups(_ game: Game) -> [String] { (definition(game)?.packs.map(\.name) ?? ["Achievements"]) + ["Unclassified"] }
    public func baseComplete(_ rows: [Achievement], game: Game) -> Bool {
        guard !rows.isEmpty else { return false }
        if rows.allSatisfy(\.unlocked) { return true }
        guard let base = definition(game)?.packs.first(where: { $0.kind == "base" }), !base.achievements.isEmpty else { return false }
        return base.achievements.allSatisfy { item in rows.contains { $0.id == item.id && Self.normalized($0.name) == Self.normalized(item.name) && $0.unlocked } }
    }
}
