import std/[json, os, sets]

import bitworld/protocol
import tribal_quest/fortress_engine
import tribal_quest/sprite_packets

const RootDir = currentSourcePath.parentDir.parentDir

template expectValueError(body: untyped, message: string) =
  var rejected = false
  try:
    body
  except ValueError:
    rejected = true
  doAssert rejected, message

proc testFortressRuntimeIsRequired() =
  validateWorldRuntime("fortress")
  validateWorldRuntime("fortress-engine")
  validateWorldRuntime("fortress_engine")

  expectValueError(validateWorldRuntime(""), "empty runtime must not be accepted")
  expectValueError(validateWorldRuntime("local"), "local runtime must be rejected")
  expectValueError(validateWorldRuntime("quest"), "unknown runtime must be rejected")

proc testAdventurerInputPayloads() =
  let mask = ButtonUp or ButtonRight or ButtonA
  let input = parseJson(adventurerInputJson(mask))
  doAssert input["type"].getStr() == AdventurerButtonsType
  doAssert input["buttons"].getInt() == int(mask)

  let raw = parseJson(adventurerRawActionJson(17))
  doAssert raw["type"].getStr() == AdventurerActionType
  doAssert raw["action"].getInt() == 17

  var parsedMask: uint8
  doAssert playerMaskFromPacket("\x84" & char(mask), parsedMask)
  doAssert parsedMask == mask
  doAssert playerMaskFromPacket(blobFromMask(mask), parsedMask)
  doAssert parsedMask == mask

proc testSpritePacketConstruction() =
  var
    packet: seq[uint8] = @[]
    known = initHashSet[int]()
  let selected = generatedSprite(1, "selected player human")

  packet.addClearObjects()
  packet.addLayer(SpriteLayerMap, SpriteLayerTypeMap, SpriteLayerFlagZoomable)
  packet.addViewport(SpriteLayerMap, QuestSpriteViewportPixels, QuestSpriteViewportPixels)
  packet.addSpriteIfNeeded(known, selected)
  packet.addObject(100, 10, 12, 20, SpriteLayerMap, selected.id)

  let summary = parseSpritePacketSummary(packet.toPacketString())
  doAssert summary.clearObjects == 1
  doAssert summary.layerCount == 1
  doAssert summary.viewportCount == 1
  doAssert summary.viewportWidth == QuestSpriteViewportPixels
  doAssert summary.viewportHeight == QuestSpriteViewportPixels
  doAssert "selected player human" in summary.spriteLabels
  doAssert selected.id in summary.definedSprites
  for spriteId in summary.objectSpriteIds:
    doAssert spriteId in summary.definedSprites

proc testGeneratedSpritePlaceholder() =
  let sprite = generatedSprite(7, "missing asset wolf")
  doAssert sprite.id == 7
  doAssert sprite.width == 16
  doAssert sprite.height == 16
  doAssert sprite.pixels.len == 16 * 16 * 4
  var nonTransparent = 0
  for i in countup(3, sprite.pixels.high, 4):
    if sprite.pixels[i] != 0:
      inc nonTransparent
  doAssert nonTransparent > 0

proc testAdventurerObservationParsing() =
  let observation = parseFortressAdventurerObservation($(%*{
    "agent_id": 42,
    "team_id": 2,
    "civilization": "Elf",
    "role": "scout",
    "position": {"x": 13, "y": 17},
    "hp": 5,
    "max_hp": 9,
    "status": "ready",
    "view_plane": {
      "origin": {"x": 8, "y": 12},
      "width": QuestAdventureCropTiles,
      "height": QuestAdventureCropTiles
    }
  }))
  doAssert observation.agentId == 42
  doAssert observation.teamId == 2
  doAssert observation.civilization == "Elf"
  doAssert observation.role == "scout"
  doAssert observation.x == 13 and observation.y == 17
  doAssert observation.hp == 5 and observation.maxHp == 9
  doAssert observation.status == "ready"
  doAssert observation.originX == 8 and observation.originY == 12
  doAssert observation.cropWidth == QuestAdventureCropTiles
  doAssert observation.cropHeight == QuestAdventureCropTiles

  let legacyCrop = parseFortressAdventurerObservation($(%*{
    "agentId": 5,
    "teamId": 1,
    "x": 20,
    "y": 21,
    "crop": {
      "origin_x": 15,
      "origin_y": 16,
      "width": 7,
      "height": 9
    }
  }))
  doAssert legacyCrop.agentId == 5
  doAssert legacyCrop.teamId == 1
  doAssert legacyCrop.x == 20 and legacyCrop.y == 21
  doAssert legacyCrop.originX == 15 and legacyCrop.originY == 16
  doAssert legacyCrop.cropWidth == 7 and legacyCrop.cropHeight == 9

proc testFortressEngineConfigValidation() =
  let config = defaultFortressEngineConfig()
  doAssert config.path.len == 0
  doAssert config.adventurerRole == "adventurer"
  doAssert config.worldWidth == FortressWorldWidthTiles
  doAssert config.worldHeight == FortressWorldHeightTiles
  doAssert config.townAgentsPerTeam == FortressTownAgentsPerTeam
  doAssert config.adventurerSlots == FortressAdventurerSlots

  expectValueError(validateAdventurerSlot(-1), "negative slot must be rejected")
  expectValueError(
    validateAdventurerSlot(FortressAdventurerSlots),
    "Fortress adventurer slots should be capped at 64"
  )
  validateAdventurerSlot(FortressAdventurerSlots - 1)

  var blankPath = config
  expectValueError(
    blankPath.validateFortressEngineConfig(),
    "fortress mode requires a concrete engine path"
  )

  let tempRoot = getTempDir() / "tribal_quest_fortress_engine_test"
  if dirExists(tempRoot):
    removeDir(tempRoot)
  createDir(tempRoot)
  createDir(tempRoot / "src")
  writeFile(tempRoot / "src" / "tribal_village_engine.nim", "")
  doAssert tempRoot.isLikelyFortressEngineCheckout()

  var engineConfig = config
  engineConfig.path = tempRoot
  engineConfig.validateFortressEngineConfig()
  removeDir(tempRoot)

proc testDefaultFortressPath() =
  let expected = RootDir / DefaultFortressCheckoutDir
  doAssert defaultFortressEnginePath(RootDir) == expected

when isMainModule:
  testFortressRuntimeIsRequired()
  testAdventurerInputPayloads()
  testSpritePacketConstruction()
  testGeneratedSpritePlaceholder()
  testAdventurerObservationParsing()
  testFortressEngineConfigValidation()
  testDefaultFortressPath()
  echo "All tests passed"
