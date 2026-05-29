# Tribal Quest

Tribal Quest is the adventurer Coworld surface for the shared Tribal Fortress
world. [plan.md](plan.md) is the canonical contract for the integration.

There is no supported local Quest simulation mode anymore. `worldRuntime` is
always `fortress`, and missing Fortress Nim engine code should fail at build or
startup instead of falling back to an old route. There is no Python bridge and
no production `/adventure` route.

## Running

Use a sibling Fortress checkout while the shared runtime is local:

```sh
BITWORLD_PATH=${BITWORLD_PATH:-$(pwd)/../bitworld}
TRIBAL_FORTRESS_PATH=${TRIBAL_FORTRESS_PATH:-$(pwd)/../coworld-tribal-fortress}
nim c \
  --path:src \
  --path:$BITWORLD_PATH/src \
  --path:$BITWORLD_PATH \
  --path:$TRIBAL_FORTRESS_PATH/src \
  -o:out/tribal_quest \
  src/tribal_quest.nim
./out/tribal_quest --address:127.0.0.1 --port:2000 --fortress-engine-path:$TRIBAL_FORTRESS_PATH
```

Open:

- `http://localhost:2000/client/player?address=ws://localhost:2000/player&name=human`

Or run the bundled Nim adventurer pilot against the same `/player` route:

```sh
nim c \
  --path:src \
  --path:$BITWORLD_PATH/src \
  --path:$BITWORLD_PATH \
  -o:out/tribal_quest_adventurer \
  players/adventurer/adventurer.nim
./out/tribal_quest_adventurer --address:127.0.0.1 --port:2000 --slot:0 --ticks:80
```

Quest expects the Fortress checkout on the Nim path to expose
`tribal_village_engine`. Quest calls that Nim engine directly from its own
`/player` server.

Optional config fields:

```json
{
  "worldRuntime": "fortress",
  "fortressEnginePath": "../coworld-tribal-fortress",
  "adventurerRole": "adventurer"
}
```

## Fortress Adapter

`src/tribal_quest/fortress_engine.nim` keeps the Quest-owned adapter contract:

- validates that only `worldRuntime = fortress` is accepted
- discovers `TRIBAL_FORTRESS_PATH` or `../coworld-tribal-fortress`
- targets a 768 by 480 Fortress world with 30 town agents per team
- caps Quest adventurer slots at 64
- forwards button masks through the typed Fortress engine API
- packs typed local crop cells into BitWorld frames without JSON in the tick loop

The old Party Progressor mechanics are now product reference material for what
should move into the Fortress engine or Quest adventurer presentation. They are
not a second runtime in this repo.

## Project Layout

- `src/tribal_quest.nim` starts the Quest `/player` surface on Fortress.
- `src/tribal_quest/player_surface.nim` owns the Quest `/player` websocket and
  packs Fortress adventurer crops into BitWorld frames.
- `src/tribal_quest/fortress_engine.nim` contains the Quest-side adapter
  contract.
- `players/adventurer/adventurer.nim` is the bundled Nim websocket pilot.
- `plan.md` is the integration source of truth for the Quest half.
- `tests/tests.nim` contains lean adapter-contract checks.
