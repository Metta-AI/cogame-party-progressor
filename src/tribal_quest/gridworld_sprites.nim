import std/[os, sets, strutils, tables]

import pixie
import tribal_village_engine
import types

import tribal_quest/fortress_engine
import tribal_quest/sprite_packets

const
  QuestSpriteViewTiles* = QuestAdventureCropTiles

  TerrainObjectBase = 1_000
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
  case terrain
  of Empty: "grass"
  of Water: "water"
  of ShallowWater: "shallow_water"
  of Bridge: "bridge"
  of Fertile: "fertile"
  of Road: "road"
  of Grass: "grass"
  of Dune: "dune"
  of Sand: "sand"
  of Snow: "snow"
  of Mud: "mud"
  of Mountain: "dune"
  of RampUpN: "oriented/ramp_up_n"
  of RampUpS: "oriented/ramp_up_s"
  of RampUpW: "oriented/ramp_up_w"
  of RampUpE: "oriented/ramp_up_e"
  of RampDownN: "oriented/ramp_down_n"
  of RampDownS: "oriented/ramp_down_s"
  of RampDownW: "oriented/ramp_down_w"
  of RampDownE: "oriented/ramp_down_e"

proc thingSpriteKeyLocal(kind: ThingKind): string =
  case kind
  of Agent: "oriented/gatherer"
  of Wall: "oriented/wall"
  of Door: "door"
  of Tree: "tree"
  of Wheat: "wheat"
  of Fish: "fish"
  of Relic: "goblet"
  of Stone: "stone"
  of Gold: "gold"
  of Bush: "bush"
  of Cactus: "cactus"
  of Stalagmite: "stalagmite"
  of Magma: "magma"
  of Altar: "altar"
  of Spawner: "spawner"
  of Tumor: "tumor"
  of Cow: "oriented/cow"
  of Bear: "oriented/bear"
  of Wolf: "oriented/wolf"
  of Corpse: "corpse"
  of Skeleton: "skeleton"
  of ClayOven: "clay_oven"
  of WeavingLoom: "weaving_loom"
  of Outpost: "outpost"
  of GuardTower: "guard_tower"
  of Barrel: "barrel"
  of Mill: "mill"
  of Granary: "granary"
  of LumberCamp: "lumber_camp"
  of Quarry: "quarry"
  of MiningCamp: "mining_camp"
  of Stump: "stump"
  of Lantern: "lantern"
  of TownCenter: "town_center"
  of House: "house"
  of Barracks: "barracks"
  of ArcheryRange: "archery_range"
  of Stable: "stable"
  of SiegeWorkshop: "siege_workshop"
  of MangonelWorkshop: "mangonel_workshop"
  of TrebuchetWorkshop: "trebuchet_workshop"
  of Blacksmith: "blacksmith"
  of Market: "market"
  of Dock: "dock"
  of Monastery: "monastery"
  of Temple: "temple"
  of University: "university"
  of Castle: "castle"
  of Wonder: "wonder"
  of ControlPoint: "control_point"
  of GoblinHive: "goblin_hive"
  of GoblinHut: "goblin_hut"
  of GoblinTotem: "goblin_totem"
  of Stubble: "stubble"
  of CliffEdgeN: "cliff_edge_ew_s"
  of CliffEdgeE: "cliff_edge_ns_w"
  of CliffEdgeS: "cliff_edge_ew"
  of CliffEdgeW: "cliff_edge_ns"
  of CliffCornerInNE: "oriented/cliff_corner_in_ne"
  of CliffCornerInSE: "oriented/cliff_corner_in_se"
  of CliffCornerInSW: "oriented/cliff_corner_in_sw"
  of CliffCornerInNW: "oriented/cliff_corner_in_nw"
  of CliffCornerOutNE: "oriented/cliff_corner_out_ne"
  of CliffCornerOutSE: "oriented/cliff_corner_out_se"
  of CliffCornerOutSW: "oriented/cliff_corner_out_sw"
  of CliffCornerOutNW: "oriented/cliff_corner_out_nw"
  of WaterfallN: "waterfall_n"
  of WaterfallE: "waterfall_e"
  of WaterfallS: "waterfall_s"
  of WaterfallW: "waterfall_w"

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

      packet.addCellObject(
        knownSprites,
        registry,
        registry.spriteForTerrain(engine.env.terrain[worldX][worldY]),
        TerrainObjectBase + localY * view.width + localX,
        localX,
        localY,
        0
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
