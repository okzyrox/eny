## eny
## 
## cc: okzyrox
import raylib
import std/[tables, strformat, sequtils, os, math]

import ./[
  hit_rating,
  chart,
  notes,
  config
]

const
  # base song scroll speed (for 1x)
  ScrollSpeed = 450.0  # Pix/s, mult 0.5x-2.5x in chart data

var
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

var holdStartTimes: Table[int, float] = {
  0: -1.0,
  1: -1.0,
  2: -1.0,
  3: -1.0
}.toTable

var keyReleasedThisFrame: Table[int, bool] = {
  0: false,
  1: false,
  2: false,
  3: false
}.toTable

var prevNotePressedStates: Table[int, bool] = {
  0: false,
  1: false,
  2: false,
  3: false
}.toTable

var currentChart: Chart
var currentSong: Music
var currentConfig: EnyConfig

var isRecording = false
var activeNoteDrawTable: Table[int, ref Note]
var inactiveNoteDrawTable: Table[int, ref Note]
var recentHits: seq[HitFeedback] = @[]
var recordedNotes: seq[RecordedNote] = @[]

proc updateKeyStates() =
  for key, index in KeyboardBinds:
    prevNotePressedStates[index] = notePressedStates[index]
    
    notePressedStates[index] = isKeyDown(key)
    keyPressedThisFrame[index] = isKeyPressed(key)
    
    # key release
    keyReleasedThisFrame[index] = prevNotePressedStates[index] and not notePressedStates[index]

proc drawRecordingUI(recordedNotes: seq[RecordedNote]) = 
  let recordingText = "RECORDING"
  let textWidth = measureText(recordingText, 20)
  let screenWidth = int32(getScreenWidth())
  drawText(recordingText, int32(screenWidth - textWidth - 10), 10, 20, Red)
  drawText("Press G to save", int32(screenWidth - measureText("Press G to save", 16) - 10), 35, 16, Red)
  drawText(fmt"Total Notes: {recordedNotes.len}", 10, 70, 20, Black)

proc drawPlayerStats(playerScore: int) =
  drawText(fmt"Score: {playerScore}", 10, 70, 20, DarkGreen)
  let statY = int32(100)
  let perfectText = "PERFECT: " & $playerScoreData["perfect"]
  let greatText = "GREAT: " & $playerScoreData["great"]
  let goodText = "GOOD: " & $playerScoreData["good"]
  let okText = "OK: " & $playerScoreData["ok"]
  let badText = "BAD: " & $playerScoreData["bad"]
  let missText = "MISS: " & $playerScoreData["miss"]
  drawText(perfectText, 10, statY, 16, getRatingColor(hrPerfect))
  drawText(greatText, 10, statY + 20, 16, getRatingColor(hrGreat))
  drawText(goodText, 10, statY + 40, 16, getRatingColor(hrGood))
  drawText(okText, 10, statY + 60, 16, getRatingColor(hrOk))
  drawText(badText, 10, statY + 80, 16, getRatingColor(hrBad))
  drawText(missText, 10, statY + 100, 16, getRatingColor(hrMiss))

