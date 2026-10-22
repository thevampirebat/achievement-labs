import Foundation

let now = Date(timeIntervalSince1970:1_800_000_000)
let sample = HomeWidgetSnapshot.demo(at:now)
assert(sample.isFresh(at:now))
assert(!sample.isFresh(at:now.addingTimeInterval(601)))
assert(sample.hasSession && sample.queueRunning)
let data = try JSONEncoder().encode(sample)
let decoded = try JSONDecoder().decode(HomeWidgetSnapshot.self,from:data)
assert(decoded == sample)
let object = try JSONSerialization.jsonObject(with:data) as! [String:Any]
assert(Set(object.keys).isSubset(of:["updatedAt","validUntil","sharingEnabled","spoofStarted","spoofExpires","spoofGame","queueRunning","nextAction","queueGame","nextAchievement","handled","total","isDemo"]))
assert(!HomeWidgetSnapshot.idle(enabled:false).isFresh(at:now))
assert(!HomeWidgetSnapshot.idle().hasSession)
print("PASS: widget snapshot round-trip, privacy allowlist, deadline and disabled state")
