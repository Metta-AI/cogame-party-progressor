# Tribal Quest on Shared Fortress Engine Plan

Last updated: 2026-05-29

## Summary

Make the Fortress grid/world simulation the shared engine underneath both
games, then expose different Coworld game surfaces on top of it.

`coworld-tribal-fortress` remains the fortress and civilization-control game:
its public `/player` route controls towns, fortresses, and broader settlement
strategy. `coworld-tribal-quest` becomes the adventurer-control game: its
public `/player` route controls one adventurer walking through that same kind
of world while fortresses, civilizations, monsters, goblin hives, camps, lairs,
and relic objectives keep simulating around them.

The intended end state is still similar to adventure mode in Dwarf Fortress,
but the integration should be an engine split rather than a permanent Quest
sidecar attached to a special public Fortress route. Quest should stay a
standalone Coworld game repo with its own client, bots, story flavor, scoring,
and adventurer-centered viewport while sharing the world runtime and mechanics
with Fortress.

## Runtime Boundary

The long-term boundary should be a shared Fortress engine plus thin Coworld
surfaces:

- shared engine: world state, step loop, terrain, entities, civilizations,
  elevation, towns, NPCs, combat, fog, tint, replay, objective hooks, local view
  crops, and control-profile routing
- Fortress surface: town/fortress/civilization control using the larger
  strategic viewport
- Quest surface: adventurer control using the adventurer-centered tactical
  viewport

Each standalone game should keep a normal Coworld `/player` route. The meaning
of `/player` is selected by the game package:

- in Fortress, `/player` binds to a town or fortress controller
- in Quest, `/player` binds to an adventurer controller
- unclaimed towns, wilderness actors, monsters, and background adventurers run
  through built-in NPC policies

The engine should distinguish these control profiles explicitly:

- `TownController`: player commands a town, fortress, or civilization slice
- `Adventurer`: player commands one adventurer agent in the broader world
- `Npc`: built-in AI controls the agent, settlement, monster, or wilderness
  actor

The current Fortress-side `/adventure` work is useful as a reference for the
adventurer observation/action shape, but Quest should not consume it as a
separate runtime protocol. Quest should own its public `/player` route and wire
that route directly to the installed Fortress engine/runtime APIs.

## Shared Engine Contract

The shared engine should support both town-scale and adventurer-scale control
without running two independent simulations side by side.

Core requirements:

- one authoritative grid/world state
- explicit ownership or control metadata for every controllable agent
- built-in AI stays active for all `Npc` actors
- externally supplied actions override AI only for claimed player-controlled
  agents
- town controllers and adventurers can coexist in the same world model
- local crop export supports small adventurer views without exposing the full
  strategic map every tick
- replay and scoring can identify which control profile produced each action

Initial player-facing surfaces:

- Fortress `/player`: town-overseer protocol, preserved for compatibility
- Quest `/player`: adventurer protocol, backed by the shared engine

Do not add a second Quest-facing `/adventure` route and do not require Quest to
proxy to Fortress over a separate WebSocket. The Quest server should translate
Coworld `/player` input into adventurer engine actions in-process or through a
local engine adapter owned by this repo.

The adventurer observation should keep the current Quest tactical shape by
default:

- existing 11 x 11 observation tensor
- local `tribalcog-view-plane-v1` crop with `origin_x` and `origin_y`
- adventurer agent id, team, civilization, position, health, status, inventory,
  role, nearby towns, camps, lairs, relics, enemies, and interactable objects
  when available

Quest can adapt that crop to its current 128 x 128 BitWorld screen path while
the shared engine remains tile/grid based. Adventurer clients should not receive
the full Fortress world every tick.

The adventurer action adapter should accept Quest's current button-mask style
and map it into engine actions:

- D-pad maps to movement
- `A` maps to attack facing
- `B` maps to use/interact facing
- role powers and mana actions map to explicit adventurer abilities as they are
  upstreamed

The payload and control semantics can be modeled after Fortress's current
adventurer work: raw engine actions are useful for tests and debugging, and
button masks remain the compatibility layer for existing Quest clients and
bots.

## Fortress Dependency And Install Shape

Quest should explicitly install and depend on the Fortress codebase once the
Fortress-side plan is implemented. The first local integration should support a
sibling checkout:

```sh
TRIBAL_FORTRESS_PATH=${TRIBAL_FORTRESS_PATH:-$(pwd)/../coworld-tribal-fortress}
```

That path dependency should be replaced by a pinned package or Git dependency
after Fortress extracts the shared engine cleanly.

Quest owns the adapter layer that turns Fortress engine state into the Quest
Coworld player surface:

- start or construct the Fortress engine/world runtime from Quest
- configure it for the large world, NPC fortresses, civilizations, elevation,
  camps, lairs, and adventurer slots
- spawn or bind one adventurer per Quest `/player` slot
- keep Fortress town/civilization agents under engine-owned NPC policies
- translate Quest button masks, role powers, and chat/control metadata into
  adventurer engine actions
- render Quest's adventurer-centered view from Fortress `view_plane`,
  `sprite_view`, observation, and agent-state data
- write Quest scores/replays from the adventurer perspective

The adapter should reuse Fortress global and environment state directly where
possible. Quest should avoid duplicating worldgen, terrain storage, civilization
state, NPC stepping, or global map export once those are available from the
installed Fortress engine.

## World And Civilizations

The first shared-engine implementation can keep a larger fixed map rather than
chunked storage:

- first target: `MapWidth = 768`, `MapHeight = 480`
- town cap: `MapAgentsPerTeam = 30`
- adventure cap: `MapAdventurerSlots = 64`
- Fortress view: larger strategic viewport for town and civilization play
- Quest view: local adventurer-centered crop, not the full map

