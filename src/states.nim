import chart, config, hit_rating
import raylib 
import discord_rpc
import std/[os, options, tables, strformat]
type
  GameState* = enum
    MainMenu, Playing, Results, Recording

type
  GameResults* = object
    score*: int
    currentCombo*: int
    maxCombo*: int
    accuracy*: float
    perfect*: int
    great*: int
    good*: int
    ok*: int
    bad*: int
    miss*: int

proc `$`*(results: GameResults): string =
  return fmt"Score: {results.score}, Max Combo: {results.maxCombo}, Current Combo: {results.currentCombo}, Accuracy: {results.accuracy}, Perfect: {results.perfect}, Great: {results.great}, Good: {results.good}, OK: {results.ok}, Bad: {results.bad}, Miss: {results.miss}"


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

var currentState*: GameState = MainMenu
var currentChart*: Chart
var currentConfig*: EnyConfig
var currentSong*: Music
var currentResults*: GameResults
var discordPresence*: DiscordRPC
var isRecording*: bool = false
var songStarted*: bool = false
var songPaused*: bool = false
var songEnded*: bool = false
var songPosition*: float = 0.0
var gameTime*: float = 0.0
var chartLength*: float = 0.0
var recentHits*: seq[HitFeedback] = newSeqOfCap[HitFeedback](128)

var playerHitCount*: Table[int, int] = {
  0: 0,
  1: 0,
  2: 0,
  3: 0
}.toTable

var holdStartTimes*: Table[int, float] = {
  0: -1.0,
  1: -1.0,
  2: -1.0,
  3: -1.0
}.toTable

var lastHitNotes*: Table[int, float] = {
  0: -1000.0,
  1: -1000.0,
  2: -1000.0,
  3: -1000.0
}.toTable

proc loadSong*(filePath: string) =
  if isRecording:
    currentChart = new Chart
    currentChart.songPath = filePath
    currentChart.notes = @[]
    
    if not fileExists("content/music/" & currentChart.songPath & ".mp3"):
      echo "Song file not found for recording: ", currentChart.songPath
      quit(1)
      
    currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
    setMusicVolume(currentSong, 0.5)
  # else:
    # var chartSongName = currentConfig.chartToLoad
    # currentChart = loadChart("content/chart/" & chartSongName & ".json")
    # if currentChart == nil:
    #   quit(1)
    # if not fileExists("content/music/" & currentChart.songPath & ".mp3"):
    #   echo "Song file not found: ", currentChart.songPath
    #   quit(1)
    # currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
    # setMusicVolume(currentSong, 0.5)

proc setState*(state: GameState) =
  currentState = state
  case state:
    of MainMenu:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "on the main menu",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Playing:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "playing a song",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Results:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "on the results screen",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Recording:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "recording a chart",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )

proc resetGameState*() =
  gameTime = 0.0
  songPosition = 0.0
  songStarted = false
  songEnded = false
  chartLength = 0.0
  
  for i in 0..3:
    playerHitCount[i] = 0
    holdStartTimes[i] = -1.0
    lastHitNotes[i] = -1000.0
  
  recentHits.setLen(0)
  
  if currentChart != nil:
    for note in currentChart.notes.mitems:
      note.hit = false
      note.released = false
      note.position = 0.0
    
  currentChart = nil
  
  currentResults = GameResults(
    score: 0,
    currentCombo: 0,
    maxCombo: 0,
    accuracy: 0.0,
    perfect: 0,
    great: 0,
    good: 0,
    ok: 0,
    bad: 0,
    miss: 0
  )


let startX = int32(250)
proc drawDebugInfo*() =
  drawText("Debug Info:", 10, getScreenHeight() - startX + 10, 18, Yellow)
  drawFPS(10, getScreenHeight() - startX + 30)
  drawText(fmt"songStarted: {songStarted}", 10, getScreenHeight() - startX + 50, 16, White)
  drawText(fmt"songEnded: {songEnded}", 10, getScreenHeight() - startX + 70, 16, White)
  drawText(fmt"chartLength: {chartLength}", 10, getScreenHeight() - startX + 90, 16, White)
  drawText(fmt"songPosition: {songPosition}", 10, getScreenHeight() - startX + 110, 16, White)
  drawText(fmt"currentState: {currentState}", 10, getScreenHeight() - startX + 130, 16, White)
  drawText(fmt"isRecording: {isRecording}", 10, getScreenHeight() - startX + 150, 16, White)
  if currentChart != nil:
    drawText(fmt"currentChart.notes.len: {currentChart.notes.len}", 10, getScreenHeight() - startX + 170, 16, White)
    drawText(fmt"currentChart.songPath: {currentChart.songPath}", 10, getScreenHeight() - startX + 190, 16, White)
    drawText(fmt"currentResults: {currentResults}", 10, getScreenHeight() - startX + 210, 16, White)
    drawText(fmt"playerHitCount (1, 2, 3, 4): {playerHitCount[0]}, {playerHitCount[1]}, {playerHitCount[2]}, {playerHitCount[3]}", 10, getScreenHeight() - startX + 230, 16, White)
  else:
    drawText("No chart loaded", 10, getScreenHeight() - startX + 170, 16, White)

