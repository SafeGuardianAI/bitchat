import Foundation

enum A2ADiscoverySpike {
    static func verifyRoundTrip() -> String {
        let value = roundTrip(input: "swift")
        precondition(value == "rust:swift", "UniFFI Rust/Swift round trip failed: \(value)")
        return "\(value);a2a=\(a2aVersion())"
    }
}
