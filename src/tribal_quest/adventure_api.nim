import std/[json, strutils, uri]
import bitworld/protocol

const
  FortressAdventurePath* = "/adventure"
  FortressWorldWidthTiles* = 768
  FortressWorldHeightTiles* = 480
  FortressTownTokenSlots* = 8
  FortressAdventurerSlots* = 64
  QuestAdventureCropTiles* = 11
  QuestBitWorldScreenPixels* = 128
  AdventureInputType* = "adventure.input"

type
  AdventureMove* = enum
    MoveNone = "none"
    MoveN = "N"
    MoveS = "S"
    MoveW = "W"
    MoveE = "E"
    MoveNW = "NW"
    MoveNE = "NE"
    MoveSW = "SW"
    MoveSE = "SE"

  AdventureObservation* = object
    agentId*: int
    team*: string
    civilization*: string
    role*: string
    x*: int
    y*: int
    hp*: int
    status*: string
    originX*: int
    originY*: int
    cropWidth*: int
    cropHeight*: int

proc moveName*(move: AdventureMove): string =
  ## Returns the wire value for one adventure movement direction.
  $move

proc adventureMoveFromMask*(mask: uint8): AdventureMove =
  ## Converts BitWorld direction bits into Fortress adventure movement.
  let
    north = (mask and ButtonUp) != 0 and (mask and ButtonDown) == 0
    south = (mask and ButtonDown) != 0 and (mask and ButtonUp) == 0
    west = (mask and ButtonLeft) != 0 and (mask and ButtonRight) == 0
    east = (mask and ButtonRight) != 0 and (mask and ButtonLeft) == 0
  if north and west:
    MoveNW
  elif north and east:
    MoveNE
  elif south and west:
    MoveSW
  elif south and east:
    MoveSE
  elif north:
    MoveN
  elif south:
    MoveS
  elif west:
    MoveW
  elif east:
    MoveE
  else:
    MoveNone

proc adventureInputJson*(mask: uint8): string =
  ## Builds the JSON message Quest sends to Fortress /adventure.
  let node = %*{
    "type": AdventureInputType,
    "move": mask.adventureMoveFromMask().moveName(),
    "attack": (mask and ButtonA) != 0,
    "use": (mask and ButtonB) != 0,
    "buttons": {
      "up": (mask and ButtonUp) != 0,
      "down": (mask and ButtonDown) != 0,
      "left": (mask and ButtonLeft) != 0,
      "right": (mask and ButtonRight) != 0,
      "a": (mask and ButtonA) != 0,
      "b": (mask and ButtonB) != 0
    }
  }
  $node

proc adventureRawActionJson*(action: int): string =
  ## Builds a raw Fortress action message; Fortress should prefer this over buttons.
  $(%*{
    "type": AdventureInputType,
    "raw_action": action
  })

proc validateAdventureSlot*(slot: int) =
  ## Raises when a Quest adventurer slot is outside Fortress's v1 slot range.
  if slot < 0 or slot >= FortressAdventurerSlots:
    raise newException(
      ValueError,
      "adventure slot must be between 0 and " & $(FortressAdventurerSlots - 1)
    )

proc adventureUrl*(
  baseUrl: string,
  slot: int,
  token: string,
  name: string,
  role: string
): string =
  ## Builds the Fortress /adventure websocket URL for one Quest adventurer.
  slot.validateAdventureSlot()
  var base = baseUrl
  if base.len == 0:
    base = "ws://localhost:8080"
  while base.endsWith("/"):
    base.setLen(base.len - 1)
  if not base.endsWith(FortressAdventurePath):
    base.add(FortressAdventurePath)
  base & "?slot=" & encodeUrl($slot) &
    "&token=" & encodeUrl(token) &
    "&name=" & encodeUrl(name) &
    "&role=" & encodeUrl(role)

proc getString(node: JsonNode, names: openArray[string], default = ""): string =
  for name in names:
    if node.hasKey(name) and node[name].kind == JString:
      return node[name].getStr()
  default

proc getInt(node: JsonNode, names: openArray[string], default = 0): int =
  for name in names:
    if node.hasKey(name) and node[name].kind == JInt:
      return node[name].getInt()
  default

proc parseAdventureObservation*(text: string): AdventureObservation =
  ## Parses the stable fields Quest needs from one Fortress adventure tick.
  let node = parseJson(text)
  if node.kind != JObject:
    raise newException(ValueError, "adventure observation must be a JSON object")
  result.agentId = node.getInt(["agent_id", "agentId"], -1)
  result.team = node.getString(["team", "faction"])
  result.civilization = node.getString(["civilization", "civ"])
  result.role = node.getString(["role"])
  result.hp = node.getInt(["hp", "health"], 0)
  result.status = node.getString(["status"])
  if node.hasKey("position") and node["position"].kind == JObject:
    result.x = node["position"].getInt(["x"], 0)
    result.y = node["position"].getInt(["y"], 0)
  else:
    result.x = node.getInt(["x"], 0)
    result.y = node.getInt(["y"], 0)
  let crop =
    if node.hasKey("view_plane") and node["view_plane"].kind == JObject:
      node["view_plane"]
    elif node.hasKey("crop") and node["crop"].kind == JObject:
      node["crop"]
    else:
      node
  result.originX = crop.getInt(["origin_x", "originX"], 0)
  result.originY = crop.getInt(["origin_y", "originY"], 0)
  result.cropWidth = crop.getInt(["width"], QuestAdventureCropTiles)
  result.cropHeight = crop.getInt(["height"], QuestAdventureCropTiles)
