import chart, config, hit_rating
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

  # menu/ui
  TitleSize* = 60
  TitlePadding* = 50
  LongTitleLength* = 40 # todo: make dynamic of screenwidth

  # discord presence
  PresenceAppID* = 1358181398514630958
  PresenceUpdateInterval* = 2.5

var currentState*: GameState = MainMenu
var currentChart*: Chart
var currentConfig*: EnyConfig
var currentSong*: Music
var currentResults*: GameResults
var discordPresence*: DiscordRPC
var lastPresenceUpdateTime*: float = 0.0
var debugInfoShown*: bool = false
var isRecording*: bool = false
var songStarted*: bool = false
var songPaused*: bool = false
var songEnded*: bool = false
var songFading*: bool = false
var songFadeStartTime*: float = 0.0
var songFadeDuration*: float = 3.5
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
  
  discordPresence.setActivity Activity(
    details: "eny - Playing",
    state: accuracyText,
    timestamps: timestamps,
    activityType: some ActivityKind.Listening,
    assets: some ActivityAssets(
      largeImage: "eny",
      largeText: fmt"Playing {songName}"
    )
  )

proc updateResultsPresence*() =
  if currentChart == nil:
    return
  
  # final score info
  let scoreText = fmt"Score: {currentResults.score} • {currentResults.accuracy:.2f}%"
  let comboText = fmt"Max Combo: {currentResults.maxCombo}x"
  try:
    discordPresence.setActivity Activity(
      details: "eny - Results",
      state: scoreText,
      assets: some ActivityAssets(
        largeImage: "eny",
        largeText: comboText
      )
    )
  except Exception as e:
    echo "Error setting Discord activity: ", e.msg

proc setState*(state: GameState) =
  currentState = state
  case state:
    of MainMenu:
      activityStartTime = 0
      activityEndTime = 0
      try:
        discordPresence.setActivity Activity(
          details: "eny - On the menu",
          state: "Browsing charts",
          assets: some ActivityAssets(
            largeImage: "eny",
            largeText: "Playing eny"
          )
        )
      except Exception as e:
        echo "Error setting Discord activity: ", e.msg
    of Playing:
      try:
        discordPresence.setActivity Activity(
          details: "eny - Loading song...",
          state: "Getting ready to play",
          assets: some ActivityAssets(
            largeImage: "eny",
            largeText: "Playing eny"
          )
        )
      except Exception as e:
        echo "Error setting Discord activity: ", e.msg
    of Results:
      activityStartTime = 0
      activityEndTime = 0
      updateResultsPresence()
    of Recording:
      try:
        discordPresence.setActivity Activity(
          details: "eny - Recording a chart",
          state: "Recording notes...",
          assets: some ActivityAssets(
            largeImage: "eny",
            largeText: "Playing eny"
          )
        )
      except Exception as e:
        echo "Error setting Discord activity: ", e.msg

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
proc drawDebugInfo*() =
  let toggleTextPosition = if not debugInfoShown: getScreenHeight() - startY + 10 else: getScreenHeight() - startY - 20
  drawText("Press `P` to toggle debug info", 10, toggleTextPosition, 18, MiscTextColor)
  if not debugInfoShown:
    return
  else:
    drawText("Debug Info:", 10, getScreenHeight() - startY + 10, 18, Yellow)
    drawFPS(10, getScreenHeight() - startY + 30)
    drawText(fmt"songStarted: {songStarted}", 10, getScreenHeight() - startY + 50, 16, White)
    drawText(fmt"songEnded: {songEnded}", 10, getScreenHeight() - startY + 70, 16, White)
    drawText(fmt"chartLength: {chartLength}", 10, getScreenHeight() - startY + 90, 16, White)
    drawText(fmt"songPosition: {songPosition}", 10, getScreenHeight() - startY + 110, 16, White)
    drawText(fmt"currentState: {currentState}", 10, getScreenHeight() - startY + 130, 16, White)
    drawText(fmt"isRecording: {isRecording}", 10, getScreenHeight() - startY + 150, 16, White)
    if currentChart != nil:
      drawText(fmt"currentChart.notes.len: {currentChart.notes.len}", 10, getScreenHeight() - startY + 170, 16, White)
      drawText(fmt"currentChart.songPath: {currentChart.songPath}", 10, getScreenHeight() - startY + 190, 16, White)
      drawText(fmt"currentResults: {currentResults}", 10, getScreenHeight() - startY + 210, 16, White)
      drawText(fmt"playerHitCount (1, 2, 3, 4): {playerHitCount[0]}, {playerHitCount[1]}, {playerHitCount[2]}, {playerHitCount[3]}", 10, getScreenHeight() - startY + 230, 16, White)
    else:
      if currentState == MainMenu:
        drawText(fmt"cachedPreviewLength: {previewMusicCache.len}", 10, getScreenHeight() - startY + 170, 16, White)
        drawText(fmt"currentPreviewSong: {currentPreviewSong}", 10, getScreenHeight() - startY + 190, 16, White)

