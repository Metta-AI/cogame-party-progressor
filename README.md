# Tribal Quest

Cooperative Coworld expedition RPG where players choose tank, DPS, or healer
roles, fight biome-specific monsters, rescue villagers, gather supplies, and
push an endless party frontier to the right.

Tribal Quest uses the BitWorld sprite protocol on the canonical `/player`
and `/global` websocket routes. The browser player client is served at
`/client/player`, and the global bird's-eye observer is served at
`/client/global`.

Tribal Quest is also preparing to run as an adventurer-centric client for
`coworld-tribal-fortress`. That integration is intentionally Quest-side only in
this repo: Fortress owns the large grid world and will expose
`WEBSOCKET /adventure`, while Quest translates its controls, bots, and local
view into that API. The Quest viewport stays a tight 11 by 11 tactical crop
even when Fortress runs a much larger world.

## Running

```sh
nimble install -d
nimble build
./tribal_quest --address:0.0.0.0 --port:8080
```

Open:

- `http://localhost:8080/client/player?address=ws://localhost:8080/player&name=human`
- `http://localhost:8080/client/global?address=ws://localhost:8080/global`
- `http://localhost:8080/debug/ascii`

For local source-checkout work without installing the package:

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/tribal_quest src/tribal_quest.nim
./out/tribal_quest --address:127.0.0.1 --port:2000
```

## Bot

The bundled Nim bot is `konrad`.

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/tribal_quest_konrad players/konrad/konrad.nim
./out/tribal_quest_konrad --address:127.0.0.1 --port:2000 --name=konrad
```

JavaScript, Python, and Go ports of Konrad live under `players/`.

## Fortress Adventure API

The future Fortress adapter contract is implemented in
`src/tribal_quest/adventure_api.nim`. It does not change the current local
simulation server; it provides the stable Quest-side pieces needed while
Fortress implements its matching endpoint in parallel:

- builds `WEBSOCKET /adventure?slot=<n>&token=<token>&name=<name>&role=<role>`
  URLs
- caps Quest adventurer slots at 64
- converts BitWorld button masks into JSON `adventure.input` messages
- preserves Quest's 11 by 11 adventurer crop rather than requesting the full
  Fortress map
- parses the stable fields Quest needs from one Fortress adventure tick

Optional config fields are accepted for the future adapter:

```json
{
  "fortressAdventureUrl": "ws://localhost:8080",
  "adventurerTokens": ["slot-0-token"],
  "adventurerRole": "adventurer"
}
```

## Debugging

`/debug/ascii` is the agent-readable render oracle. It prints the current
11 by 11 player observation, terrain glyphs, occlusion, entities, HP, mana,
cooldowns, role, biome, weather, and effect state.

## Project Layout

- `src/tribal_quest.nim` starts the Coworld server.
- `src/tribal_quest/` contains the simulation, sprite renderer, and server.
- `data/` contains game sprites and generated monster assets.
- `players/` contains bundled player bots.
- `tests/tests.nim` contains the focused gameplay and sprite protocol checks.
- `FULL_GAME_PLAN.md` records current state and near-term product direction.
