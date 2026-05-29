import std/sets

import supersnappy

const
  SpriteMsgDefineSprite* = 0x01'u8
  SpriteMsgDefineObject* = 0x02'u8
  SpriteMsgDeleteObject* = 0x03'u8
  SpriteMsgClearObjects* = 0x04'u8
  SpriteMsgSetViewport* = 0x05'u8
  SpriteMsgDefineLayer* = 0x06'u8
  SpriteInputText* = 0x81'u8
  SpritePlayerInput* = 0x84'u8

  SpriteLayerMap* = 0
  SpriteLayerUi* = 1
  SpriteLayerTypeMap* = 0
  SpriteLayerTypeTopLeftUi* = 1
  SpriteLayerFlagZoomable* = 1
  SpriteLayerFlagUi* = 2

type
  SpriteAsset* = object
    id*: int
    width*: int
    height*: int
    pixels*: seq[uint8]
    label*: string

  SpritePacketSummary* = object
    clearObjects*: int
    layerCount*: int
    viewportCount*: int
    viewportWidth*: int
    viewportHeight*: int
    spriteLabels*: seq[string]
    definedSprites*: HashSet[int]
    objectSpriteIds*: seq[int]

proc addU8*(packet: var seq[uint8], value: uint8) =
  packet.add(value)

