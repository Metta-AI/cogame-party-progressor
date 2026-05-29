const
  PlayerClientRoute* = "/client/player"
  PlayerClientHtmlRoute* = "/client/player.html"
  SnappyClientRoute* = "/snappyjs.min.js"
  SnappyClientPath* = "/client/snappyjs.min.js"

  EmbeddedPlayerClientHtml = staticRead("client_assets/player_client.html")
  EmbeddedSnappyClientJs = staticRead("client_assets/snappyjs.min.js")

proc clientRoute(route: string): string =
  case route
  of PlayerClientRoute, PlayerClientHtmlRoute, "/client/player_client.html":
    PlayerClientRoute
  of SnappyClientPath:
    SnappyClientRoute
  else:
    route

proc clientStaticContentType*(route: string): string =
  case clientRoute(route)
  of SnappyClientRoute:
    "application/javascript; charset=utf-8"
  else:
    "text/html; charset=utf-8"

proc clientStaticBody*(route: string): string =
  case clientRoute(route)
  of PlayerClientRoute:
    EmbeddedPlayerClientHtml
  of SnappyClientRoute:
    EmbeddedSnappyClientJs
  else:
    ""

proc readClientHtml*(route: string): string {.raises: [IOError].} =
  let body = clientStaticBody(route)
  if body.len == 0:
    raise newException(IOError, "unknown client route: " & route)
  body
