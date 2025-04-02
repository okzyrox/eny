## eny
## 
## cc: okzyrox
import raylib
import std/[tables, strutils, strformat, json, sequtils, os]

import ./[
  hit_rating,
  chart,
  notes
]

const
  # base song scroll speed (for 1x)
  ScrollSpeed = 450.0  # Pix/s, mult 0.5x-2.5x in chart data
  KeyboardBinds: Table[KeyboardKey, int] = {
    KeyboardKey.D: 0,
    KeyboardKey.F: 1,
    KeyboardKey.J: 2,
    KeyboardKey.K: 3
  }.toTable

var notePressedStates: Table[int, bool] = {
  0: false,
  1: false,
  2: false,
  3: false
}.toTable

var keyPressedThisFrame: Table[int, bool] = {
  0: false,
  1: false,
  2: false,
  3: false
}.toTable

var playerScoreData: Table[string, int] = {
  "perfect": 0,
  "great": 0,
  "good": 0,
  "ok": 0,
  "bad": 0,
  "miss": 0
}.toTable

var playerHitCount: Table[int, int] = {
  0: 0,
  1: 0,
  2: 0,
  3: 0
}.toTable

var isRecording = false
var activeNoteDrawTable: Table[int, ref Note]
var inactiveNoteDrawTable: Table[int, ref Note]
var recentHits: seq[HitFeedback] = @[]

proc loadEnyData(): JsonNode =
  if not fileExists("eny.json"):
    echo "eny.json not found, creating default file"
    let defaultData = newJObject()
    defaultData["chartToLoad"] = %"recordedtest"
    defaultData["recordingMode"] = %false
    defaultData["recordingModeSong"] = %"testsong"
    defaultData["scrollSpeed"] = %1.5

    writeFile("eny.json", pretty(defaultData))
    echo "Default eny.json created"
    return defaultData
  else:
    let jsonContent = readFile("eny.json")
    let jsonNode = parseJson(jsonContent)
    return jsonNode

proc updateKeyStates() =
  for key, index in KeyboardBinds:
    notePressedStates[index] = isKeyDown(key)
    keyPressedThisFrame[index] = isKeyPressed(key)

proc drawRecordingUI(recordedNotes: seq[RecordedNote]) = 
  let recordingText = "RECORDING"
  let textWidth = measureText(recordingText, 20)
  drawText(recordingText, int32(getScreenWidth() - textWidth - 10), 10, 20, Red)
  drawText("Press G to save", int32(getScreenWidth() - measureText("Press G to save", 16) - 10), 35, 16, Red)
  drawText(fmt"Total Notes: {recordedNotes.len}", 10, 70, 20, Black)

proc drawPlayerStats(playerScore: int) =
  drawText(fmt"Score: {playerScore}", 10, 70, 20, DarkGreen)
  let statY = 100
  let perfectText = "PERFECT: " & $playerScoreData["perfect"]
  let greatText = "GREAT: " & $playerScoreData["great"]
  let goodText = "GOOD: " & $playerScoreData["good"]
  let okText = "OK: " & $playerScoreData["ok"]
  let badText = "BAD: " & $playerScoreData["bad"]
  let missText = "MISS: " & $playerScoreData["miss"]
  drawText(perfectText, 10, int32(statY), 16, getRatingColor(hrPerfect))
  drawText(greatText, 10, int32(statY + 20), 16, getRatingColor(hrGreat))
  drawText(goodText, 10, int32(statY + 40), 16, getRatingColor(hrGood))
  drawText(okText, 10, int32(statY + 60), 16, getRatingColor(hrOk))
  drawText(badText, 10, int32(statY + 80), 16, getRatingColor(hrBad))
  drawText(missText, 10, int32(statY + 100), 16, getRatingColor(hrMiss))

