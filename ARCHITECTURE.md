# Architecture

Baro Wardrobe Switcher is a hybrid modular monolith. It is one Barotrauma content package, but game-facing adapters are kept separate from deterministic state and protocol code.

## Runtime boundaries

- `Lua/WardrobeCore.lua` owns the versioned look schema, slot keys, network codecs, limits, and client reducer. It has no Barotrauma or LuaCs dependency and is loaded in both realms.
- `Lua/WardrobeSwitcher.lua` is the client adapter. It owns the two-page UI, native target dropdown, character/inventory hooks, persistence and renderer calls, and protocol-5/v1 negotiation through the existing `v2`-named channels.
- `Lua/WardrobeSwitcherServer.lua` is the authoritative server adapter. It validates commands against server content, owns revisions and idempotency, persists stable accounts, and sends canonical state.
- `CSharp/Client` is a client-only compatibility adapter for Barotrauma rendering, animation, and sound. It must not own multiplayer truth.

The server does not load C#. Linux dedicated servers therefore use the same Lua server implementation as Windows hosts.

## State and effects

The pure client reducer uses these phases:

`NoCharacter -> Idle -> Saving -> SavedInactive -> ApplyPending -> Active`

Clear operations pass through `ClearPending`; rejected commands, invalid render assets, and unavailable required hooks enter `Faulted`. The reducer returns effects such as capture, persistence, network send, render, and clear. The client adapter performs those effects and feeds success or failure events back to the reducer.

Attachment visibility is a canonical four-key value object (`Hair`, `Beard`, `Moustache`, `FaceAttachment`) with `auto`, `hide`, and `show` states. The reducer updates it atomically. Active changes preview through `ApplyAttachmentVisibility`; persistence, network rejection, timeout, or renderer failure use explicit compensation effects to restore the previous whole policy.

`autoApply` represents activation intent, not merely the existence of a saved look. Save leaves it disabled, a successful render enables it, and clear/forget disable it. Character and scene cleanup may carry `preserveAutoApply` only when the outgoing look was active or already marked for reapplication, allowing the replacement character to render once after the initial-equipment gate without undoing a manual clear.

Server state is grouped per client session. Every accepted v2 command advances a server-owned revision. Commands include their base revision and operation ID, so retries are idempotent and stale apply requests cannot reactivate a look after clear or forget. A stable account keeps the current client-session dedupe cache across reconnects. Each cache retains at most 512 results; once full, unknown operations fail closed with a stable `operation_limit_reached` result until the client starts a new session. Revision exhaustion similarly rejects mutations with `revision_exhausted` instead of reusing `UInt32.MaxValue`.

In single-player, runtime state is keyed by `Character.Info.ID`, so changing the controlled Character or the UI-selected wardrobe target does not replace another crew member's state. The disk key is a stable fingerprint built from `OriginalName`, `SpeciesName`, and `HumanPrefabIds`; runtime entity IDs are never persisted. Fingerprint collisions fail closed for automatic restoration.

In multiplayer, protocol 5 retains player account looks and independent host-owned crew looks. A `CrewTargeting` hello capability enables the target-command channel whose entity ID is frozen when queued and revalidated by the server. Only living friendly human bots are accepted. Crew normal/diving profiles restore by campaign and crew identity; an active diving command owner prevents competing edits until disconnect or round cleanup.

Diving configuration is separate from normal reducer state. Capability `0x40` enables `diving` and authoritative `diving-save` commands through the same transport queue. Completion requires both ACK and the matching operation's diving state, in either arrival order. A new server epoch or round generation invalidates old diving settings; each character also has a monotonic revision. Entity waits are capped at 256 entries and expire after 30 seconds at 60 updates/second. Own settings register from local persistence after the initial-equipment gate. Bot settings persist in the host crew profile; runtime ownership is released on disconnect and generation-bound references are rebuilt on round changes. The older crew-only `0x10` messages retain their own codec and are translated into the same host profile.

Idle transports rotate at the existing 512-operation ceiling. A timeout releases controls after bounded retries of the same operation ID; manual resynchronization requests snapshots and retries local rendering, without replaying uncertain Save/Forget operations under a fresh ID.

At round start the client scans `Character.CharacterList` once, then follows `character.created`, `item.equip`, and `item.unequip` events. Each queued NPC waits for 12 stable equipment ticks, with a 120-tick fallback, before rebuilding its renderer session. The per-frame hook only processes this bounded queue; it does not scan the full crew list.

