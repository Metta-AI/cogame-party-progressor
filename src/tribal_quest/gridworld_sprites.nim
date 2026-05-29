import std/[os, sets, strutils, tables]

import pixie
import environment
import tribal_village_engine
import types

import tribal_quest/fortress_engine
import tribal_quest/sprite_packets

const
  QuestSpriteViewTiles* = QuestAdventureCropTiles

  TerrainObjectBase = 1_000
  TerrainAssetObjectBase = 2_000
  BackgroundObjectBase = 10_000
  ThingObjectBase = 20_000
  SelectionObjectId = 30_000
  StatusObjectBase = 31_000

type
  QuestSpriteRegistry* = object
    dataDir: string
    nextSpriteId: int
    sprites: Table[string, SpriteAsset]

proc initQuestSpriteRegistry*(fortressPath = ""): QuestSpriteRegistry =
  let root =
    if fortressPath.strip().len > 0:
      fortressPath
    else:
      defaultFortressEnginePath()
  QuestSpriteRegistry(
    dataDir: root / "data",
    nextSpriteId: 1,
    sprites: initTable[string, SpriteAsset]()
  )

proc nextId(registry: var QuestSpriteRegistry): int =
  result = registry.nextSpriteId
  inc registry.nextSpriteId

proc directionKey(orientation: Orientation): string =
  case orientation
  of N: "n"
  of S: "s"
  of W: "w"
  of E: "e"
  of NW: "nw"
  of NE: "ne"
  of SW: "sw"
  of SE: "se"

proc terrainSpriteKeyLocal(terrain: TerrainType): string =
  let key = terrainSpriteKey(terrain)
  if key.len > 0:
    key
  else:
    "grass"

proc thingSpriteKeyLocal(kind: ThingKind): string =
  thingSpriteKey(kind)

when declared(QuestMonster):
  proc questMonsterSpeciesName(thing: Thing): string =
    when compiles(thing.questMonsterSpecies):
      $thing.questMonsterSpecies
    else:
      ""

  proc questMonsterSpriteKeyLocal(speciesName: string): string =
    let lower = speciesName.toLowerAscii()
    if "goblin" in lower:
      "oriented/goblin"
    elif "slime" in lower or "scorpion" in lower or "burrower" in lower or
        "scarab" in lower or "leech" in lower:
      "oriented/tumor"
    elif "wraith" in lower or "mender" in lower or "witch" in lower or
        "shaman" in lower or "seer" in lower or "necromancer" in lower:
      "skeleton"
    elif "bear" in lower or "boar" in lower or "buck" in lower or
        "yeti" in lower or "troll" in lower or "maw" in lower or
        "titan" in lower:
      "oriented/bear"
    else:
      "oriented/wolf"

  proc questMonsterLabelLocal(speciesName: string): string =
    result = speciesName
    if result.startsWith("QuestMonster"):
      result = result["QuestMonster".len .. ^1]
    if result.len == 0 or result == "None":
      return "quest monster"
    var label = newStringOfCap(result.len + 4)
    for i, ch in result:
      if i > 0 and ch.isUpperAscii():
        label.add(' ')
      label.add(ch.toLowerAscii())
    result = label

