import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct XboxService {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    private func request(_ url: String, authorization: String, version: String = "2", method: String = "GET", body: Any? = nil) async throws -> Data {
        guard let endpoint = URL(string: url), endpoint.scheme == "https", endpoint.host?.hasSuffix(".xboxlive.com") == true else { throw LabsError.message("Invalid Xbox endpoint.") }
        var r = URLRequest(url: endpoint); r.timeoutInterval = 45; r.httpMethod = method
        r.setValue(authorization, forHTTPHeaderField: "Authorization"); r.setValue(version, forHTTPHeaderField: "x-xbl-contract-version")
        r.setValue("application/json", forHTTPHeaderField: "Accept"); r.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        if let body { r.httpBody = try JSON.data(body); r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: r)
        try Self.check(response, endpoint: endpoint.host ?? "Xbox"); guard data.count <= 128 * 1024 * 1024 else { throw LabsError.message("The response is too large.") }; return data
    }
    private static func check(_ response: URLResponse, event: Bool = false, endpoint: String = "Xbox") throws {
        guard let http = response as? HTTPURLResponse else { throw LabsError.message("No HTTP response.") }
        guard (200...299).contains(http.statusCode) else {
            let detail: String
            if endpoint == "presence-heartbeat.xboxlive.com", http.statusCode == 403 {
                detail = "Xbox refused title spoofing for this session (403). Library access can still work. The iOS and desktop sign-in profiles can have different permissions; choose Xbox desktop in Settings and sign in again to test compatibility. Xbox may still refuse it. An event token does not authorize spoofing."
            } else if http.statusCode == 401 {
                detail = event ? "The collector rejected authorization (401). Check the event token and account authorization." : "Xbox account authorization expired or was rejected (401). Sign in again."
            } else if http.statusCode == 403 {
                detail = event ? "Xbox refused the event request (403)." : "Xbox refused access to \(endpoint) (403). Permissions or profile privacy may restrict this request."
            } else { detail = "Xbox returned HTTP \(http.statusCode) from \(endpoint)." }
            throw LabsError.message(detail)
        }
    }
    public func connect(_ token: String) async throws -> Account {
        let auth = try Tokens.normalize(token, event: false)
        let data = try await request("https://profile.xboxlive.com/users/me/profile/settings?settings=Gamertag,GameDisplayPicRaw,Gamerscore", authorization: auth)
        let root = try JSON.object(data)
        guard let profile = (root["profileUsers"] as? [[String: Any]])?.first else { throw LabsError.message("Xbox did not return an account.") }
        let xuid = try JSON.requiredID(profile, "id")
        let settings = profile["settings"] as? [[String: Any]] ?? []
        let name = settings.first { JSON.string($0["id"]) == "Gamertag" }.map { JSON.string($0["value"]) } ?? "Xbox account"
        var account = Account(authorization: auth, xuid: xuid, gamertag: name)
        account.gamerpic = settings.first { JSON.string($0["id"]) == "GameDisplayPicRaw" }.flatMap { Artwork.resolve($0["value"]) }
        account.gamerscore = settings.first { JSON.string($0["id"]) == "Gamerscore" }.map { JSON.string($0["value"]) }
        return account
    }
    public func games(_ account: Account) async throws -> [Game] {
        guard JSON.numeric(account.xuid) else { throw LabsError.message("Invalid account.") }
        let data = try await request("https://titlehub.xboxlive.com/users/xuid(\(account.xuid))/titles/titleHistory/decoration/TitleHistory,Achievement,detail,scid?maxItems=10000", authorization: account.authorization)
        let root = try JSON.object(data)
        guard let titles = root["titles"] as? [[String: Any]] else { throw LabsError.message("Library response is incomplete; previous library retained.") }
        return try titles.map(Game.init)
    }
    public func achievements(_ game: Game, account: Account, xuid: String? = nil) async throws -> [Achievement] {
        let target = xuid ?? account.xuid
        guard JSON.numeric(game.id), JSON.numeric(target) else { throw LabsError.message("Invalid title or account.") }
        var results: [Achievement] = []; var continuation: String?; var seen = Set<String>()
        repeat {
            try Task.checkCancellation()
            var components = URLComponents(string: "https://achievements.xboxlive.com/users/xuid(\(target))/\(game.legacy ? "titleachievements" : "achievements")")!
            components.queryItems = [URLQueryItem(name: "titleId", value: game.id), URLQueryItem(name: "maxItems", value: "1000")]
            if let continuation { components.queryItems!.append(URLQueryItem(name: "continuationToken", value: continuation)) }
            let data = try await request(components.url!.absoluteString, authorization: account.authorization, version: game.legacy ? "3" : "4")
            let j = try JSON.object(data)
            guard let rows = j["achievements"] as? [[String: Any]] else { throw LabsError.message("Incomplete achievement response. Previous progress retained.") }
            results += try rows.map { try Achievement($0, legacy: game.legacy) }
            continuation = (j["pagingInfo"] as? [String: Any])?["continuationToken"] as? String
            if continuation == "" { continuation = nil }
            if let continuation { guard seen.insert(continuation).inserted, seen.count < 100 else { throw LabsError.message("Invalid achievement pagination.") } }
        } while continuation != nil
        return results
    }
    public func profile(gamertag: String, account: Account) async throws -> Account {
        let tag = gamertag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, tag.count <= 64 else { throw LabsError.message("Enter a gamertag.") }
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let data = try await request("https://profile.xboxlive.com/users/gt(\(encoded))/profile/settings?settings=Gamertag", authorization:account.authorization)
        guard let profile = (try JSON.object(data)["profileUsers"] as? [[String:Any]])?.first else { throw LabsError.message("Gamertag not found.") }
        let xuid = try JSON.requiredID(profile,"id")
        let settings = profile["settings"] as? [[String:Any]] ?? []
        let name = settings.first { JSON.string($0["id"]) == "Gamertag" }.map { JSON.string($0["value"]) } ?? tag
        return Account(authorization:account.authorization,xuid:xuid,gamertag:name)
    }
    public func game(_ title: String, account: Account) async throws -> Game {
        guard JSON.numeric(title) else { throw LabsError.message("Enter a numeric Title ID.") }
        let data = try await request("https://titlehub.xboxlive.com/users/xuid(\(account.xuid))/titles/batch/decoration/TitleHistory,Achievement,detail,scid", authorization:account.authorization, method:"POST", body:["Pfns":NSNull(),"TitleIds":[title]])
        guard let row = (try JSON.object(data)["titles"] as? [[String:Any]])?.first(where: { JSON.string($0["titleId"]) == title }) else { throw LabsError.message("Xbox did not return this title.") }
        return try Game(row)
    }
    public func playedMinutes(_ title: String, account: Account) async throws -> Double? {
        guard JSON.numeric(title) else { throw LabsError.message("Invalid Title ID.") }
        let data = try await request("https://userstats.xboxlive.com/batch", authorization:account.authorization, method:"POST", body:["ArrangeByField":"xuid","Xuids":[account.xuid],"Stats":[["Name":"MinutesPlayed","TitleId":title]]])
        func find(_ value: Any) -> Double? {
            if let object = value as? [String:Any] {
                if JSON.string(object["name"] ?? object["Name"]).caseInsensitiveCompare("MinutesPlayed") == .orderedSame, let result = Double(JSON.string(object["value"] ?? object["Value"])), result.isFinite, result >= 0 { return result }
                for key in object.keys.sorted() { if let result = find(object[key]!) { return result } }
            } else if let array = value as? [Any] { for item in array { if let result = find(item) { return result } } }
            return nil
        }
        return find(try JSON.object(data))
    }
    public func titleUnlock(_ achievement: Achievement, game: Game, account: Account) async throws {
        guard !game.legacy, !achievement.eventBased, JSON.numeric(game.id), JSON.numeric(achievement.id), UUID(uuidString: achievement.serviceConfigID) != nil else { throw LabsError.message("This achievement cannot use title-based unlocks.") }
        _ = try await request("https://achievements.xboxlive.com/users/xuid(\(account.xuid))/achievements/\(achievement.serviceConfigID)/update", authorization: account.authorization, method: "POST", body: ["action":"progressUpdate", "serviceConfigId":achievement.serviceConfigID, "titleId":game.id, "userId":account.xuid, "achievements":[["id":achievement.id,"percentComplete":"100"]]])
    }
    public func presence(_ title: String?, account: Account) async throws {
        if let title { guard JSON.numeric(title) else { throw LabsError.message("Enter a numeric Title ID.") } }
        let body: Any? = title.map { ["titles":[["id":$0,"expiration":600,"state":"active","sandbox":"RETAIL"]]] }
        _ = try await request("https://presence-heartbeat.xboxlive.com/users/xuid(\(account.xuid))/devices/current/", authorization: account.authorization, version: "3", method: title == nil ? "DELETE" : "POST", body: body)
    }
    public func sendEvent(_ payload: String, account: Account) async throws {
        let token = try Tokens.normalize(account.eventToken, event: true)
        var r = URLRequest(url: URL(string: "https://v20.events.data.microsoft.com/OneCollector/1.0/")!)
        r.httpMethod = "POST"; r.timeoutInterval = 45; r.httpBody = payload.data(using: .utf8)
        let redacted = account.authorization.replacingOccurrences(of: #"(?i)x=[^;]+;"#, with: "x=-;", options: .regularExpression)
        let headers = ["Content-Type":"application/x-json-stream", "Accept":"application/json", "User-Agent":"MSDW", "reliability-mode":"standard", "Client-Id":"NO_AUTH", "client-version":"EUTC-Windows-C++-no-10.0.22621.3296.amd64fre.ni_release.220506-1250-no", "apikey":"0890af88a9ed4cc886a14f5e174a2827-9de66c5e-f867-43a8-a7b8-e0ddd481cca4-7548,95c1f21d6cb047a09e7b423c1cb2222e-9965f07b-54fa-498e-9727-9e8d24dec39e-7027", "authxtoken":redacted, "tickets":"\"1\"=\"\(token)\""]
        headers.forEach { r.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: r); try Self.check(response, event: true); try Self.validateCollector(data)
    }
    public static func validateCollector(_ data: Data) throws {
        guard !data.isEmpty else { return }
        guard data.count <= 65536 else { throw LabsError.message("Collector acknowledgement could not be checked.") }
        guard let j = try? JSON.object(data) else { throw LabsError.message("Unrecognised collector acknowledgement; refresh to verify progress.") }
        let failure = j["TokenCrackingFailure"]
        let badToken = failure != nil && !(failure is NSNull) && (failure as? Bool != false)
        let explicit = (j["efi"] as? [String: Any] ?? [:]).values.contains { ($0 as? String) == "all" || (($0 as? [Any])?.isEmpty == false) }
        if badToken || explicit || (j["rej"] as? Int ?? 0) > 0 || (j["acc"] as? Int) == 0 { throw LabsError.message("Collector rejected the event. Refresh your token or check the mapping; no unlock is confirmed.") }
    }
}
