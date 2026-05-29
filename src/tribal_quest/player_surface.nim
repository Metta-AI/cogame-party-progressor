import
  std/[json, locks, monotimes, os, strutils, tables, times],
  mummy,
  bitworld/client,
  bitworld/protocol,
  tribal_village_engine,
  tribal_quest/fortress_engine

const
  PlayerSocketPath = "/player"
  StepMilliseconds = 100
  QuestViewCells = QuestAdventureCropTiles * QuestAdventureCropTiles

type
  QuestPlayerFrame* = tuple[websocket: WebSocket, frame: string]

  ViewerState = object
    slot: int
    lastMask: uint8

  SurfaceState = object
    lock: Lock
    engine: ptr FortressEngine
    tokens: seq[string]
    viewers: Table[WebSocket, ViewerState]
    closedSockets: seq[WebSocket]

  ServerThreadArgs = object
    server: ptr Server
    address: string
    port: int

var surface: SurfaceState

proc textHeaders(contentType = "text/plain; charset=utf-8"): HttpHeaders =
  result["Content-Type"] = contentType

proc queryValue(request: Request, key: string): string =
  if key in request.queryParams:
    return request.queryParams[key]
  ""

proc parseSlot(raw: string): int =
  if raw.len == 0:
    return -1
  try:
    parseInt(raw)
  except ValueError:
    -1

proc tokenSlot(token: string): int =
  for i, item in surface.tokens:
    if item == token:
      return i
  -1

proc surfaceIsInitialized(): bool {.gcsafe.} =
  {.gcsafe.}:
    result = not surface.engine.isNil

proc firstAvailableSlot(): int =
  if surface.engine.isNil:
    return -1
  var used: array[FortressAdventurerSlots, bool]
  for _, viewer in surface.viewers.pairs:
    if viewer.slot >= 0 and viewer.slot < used.len:
      used[viewer.slot] = true
  for slot in 0 ..< surface.engine[].adventurerSlots:
    if not used[slot]:
      return slot
  -1

proc claimViewerSlot(request: Request): int =
  let
    token = request.queryValue("token")
    explicitSlot = parseSlot(request.queryValue("slot"))
  if surface.tokens.len > 0:
    let tokenIndex = tokenSlot(token)
    if tokenIndex < 0:
      return -2
    if explicitSlot >= 0 and explicitSlot != tokenIndex:
      return -2
    result = tokenIndex
  else:
    result = if explicitSlot >= 0: explicitSlot else: firstAvailableSlot()
  if surface.engine.isNil or result < 0 or result >= surface.engine[].adventurerSlots:
    return -1

proc handleQuestAdventurerHttp*(request: Request): bool {.gcsafe.} =
  ## Handles Quest-owned adventurer routes for a host that already owns
  ## the Fortress engine/world. Returns false when the route is not ours.
  if request.path == PlayerSocketPath and request.httpMethod == "GET":
    result = true
    if not surfaceIsInitialized():
      request.respond(
        500,
        textHeaders(),
        "Quest adventurer surface is not initialized\n"
      )
      return
    {.gcsafe.}:
      withLock surface.lock:
        let slot = claimViewerSlot(request)
        if slot == -2:
          request.respond(403, textHeaders(), "invalid token\n")
          return
        if slot < 0:
          request.respond(400, textHeaders(), "invalid or unavailable adventurer slot\n")
          return
        let agentId = surface.engine[].claimAdventurer(slot, slot mod FortressTownTokenSlots)
        if agentId < 0:
          request.respond(409, textHeaders(), "could not claim adventurer\n")
          return
        let websocket = request.upgradeToWebSocket()
        surface.viewers[websocket] = ViewerState(slot: slot, lastMask: 0)
    return

  if request.path in [PlayerClientRoute, PlayerClientHtmlRoute] and
      request.httpMethod == "GET":
    result = true
    try:
      request.respond(
        200,
        textHeaders(clientStaticContentType(request.path)),
        readClientHtml(request.path)
      )
    except IOError:
      request.respond(404, textHeaders(), "client not found\n")
    return

  if request.path in [
      SnappyClientRoute,
      SnappyClientPath,
      QrcodeClientRoute,
      QrcodeClientPath
    ] and request.httpMethod == "GET":
    result = true
    try:
      request.respond(
        200,
        textHeaders(clientStaticContentType(request.path)),
        readFile(clientStaticPath(request.path))
      )
    except IOError:
      request.respond(404, textHeaders(), "asset not found\n")
    return

  if request.path == "/" and request.httpMethod == "GET":
    result = true
    request.respond(200, textHeaders(), "Tribal Quest Fortress player surface\n")

proc httpHandler(request: Request) {.gcsafe.} =
  if not handleQuestAdventurerHttp(request):
    request.respond(404, textHeaders(), "not found\n")

proc handleQuestAdventurerWebSocket*(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) {.gcsafe.} =
  case event
  of OpenEvent:
    discard
  of MessageEvent:
    if message.kind == BinaryMessage:
      {.gcsafe.}:
        withLock surface.lock:
          if websocket in surface.viewers:
            var viewer = surface.viewers[websocket]
            viewer.lastMask = blobToMask(message.data)
            surface.viewers[websocket] = viewer
  of ErrorEvent, CloseEvent:
    {.gcsafe.}:
      withLock surface.lock:
        surface.closedSockets.add(websocket)

proc websocketHandler(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) {.gcsafe.} =
  handleQuestAdventurerWebSocket(websocket, event, message)

proc serverThreadProc(args: ServerThreadArgs) {.thread.} =
  args.server[].serve(Port(args.port), args.address)