Add an explicit `CivilizationKind` model with these initial values:

- `Human`
- `Elf`
- `Dwarf`
- `Orc`
- `Goblin`

Humans should keep the current baseline town behavior. For v1, other
civilizations should at least have stable metadata, settlement identity, and
worldgen hooks. Civ-specific balance and deep behavior differences can follow
after the shared control path is stable.

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
tiles. This supports elven tree houses and dwarf mountain settlements without
introducing a full 3D engine.

## Tribal Quest Migration

Quest should prepare to run on the shared Fortress engine with an
adventurer-control surface. It should not permanently own duplicated
terrain/world simulation once the engine-backed path works.

The first Quest migration should:

- keep the Quest player-facing adventure client and bundled bots
- keep Quest's public Coworld player entrypoint as `/player`
- install and launch the shared Fortress engine through a local/package
  dependency, not a separate public adventure socket
- launch the engine with an `Adventurer` control profile for Quest players
- bind each Quest player token to one adventurer agent
- keep towns, fortresses, wilderness actors, and hostile groups running under
  `Npc` policies unless explicitly claimed by another surface
- translate Quest movement and ability controls into shared-engine adventurer
  input
- render the shared-engine local view crop and adventurer state
- keep Quest-specific story, role defaults, scoring, docs, and reference bots

Quest should treat the older Party Progressor loop as the product reference:
one or more adventurers moving through a dangerous world, making forward
progress, gathering resources, using roles, and surviving encounters. The world
source changes from Quest's local route simulation to the installed Fortress
engine, but the player-facing mode remains Quest-owned adventurer play.

Quest may continue using BitWorld helpers internally for its client and bot
code, but the shared engine should not need to serve the old BitWorld binary
sprite protocol. Quest should adapt engine JSON/view-plane data to whatever
local client shape it needs.

## Quest Mechanics To Share Upstream

Port useful Tribal Quest mechanics into the shared engine as reusable world
systems after the control-profile path is stable. They should enrich both game
surfaces rather than recreate the current Quest route as a sidecar.

Initial candidates:

- adventurer roles and civilization-specific specialists
- mana or ability energy for adventurer powers and special units
- camps as outposts, shelters, staging sites, or civilization structures
- lairs as hostile spawn structures with pacification or reward states
- relic chains as exploration objectives tied into Fortress relic and victory
  systems

Keep Quest-specific presentation, default role tuning, scoring, player bot
contracts, and adventurer route flavor in this repo unless they clearly belong
in the shared engine.

## Pull Request Breakdown

Suggested cross-repo sequence:

1. Fortress factors world simulation and control ownership away from the
   town-controller server surface.
2. Fortress/shared engine adds `TownController`, `Adventurer`, and `Npc`
   control profiles with hybrid AI/player action overlay.
3. Fortress preserves `/player` as the town/fortress-control game surface and
   expands the strategic viewport for fortress play.
4. Quest adds a path/package dependency on the Fortress engine and a small
   adapter that starts a large NPC-fortress world locally.
5. Quest keeps `/player` as its public adventurer route, modeled after the
   useful parts of Fortress's current adventurer control semantics.
6. Quest migrates controls, observations, bots, scoring, and adventurer UI to
   the shared-engine crop/action contract.
7. Shared camps, lairs, relic chains, roles, mana, civilization depth, and
   elevation mechanics move upstream after the attachment path works.

If Fortress keeps a `/adventure` endpoint for its own debugging, Quest may use
its schema as a reference, but the Quest implementation should not be a socket
proxy. The production Quest route remains `/player`.

## Test Plan

Quest validation before pushing plan or migration changes:

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim r --path:../src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH tests/tests.nim
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/tribal_quest src/tribal_quest.nim
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/tribal_quest_konrad players/konrad/konrad.nim
node --check players/js_konrad/konrad.js
python3 -m py_compile players/py_konrad/konrad.py scripts/prepare_monster_assets.py
git diff --check
```

Shared engine contract tests to add once implementation starts:

- `TownController` input affects only the assigned town/fortress/civilization
  slice
- `Adventurer` input affects only the bound adventurer
- `Npc` towns and wilderness actors continue ticking while an adventurer player
  is connected
- player action overlay does not disable BuiltinAI for unclaimed actors
- local crop origins and payload shape match the adventurer-centered contract
- Quest button masks map to shared-engine movement, attack, use, and role
  abilities
- replay rows preserve control profile, agent id, and player-token ownership

Surface-specific smoke tests:

- Fortress `/player` still behaves as town/fortress control
- Fortress strategic viewport can be larger than Quest's tactical viewport
- Quest can start with `TRIBAL_FORTRESS_PATH` pointing at a sibling Fortress
  checkout
- Quest `/player` spawns or resumes an adventurer
- Quest renders an adventurer-centered crop
- NPC fortresses continue acting while the Quest player moves
- bundled Quest JS, Python, and Nim bots still connect through Quest's public
  route or are intentionally updated with documented contract changes

## Assumptions

- Fortress is the likely home for the extracted shared engine because it owns
  the larger world simulation work.
- This repo should not edit Fortress while Fortress work is happening in
  parallel.
- Quest's final public player route should be `/player`, not `/adventure`.
- Quest should not depend on a separate public `/adventure` protocol. Existing
  Fortress adventurer code is a design reference, not the Quest runtime
  boundary.
- Quest keeps its adventurer-centric viewport while Fortress uses a larger
  fortress/civilization viewport.
- Adventure mode uses shared-engine JSON/view-plane protocols, not the old
  BitWorld binary sprite protocol.
- A package or Git dependency extraction is useful follow-up work, but it is not
  a blocker for documenting or starting the shared-runtime migration.
