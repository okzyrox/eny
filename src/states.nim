## eny
## 
## cc: okzyrox
import ./[chart, config, hit_rating, utils]
import ui/[titlebar]
import raylib 
import discord_rpc
import std/[os, options, tables, strformat, times]
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
  return fmt"Score: {results.score}, Max Combo: {results.maxCombo}, Current Combo: {results.currentCombo}, Accuracy: {results.accuracy:.2f}, Perfect: {results.perfect}, Great: {results.great}, Good: {results.good}, OK: {results.ok}, Bad: {results.bad}, Miss: {results.miss}"


const
  # menu/ui
  TitleSize* = 60
  TitlePadding* = 50
  LongTitleLength* = 40 # todo: make dynamic of screenwidth

  # discord presence
  PresenceAppID* = 1358181398514630958
  PresenceUpdateInterval* = 2.5

  # transitions

  SongFadeDuration* = 2.2
  PreviewFadeDuration* = 0.85
  ResultsFadeDuration* = 1.0

var currentState*: GameState = MainMenu
var currentChart*: Chart
var currentConfig*: EnyConfig
var currentSong*: Music
var currentResults*: GameResults
var currentTitleBar*: TitleBar

# discord presence

var discordPresence*: DiscordRPC
var lastPresenceUpdateTime*: float = 0.0

# gameplay stuffs

var debugInfoShown*: bool = false
var isRecording*: bool = false
var songStarted*: bool = false
var songPaused*: bool = false
var songEnded*: bool = false
var songFading*: bool = false
var songFadeStartTime*: float = 0.0
var songEndDelay*: float = 0.0
var songPosition*: float = 0.0
var gameTime*: float = 0.0
var chartLength*: float = 0.0
var recentHits*: seq[HitFeedback] = newSeqOfCap[HitFeedback](128)

# results screen fade
var screenFadeAlpha*: float = 0.0
var resultsScreenFadeIn*: bool = false
var resultsScreenFadeStartTime*: float = 0.0

# main menu preview stuff
var previewCooldownTime*: float = 0.0
var previewCooldownDuration*: float = 0.2  # 200ms cooldown
var currentPreviewSong*: string = ""
var previewMusicCache*: Table[string, Music] = initTable[string, Music]()
var previewMusicActive*: bool = false

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

var activityStartTime*: int64 = 0
var activityEndTime*: int64 = 0
var rpcErrorCount*: int64 = 0
proc updatePlayingPresence*() =
  if currentChart == nil:
    return
    
  let songName = if currentChart.songTitle.len > 0: currentChart.songTitle else: currentChart.songPath
  
  # accuracy and combo
  let accuracyText = fmt"{currentResults.accuracy:.2f}% • {currentResults.currentCombo}x"
  if activityStartTime == 0:
    activityStartTime = times.getTime().toUnix()
  if activityEndTime == 0:
    activityEndTime = activityStartTime + int64(chartLength)

  # progress bar info
  var timestamps = ActivityTimestamps(
    start: activityStartTime,
    finish: activityEndTime
  )
  let stateText = fmt"Playing {songName}"
  setActivity(
    discordPresence,
    "eny - Playing",
    accuracyText,
    ProgressBar,
    "eny",
    stateText,
    some timestamps
  )

proc updateResultsPresence*() =
  if currentChart == nil:
    return
  
  # final score info
  let scoreText = fmt"Score: {currentResults.score} • {currentResults.accuracy:.2f}%"
  let comboText = fmt"Max Combo: {currentResults.maxCombo}x"
  setActivity(
    discordPresence,
    "eny - Results",
    scoreText,
    Normal,
    "eny",
    comboText
  )