proc drawReceptors(startX: int, receptorY: int, totalNotesWidth: int, noteSpacing: int, receptorLineY: int, receptorLineHeight: int, noteTextY: int) =
  let receptorLineY32 = int32(receptorLineY)
  let receptorY32 = int32(receptorY)
  let receptorLineHeight32 = int32(receptorLineHeight)
  let startX32 = int32(startX)
  let totalNotesWidth32 = int32(totalNotesWidth)

  let halfScale = int32(SpriteUpscale / 2)
  let quarterScale = int32(SpriteUpscale / 4)
  drawRectangle(
    startX32 - 10, 
    receptorLineY32, 
    totalNotesWidth32 + 20, 
    receptorLineHeight32, 
    fade(DarkBlue, 0.6)
  )
  drawRectangle(
    startX32 - 10, 
    receptorY32, 
    totalNotesWidth32 + 20, 
    receptorLineHeight32, 
    fade(Blue, 0.6)
  )
    
    
  # Draw receptors
  for i in 0..<inactiveNoteDrawTable.len:
    let noteX = startX32 + int32(i * (SpriteUpscale + noteSpacing))
    
    var isActiveHold = false
    if not isRecording:
      for note in currentChart.notes:
        if note.columnIndex == i and note.isHoldNote and note.hit and not note.released:
          isActiveHold = true
          break
    
    if (notePressedStates.hasKey(i) and notePressedStates[i]) or isActiveHold:
      drawTexture(activeNoteDrawTable[i].texture, noteX, receptorY32 - 20, White)
      
      if isActiveHold:
        drawRectangle(
          noteX + quarterScale, 
          receptorY32 - 5,
          halfScale,
          int32(10),
          fade(colorFromHSV(float(i * 60), 0.7, 0.9), 0.8)
        )
    else:
      drawTexture(inactiveNoteDrawTable[i].texture, noteX, receptorY32 - 20, White)
    
    let keyName = case i:
      of 0: currentConfig.keybinds[0]
      of 1: currentConfig.keybinds[1]
      of 2: currentConfig.keybinds[2]
      of 3: currentConfig.keybinds[3]
      else: ""
    
    let textWidth = measureText(keyName, 20)
    let textX = int32(noteX + (SpriteUpscale - textWidth) div 2)
    drawText(keyName, textX, int32(noteTextY), 20, White)

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

proc drawNotes(startX: int, noteSpacing: int, chartScrollSpeed: float, receptorY: int) =
  for note in currentChart.notes:
    if not note.hit or (note.isHoldNote and (not note.released)):
      if note.position > -100:
        let noteX = int32(startX + (note.columnIndex * (SpriteUpscale + noteSpacing)))
        let halfScale = int32(SpriteUpscale / 2)
        let quarterScale = int32(SpriteUpscale / 4)
        
        if note.isHoldNote:
          let holdEndPosition = int32(note.position - (note.length * chartScrollSpeed))
          let noteColour = colorFromHSV(float(note.columnIndex * 60))
          if not note.hit:
            let holdHeight = int32(note.position - holdEndPosition)
            
            if holdHeight > 0:
              drawRectangle(
                noteX + quarterScale, 
                holdEndPosition + halfScale,
                halfScale,
                holdHeight - halfScale,
                fade(noteColour, 0.7, 0.9), 0.6)
              )
              
              drawRectangle(
                noteX, 
                holdEndPosition,
                int32(SpriteUpscale),
                quarterScale,
                fade(White, 0.8)
              )
          else:
            let visibleHeight = float(receptorY) - holdEndPosition
            
            if visibleHeight > 0:
              drawRectangle(
                noteX + quarterScale, 
                holdEndPosition + halfScale,
                halfScale,
                int32(float(receptorY) - holdEndPosition - halfScale),
                fade(noteColour, 0.7, 0.9), 0.6)
              )
              
              drawRectangle(
                noteX, 
                holdEndPosition,
                int32(SpriteUpscale),
                quarterScale,
                fade(White, 0.8)
              )
        # note head
        if not note.hit:
          drawTexture(inactiveNoteDrawTable[note.columnIndex].texture, noteX, int32(note.position), White)


proc updateRecording(songPosition: float) =
  for key, index in KeyboardBinds:
    if keyPressedThisFrame[index]:
      holdStartTimes[index] = songPosition
    
    if keyReleasedThisFrame[index] and holdStartTimes[index] >= 0:
      let holdDuration = songPosition - holdStartTimes[index]
      let noteTimePosition = round(holdStartTimes[index], 3)
      
      if holdDuration >= 0.25: # adjusted to reduce random hold notes when pressing a note for slightly too long
        recordedNotes.add(RecordedNote(
          column: index, 
          time: noteTimePosition, 
          isHoldNote: true, 
          length: round(holdDuration, 3)
        ))
      else:
        # generic note
        recordedNotes.add(RecordedNote(
          column: index, 
          time: noteTimePosition, 
          isHoldNote: false, 
          length: 0.0
        ))
      
      holdStartTimes[index] = -1.0


