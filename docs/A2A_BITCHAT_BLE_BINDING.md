# A2A protocol binding: bitchat BLE v1

Status: Phase 1 design baseline  
Protocol binding identifier: `bitchat-ble/v1`  
A2A protocol: 1.0  
Transport: bitchat BLE mesh

## 1. Scope

This document binds A2A request/response semantics to bitchat's existing BLE mesh rather than introducing an HTTP URL transport. Phase 2 BLE code MUST conform to this document unless the binding identifier is revised.

The binding deliberately separates A2A semantics from BLE delivery. A2A payloads are serialized at the binding layer, wrapped in a small binding envelope, and then handed to bitchat's existing packet encoder, fragmentation/reassembly, encryption, relay, TTL, and deduplication machinery. The binding MUST NOT define a second BLE fragmentation protocol.

## 2. Endpoint model and addressing

A bitchat A2A endpoint is identified by a persistent identity public key, not a URL. The canonical endpoint identifier is:

`bitchat://<lowercase-base32-identity-key>`

The URI is a logical A2A address only; it is never dereferenced through DNS or HTTP. The full persistent identity key is the authority. Ephemeral BLE peer IDs, peripheral UUIDs, nicknames, channel names, and current radio routes are locators and MUST NOT be treated as agent identity.

Resolution is local: the transport maps the persistent identity key to the currently observed bitchat peer/session and route. A missing route means temporarily unreachable, not unknown identity. Key rotation requires an authenticated continuity statement or creates a new endpoint identity.

## 3. Protocol binding declaration

An AgentCard that supports this transport advertises an interface with:

- `protocolBinding`: `bitchat-ble/v1`
- `url`: the logical `bitchat://<identity-key>` endpoint
- A2A protocol version: `1.0`

Implementations MUST reject an incompatible major binding version. Additive v1 envelope flags may be ignored only when explicitly marked ignorable.

## 4. Binding envelope

Each logical A2A transfer is encoded as one envelope before it enters bitchat packetization:

| Field | Size | Meaning |
|---|---:|---|
| magic | 2 B | ASCII `A2` |
| bindingVersion | 1 B | `0x01` |
| kind | 1 B | message kind below |
| flags | 1 B | response/error/stream/final/card-compressed bits |
| messageId | 16 B | UUID bytes; stable across retries |
| correlationId | 16 B | request messageId; zero for unsolicited control messages |
| cardRevision | 8 B | sender AgentCard revision/hash prefix; zero if not applicable |
| payloadLength | 4 B | unsigned network-order payload length |
| payload | N B | encoded A2A or control payload |

Kinds:

- `0x01` A2A request
- `0x02` A2A response
- `0x03` A2A stream event
- `0x04` binding error
- `0x10` AgentCard announce
- `0x11` AgentCard request
- `0x12` AgentCard response

The initial v1 payload encoding is UTF-8 JSON using the A2A JSON representation. The envelope is binary so routing/framing metadata does not incur JSON overhead. A later compact encoding requires a new negotiated flag or binding revision; it MUST NOT silently change v1 payload interpretation.

## 5. Mapping onto bitchat BLE packets

The complete envelope is the payload supplied to bitchat's existing logical-message send path. Existing bitchat packet types remain responsible for peer delivery, encryption, relay, TTL, and fragmentation.

If the envelope fits in one bitchat payload, send it as one logical message. If it exceeds the current bitchat payload limit, invoke the existing bitchat fragmentation path. Every fragment therefore carries the normal bitchat fragment metadata; the A2A `messageId` remains constant and is evaluated only after normal bitchat reassembly succeeds.

Receive order is:

1. BLE receives ordinary bitchat packets/fragments.
2. Existing bitchat authentication/decryption and fragment reassembly completes.
3. Existing duplicate suppression runs.
4. The reassembled payload is recognized by the `A2` magic and binding version.
5. The A2A binding validates `payloadLength`, kind, correlation, and sender identity.
6. The decoded A2A object is delivered to the A2A runtime.

