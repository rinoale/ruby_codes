# P2P connectivity: who does what

The mental model behind this demo. The short version:

> **STUN tells you who *you* are. Signaling tells you who the *other peer* is.
> Hole punching makes the path. TURN is the fallback when no path exists.**

## The four roles

| role | question it answers | who performs it | mandatory? |
|------|--------------------|-----------------|------------|
| STUN | "what is *my* public IP:port?" | server (a mirror) | usually |
| Signaling (broker) | "what is the *other peer's* address?" | app's own server / any out-of-band channel | **always** |
| Hole punching | "can our NATs pass traffic directly?" | the peers themselves | for direct P2P |
| TURN | "no direct path — relay through me" | server (a data relay) | fallback only (~10–20% of cases) |

**ICE** (the WebRTC connection procedure) is not a fifth mechanism — it's this
recipe standardized: gather candidates via STUN/TURN, exchange them via
signaling, punch and probe candidate pairs, use the best one that works.

## STUN is a mirror, not a matchmaker

A common first assumption is that a STUN server "brokers" peers — it doesn't.
Standard STUN (RFC 5389) is essentially one stateless operation: you send a
Binding Request, it replies "here is the IP:port your packet arrived from"
(XOR-MAPPED-ADDRESS). You can't discover this yourself because your NAT
rewrites your source address invisibly.

A STUN server has no concept of users, rooms, or sessions. Two peers querying
the same STUN server at the same moment learn nothing about each other.

In this demo, `stun_server.rb` is therefore two things sharing one UDP port:

- Binding Request/Response — **real STUN**, byte-for-byte per the RFC.
- REGISTER / PEER-INFO (rooms, introductions) — a **signaling server** bolted
  on, reusing STUN's packet format for convenience. Real STUN servers do not
  answer these; the code labels them "demo extension".

## Signaling: how real apps learn the peer's address

Almost anticlimactic: **the app already has a server connection, so it uses
it.** Every chat/call app keeps a persistent, client-initiated, outbound
connection to its backend (websocket, or push channel) — that's how a text
message reaches you at all. Outbound connections traverse any NAT for free;
*inbound* is the hard part P2P solves.

A video call then goes:

1. Both peers are logged in (websocket/push to the app server).
2. Alice hits "call Bob" → her app gathers candidates: LAN address,
   reflexive address (STUN), relayed address (TURN).
3. Her app sends the candidates to the server addressed to Bob's
   **identity** (user ID, phone number) — not to an IP. The server forwards
   them to Bob's socket; Bob answers with his candidates the same way.
   (In WebRTC: SDP offer/answer + trickled ICE candidates.)
4. Only now does P2P start: probe candidate pairs (which also punches the
   NAT holes), pick the best working pair — direct if possible, TURN if not.
   Media leaves the signaling channel entirely.

Resolution chain: **identity → (app server) → candidate addresses →
(STUN/hole punch/TURN) → working path.** The broker deals in identities;
STUN/TURN deal only in addresses.

The broker doesn't have to be a *system*, though — any out-of-band channel
that can move a few hundred bytes both ways works: pasting blobs into IM,
QR codes, DNS records, config files. It becomes a server only when you want
it automatic and identity-addressed ("call Bob").

In this demo the room name is the "identity", the peers' registration with
the server is the "logged-in websocket", and the PEER-INFO Indication is
step 3.

## Why you can't just remember your public IP:port

The broker isn't a convenience — it's unavoidable, because the reflexive
address is not a stable property of your machine. It's a **live NAT mapping**
that exists only while your specific UDP socket keeps sending traffic. Close
the socket, idle for ~30–120 seconds, or reboot the router, and it's gone;
the next socket gets a different port.

That's why `peer.rb` creates the mapping and then keeps re-registering /
sending keepalives — and why candidates are gathered fresh per call, never
stored. It's also why you can't P2P-call someone who is fully offline: the
exchange needs the other side reachable through signaling *right now*.

(The exception proves the rule: machines with a public IP or a static
port-forward — i.e. servers — don't need any of this.)

## TURN isn't really P2P

TURN is the admission that hole punching failed (e.g. symmetric NATs that
allocate a new port per destination). The client rents a public relay port
(`Allocate`), whitelists the peer (`CreatePermission`), and traffic flows
client ⇄ relay ⇄ peer, wrapped in Send/Data Indications on the client's leg.
It works everywhere but costs the operator bandwidth — which is why ICE
prefers direct candidates and uses relay as last resort.

## Mapping to the files here

| concept | in this demo |
|---------|--------------|
| STUN mirror | Binding handling in `rendezvous.rb` (used by both servers) |
| signaling broker | REGISTER/PEER-INFO in `rendezvous.rb` (demo extension); the scripted walkthrough uses a separate `signaling_server.rb` instead, which is closer to real-world structure |
| hole punching | `P2H` hello frames in `peer.rb` |
| TURN relay | `turn_server.rb` (Allocate / CreatePermission / Data Indication), used by `peer.rb --turn` |
| keepalive against NAT expiry | periodic re-REGISTER + `P2P`/`P2O` ping frames in `peer.rb` |