proc unitSpriteBase(unitClass: AgentUnitClass, agentId: int, packed: bool): string =
  case unitClass
  of UnitVillager:
    case agentId mod MapAgentsPerTeam
    of 0, 1: "oriented/gatherer"
    of 2, 3: "oriented/builder"
    of 4, 5: "oriented/fighter"
    else: "oriented/gatherer"
  of UnitManAtArms: "oriented/man_at_arms"
  of UnitArcher: "oriented/archer"
  of UnitScout: "oriented/scout"
  of UnitKnight: "oriented/knight"
  of UnitMonk: "oriented/monk"
  of UnitBatteringRam: "oriented/battering_ram"
  of UnitMangonel: "oriented/mangonel"
  of UnitTrebuchet:
    if packed: "oriented/trebuchet_packed" else: "oriented/trebuchet_unpacked"
  of UnitGoblin: "oriented/goblin"
  of UnitBoat: "oriented/boat"
  of UnitTradeCog: "oriented/trade_cog"
  of UnitSamurai: "oriented/samurai"
  of UnitLongbowman: "oriented/longbowman"
  of UnitCataphract: "oriented/cataphract"
  of UnitWoadRaider: "oriented/woad_raider"
  of UnitTeutonicKnight: "oriented/teutonic_knight"
  of UnitHuskarl: "oriented/huskarl"
  of UnitMameluke: "oriented/mameluke"
  of UnitJanissary: "oriented/janissary"
  of UnitKing: "oriented/king"
  of UnitLongSwordsman: "oriented/long_swordsman"
  of UnitChampion: "oriented/champion"
  of UnitLightCavalry: "oriented/light_cavalry"
  of UnitHussar: "oriented/hussar"
  of UnitCrossbowman: "oriented/crossbowman"
  of UnitArbalester: "oriented/arbalester"
  of UnitGalley: "oriented/galley"
  of UnitFireShip: "oriented/fire_ship"
  of UnitFishingShip: "oriented/fishing_ship"
  of UnitTransportShip: "oriented/transport_ship"
  of UnitDemoShip: "oriented/demo_ship"
  of UnitCannonGalleon: "oriented/cannon_galleon"
  of UnitScorpion: "oriented/scorpion"
  of UnitCavalier: "oriented/cavalier"
  of UnitPaladin: "oriented/paladin"
  of UnitCamel: "oriented/camel"
  of UnitHeavyCamel: "oriented/heavy_camel"
  of UnitImperialCamel: "oriented/imperial_camel"
  of UnitSkirmisher: "oriented/skirmisher"
  of UnitEliteSkirmisher: "oriented/elite_skirmisher"
  of UnitCavalryArcher: "oriented/cavalry_archer"
  of UnitHeavyCavalryArcher: "oriented/heavy_cavalry_archer"
  of UnitHandCannoneer: "oriented/hand_cannoneer"

proc candidatePaths(registry: QuestSpriteRegistry, key, dir: string): seq[string] =
  if key.len == 0:
    return
  result.add(registry.dataDir / (key & ".png"))
  if "." notin key:
    result.add(registry.dataDir / (key & "." & dir & ".png"))
    result.add(registry.dataDir / (key & ".s.png"))
    if not key.startsWith("oriented/"):
      result.add(registry.dataDir / "oriented" / (key & "." & dir & ".png"))
      result.add(registry.dataDir / "oriented" / (key & ".s.png"))

proc resolveAssetPath(registry: QuestSpriteRegistry, key: string, orientation = S): string =
  let dir = directionKey(orientation)
  for path in registry.candidatePaths(key, dir):
    if fileExists(path):
      return path
  ""

proc normalizedRgba(path: string, width, height: int): seq[uint8] =
  let image = readImage(path)
  result = newSeq[uint8](width * height * 4)
  for y in 0 ..< height:
    let sy = min(image.height - 1, y * image.height div height)
    for x in 0 ..< width:
      let
        sx = min(image.width - 1, x * image.width div width)
        color = image[sx, sy].rgba()
        offset = (y * width + x) * 4
      result[offset] = color.r
      result[offset + 1] = color.g
      result[offset + 2] = color.b
      result[offset + 3] = color.a

proc spriteForLabel(
  registry: var QuestSpriteRegistry,
  cacheKey, label: string,
  pixels: seq[uint8],
  width = QuestSpriteTilePixels,
  height = QuestSpriteTilePixels
): SpriteAsset =
  if cacheKey in registry.sprites:
    return registry.sprites[cacheKey]
  result = SpriteAsset(
    id: registry.nextId(),
    width: width,
    height: height,
    pixels: pixels,
    label: label
  )
  registry.sprites[cacheKey] = result

proc spriteForAsset(
  registry: var QuestSpriteRegistry,
  key: string,
  label: string,
  orientation = S
): SpriteAsset =
  let cacheKey = key & "|" & directionKey(orientation) & "|" & label
  if cacheKey in registry.sprites:
    return registry.sprites[cacheKey]

  let path = registry.resolveAssetPath(key, orientation)
  if path.len > 0:
    try:
      return registry.spriteForLabel(
        cacheKey,
        label,
        normalizedRgba(path, QuestSpriteTilePixels, QuestSpriteTilePixels)
      )
    except PixieError:
      discard

  registry.spriteForLabel(
    cacheKey,
    "missing asset " & label,
    rgbaTile(
      QuestSpriteTilePixels,
      QuestSpriteTilePixels,
      colorFromKey(label),
      (r: 255'u8, g: 0'u8, b: 88'u8, a: 255'u8)
    )
  )