proc frameFromEngine(engine: var FortressEngine, slot: int): string =
  result = newString(ProtocolBytes)
  var cells: array[QuestViewCells, uint8]
  let view = engine.adventurerViewCells(slot, cells)
  if not view.ok or view.done or view.width <= 0 or view.height <= 0:
    return

  var outIndex = 0
  for py in 0 ..< ScreenHeight:
    let
      cellY = min(view.height - 1, py * view.height div ScreenHeight)
      rowStart = cellY * view.width
    var px = 0
    while px < ScreenWidth:
      let
        cellX0 = min(view.width - 1, px * view.width div ScreenWidth)
        cellX1 = min(view.width - 1, (px + 1) * view.width div ScreenWidth)
        lo = cells[rowStart + cellX0] and 0x0f
        hi = cells[rowStart + cellX1] and 0x0f
      result[outIndex] = char(lo or (hi shl 4))
      inc outIndex
      px += 2

proc pruneClosedViewers() =
  for websocket in surface.closedSockets:
    if websocket in surface.viewers:
      let slot = surface.viewers[websocket].slot
      surface.viewers.del(websocket)
      var slotStillViewed = false
      for _, viewer in surface.viewers.pairs:
        if viewer.slot == slot:
          slotStillViewed = true
          break
      if not slotStillViewed:
        discard surface.engine[].releaseAdventurer(slot)
  surface.closedSockets.setLen(0)

proc submitQuestAdventurerInputs*() =
  ## Pushes the latest Quest button masks into the shared Fortress engine.
  ## The caller owns the engine step so multiple surfaces can share one tick.
  if not surfaceIsInitialized():
    raise newException(ValueError, "Quest adventurer surface is not initialized")
  withLock surface.lock:
    pruneClosedViewers()
    for _, viewer in surface.viewers.pairs:
      surface.engine[].submitAdventurerButtons(viewer.slot, viewer.lastMask)

proc buildQuestAdventurerFrames*(): seq[QuestPlayerFrame] =
  ## Builds player frames from the current post-step Fortress engine state.
  if not surfaceIsInitialized():
    raise newException(ValueError, "Quest adventurer surface is not initialized")
  withLock surface.lock:
    pruneClosedViewers()
    for websocket, viewer in surface.viewers.pairs:
      result.add((
        websocket: websocket,
        frame: surface.engine[].frameFromEngine(viewer.slot)
      ))

proc stepAndBuildFrames(): seq[QuestPlayerFrame] =
  submitQuestAdventurerInputs()
  surface.engine[].step()
  buildQuestAdventurerFrames()

proc sendQuestAdventurerFrames*(frames: openArray[QuestPlayerFrame]) =
  ## Sends already-built frames and marks broken sockets for release.
  if not surfaceIsInitialized():
    raise newException(ValueError, "Quest adventurer surface is not initialized")
  for item in frames:
    try:
      item.websocket.send(item.frame, BinaryMessage)
    except CatchableError:
      withLock surface.lock:
        surface.closedSockets.add(item.websocket)

proc tickQuestAdventurerSurface*(): int =
  ## Convenience one-process tick: submit Quest inputs, step the shared engine,
  ## render Quest frames, and send them. Combined hosts should call the pieces.
  let frames = stepAndBuildFrames()
  sendQuestAdventurerFrames(frames)
  frames.len

proc writeJsonFile(path: string, node: JsonNode) =
  if path.len > 0:
    writeFile(path, $node)

proc runLoop(): int =
  var previousTick = getMonoTime()
  while surface.engine[].maxSteps <= 0 or surface.engine[].tick < surface.engine[].maxSteps:
    discard tickQuestAdventurerSurface()
    inc result
    let elapsed = inMilliseconds(getMonoTime() - previousTick)
    if elapsed < StepMilliseconds:
      sleep(StepMilliseconds - elapsed.int)
    previousTick = getMonoTime()

proc initQuestAdventurerSurface*(
  engine: var FortressEngine,
  tokens: seq[string]
) =
  ## Installs Quest's adventurer controls onto an existing Fortress engine.
  if tokens.len > engine.adventurerSlots:
    raise newException(ValueError, "more player tokens than adventurer slots")
  initLock(surface.lock)
  surface.engine = addr engine
  surface.tokens = tokens
  surface.viewers = initTable[WebSocket, ViewerState]()
  surface.closedSockets = @[]

proc runQuestPlayerSurface*(
  engine: var FortressEngine,
  address: string,
  port: int,
  saveReplayPath: string,
  loadReplayPath: string,
  saveScoresPath: string,
  tokens: seq[string],
  maxGames: int,
  adventurerRole: string
) =
  discard loadReplayPath
  discard maxGames
  discard adventurerRole
  initQuestAdventurerSurface(engine, tokens)

  let httpServer = newServer(
    httpHandler,
    websocketHandler,
    workerThreads = 4,
    tcpNoDelay = true
  )
  var
    serverThread: Thread[ServerThreadArgs]
    serverPtr = cast[ptr Server](unsafeAddr httpServer)
  createThread(
    serverThread,
    serverThreadProc,
    ServerThreadArgs(server: serverPtr, address: address, port: port)
  )
  httpServer.waitUntilReady()
  echo "Tribal Quest player surface listening on http://", address, ":", port

  let ticks = runLoop()
  httpServer.close()
  joinThread(serverThread)
  writeJsonFile(saveScoresPath, %*{
    "runtime": "fortress",
    "ticks": ticks,
    "adventurer_slots": engine.adventurerSlots
  })
  writeJsonFile(saveReplayPath, %*{
    "runtime": "fortress",
    "ticks": ticks
  })
