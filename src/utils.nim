import std/[strutils, strformat, os, tables, options]

import discord_rpc

import raylib

const 
  EnyVersionText* {.strdefine.} = "v0.1.0"
  EnyCommitText* {.strdefine.} = "000000"
  VersionText* = EnyVersionText & "-" & EnyCommitText

const
  BackgroundColor* = Color(r: 48, g: 25, b: 52, a: 255)
  BackgroundColor2* = Color(r: 30, g: 10, b: 20, a: 255)
  BackgroundColor3* = Color(r: 15, g: 15, b: 25, a: 255)
  BackgroundColor4* = Color(r: 41, g: 8, b: 47, a: 255)
  AccentColor* = Color(r: 230, g: 230, b: 250, a: 255)
  AccentColor2* = Color(r: 207, g: 159, b: 255, a: 255)
  TextColor* = Color(r: 239, g: 209, b: 229, a: 255)
  MiscTextColor* = Color(r: 150, g: 150, b: 150, a: 255)
  EnyPink* = Color(r: 229, g: 88, b: 170 , a: 255)

const
  # hit feedback colors
  PerfectColor* = Color(r: 255, g: 215, b: 0, a: 255)
  GreatColor* = Color(r: 50, g: 205, b: 50, a: 255)
  GoodColor* = Color(r: 30, g: 144, b: 255, a: 255)
  OkColor* = Color(r: 255, g: 165, b: 0, a: 255)
  BadColor* = Color(r: 178, g: 34, b: 34, a: 255)
  MissColor* = Color(r: 169, g: 169, b: 169, a: 255)

const
  BaseScreenWidth* = 1280
  BaseScreenHeight* = 720

# scaling

proc getScaleFactors*(): (float, float) =
  let
    windowWidth = getScreenWidth().float
    windowHeight = getScreenHeight().float
  result = (windowWidth / BaseScreenWidth, windowHeight / BaseScreenHeight)

proc scaleX*(x: float, scaleX: float): float = 
  result = x * scaleX
proc scaleY*(y: float, scaleY: float): float = 
  result = y * scaleY
proc scaleFont*(size: int, scale: float): int = 
  result = max(12, int(size.float * scale))

# resources

var contentFolderPath*: string = "content"
var assetFolderPath*: string = "assets"

var currentFontName*: string = ""
var fontCache*: Table[string, Font] = initTable[string, Font]()

proc setCurrentFont*(fontName: string) =
  if fontCache.hasKey(fontName):
    currentFontName = fontName
  else:
    echo "Font not found in cache: " & fontName
    echo "Using default font"
    currentFontName = ""

proc getLoadedFonts*(): seq[string] =
  result = @[]
  for fontName in fontCache.keys:
    result.add(fontName)

proc loadFontToCache*(fontName, fontFileName: string) =
  let path = assetFolderPath & "/font/" & fontFileName
  if not fileExists(path):
    echo "Font file not found: " & path
    quit(1)
  try:
    var font = loadFont(path)
    setTextureFilter(font.texture, Trilinear) # antialiasing
    fontCache[fontName] = font
  except Exception as e:
    echo "Error loading font: " & e.msg
    quit(1)

proc drawFText*(text: string, x, y: int32, textSize: int32, color: Color) =
  let position = Vector2(x: x.float32, y: y.float32)
  if currentFontName == "":
    drawText(text, x, y, textSize.int32, color)
  else:
    drawText(fontCache[currentFontName], text, position, textSize.float32, 0.0, color)

proc drawFText*(fontName, text: string, x, y: int32, textSize: int32, color: Color) =
  if fontCache.hasKey(fontName):
    drawText(fontCache[fontName], text, Vector2(x: x.float32, y: y.float32), textSize.float32, 0.0, color)
  else:
    echo "Font not found in cache: " & fontName
    echo "Using default font"

proc drawDualText*(text1, text2: string, x, y: int32, textSize: int32, spacing: int32, color1, color2: Color) =
  let textWidth1 = measureText(text1, textSize)
  let reduced = if textWidth1 <= 64: 8 else: 0
  let spacing = int32(spacing - reduced)
  
  drawFText(text1, x, y, textSize, color1)
  drawFText(text2, (x + textWidth1 + spacing), y, textSize, color2)

proc drawDualText*(fontName, text1, text2: string, x, y: int32, textSize: int32, spacing: int32, color1, color2: Color) =
  let textWidth1 = measureText(fontCache[fontName], text1, textSize.float32, 0.0)
  let reduced = if textWidth1.x.int32 <= 64: 4 else: 0
  let spacing = int32(spacing - reduced)
  
  drawFText(fontName, text1, x, y, textSize, color1)
  drawFText(fontName, text2, (x + textWidth1.x.int32 + spacing), y, textSize, color2)


#ext

proc formatTime*(seconds: float): string =
  let totalSeconds = int(seconds)
  let hours = totalSeconds div 3600
  let minutes = (totalSeconds mod 3600) div 60
  let seconds = totalSeconds mod 60
  if hours > 0:
    return &"{hours:02}:{minutes:02}:{seconds:02}"
  else:
    return &"{minutes:02}:{seconds:02}"

# rich presence

type ActivityType* = enum # simplify
  Normal
  ProgressBar

proc getActivityKind*(activityType: ActivityType): ActivityKind =
  case activityType:
    of Normal: result = ActivityKind.Playing
    of ProgressBar: result = ActivityKind.Listening

const BlankTimestamps = none(ActivityTimestamps)
proc setActivity*(presence: DiscordRPC, details: string, state: string, activityType: ActivityType, largeImage: string = "eny", largeText: string = "", timestamps: Option[ActivityTimestamps] = BlankTimestamps) =
  try:
    if timestamps.isNone:
      presence.setActivity Activity(
        details: details,
        state: state,
        activityType: some getActivityKind(activityType),
        assets: some ActivityAssets(
          largeImage: largeImage,
          largeText: largeText
        )
      )
    else:
      presence.setActivity Activity(
        details: details,
        state: state,
        timestamps: timestamps.get(),
        activityType: some getActivityKind(activityType),
        assets: some ActivityAssets(
          largeImage: largeImage,
          largeText: largeText
        )
      )
  except Exception as e:
    echo "Error setting Discord activity: ", e.msg