proc drawReceptors(startX: int, receptorY: int, totalNotesWidth: int, noteSpacing: int, receptorLineY: int, receptorLineHeight: int, noteTextY: int) =
  drawRectangle(
    int32(startX - 10), 
    int32(receptorLineY), 
    int32(totalNotesWidth + 20), 
    int32(receptorLineHeight), 
    fade(DarkBlue, 0.6)
  )
  drawRectangle(
    int32(startX - 10), 
    int32(receptorY), 
    int32(totalNotesWidth + 20), 
    int32(receptorLineHeight), 
    fade(Blue, 0.6)
  )
    
    
  # Draw receptors
  for i in 0..<inactiveNoteDrawTable.len:
    let noteX = startX + (i * (SpriteUpscale + noteSpacing))
    
    if notePressedStates.hasKey(i) and notePressedStates[i]:
      drawTexture(activeNoteDrawTable[i].texture, int32(noteX), int32(receptorY) - 20, White)
    else:
      drawTexture(inactiveNoteDrawTable[i].texture, int32(noteX), int32(receptorY) - 20, White)
    
    let keyName = case i:
      of 0: "D"
      of 1: "F"
      of 2: "J"
      of 3: "K"
      else: ""
    
    let textWidth = measureText(keyName, 20)
    let textX = noteX + (SpriteUpscale - textWidth) div 2
    drawText(keyName, int32(textX), int32(noteTextY), 20, White)

proc drawHitRatings(startX: int, noteSpacing: int, receptorY: int) = 
  for hit in recentHits:
    let noteX = startX + (hit.column * (SpriteUpscale + noteSpacing))
    let ratingText = case hit.rating:
      of hrPerfect: "PERFECT"
      of hrGreat: "GREAT"
      of hrGood: "GOOD"
      of hrOk: "OK"
      of hrBad: "BAD"
      of hrMiss: "MISS"
    
    let textWidth = measureText(ratingText, 20)
    let textX = noteX + (SpriteUpscale - textWidth) div 2
    let textY = int32(receptorY - 40)
    let color = getRatingColor(hit.rating)
    
    let fadeColor = fade(color, hit.alpha)
    drawText(ratingText, int32(textX), textY, 20, fadeColor)