Multiplayer connection, round, and LuaCs `character.created` events continue to rebind active normal sessions to new Character entity IDs. A bounded event-triggered retry handles the assignment race during respawn. Pre-native equip/unequip hooks only mark characters dirty; the next update refreshes each character at most once from its final six-slot signature. A 60-update fallback visits only owned characters, removes stale references, and refreshes both cached sessions' equipment suppression sets. There is no per-frame full-client or full-inventory scan.

Diving checks run every six updates using native `Character.InPressure`. A custom asset signature depends on its saved look; suit-only signatures depend on the actual suit identifiers/colors. Transient capture failures use bounded backoff; known missing prefabs wait for changed settings, scene reload, or manual retry. Panel state updates reuse controls; structural/page/size changes rebuild on the next update, restoring page scroll after content construction.

## Renderer safety boundary

The renderer targets only the exact Barotrauma signatures recorded in [COMPATIBILITY.md](COMPATIBILITY.md). Required draw hooks fail closed; optional animation and sound hooks degrade independently.

Fashion sprites are initialized for the target character before use and are owned by a render session. A draw transaction may temporarily expose validated sprites to Barotrauma's official renderer, but it must snapshot and restore every changed collection or masking value in its finalizer. Cleanup never suppresses an exception from Barotrauma or another mod.

The normal and diving dictionaries own at most two committed `RenderSession` instances per character. The active dictionary only borrows the selected session. Capture stages a replacement separately and commits after validation. Pressure changes select a cached session, stop its predecessor's cosmetic loops/appendages, and preserve the latest normal session for restoration. Clear/Forget default to normal; lifecycle cleanup clears both. Typed delegates for draw, animation, and sound are bound after patch installation; footstep and drawing paths share cached limb candidates.

Functional-fashion filtering is composed directly as policy. It does not Harmony-patch private methods of this mod.

Conditional or required-item `StatusEffect` sounds are classified as gameplay alarms. They are excluded from fashion capture and real-equipment suppression so Barotrauma retains ownership of their start/stop lifecycle; reflection failure defaults to allowing the original sound.

## Persistence boundary

Only stable identifiers, optional packed sprite colors, and user intent are persisted. Runtime entity IDs and localized display names are never authoritative.

- Client: `ClientLook.json`, persistence schema 5.
- Single-player: `SinglePlayerProfiles.json`, schema 3. It stores the global transfer toggle, imported campaign hashes, campaign/character-scoped profiles, complete attachment visibility, and optional colors.
- Server: `ServerLooks.json`, persistence schema 5, keyed by stable `Client.AccountId` representation.
- Host crew: `ServerCrewLooks.json`, schema 2, stores independent normal/diving looks and normal activation intent.
- Diving: `DivingProfiles.json`, schema 1, using the existing hashed profile keys. Multiplayer bots never write these settings to disk.
- Anonymous clients: memory only for the current server session.

Local campaign save paths and stable character fingerprints are SHA-256 hashed before persistence. Host crew storage retains the existing campaign path and crew-identity format, including its legacy name fallback. A campaign-less single-player scene uses memory-only profiles. Legacy `ClientLook.json` data is imported once per campaign into the first controlled non-bot character and never overwrites an existing profile. Import preserves the captured look but deliberately clears auto-apply intent, because a legacy saved look is not consent to override a new campaign's starting equipment.

Wire look schema 4 and persistence schema 5 are separate constants. Each network slot carries its identifier, a color-presence bit, and an optional packed color; the optional marker/version/mask, movement, and footstep tail remains independent of persistence.

Writes use a same-directory temporary file and replacement/backup. Valid older client/server/profile files migrate with versioned backups. Missing legacy colors remain absent so Barotrauma uses each prefab's base color. Corrupt files are quarantined instead of being applied.

Normal/diving profile getters cache only validated read-only documents, keyed by path, length, and last-write timestamp. Mutations read fresh documents and invalidate the cache before atomic writing. Read failures are never cached as successful empty documents. Same-size external edits that deliberately preserve the timestamp require a reload; there is no background file watcher. Client detail logs default off; bounded client rotation and server in-memory log contents avoid rereading the complete log on every message.

## Packaging

LuaCs compiles client C# from source through `ModConfig.xml`. Release packages therefore contain source only. `bin`, `obj`, `artifacts`, disabled binaries, runtime persistence files, and game assemblies are never package inputs.
