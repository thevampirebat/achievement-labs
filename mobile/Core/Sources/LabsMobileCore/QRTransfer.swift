import Foundation
import CryptoKit

/// Bounded, order-independent collector. QR content is a private credential transfer.
public struct QRTransferCollector {
    private var digest: String?
    private var total = 0
    private var pieces: [Int:String] = [:]
    public init() {}
    public var progress: String { total == 0 ? "Point the camera at the PC codes." : "Collected \(pieces.count) of \(total) codes" }
    public mutating func accept(_ frame: String) throws -> (Data,String)? {
        guard frame.utf8.count <= 1000 else { throw LabsError.message("QR code is too large.") }
        let fields = frame.split(separator:"|",omittingEmptySubsequences:false).map(String.init)
        guard fields.count == 5, fields[0] == "ALPC1", fields[1].count == 64,
              fields[1].allSatisfy({ "0123456789abcdef".contains($0) }),
              let index = Int(fields[2]), let count = Int(fields[3]), (1...256).contains(count),
              (0..<count).contains(index), !fields[4].isEmpty, fields[4].count <= 800 else {
            throw LabsError.message("This is not an Achievement Labs PC transfer code.")
        }
        if let digest { guard digest == fields[1], total == count else { throw LabsError.message("Different transfer detected. Reset the scanner to scan a new PC transfer.") } }
        else { digest = fields[1]; total = count }
        if let previous = pieces[index], previous != fields[4] { throw LabsError.message("Conflicting QR code. Reset the scanner.") }
        pieces[index] = fields[4]
        guard pieces.count == total else { return nil }
        guard let bytes = Data(base64Encoded:(0..<total).map { pieces[$0]! }.joined()), bytes.count <= 180*1024,
              SHA256.hash(data:bytes).map({ String(format:"%02x",$0) }).joined() == digest else { throw LabsError.message("QR transfer checksum failed. Reset and scan again.") }
        struct Payload: Decodable { let key: String; let file: String }
        let payload = try JSONDecoder().decode(Payload.self,from:bytes)
        guard payload.key.count == 43, let file = Data(base64Encoded:payload.file), file.count <= 128*1024 else { throw LabsError.message("Invalid QR transfer.") }
        return (file,payload.key)
    }
}
