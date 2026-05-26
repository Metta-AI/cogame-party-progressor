# AGENTS.md

Party Progressor is a standalone Coworld game repo. Keep it shaped like the
other standalone Metta cogame repos rather than like the BitWorld monorepo.

Use these repositories as layout and packaging references:

- https://github.com/Metta-AI/cogame-asteroid-arena
- https://github.com/Metta-AI/cogame-big-adventure
- https://github.com/Metta-AI/cogame-infinite-blocks
- https://github.com/Metta-AI/cogame-jumper
- https://github.com/Metta-AI/cogame-planet-wars
- https://github.com/Metta-AI/cogame-crewrift
- https://github.com/Metta-AI/cogame-heartleaf

The game depends on `bitworld` for shared sprite protocol, browser clients,
palette/font helpers, and Coworld runtime env handling. Keep Party
Progressor-specific code under `src/party_progressor/`, the executable at
`src/party_progressor.nim`, tests under `tests/`, and bundled player bots under
`players/`.

Before pushing gameplay or protocol changes, run:

```sh
nim r --path:src tests/tests.nim
nim c --path:src -o:out/party_progressor src/party_progressor.nim
nim c --path:src -o:out/party_progressor_konrad players/konrad/konrad.nim
node --check players/js_konrad/konrad.js
python3 -m py_compile players/py_konrad/konrad.py scripts/prepare_monster_assets.py
git diff --check
```

