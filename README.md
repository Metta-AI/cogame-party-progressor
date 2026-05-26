# Party Progressor

Cooperative Coworld expedition RPG where players choose tank, DPS, or healer
roles, fight biome-specific monsters, rescue villagers, gather supplies, and
push an endless party frontier to the right.

Party Progressor uses the BitWorld sprite protocol on the canonical `/player`
and `/global` websocket routes. The browser player client is served at
`/client/player`, and the global bird's-eye observer is served at
`/client/global`.

## Running

```sh
nimble install -d
nimble build
./party_progressor --address:0.0.0.0 --port:8080
```

Open:

- `http://localhost:8080/client/player?address=ws://localhost:8080/player&name=human`
- `http://localhost:8080/client/global?address=ws://localhost:8080/global`
- `http://localhost:8080/debug/ascii`

For local source-checkout work without installing the package:

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/party_progressor src/party_progressor.nim
./out/party_progressor --address:127.0.0.1 --port:2000
```

## Bot

The bundled Nim bot is `konrad`.

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
nim c --path:src --path:$BITWORLD_PATH/src --path:$BITWORLD_PATH -o:out/party_progressor_konrad players/konrad/konrad.nim
./out/party_progressor_konrad --address:127.0.0.1 --port:2000 --name=konrad
```

JavaScript, Python, and Go ports of Konrad live under `players/`.

## Debugging

`/debug/ascii` is the agent-readable render oracle. It prints the current
11 by 11 player observation, terrain glyphs, occlusion, entities, HP, mana,
cooldowns, role, biome, weather, and effect state.

## Project Layout

- `src/party_progressor.nim` starts the Coworld server.
- `src/party_progressor/` contains the simulation, sprite renderer, and server.
- `data/` contains game sprites and generated monster assets.
- `players/` contains bundled player bots.
- `tests/tests.nim` contains the focused gameplay and sprite protocol checks.
- `FULL_GAME_PLAN.md` records current state and near-term product direction.
