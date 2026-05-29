const
  ScreenWidth* = 128
  ScreenHeight* = 128
  ProtocolBytes* = (ScreenWidth * ScreenHeight) div 2

  PacketInput* = 0'u8
  PacketChat* = 1'u8
  InputPacketBytes* = 2

  DefaultHost* = "localhost"
  DefaultPort* = 8080

  ButtonUp* = 1'u8 shl 0
  ButtonDown* = 1'u8 shl 1
  ButtonLeft* = 1'u8 shl 2
  ButtonRight* = 1'u8 shl 3
  ButtonSelect* = 1'u8 shl 4
  ButtonA* = 1'u8 shl 5
  ButtonB* = 1'u8 shl 6

proc blobFromBytes*(bytes: openArray[uint8]): string =
  result = newString(bytes.len)
  for i, value in bytes:
    result[i] = char(value)

proc blobFromMask*(mask: uint8): string =
  ## Builds the legacy two-byte button packet accepted by /client/pixel.
  result = newString(InputPacketBytes)
  result[0] = char(PacketInput)
  result[1] = char(mask)
