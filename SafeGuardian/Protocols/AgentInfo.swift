import Foundation

/// Minimal agent-discovery signal carried in AnnouncementPacket's agentInfo TLV.
/// Deliberately not a full AgentCard: no separate agent identity, no skills list,
/// just enough for a peer to know "this device has an agent" and roughly what
/// it can do. Actual capability negotiation happens over agentText messages,
/// not in this struct.
struct AgentInfo: Equatable {
    static let maxBioBytes = 96

    struct Capabilities: OptionSet {
        let rawValue: UInt8
        static let toolsEnabled = Capabilities(rawValue: 1 << 0)
    }

    let capabilities: Capabilities
    let bio: String

    func encode() -> Data? {
        guard let bioData = bio.data(using: .utf8)?.prefix(Self.maxBioBytes) else { return nil }
        var data = Data([capabilities.rawValue])
        data.append(bioData)
        return data
    }

    static func decode(from data: Data) -> AgentInfo? {
        guard let first = data.first else { return nil }
        let bio = String(data: data.dropFirst(), encoding: .utf8) ?? ""
        return AgentInfo(capabilities: Capabilities(rawValue: first), bio: bio)
    }
}