proc main() =
  initWindow(800, 600, "eny")
  setTargetFPS(60)
  initAudioDevice()
  defer: closeAudioDevice()

  var loadedNotes = loadNoteTextures("assets/image/notesheet.png")
  activeNoteDrawTable = loadedNotes["Active"]
  inactiveNoteDrawTable = loadedNotes["Inactive"]

  var chart: Chart
  var song: Music

  let config = loadEnyData()
  let isRecordingMode = config["recordingMode"].getBool()
  let recordingModeSong = config["recordingModeSong"].getStr()
  let songScrollSpeed = config["scrollSpeed"].getFloat()
  
  if isRecordingMode:
    chart = new Chart
    chart.songPath = recordingModeSong
    chart.notes = @[]
    
    if not fileExists("assets/music/" & chart.songPath & ".mp3"):
      echo "Song file not found for recording: ", chart.songPath
      return
      
    song = loadMusicStream("assets/music/" & chart.songPath & ".mp3")
    setMusicVolume(song, 0.5)
  else:
    var chartSongName = config["chartToLoad"].getStr() 
    chart = loadChart("assets/chart/" & chartSongName & ".json")
    if chart == nil:
      echo "Failed to load chart"
      return
    if not fileExists("assets/music/" & chart.songPath & ".mp3"):
      echo "Song file not found: ", chart.songPath
      return
    song = loadMusicStream("assets/music/" & chart.songPath & ".mp3")
    setMusicVolume(song, 0.5)
  
  chart.startTime = -3.0
  
  let noteSpacing = 24
  let totalNotesWidth = (inactiveNoteDrawTable.len * SpriteUpscale) + ((inactiveNoteDrawTable.len - 1) * noteSpacing)
  let startX = (getScreenWidth() - totalNotesWidth) div 2
  let receptorY = getScreenHeight() - SpriteUpscale - 80
  let noteTextY = receptorY + 70

  let receptorLineY = receptorY + 30
  let receptorLineHeight = 4

  var gameTime = 0.0
  var songStarted = false
  var score = 0
  
  var recordedNotes: seq[RecordedNote] = @[]
  isRecording = isRecordingMode

  let chartScrollSpeed = ScrollSpeed * songScrollSpeed
  
  # notes missed
  var notesToCheck: seq[ChartNote] = @[]

  while not windowShouldClose():
    let deltaTime = getFrameTime()
    gameTime += deltaTime
    
    updateKeyStates()

    let songPosition = gameTime + chart.startTime

    if songPosition >= 0 and not songStarted:
      playMusicStream(song)
      songStarted = true
    
    if songStarted:
      updateMusicStream(song)
    
    # Recording mode
    if isRecording and songPosition >= 0:
      for key, index in KeyboardBinds:
        if keyPressedThisFrame[index]:
          recordedNotes.add(RecordedNote(column: index, time: songPosition))
    
    if isRecording and isKeyPressed(KeyboardKey.G):
      saveRecordedChart(recordedNotes, chart.songPath)
      isRecording = false
    
    if not isRecording:
      notesToCheck.setLen(0)
      
      for note in chart.notes:
        if note.hit:
          continue
          
        let timeToHit = note.time - songPosition
        note.position = float(receptorY) - (timeToHit * chartScrollSpeed)
        
        if abs(timeToHit) < BadWindowMs / 1000.0:
          if keyPressedThisFrame[note.columnIndex]:
            note.hit = true
            playerHitCount[note.columnIndex] += 1
            
            # hit rating
            let timeDiffMs = timeToHit * 1000.0
            let rating = getHitRating(timeDiffMs)
            let points = getScorePoints(rating)
            score += points
            
            # Update score
            case rating:
              of hrPerfect: playerScoreData["perfect"] += 1
              of hrGreat: playerScoreData["great"] += 1
              of hrGood: playerScoreData["good"] += 1
              of hrOk: playerScoreData["ok"] += 1
              of hrBad: playerScoreData["bad"] += 1
              of hrMiss: playerScoreData["miss"] += 1
            
            recentHits.add(HitFeedback(
              rating: rating,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
        
        # check for misses
        elif timeToHit < -BadWindowMs / 1000.0 and note.position > float(receptorY + SpriteUpscale):
          notesToCheck.add(note)
      
      for i in countdown(recentHits.len - 1, 0):
        recentHits[i].time += deltaTime
        recentHits[i].alpha = 1.0 - (recentHits[i].time / 0.8)
        
        if recentHits[i].alpha <= 0:
          recentHits.delete(i)
      
      for note in notesToCheck:
        if not note.hit:
          note.hit = true
          playerScoreData["miss"] += 1
      
      chart.notes.keepItIf(not it.hit or it.position > -200)
    
    beginDrawing()
    clearBackground(Gray)
    drawFPS(10, 10)
    
    let songTitle = chart.songPath
    let titleWidth = measureText(songTitle, 24)
    drawText(songTitle, int32((getScreenWidth() - titleWidth) div 2), 20, 24, DarkBlue)
    
    # Record UI
    if isRecording:
      drawRecordingUI(recordedNotes)
    
    # Countdown
    if songPosition < 0:
      let countdownText = $(-int(songPosition) + 1)
      let textWidth = measureText(countdownText, 40)
      drawText(countdownText, int32((getScreenWidth() - textWidth) div 2), 100, 40, Red)
    else:
      # stats
      drawText(fmt"Time: {songPosition:.2f}s", 10, 40, 20, Black)
      
      # Score breakdown
      if not isRecording:
        drawPlayerStats(score)
    
    drawReceptors(
      startX, 
      receptorY, 
      totalNotesWidth, 
      noteSpacing, 
      receptorLineY, 
      receptorLineHeight, 
      noteTextY
    )
    
    # hit rating
    drawHitRatings(startX, noteSpacing, receptorY)
    
    # Fallin notes
    if not isRecording:
      for note in chart.notes:
        if not note.hit and note.position > -100:
          let noteX = startX + (note.columnIndex * (SpriteUpscale + noteSpacing))
          drawTexture(inactiveNoteDrawTable[note.columnIndex].texture, int32(noteX), int32(note.position), White)
    
    endDrawing()

  closeWindow()

main()