proc selectedSprite(
  registry: var QuestSpriteRegistry,
  civ: CivilizationKind,
  orientation: Orientation
): SpriteAsset =
  let
    civKey = civilizationKey(civ)
    key = "civs/oriented/" & civKey & "_adventurer." & directionKey(orientation)
  registry.spriteForAsset(key, "adventurer " & civKey, orientation)

proc spriteForTerrain(
  registry: var QuestSpriteRegistry,
  terrain: TerrainType
): SpriteAsset =
  registry.spriteForAsset(terrainSpriteKeyLocal(terrain), "terrain " & $terrain)

proc terrainBaseColor(terrain: TerrainType): tuple[r, g, b, a: uint8] =
  case terrain
  of Water:
    (r: 54'u8, g: 120'u8, b: 172'u8, a: 255'u8)
  of ShallowWater:
    (r: 96'u8, g: 160'u8, b: 184'u8, a: 255'u8)
  of Bridge, Road:
    (r: 156'u8, g: 138'u8, b: 94'u8, a: 255'u8)
  of Fertile, Grass:
    (r: 160'u8, g: 150'u8, b: 82'u8, a: 255'u8)
  of Dune, Sand:
    (r: 208'u8, g: 178'u8, b: 104'u8, a: 255'u8)
  of Snow:
    (r: 202'u8, g: 210'u8, b: 204'u8, a: 255'u8)
  of Mud:
    (r: 116'u8, g: 96'u8, b: 70'u8, a: 255'u8)
  of CanyonWash:
    (r: 115'u8, g: 80'u8, b: 55'u8, a: 255'u8)
  of CanyonFloor:
    (r: 175'u8, g: 80'u8, b: 45'u8, a: 255'u8)
  of CanyonRim:
    (r: 145'u8, g: 55'u8, b: 35'u8, a: 255'u8)
  of Mountain:
    (r: 118'u8, g: 112'u8, b: 96'u8, a: 255'u8)
  of RampUpN, RampUpS, RampUpW, RampUpE, RampDownN, RampDownS, RampDownW, RampDownE:
    (r: 142'u8, g: 124'u8, b: 86'u8, a: 255'u8)
  else:
    (r: 154'u8, g: 140'u8, b: 86'u8, a: 255'u8)

proc spriteForTerrainBase(
  registry: var QuestSpriteRegistry,
  terrain: TerrainType
): SpriteAsset =
  let label = "terrain base " & $terrain
  registry.spriteForLabel(
    "terrain-base/" & $terrain,
    label,
    rgbaTile(
      QuestSpriteTilePixels,
      QuestSpriteTilePixels,
      terrainBaseColor(terrain),
      terrainBaseColor(terrain)
    )
  )

proc spriteForThing(
  registry: var QuestSpriteRegistry,
  thing: Thing,
  selectedAgentId: int,
  selectedCiv: CivilizationKind
): SpriteAsset =
  if thing.kind == Agent:
    if thing.agentId == selectedAgentId:
      return registry.selectedSprite(selectedCiv, thing.orientation)
    return registry.spriteForAsset(
      unitSpriteBase(thing.unitClass, thing.agentId, thing.packed),
      "unit " & $thing.unitClass,
      thing.orientation
    )
  when declared(QuestMonster):
    if thing.kind == QuestMonster:
      let speciesName = thing.questMonsterSpeciesName()
      return registry.spriteForAsset(
        questMonsterSpriteKeyLocal(speciesName),
        questMonsterLabelLocal(speciesName),
        thing.orientation
      )
  registry.spriteForAsset(thingSpriteKeyLocal(thing.kind), "thing " & $thing.kind, thing.orientation)

proc addCellObject(
  packet: var seq[uint8],
  known: var HashSet[int],
  registry: var QuestSpriteRegistry,
  sprite: SpriteAsset,
  objectId, localX, localY, z: int
) =
  packet.addSpriteIfNeeded(known, sprite)
  packet.addObject(
    objectId,
    localX * QuestSpriteTilePixels,
    localY * QuestSpriteTilePixels,
    z,
    SpriteLayerMap,
    sprite.id
  )

