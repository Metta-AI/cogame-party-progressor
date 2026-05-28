# Tribal Quest on Fortress Adventure API Plan

Last updated: 2026-05-28

## Summary

Make `coworld-tribal-fortress` the authoritative grid/world simulation, and
turn `coworld-tribal-quest` into an adventure-focused consumer that inserts
adventurers into a running Fortress server.

Quest should keep the adventurer experience, player client, default adventure
configuration, bots, story flavor, and scoring. Fortress should own the large
shared world, civilizations, elevation, towns, NPCs, combat, fog, tint, replay,
and runtime protocols.

The intended end state is similar to adventure mode in Dwarf Fortress: a player
walks one adventurer through a sprawling active Fortress world while towns,
civilizations, monsters, goblin hives, camps, lairs, and relic objectives
continue to exist around them.

## Shared Runtime Contract

- Fortress remains the canonical world server.
- Quest connects to Fortress through a new `WEBSOCKET /adventure` endpoint.
- Do not overload Fortress's existing `/player` endpoint. `/player` remains the
  town-overseer protocol.
- Do not add a `player_mode=adventure` switch for v1. Quest should be able to
  attach adventurers to the same running Fortress server that still supports
  town overseers.
- Fortress config should add `adventurer_tokens`, with up to 64 adventurer
  slots, while preserving the existing 8 town `tokens`.
- Fortress should keep BuiltinAI active for towns and NPCs, then overlay
  externally supplied actions only for claimed adventurer agents before each
  step.

The `/adventure` connection should use:

```text
WEBSOCKET /adventure?slot=<n>&token=<token>&name=<name>&role=<role>
```

Fortress should send per-tick JSON with:

- adventurer agent id
- team and civilization
- position
- health and status
- inventory or held item state
- existing 11x11 observation tensor
- local `tribalcog-view-plane-v1` crop with `origin_x` and `origin_y`
- nearby towns, camps, lairs, relics, enemies, and interactable objects when
  available

Fortress should accept both raw Fortress actions and BitWorld-style button
masks. D-pad maps to movement, `A` maps to attack facing, and `B` maps to use
facing. Raw Fortress actions take precedence when both are supplied.

## Fortress World Work

The first Fortress implementation should use a larger fixed map rather than
chunked storage:

- first target: `MapWidth = 384`, `MapHeight = 240`
- town cap: `MapAgentsPerTeam = 30`
- adventure cap: `MapAdventurerSlots = 64`
- stretch target after profiling: `768 x 480`

Add an explicit `CivilizationKind` model with these initial values:

- `Human`
- `Elf`
- `Dwarf`
- `Orc`
- `Goblin`

Humans should keep the current baseline town behavior. For v1, other
civilizations should at least have stable metadata, settlement identity, and
worldgen hooks. Civ-specific balance and deep behavior differences can follow
after the attachment path is stable.

Initial civilization direction:

- Elves live in forest settlements with tree houses, high platforms, bridges,
  and drawbridges.
- Dwarves live in mountains, mine, tunnel, and build smithies.
- Orcs build surface strongholds and direct or amplify nearby goblin raids.
- Goblins spawn readily as hostile hives, camps, patrols, and raiders. Goblins
  can become playable later, but hostile goblin ecology should come first.
- Humans remain the stable default civilization and compatibility baseline.

Make the existing elevation concept explicit and consistent:

- low
- base
- high

Movement should use ramps, roads, bridges, drawbridges, and tunnels to cross
elevation boundaries. Visibility should respect higher ground and obscured
tiles. This should support elven tree houses and dwarf mountain settlements
without introducing a full 3D engine.

## Tribal Quest Migration

After Fortress exposes `/adventure`, change Quest from a standalone world
simulation into a Fortress adventure consumer.

The first Quest migration should:

- keep the Quest player-facing adventure client and bots
- connect to Fortress `/adventure`
- translate Quest movement/ability controls into Fortress adventure input
- render the Fortress local view crop and adventurer state
- keep Quest-specific story, role defaults, scoring, docs, and reference bots
- stop owning duplicated terrain/world simulation once the Fortress-backed path
  works

Quest may continue using BitWorld helpers internally for its client and bot
code, but Fortress should not serve the old BitWorld binary sprite protocol in
v1. Quest should adapt Fortress JSON/view-plane data to whatever local client
shape it needs.

## Quest Mechanics To Share Upstream

Port useful Tribal Quest mechanics into Fortress as reusable world systems only
after the attachment path is stable. They should enrich the shared Fortress
world rather than recreate the current Quest route as a sidecar.

Initial candidates:

- adventurer roles and civilization-specific specialists
- mana or ability energy for adventurer powers and special units
- camps as outposts, shelters, staging sites, or civilization structures
- lairs as hostile spawn structures with pacification or reward states
- relic chains as exploration objectives tied into Fortress relic and victory
  systems

## Pull Request Breakdown

Suggested PR sequence:

1. Fortress `/adventure` runtime foundation.
2. Fortress larger fixed world, population cap, region export, and global-view
   throttling.
3. Fortress civilization and elevation foundation.
4. Tribal Quest `/adventure` consumer migration.
5. Shared camps, lairs, relic chains, roles, and mana systems.

The first Fortress PR should stay focused on the runtime contract:
adventurer slots, direct adventurer control, hybrid action override, local view
crops, and backwards-compatible town `/player`.

## Test Plan

Fortress validation:

```sh
make check
timeout 15s nim r -d:release --path:src tribal_village.nim
make test-nim
```

Add targeted Fortress tests for:

- `/player` preserving current town commands and observations
- `/adventure` auth and duplicate slot handling
- one direct adventurer per connected adventure slot
- direct movement, attack, and use commands
- hybrid stepping where AI controls non-adventurers and player input overrides
  only assigned adventurers
- local crop origins and payload shape
- civilization assignment and world-generation invariants
- low/base/high elevation traversal and visibility

Tribal Quest validation after migration:

```sh
git diff --check
```

Then smoke the Quest adapter against the Fortress runtime:

- local Fortress server starts
- Quest connects to `/adventure`
- `/client/global` opens the Fortress world view
- a player can move the adventurer
- towns and NPCs continue acting while the player moves
- bundled reference bots still run or are intentionally replaced

## Assumptions

- Fortress remains backwards compatible by preserving `/player` for town
  overseers.
- Quest uses the new Fortress `/adventure` API rather than requiring a
  `player_mode=adventure` server mode.
- Adventure mode uses Fortress JSON/view-plane protocols, not the old BitWorld
  binary sprite protocol.
- Quest mechanics are upstreamed into Fortress after the attachment path works,
  not before.
- A Nimble package extraction is optional follow-up work, not a blocker for the
  first shared-runtime milestone.