proc addU16*(packet: var seq[uint8], value: int) =
  let v = uint16(value)
  packet.add(uint8(v and 0xff'u16))
  packet.add(uint8(v shr 8))

proc addU32*(packet: var seq[uint8], value: int) =
  let v = uint32(value)
  for shift in countup(0, 24, 8):
    packet.add(uint8((v shr shift) and 0xff'u32))

proc addI16*(packet: var seq[uint8], value: int) =
  let v = cast[uint16](int16(value))
  packet.add(uint8(v and 0xff'u16))
  packet.add(uint8(v shr 8))

proc addLayer*(packet: var seq[uint8], layer, layerType, flags: int) =
  packet.addU8(SpriteMsgDefineLayer)
  packet.addU8(uint8(layer))
  packet.addU8(uint8(layerType))
  packet.addU8(uint8(flags))

proc addViewport*(packet: var seq[uint8], layer, width, height: int) =
  packet.addU8(SpriteMsgSetViewport)
  packet.addU8(uint8(layer))
  packet.addU16(width)
  packet.addU16(height)

proc addClearObjects*(packet: var seq[uint8]) =
  packet.addU8(SpriteMsgClearObjects)

proc addSprite*(
  packet: var seq[uint8],
  spriteId, width, height: int,
  pixels: openArray[uint8],
  label = ""
) =
  packet.addU8(SpriteMsgDefineSprite)
  packet.addU16(spriteId)
  packet.addU16(width)
  packet.addU16(height)
  var raw = newSeq[uint8](pixels.len)
  for i in 0 ..< pixels.len:
    raw[i] = pixels[i]
  let compressed = supersnappy.compress(raw)
  packet.addU32(compressed.len)
  for byte in compressed:
    packet.addU8(byte)
  packet.addU16(label.len)
  for ch in label:
    packet.addU8(uint8(ord(ch)))

proc addObject*(packet: var seq[uint8], objectId, x, y, z, layer, spriteId: int) =
  packet.addU8(SpriteMsgDefineObject)
  packet.addU16(objectId)
  packet.addI16(x)
  packet.addI16(y)
  packet.addI16(z)
  packet.addU8(uint8(layer))
  packet.addU16(spriteId)

proc addSpriteIfNeeded*(
  packet: var seq[uint8],
  known: var HashSet[int],
  sprite: SpriteAsset
) =
  if sprite.id notin known:
    packet.addSprite(sprite.id, sprite.width, sprite.height, sprite.pixels, sprite.label)
    known.incl(sprite.id)

proc toPacketString*(packet: openArray[uint8]): string =
  result = newString(packet.len)
  for i, byte in packet:
    result[i] = char(byte)

proc playerMaskFromPacket*(blob: string, mask: var uint8): bool =
  ## Reads both old pixel input and sprite_v1 player input packets.
  if blob.len == 2 and blob[0].uint8 in {0'u8, SpritePlayerInput}:
    mask = blob[1].uint8 and 0x7f'u8
    return true
  false

proc isTextInputPacket*(blob: string): bool =
  blob.len > 0 and blob[0].uint8 in {1'u8, SpriteInputText}

proc rgbaTile*(
  width, height: int,
  fill: tuple[r, g, b, a: uint8],
  border: tuple[r, g, b, a: uint8]
): seq[uint8] =
  result = newSeq[uint8](width * height * 4)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let
        edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
        color = if edge: border else: fill
        offset = (y * width + x) * 4
      result[offset] = color.r
      result[offset + 1] = color.g
      result[offset + 2] = color.b
      result[offset + 3] = color.a

proc selectionRingPixels*(width, height: int): seq[uint8] =
  result = newSeq[uint8](width * height * 4)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let
        edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
        corner = (x < 3 or x >= width - 3) and (y < 3 or y >= height - 3)
        offset = (y * width + x) * 4
      if edge or corner:
        result[offset] = 255
        result[offset + 1] = 235
        result[offset + 2] = 80
        result[offset + 3] = 230

proc colorFromKey*(key: string): tuple[r, g, b, a: uint8] =
  var h = 2166136261'u32
  for ch in key:
    h = (h xor uint32(ch.uint8)) * 16777619'u32
  (
    r: uint8(48 + (h and 0x7f'u32)),
    g: uint8(64 + ((h shr 8) and 0x7f'u32)),
    b: uint8(56 + ((h shr 16) and 0x7f'u32)),
    a: 255'u8
  )

proc generatedSprite*(id: int, label: string, width = 16, height = 16): SpriteAsset =
  let fill = colorFromKey(label)
  SpriteAsset(
    id: id,
    width: width,
    height: height,
    pixels: rgbaTile(width, height, fill, (r: 24'u8, g: 24'u8, b: 28'u8, a: 255'u8)),
    label: label
  )

proc readU16(bytes: openArray[uint8], offset: int): int =
  int(bytes[offset]) or (int(bytes[offset + 1]) shl 8)

proc readU32(bytes: openArray[uint8], offset: int): int =
  int(bytes[offset]) or
    (int(bytes[offset + 1]) shl 8) or
    (int(bytes[offset + 2]) shl 16) or
    (int(bytes[offset + 3]) shl 24)

proc parseSpritePacketSummary*(packet: string): SpritePacketSummary =
  result.definedSprites = initHashSet[int]()
  var bytes = newSeq[uint8](packet.len)
  for i, ch in packet:
    bytes[i] = ch.uint8
  var offset = 0
  while offset < bytes.len:
    let msg = bytes[offset]
    inc offset
    case msg
    of SpriteMsgDefineSprite:
      let
        spriteId = bytes.readU16(offset)
        width = bytes.readU16(offset + 2)
        height = bytes.readU16(offset + 4)
        compressedLen = bytes.readU32(offset + 6)
        labelOffset = offset + 10 + compressedLen
        labelLen = bytes.readU16(labelOffset)
      offset = labelOffset + 2
      var label = ""
      for _ in 0 ..< labelLen:
        label.add(char(bytes[offset]))
        inc offset
      result.definedSprites.incl(spriteId)
      result.spriteLabels.add(label)
      discard width
      discard height
    of SpriteMsgDefineObject:
      let spriteId = bytes.readU16(offset + 9)
      result.objectSpriteIds.add(spriteId)
      offset += 11
    of SpriteMsgDeleteObject:
      offset += 2
    of SpriteMsgClearObjects:
      inc result.clearObjects
    of SpriteMsgSetViewport:
      result.viewportWidth = bytes.readU16(offset + 1)
      result.viewportHeight = bytes.readU16(offset + 3)
      inc result.viewportCount
      offset += 5
    of SpriteMsgDefineLayer:
      inc result.layerCount
      offset += 3
    else:
      raise newException(ValueError, "unknown sprite packet type " & $msg)
