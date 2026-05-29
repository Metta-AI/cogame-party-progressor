# Tribal Quest / Fortress Shared Engine Contract

Last updated: 2026-05-29

## Canonical Shape

Tribal Quest is the adventurer Coworld game. Tribal Fortress is the shared world
engine and fortress/town Coworld game.

- A single world host owns one authoritative `FortressEngine` instance.
- Quest owns its public `/player` adventurer route.
- Fortress `/player` remains town/fortress/civilization control.
- Quest `/player` claims one adventurer in that already-created Fortress world.
- There is no Quest local simulation fallback.
- There is no production `/adventure` route.
- There is no Python bridge in the Quest runtime path.
- There is no second Quest engine when Quest is mounted into a shared host.

The integration is Nim-to-Nim for performance and simplicity. The standalone
`src/tribal_quest.nim` executable is a development host: it creates a Fortress
engine only because no external host is present. The integrated shape is a
host-created engine with the Quest adventurer surface installed on top of that
same engine object.

## Fortress Must Provide

Quest expects `TRIBAL_FORTRESS_PATH/src` to expose a Nim module named
`tribal_village_engine`.

The module should provide a small API:

```nim
type
  FortressEngineConfig* = object
    maxSteps*: int
    seed*: int
    adventurerViewRadius*: int
    aiMode*: string
    worldWidth*: int
    worldHeight*: int
    townAgentsPerTeam*: int
    adventurerSlots*: int

  FortressEngine* = object

  FortressAdventurerView* = object
    ok*: bool
    done*: bool
    slot*: int
    agentId*: int
    teamId*: int
    x*: int
    y*: int
    hp*: int
    maxHp*: int
    originX*: int
    originY*: int
    width*: int
    height*: int

proc initFortressEngine*(config: FortressEngineConfig): FortressEngine
proc close*(engine: var FortressEngine)
proc claimAdventurer*(engine: var FortressEngine, slot: int, teamId = -1): int
proc releaseAdventurer*(engine: var FortressEngine, slot: int): bool
proc submitAdventurerButtons*(engine: var FortressEngine, slot: int, mask: uint8)
proc submitAdventurerAction*(engine: var FortressEngine, slot: int, action: uint16)
proc submitAdventurerInput*(engine: var FortressEngine, slot: int, payloadJson: string)
proc step*(engine: var FortressEngine)
proc adventurerViewCells*(engine: var FortressEngine, slot: int, cells: var openArray[uint8]): FortressAdventurerView
proc adventurerObservationJson*(engine: FortressEngine, slot: int): string
```

That API owns worldgen, terrain, civilizations, NPC policies, claim tracking,
action decoding, stepping, and local crop export.
Quest should use the typed button and crop APIs in its live tick loop. The JSON
input and observation APIs are compatibility/debug surfaces, not the hot path.

## Quest Must Provide

Quest imports `tribal_village_engine` and provides an adventurer surface that
can be installed onto a host-owned engine. In a Quest-only development run,
Quest may create the engine first and then install the same surface.

Quest is responsible for:

- token-to-adventurer-slot binding
- websocket lifecycle for `/player`
- forwarding player input masks to the typed engine button API
- rendering the adventurer-centered gridworld sprite view
- Quest scoring and replay output
- Quest-specific docs and future reference bots

The current Quest surface code lives in `src/tribal_quest/player_surface.nim`.
It consumes the shared Fortress grid state and sends `sprite_v1` packets for
`/client/player` through Quest's vendored player client. Terrain, resources,
buildings, units, wildlife, and hostile entities are rendered as grid objects
using the shared Fortress data asset keys. The old 128 x 128 packed-pixel
protocol is retained only as `protocol=pixel` debug compatibility and
`/client/pixel`.

Quest should not duplicate Fortress world simulation code.

The mountable surface API is:

```nim
proc initQuestAdventurerSurface(engine: var FortressEngine, tokens: seq[string])
proc handleQuestAdventurerHttp(request: Request): bool
proc handleQuestAdventurerWebSocket(websocket: WebSocket, event: WebSocketEvent, message: Message)
proc submitQuestAdventurerInputs()
proc buildQuestAdventurerFrames(): seq[QuestPlayerFrame]
proc sendQuestAdventurerFrames(frames: openArray[QuestPlayerFrame])
proc tickQuestAdventurerSurface(): int
```

A combined host should run the flat shared-world tick as:

```nim
initQuestAdventurerSurface(engine, tokens)

while running:
  submitQuestAdventurerInputs()
  # Other Fortress town/civ surfaces submit their inputs here.
  engine.step()
  sendQuestAdventurerFrames(buildQuestAdventurerFrames())
```

`tickQuestAdventurerSurface` is only the Quest-only convenience path. It submits
Quest inputs, steps the engine, and sends Quest frames in one call.

## Action Contract

Quest forwards player input as button masks through `submitAdventurerButtons`.
The canonical sprite client sends the `sprite_v1` player input packet:

```text
0x84 <button-mask>
```

The JSON compatibility form is:

```json
{"type":"adventurer.buttons","buttons":33}
```

Button bits are Quest's vendored player mask contract, kept compatible with the
historic Coworld/BitWorld values:

- `up = 1`
- `down = 2`
- `left = 4`
- `right = 8`
- `a = 32`
- `b = 64`

Tests may send raw engine actions:

```json
{"type":"adventurer.action","action":28}
```

Fortress owns decoding masks into move, attack, use, and future role abilities.

## Observation Contract

`adventurerObservationJson(engine, slot)` returns a JSON object with stable
fields Quest can parse:

- `type = "engine.adventurer_observation"`
- `control_profile = "Adventurer"`
- `slot`
- `agent_id`
- `team_id`
- `civilization`
- `position`
- `hp`
- `max_hp`
- `done`
- `view_plane`
- `sprite_view`
- `observation`

`view_plane` and `sprite_view` are local adventurer-centered crops. They are not
full-map payloads.

## Rendering Contract

Quest `/client/player` is the adventurer gridworld view:

- protocol: `sprite_v1`
- crop: `21 x 21` tiles centered on the claimed adventurer
- tile size: `16 x 16` pixels
- viewport: `336 x 336` pixels
- layers: map layer first, optional UI/status layers later
- asset source: Fortress `data/` using registry-compatible sprite keys

Missing assets must produce visible placeholder sprites with stable labels.
Invalid, dormant, or dead adventurer states must render a visible status frame,
not an all-black canvas.

Quest-only art should be limited to adventurer presentation overlays such as
selection rings, target cursors, and status markers. Old Party Progressor
assets and mechanics should be incorporated as shared Fortress grid assets,
entities, enemies, terrain features, items, and engine actions rather than as a
parallel Quest simulation.

## Defaults

- world runtime: `fortress`
- world size: `768 x 480`
- town agents per team: `30`
- adventurer slots: `64`
- Quest adventurer crop: `21 x 21`
- Quest sprite tile size: `16 px`
- default adventurer role: `adventurer`

## Validation

Quest-side checks:

```sh
nim r --path:src tests/tests.nim
TRIBAL_FORTRESS_PATH=${TRIBAL_FORTRESS_PATH:-$(pwd)/../coworld-tribal-fortress}
nim c --path:src --path:$TRIBAL_FORTRESS_PATH/src -o:out/tribal_quest src/tribal_quest.nim
git diff --check
```

If `tribal_village_engine` is missing from the Fortress checkout, the build
should fail immediately on that import. Do not revive local Quest simulation or
add a Python bridge to make it pass.
