import Foundation

#if canImport(bitchat_a2a)
import bitchat_a2a
#endif

enum A2ADiscoverySpike {
    static func verifyRoundTrip() -> String {
#if canImport(bitchat_a2a)
        let value = roundTrip(input: "swift")
        precondition(value == "rust:swift", "UniFFI Rust/Swift round trip failed: \(value)")
        return "\(value);a2a=\(a2aVersion())"
#else
        return "A2A bridge not linked"
#endif
    }
}
