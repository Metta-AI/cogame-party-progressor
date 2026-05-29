import std/[parseopt, strutils, uri]

import asyncdispatch
import ws

import bitworld/protocol

type
  BotError = object of CatchableError

  BotConfig = object
    address: string
    port: int
    slot: int
    token: string
    ticks: int

proc requireOptionValue(name, value: string) =
  if value.len == 0:
    raise newException(BotError, "Option --" & name & " requires a value.")

proc parseOptionInt(name, value: string): int =
  name.requireOptionValue(value)
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(BotError, "Option --" & name & " must be an integer.")

proc playerUrl(config: BotConfig): string =
  result = "ws://" & config.address & ":" & $config.port &
    "/player?protocol=pixel&slot=" & $config.slot
  if config.token.len > 0:
    result.add("&token=" & encodeUrl(config.token))

proc frameDigest(frame: string): uint32 =
  result = 2166136261'u32
  for ch in frame:
    result = (result xor uint32(ch.uint8)) * 16777619'u32

proc nonZeroBytes(frame: string): int =
  for ch in frame:
    if ch != char(0):
      inc result

proc closeSocket(socket: WebSocket) =
  try:
    socket.hangup()
  except CatchableError:
    discard

proc chooseMask(tick, stagnantFrames: int): uint8 =
  let phase = ((tick div 12) + (stagnantFrames div 3)) mod 6
  case phase
  of 0, 1:
    result = ButtonRight
  of 2:
    result = ButtonDown
  of 3, 4:
    result = ButtonLeft
  else:
    result = ButtonUp

  if tick mod 9 == 0:
    result = result or ButtonA
  if tick mod 37 == 0:
    result = result or ButtonB

proc runBot(config: BotConfig): Future[int] {.async.} =
  let url = config.playerUrl()
  echo "Connecting adventurer bot to " & url
  let socket = await newWebSocket(url)
  var
    sent = 0
    frames = 0
    nonBlankFrames = 0
    stagnantFrames = 0
    lastDigest = 0'u32

  try:
    for tick in 0 ..< config.ticks:
      let mask = chooseMask(tick, stagnantFrames)
      await socket.send(blobFromMask(mask), Binary)
      inc sent

      let (opcode, frame) = await socket.receivePacket()
      if opcode != Binary:
        raise newException(BotError, "Expected binary frame from /player.")
      if frame.len != ProtocolBytes:
        raise newException(
          BotError,
          "Expected " & $ProtocolBytes & " frame bytes, got " & $frame.len & "."
        )

      let digest = frame.frameDigest()
      if frames > 0 and digest == lastDigest:
        inc stagnantFrames
      else:
        stagnantFrames = 0
      lastDigest = digest

      if frame.nonZeroBytes() > 0:
        inc nonBlankFrames
      inc frames
  finally:
    socket.closeSocket()

  echo "Sent input packets: " & $sent
  echo "Received frame packets: " & $frames
  echo "Non-blank frames: " & $nonBlankFrames
  if frames == 0 or nonBlankFrames == 0:
    return 1
  0

when isMainModule:
  var config = BotConfig(
    address: DefaultHost,
    port: DefaultPort,
    slot: 0,
    token: "",
    ticks: 60
  )

  for kind, key, val in getopt():
    case kind
    of cmdLongOption:
      case key
      of "address":
        key.requireOptionValue(val)
        config.address = val
      of "port":
        config.port = key.parseOptionInt(val)
      of "slot":
        config.slot = key.parseOptionInt(val)
      of "token":
        key.requireOptionValue(val)
        config.token = val
      of "ticks":
        config.ticks = key.parseOptionInt(val)
      else:
        raise newException(BotError, "Unknown option: --" & key)
    of cmdShortOption:
      raise newException(BotError, "Unknown option: -" & key)
    of cmdArgument:
      raise newException(BotError, "Unexpected argument: " & key)
    of cmdEnd:
      discard

  if config.slot < 0:
    raise newException(BotError, "slot must be non-negative.")
  if config.ticks < 1:
    raise newException(BotError, "ticks must be positive.")

  quit(waitFor runBot(config))
