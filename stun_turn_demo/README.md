# STUN / TURN P2P demo in pure Ruby

Real STUN wire format (RFC 5389) and a simplified TURN server (RFC 5766),
with every handshake packet hex-dumped and decoded.

> New to STUN/TURN/signaling and who does what? Read [CONCEPTS.md](CONCEPTS.md)
> first — it explains the roles (mirror vs. broker vs. relay) and how real
> apps resolve "call Bob" into an IP:port.

Two ways to run it:

- **Interactive** (real-world style): run a server, run two peers in
  separate terminals, chat and transfer files over the P2P channel.
- **Scripted walkthrough**: `ruby run_scripted_demo.rb` runs the whole
  STUN → signaling → hole punch → TURN flow automatically in one terminal.

## Interactive: direct P2P (STUN + hole punching)

```
terminal 1:  ruby stun_server.rb
terminal 2:  ruby peer.rb --name alice --room demo
terminal 3:  ruby peer.rb --name bob   --room demo
```

The server answers STUN Binding Requests *and* mediates the peers: each
peer REGISTERs into a room, and when both are present the server sends
each one a PEER-INFO Indication with the other's IP:port. The peers then
hole-punch and talk **directly** — no data touches the server.

## Interactive: relayed (TURN)

```
terminal 1:  ruby turn_server.rb
terminal 2:  ruby peer.rb --name alice --room demo --turn
terminal 3:  ruby peer.rb --name bob   --room demo --turn
```

Each peer Allocates a relay port on the TURN server and advertises it as
its candidate. Data sent to a peer's relay port is wrapped in a Data
Indication and forwarded to that peer — everything flows via the server
(this is the fallback when hole punching fails, e.g. symmetric NATs).

## Console commands (once connected)

```
/send <text>       chat (plain text without a command also sends)
/sendfile <path>   any file — chunked UDP (1 KB) with retransmission,
                   saved to ./downloads/ on the receiving side
/status            connection info + transfer stats
/quit
```

Peer flags: `--server HOST:PORT` (defaults 127.0.0.1:3478, or :3479 with
`--turn`), `--verbose` (hexdump *every* packet incl. file chunks).
Server args: `ruby stun_server.rb [port]`,
`ruby turn_server.rb [advertised_ip] [port]` — set `advertised_ip` to the
machine's LAN/public IP when peers connect from other hosts.

## Handshake sequence

```
peer ── STUN Binding Request ──────────────> server
peer <── Binding Success(XOR-MAPPED-ADDRESS) ── server   "you look like ip:port"
peer ── TURN Allocate ─────────────────────> server      (--turn only)
peer <── Allocate Success(XOR-RELAYED-ADDRESS) ── server
peer ── REGISTER(USERNAME "room/name") ────> server      (demo extension)
peer <── REGISTER Success ── server
peer <── PEER-INFO Indication(USERNAME, XOR-PEER-ADDRESS
         [, XOR-RELAYED-ADDRESS]) ── server              "your peer is here"
peer ── TURN CreatePermission(peer ip) ────> server      (--turn only)
peer <──── hole punch hellos ("P2H") ─────> peer         both sides, until answered
peer <════ application data (chat, files) ═══> peer      direct, or via relay ports
```

## Files

| file                   | role |
|------------------------|------|
| `stun_message.rb`      | STUN encoder/decoder, hexdump packet logger |
| `rendezvous.rb`        | room registration + peer introduction (shared by both servers) |
| `stun_server.rb`       | udp/3478 — STUN binding + rendezvous |
| `turn_server.rb`       | udp/3479 — the above + Allocate/CreatePermission/relay |
| `peer.rb`              | interactive peer |
| `run_scripted_demo.rb` | automated single-terminal walkthrough |
| `scripted_peer.rb`, `signaling_server.rb` | used by the scripted walkthrough |

## Notes

- Addresses inside STUN are XOR'd with the magic cookie `0x2112A442`
  (hence XOR-MAPPED/XOR-PEER/XOR-RELAYED) so address-rewriting NATs can't
  corrupt them; requests/responses are matched by the 96-bit transaction ID.
- REGISTER / PEER-INFO are **demo extensions**, not standard STUN — real
  apps use a separate signaling channel (websockets etc.) for this.
- Omitted vs. real TURN: long-term-credential auth (MESSAGE-INTEGRITY /
  NONCE — real servers reject the first Allocate with 401), allocation
  refresh, and ChannelBind (the 4-byte-header fast path).
- File transfer protocol: `F` header → `C` chunks (id, seq, 1 KB data) →
  `E` end → receiver replies `R` (missing seqs, retransmitted) or `D` done.
  Bulk chunks are summarized in the logs; use `--verbose` to dump them all.
