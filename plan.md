# Tribal Quest / Fortress Shared Engine Contract

Last updated: 2026-05-29

## Canonical Shape

Tribal Quest is the adventurer Coworld game. Tribal Fortress is the shared world
engine and fortress/town Coworld game.

- Fortress owns the authoritative grid simulation.
- Quest owns its public `/player` adventurer route.
- Fortress `/player` remains town/fortress/civilization control.
- Quest `/player` claims one adventurer in the Fortress world.
- There is no Quest local simulation fallback.
- There is no production `/adventure` route.
- There is no Python bridge in the Quest runtime path.

The integration is Nim-to-Nim for performance and simplicity.

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

proc initFortressEngine*(config: FortressEngineConfig): FortressEngine
proc close*(engine: var FortressEngine)
proc claimAdventurer*(engine: var FortressEngine, slot: int, teamId = -1): int
proc releaseAdventurer*(engine: var FortressEngine, slot: int): bool
proc submitAdventurerButtons*(engine: var FortressEngine, slot: int, mask: uint8)
proc submitAdventurerAction*(engine: var FortressEngine, slot: int, action: uint16)
proc submitAdventurerInput*(engine: var FortressEngine, slot: int, payloadJson: string)
proc step*(engine: var FortressEngine)
proc adventurerViewCells*(engine: FortressEngine, slot: int, cells: var openArray[uint8]): FortressAdventurerView
proc adventurerObservationJson*(engine: FortressEngine, slot: int): string
```

That API owns worldgen, terrain, civilizations, NPC policies, claim tracking,
action decoding, stepping, and local crop export.
Quest should use the typed button and crop APIs in its live tick loop. The JSON
input and observation APIs are compatibility/debug surfaces, not the hot path.

## Quest Must Provide

Quest imports `tribal_village_engine`, starts the engine, and wraps it with its
own Coworld `/player` route.

Quest is responsible for:

- token-to-adventurer-slot binding
- websocket lifecycle for `/player`
- forwarding player input masks to the typed engine button API
- rendering or adapting the adventurer-centered view
- Quest scoring and replay output
- Quest-specific docs and future reference bots

The current Quest surface code lives in `src/tribal_quest/player_surface.nim`.
It consumes typed `adventurerViewCells` crops and packs them into the existing
BitWorld 128 x 128 player frame protocol without JSON in the tick loop.

Quest should not duplicate Fortress world simulation code.

## Action Contract

Quest forwards player input as button masks through `submitAdventurerButtons`.
The JSON compatibility form is:

```json
{"type":"adventurer.buttons","buttons":33}
```

Button bits match BitWorld:

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

## Defaults

- world runtime: `fortress`
- world size: `768 x 480`
- town agents per team: `30`
- adventurer slots: `64`
- Quest tactical crop: `11 x 11`
- default adventurer role: `adventurer`

## Validation

Quest-side checks:

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim r --path:../src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH tests/tests.nim
TRIBAL_FORTRESS_PATH=${TRIBAL_FORTRESS_PATH:-$(pwd)/../coworld-tribal-fortress}
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH --path:$TRIBAL_FORTRESS_PATH/src -o:out/tribal_quest src/tribal_quest.nim
git diff --check
```

If `tribal_village_engine` is missing from the Fortress checkout, the build
should fail immediately on that import. Do not revive local Quest simulation or
add a Python bridge to make it pass.