proc addFrameHeader(packet: var seq[uint8]) =
  packet.addClearObjects()
  packet.addLayer(SpriteLayerMap, SpriteLayerTypeMap, SpriteLayerFlagZoomable)
  packet.addViewport(SpriteLayerMap, QuestSpriteViewportPixels, QuestSpriteViewportPixels)

proc addStatusFrame(
  packet: var seq[uint8],
  known: var HashSet[int],
  registry: var QuestSpriteRegistry,
  label: string
) =
  let
    floor = registry.spriteForLabel(
      "status/floor",
      "status floor",
      rgbaTile(
        QuestSpriteTilePixels,
        QuestSpriteTilePixels,
        (r: 38'u8, g: 36'u8, b: 42'u8, a: 255'u8),
        (r: 20'u8, g: 20'u8, b: 24'u8, a: 255'u8)
      )
    )
    marker = registry.spriteForLabel(
      "status/" & label,
      label,
      rgbaTile(
        QuestSpriteTilePixels,
        QuestSpriteTilePixels,
        (r: 156'u8, g: 34'u8, b: 58'u8, a: 255'u8),
        (r: 255'u8, g: 220'u8, b: 90'u8, a: 255'u8)
      )
    )

  for y in 0 ..< QuestSpriteViewTiles:
    for x in 0 ..< QuestSpriteViewTiles:
      packet.addCellObject(
        known,
        registry,
        floor,
        StatusObjectBase + y * QuestSpriteViewTiles + x,
        x,
        y,
        0
      )
  packet.addCellObject(
    known,
    registry,
    marker,
    SelectionObjectId,
    QuestSpriteViewTiles div 2,
    QuestSpriteViewTiles div 2,
    40
  )

proc buildAdventurerSpriteFrame*(
  engine: var FortressEngine,
  slot: int,
  registry: var QuestSpriteRegistry,
  knownSprites: var HashSet[int]
): string =
  var packet: seq[uint8] = @[]
  packet.addFrameHeader()

  var cells: array[QuestSpriteViewTiles * QuestSpriteViewTiles, uint8]
  let view = engine.adventurerViewCells(slot, cells)
  if not view.ok or view.done or view.width <= 0 or view.height <= 0:
    packet.addStatusFrame(knownSprites, registry, "adventurer dormant")
    return packet.toPacketString()

  for localY in 0 ..< view.height:
    for localX in 0 ..< view.width:
      let
        worldX = view.originX + localX
        worldY = view.originY + localY
      if worldX < 0 or worldY < 0 or worldX >= MapWidth or worldY >= MapHeight:
        continue

      let terrain = engine.env.terrain[worldX][worldY]
      packet.addCellObject(
        knownSprites,
        registry,
        registry.spriteForTerrainBase(terrain),
        TerrainObjectBase + localY * view.width + localX,
        localX,
        localY,
        0
      )
      packet.addCellObject(
        knownSprites,
        registry,
        registry.spriteForTerrain(terrain),
        TerrainAssetObjectBase + localY * view.width + localX,
        localX,
        localY,
        2
      )

      let background = engine.env.backgroundGrid[worldX][worldY]
      if not background.isNil:
        packet.addCellObject(
          knownSprites,
          registry,
          registry.spriteForThing(background, view.agentId, view.civilization),
          BackgroundObjectBase + localY * view.width + localX,
          localX,
          localY,
          10
        )

      let thing = engine.env.grid[worldX][worldY]
      if not thing.isNil:
        packet.addCellObject(
          knownSprites,
          registry,
          registry.spriteForThing(thing, view.agentId, view.civilization),
          ThingObjectBase + localY * view.width + localX,
          localX,
          localY,
          20
        )

  let
    selectedX = view.x - view.originX
    selectedY = view.y - view.originY
    civKey = civilizationKey(view.civilization)
    ring = registry.spriteForLabel(
      "selected/" & civKey,
      "selected player " & civKey,
      selectionRingPixels(QuestSpriteTilePixels, QuestSpriteTilePixels)
    )
  if selectedX >= 0 and selectedX < view.width and selectedY >= 0 and selectedY < view.height:
    packet.addCellObject(
      knownSprites,
      registry,
      ring,
      SelectionObjectId,
      selectedX,
      selectedY,
      50
    )

  packet.toPacketString()