proc setState*(state: GameState) =
  currentState = state
  case state:
    of MainMenu:
      activityStartTime = 0
      activityEndTime = 0
      setActivity(
        discordPresence,
        "eny - On the menu",
        "Browsing charts",
        Normal,
        "eny",
        "Playing eny"
      )
      currentTitleBar.setTitle("eny - Main Menu")
    of Playing:
      setActivity(
        discordPresence,
        "eny - Loading song...",
        "Getting ready to play",
        Normal,
        "eny",
        "Playing eny"
      )
      currentTitleBar.setTitle("eny")
    of Results:
      activityStartTime = 0
      activityEndTime = 0
      updateResultsPresence()
    of Recording:
      setActivity(
        discordPresence,
        "eny - Recording a chart",
        "Recording notes...",
        Normal,
        "eny",
        "Playing eny"
      )
      currentTitleBar.setTitle("eny - Recording")

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

proc resetResultsScreenFade*() =
  songFading = false
  songFadeStartTime = 0.0
  screenFadeAlpha = 0.0
  resultsScreenFadeIn = false

let startY = int32(260)
let baseFont = 18
let smallFont = 16
proc drawDebugInfo*() =
  let (sx, sy) = getScaleFactors()
  let baseX = 10.0
  let baseY = float(getScreenHeight()) - scaleY(startY.float, sy)

  let fontSize = scaleFont(baseFont, sy).int32
  let smallFontSize = scaleFont(smallFont, sy).int32
  let lineHeight = scaleY(22, sy) # adjust as needed

  let scaleXPos = scaleX(baseX, sx).int32
  let scaleYPos = scaleY(baseY, sy).int32

  let toggleTextYPosition = if not debugInfoShown: 0.0 else: -20.0
  drawFText("Press `P` to toggle debug info", scaleXPos, (baseY + scaleY(toggleTextYPosition, sy)).int32, fontSize.int32, MiscTextColor)
  if not debugInfoShown:
    return
  else:
    drawFText("Debug Info:", scaleXPos, (baseY + scaleY(10, sy)).int32, fontSize, Yellow)
    drawFPS(scaleXPos, (baseY + scaleY(30, sy)).int32)
    drawDualText("songStarted:", $songStarted, scaleXPos, (baseY + scaleY(50, sy)).int32, 16, 8, White, Yellow)
    drawDualText("songEnded:", $songEnded, scaleXPos, (baseY + scaleY(70, sy)).int32, 16, 8, White, Yellow)
    drawDualText("chartLength:", $chartLength, scaleXPos, (baseY + scaleY(90, sy)).int32, 16, 8, White, Yellow)
    drawDualText("songPosition:", $songPosition, scaleXPos, (baseY + scaleY(110, sy)).int32, 16, 8, White, Yellow)
    drawDualText("currentState:", $currentState, scaleXPos, (baseY + scaleY(130, sy)).int32, 16, 8, White, Yellow)
    drawDualText("isRecording:", $isRecording, scaleXPos,(baseY + scaleY(150, sy)).int32, 16, 8, White, Yellow)
    if currentChart != nil:
      drawDualText("currentChart.notes.len:", $currentChart.notes.len, scaleXPos, (baseY + scaleY(170, sy)).int32, 16, 8, White, AccentColor2)
      drawDualText("currentChart.songPath:", $currentChart.songPath, scaleXPos, (baseY + scaleY(190, sy)).int32, 16, 8, White, AccentColor2)
      drawDualText("currentResults:", $currentResults, scaleXPos, (baseY + scaleY(210, sy)).int32, 16, 8, White, AccentColor2)
      let playerHitCountText = fmt"{playerHitCount[0]}, {playerHitCount[1]}, {playerHitCount[2]}, {playerHitCount[3]}"
      drawDualText("playerHitCount (1, 2, 3, 4):", playerHitCountText, scaleXPos, (baseY + scaleY(230, sy)).int32, 16, 8, White, AccentColor2)
    else:
      if currentState == MainMenu:
        drawDualText("cachedPreviewLength:", $previewMusicCache.len, scaleXPos, (baseY + scaleY(170, sy)).int32, 16, 8, White, AccentColor)
        drawDualText("currentPreviewSong:", $currentPreviewSong, scaleXPos, (baseY + scaleY(190, sy)).int32, 16, 8, White, AccentColor)
        drawDualText("currentFontName:", $currentFontName, scaleXPos, (baseY + scaleY(210, sy)).int32, 16, 8, White, AccentColor)

