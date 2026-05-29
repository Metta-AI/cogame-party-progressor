# AGENTS.md

Tribal Quest is a standalone Coworld game repo. Keep it shaped like the
other standalone Metta cogame repos rather than like the BitWorld monorepo.

Use these repositories as layout and packaging references:

- https://github.com/Metta-AI/cogame-asteroid-arena
- https://github.com/Metta-AI/cogame-big-adventure
- https://github.com/Metta-AI/cogame-infinite-blocks
- https://github.com/Metta-AI/cogame-jumper
- https://github.com/Metta-AI/cogame-planet-wars
- https://github.com/Metta-AI/cogame-crewrift
- https://github.com/Metta-AI/cogame-heartleaf

The game vendors its tiny browser client and wire protocol helpers under
`src/tribal_quest/`, and depends on the installed `coworld-tribal-fortress`
runtime for the world simulation. Keep Tribal Quest-specific adapter code under
`src/tribal_quest/`, the executable at `src/tribal_quest.nim`, and tests under
`tests/`. Do not reintroduce the old local Quest simulation as a fallback.

Before pushing gameplay or protocol changes, run:

```sh
nim r --path:src tests/tests.nim
TRIBAL_FORTRESS_PATH=${TRIBAL_FORTRESS_PATH:-$(pwd)/../coworld-tribal-fortress}
nim c --path:src --path:$TRIBAL_FORTRESS_PATH/src -o:out/tribal_quest src/tribal_quest.nim
git diff --check
```

If the Fortress checkout has not landed the `tribal_village_engine` Nim module
yet, the build should fail at that missing import. Do not add a local fallback
runtime or Python bridge to make it pass.
