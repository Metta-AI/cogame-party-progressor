# Tribal Quest

Tribal Quest is the adventurer Coworld surface for the shared Tribal Fortress
world. [plan.md](plan.md) is the canonical contract for the integration.

There is no supported local Quest simulation mode anymore. `worldRuntime` is
always `fortress`, and missing Fortress Nim engine code should fail at build or
startup instead of falling back to an old route. There is no Python bridge and
no production `/adventure` route.

The intended integrated runtime has one host-owned `FortressEngine` world.
Quest installs its adventurer `/player` surface onto that existing engine and
does not create a second world. The standalone binary below is only the
Quest-only development host for exercising the same surface before a combined
Fortress host imports it.

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

- `http://127.0.0.1:2000/client/player?slot=0&name=human&reconnect=2`

`/client/player` is the canonical sprite-based adventurer gridworld view. It
uses the shared Fortress terrain/entity state and renders BitWorld `sprite_v1`
packets centered on the controlled adventurer.

The old packed-pixel stream is debug compatibility only:

- `http://127.0.0.1:2000/client/pixel?slot=0&name=human&reconnect=2`

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
`src/tribal_village_engine.nim`. Quest calls that Nim engine directly from the
adventurer surface.

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
- fails fast unless that checkout exposes `src/tribal_village_engine.nim`
- targets a 768 by 480 Fortress world with 30 town agents per team
- caps Quest adventurer slots at 64
- forwards button masks through the typed Fortress engine API
- renders the local adventurer grid as BitWorld `sprite_v1` packets without JSON
  in the tick loop
- resolves sprites from the shared Fortress `data/` asset set and uses visible
  placeholders for missing art

The old Party Progressor mechanics are now product reference material for what
should move into the Fortress engine or Quest adventurer presentation. They are
not a second runtime in this repo.

## Project Layout

- `src/tribal_quest.nim` is the Quest-only development host that starts a
  Fortress engine and installs the Quest `/player` adventurer surface.
- `src/tribal_quest/player_surface.nim` owns the Quest `/player` websocket and
  exposes mount hooks for a host-owned Fortress engine.
- `src/tribal_quest/fortress_engine.nim` contains the Quest-side adapter
  contract.
- `players/adventurer/adventurer.nim` is the bundled Nim websocket pilot.
- `plan.md` is the integration source of truth for the Quest half.
- `tests/tests.nim` contains lean adapter-contract checks.