Send order is the exact inverse.

A2A code MUST NOT depend on BLE MTU, fragment count, or CoreBluetooth peripheral UUID. BLE MTU changes therefore do not alter this binding.

## 6. Request, response, retry, and streaming semantics

`messageId` is generated once per logical outbound binding message. A retry reuses the same `messageId`; a semantically new A2A request gets a new ID. Receivers maintain a bounded replay/dedup cache keyed by `(sender identity key, messageId)` and MUST NOT execute a duplicate request twice.

Responses and stream events set `correlationId` to the originating request `messageId`. Streaming uses ordered A2A event semantics after reassembly; each event is its own envelope and logical bitchat message. `final` marks the last event. v1 does not attempt fragment-level streaming into the A2A parser.

Transport timeout is route/liveness policy, not an A2A semantic failure. A peer disappearing from BLE range does not invalidate the task or peer identity.

## 7. AgentCard distribution and cache

AgentCards are cache-first because BLE makes per-call fetch wasteful. Each local agent stores the latest validated card by persistent identity key.

A card has a `cardRevision`: the first 8 bytes of SHA-256 over the canonical serialized card. The full card SHOULD also carry its normal A2A version/interface data. Peers advertise the revision cheaply during peer capability exchange or via a small `AgentCard announce` control envelope. An announce contains identity key, card revision, A2A version, supported binding identifiers, and optional expiry/max-age; it does not contain the full card unless policy chooses to piggyback a small card.

On first encounter, unknown revision, expiry, or explicit invalidation, the receiver sends `AgentCard request`. The owner answers once with `AgentCard response`; the receiver validates that the card's logical bitchat endpoint corresponds to the authenticated persistent identity key, computes the revision, and caches it.

Normal A2A calls then carry only `cardRevision`. A receiver MAY continue using a cached card while the announced revision is unchanged. If a request references an unknown/new revision, the receiver may queue the request briefly while fetching the card or return a binding error requesting card refresh. It MUST NOT repeatedly fetch an unchanged card per call.

AgentCard responses are ordinary logical bitchat messages and therefore use existing encryption, fragmentation, and relay behavior. Large cards SHOULD be minimized for BLE; external assets referenced by a card are not implicitly fetched by this binding.

## 8. Identity and security invariants

The authenticated bitchat persistent identity key is authoritative for sender identity. The `bitchat://` identity in an AgentCard MUST match that authenticated key. A card received from peer A cannot assert peer B without a separately verifiable delegation mechanism.

The binding adds no new plaintext security layer beneath A2A. It relies on bitchat's existing authenticated/encrypted peer transport and preserves its relay/privacy properties. Implementations MUST apply payload size limits before allocation and MUST bound replay caches, pending correlations, card caches, and incomplete transfers.

## 9. Errors

Binding errors use kind `0x04` and a compact JSON body containing `code`, `message`, and optional `retryable`/`cardRevision`. Initial codes:

- `unsupported_binding`
- `malformed_envelope`
- `payload_too_large`
- `identity_mismatch`
- `agent_card_required`
- `agent_card_stale`
- `correlation_unknown`
- `temporarily_unreachable`

A transport/binding error MUST remain distinguishable from an A2A application error.

## 10. Phase 2 conformance gates

Phase 2 is conformant only when tests demonstrate: single-packet request/response; multi-fragment request/response through the existing bitchat fragmenter; identity-key addressing surviving BLE session/peripheral changes; duplicate request suppression across retry; cached AgentCard reuse without per-call transfer; revision change causing exactly one refresh; stale/forged card rejection; route loss represented as transport unreachability; and iOS device plus Apple-silicon simulator builds.

Any Phase 2 implementation that introduces parallel fragmentation, uses nicknames/peripheral UUIDs as A2A identity, or re-fetches an unchanged AgentCard for each request violates this binding.