proc loadSong(filePath: string) =
  if isRecording:
    currentChart = new Chart
    currentChart.songPath = filePath
    currentChart.notes = @[]
    
    if not fileExists("assets/music/" & currentChart.songPath & ".mp3"):
      echo "Song file not found for recording: ", currentChart.songPath
      quit(1)
      
    currentSong = loadMusicStream("assets/music/" & currentChart.songPath & ".mp3")
    setMusicVolume(currentSong, 0.5)
  else:
    var chartSongName = currentConfig.chartToLoad
    currentChart = loadChart("assets/chart/" & chartSongName & ".json")
    if currentChart == nil:
      quit(1)
    if not fileExists("assets/music/" & currentChart.songPath & ".mp3"):
      echo "Song file not found: ", currentChart.songPath
      quit(1)
    currentSong = loadMusicStream("assets/music/" & currentChart.songPath & ".mp3")
    setMusicVolume(currentSong, 0.5)

proc main() =
  # load raylib

  initWindow(800, 600, "eny")
  setTargetFPS(60)
  initAudioDevice()
  defer: closeAudioDevice()

  let icon = loadImage("assets/eny/eny.png")
  setWindowIcon(icon)

  # load config & chart
  currentConfig = loadEnyConfig("eny.json")
  isRecording = currentConfig.isRecordingMode
  if isRecording:
    loadSong(currentConfig.recordingModeSongName)
  else:
    loadSong(currentConfig.chartToLoad)
  currentChart.startTime = -3.0

  let chartLength = getChartSecondsLength(currentChart) + (10.0) # 10 seconds wait after it ends

  # load sprites

  var loadedNotes = loadNoteTextures("assets/image/notesheet.png")
  activeNoteDrawTable = loadedNotes["Active"]
  inactiveNoteDrawTable = loadedNotes["Inactive"]
  
  # draw configs (used for input too)
  let noteSpacing = 24
  let totalNotesWidth = (inactiveNoteDrawTable.len * SpriteUpscale) + ((inactiveNoteDrawTable.len - 1) * noteSpacing)
  let startX = (getScreenWidth() - totalNotesWidth) div 2
  let receptorY = getScreenHeight() - SpriteUpscale - 80
  let noteTextY = receptorY + 70
  let receptorLineY = receptorY + 30
  let receptorLineHeight = 4
  
  # update vars
  var gameTime = 0.0
  var songStarted = false
  var songEnded = false
  var score = 0
  let chartScrollSpeed = ScrollSpeed * currentConfig.scrollSpeed

  # update keybinds
  if currentConfig.keybinds.len > 0:
    KeyboardBinds.clear()
    for i in 0..<currentConfig.keybinds.len:
      let keybind = currentConfig.keybinds[i]
      KeyboardBinds[getKeyFromKeybind(keybind)] = i
    for kbind in KeyboardBinds.pairs:
      echo fmt"Key: {kbind[0]}, Index: {kbind[1]}"
  # notes missed
  var notesToCheck: seq[ChartNote] = @[]

  while not windowShouldClose():
    let deltaTime = getFrameTime()
    gameTime += deltaTime
    
    updateKeyStates()

    let songPosition = gameTime + currentChart.startTime

    if songPosition >= 0 and not songStarted:
      playMusicStream(currentSong)
      songStarted = true
    
    if songStarted:
      updateMusicStream(currentSong)
      if songPosition >= chartLength:
        break

    
    # Recording mode
    if isRecording and songPosition >= 0:
      updateRecording(songPosition)
    
    if isRecording and isKeyPressed(KeyboardKey.G):
      saveRecordedChart(recordedNotes, currentChart.songPath)
      isRecording = false
    
    if not isRecording:
      notesToCheck.setLen(0)
      
      for note in currentChart.notes:
        if note.hit and (not note.isHoldNote or note.released):
          continue
          
        let timeToHit = note.time - songPosition
        note.position = float(receptorY) - (timeToHit * chartScrollSpeed)
        
        if not note.hit and abs(timeToHit) < BadWindowMs / 1000.0:
          if keyPressedThisFrame[note.columnIndex]:
            note.hit = true
            playerHitCount[note.columnIndex] += 1
            
            let timeDiffMs = timeToHit * 1000.0
            let rating = getHitRating(timeDiffMs)
            let points = getScorePoints(rating)
            score += points
            
            if not note.isHoldNote:
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
        elif note.isHoldNote and note.hit and not note.released:
          let holdEndTime = note.time + note.length
          let timeToHoldEnd = holdEndTime - songPosition
          
          if not notePressedStates[note.columnIndex]:
            note.released = true
            let releaseTimeDiffMs = timeToHoldEnd * 1000.0
            let releaseRating = if releaseTimeDiffMs <= -BadWindowMs: hrMiss else: getHitRating(releaseTimeDiffMs)
            let releasePoints = getScorePoints(releaseRating) div 2
            
            score += releasePoints
            
            case releaseRating:
              of hrPerfect: playerScoreData["perfect"] += 1
              of hrGreat: playerScoreData["great"] += 1
              of hrGood: playerScoreData["good"] += 1
              of hrOk: playerScoreData["ok"] += 1
              of hrBad: playerScoreData["bad"] += 1
              of hrMiss: playerScoreData["miss"] += 1
            
            recentHits.add(HitFeedback(
              rating: releaseRating,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
          elif timeToHoldEnd < -BadWindowMs / 1000.0:
            # hold ends naturally
            note.released = true
            playerScoreData["perfect"] += 1
            score += getScorePoints(hrPerfect) div 2
            
            recentHits.add(HitFeedback(
              rating: hrPerfect,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
        elif timeToHit < -BadWindowMs / 1000.0 and note.position > float(receptorY + SpriteUpscale):
          if not note.hit:
            notesToCheck.add(note)
      
      for i in countdown(recentHits.len - 1, 0):
        recentHits[i].time += deltaTime
        recentHits[i].alpha = 1.0 - (recentHits[i].time / 0.8)
        
        if recentHits[i].alpha <= 0:
          recentHits.delete(i)
      
      # for note in notesToCheck:
      #   if not note.hit:
      #     note.hit = true
      #     playerScoreData["miss"] += 1

      ## Hit check: Generic notes
      for note in notesToCheck:
        let timeDiffMs = (note.time - songPosition) * 1000.0
        let withinHitWindow = abs(timeDiffMs) <= BadWindowMs
        let pastHitWindow = timeDiffMs < -BadWindowMs
        
        if not note.hit:
          if withinHitWindow and notePressedStates[note.columnIndex]:
            note.hit = true
            let rating = getHitRating(timeDiffMs)
            let points = getScorePoints(rating)
            
            score += points
            
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
          # passed hit window without being hit
          elif pastHitWindow:
            note.hit = true
            if note.isHoldNote:
              note.released = true # hold notes are marked as released if missed initially
            
            playerScoreData["miss"] += 1
            
            recentHits.add(HitFeedback(
              rating: hrMiss,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
      
      ## Hit check: Hold notes
      for note in notesToCheck:
        if note.isHoldNote and note.hit and not note.released:
          let holdEndTime = note.time + note.length
          let timeToHoldEnd = holdEndTime - songPosition
          
          # Player released early
          if not notePressedStates[note.columnIndex]:
            note.released = true
            
            # rating based on release
            let releaseTimeDiffMs = timeToHoldEnd * 1000.0
            let releaseRating = if releaseTimeDiffMs > BadWindowMs: hrMiss else: getHitRating(releaseTimeDiffMs)
            let releasePoints = getScorePoints(releaseRating) div 2
            
            score += releasePoints
            
            case releaseRating:
              of hrPerfect: playerScoreData["perfect"] += 1
              of hrGreat: playerScoreData["great"] += 1
              of hrGood: playerScoreData["good"] += 1
              of hrOk: playerScoreData["ok"] += 1
              of hrBad: playerScoreData["bad"] += 1
              of hrMiss: playerScoreData["miss"] += 1
            
            recentHits.add(HitFeedback(
              rating: releaseRating,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
          # hold note finished fully
          elif timeToHoldEnd <= 0:
            note.released = true
            playerScoreData["perfect"] += 1
            score += getScorePoints(hrPerfect) div 2
            
            recentHits.add(HitFeedback(
              rating: hrPerfect,
              column: note.columnIndex,
              alpha: 1.0,
              time: 0.0
            ))
      
      currentChart.notes.keepItIf(not it.hit or it.position > -200)
    
    beginDrawing()
    clearBackground(Gray)
    drawFPS(10, 10)
    
    let songTitle = currentChart.songTitle
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
      drawNotes(startX, noteSpacing, chartScrollSpeed, receptorY)
    
    endDrawing()

  closeWindow()

main()
