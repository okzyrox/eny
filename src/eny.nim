## eny
## 
## cc: okzyrox
import raylib
import discord_rpc

import std/[tables, strformat, sequtils, math, options]

import ./[
  hit_rating,
  chart,
  notes,
  config,

  menu,
  states,
  results
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

var activeNoteDrawTable: Table[int, ref Note]
var inactiveNoteDrawTable: Table[int, ref Note]
var recordedNotes: seq[RecordedNote] = @[]

var screenHeight: int32
var screenWidth: int32

proc allNotesCompleted(chart: Chart): bool =
  if chart.notes.len == 0:
    return true
  
  for note in chart.notes:
    if not note.hit or (note.isHoldNote and not note.released):
      return false
  
  return true

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
  drawText(recordingText, int32(screenWidth - textWidth - 10), 10, 20, AccentColor)
  drawText("Press G to save", int32(screenWidth - measureText("Press G to save", 16) - 10), 35, 16, AccentColor)
  drawText(fmt"Total Notes: {recordedNotes.len}", 10, 70, 20, TextColor)

proc drawPlayerStats() =
  drawText(fmt"Score: {currentResults.score}", 10, 70, 20, AccentColor2)
  
  let comboY = int32(45)
  if currentResults.currentCombo > 4:  # Only show combo after a certain threshold
    let comboText = fmt"Combo: {currentResults.currentCombo}"
    let comboWidth = measureText(comboText, 24)
    drawText(comboText, (screenWidth - comboWidth) div 2, comboY, 24, White)
  
  drawText(fmt"Accuracy: {currentResults.accuracy:.2f}%", 10, 90, 20, AccentColor2)
  
  let statY = int32(120)
  let perfectText = "PERFECT: " & $currentResults.perfect
  let greatText = "GREAT: " & $currentResults.great 
  let goodText = "GOOD: " & $currentResults.good
  let okText = "OK: " & $currentResults.ok
  let badText = "BAD: " & $currentResults.bad
  let missText = "MISS: " & $currentResults.miss
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
    let noteTextY32 = int32(noteTextY)
    drawText(keyName, textX, noteTextY32, 20, AccentColor)

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
      if note.position > -100 and (note.isHoldNote or note.position < float(screenHeight + 100)): # only draw notes that are on screen
        # special case to handle hold note trails (so they dont end abruptly due to cutoff)
        let noteX = int32(startX + (note.columnIndex * (SpriteUpscale + noteSpacing)))
        let halfScale = int32(SpriteUpscale / 2)
        let quarterScale = int32(SpriteUpscale / 4)
        
        if note.isHoldNote:
          let holdEndPosition = int32(note.position - (note.length * chartScrollSpeed))
          let noteColour = AccentColor2
          let receptorY32 = int32(receptorY)
          if not note.hit:
            let holdHeight = int32(note.position) - holdEndPosition
            
            if holdHeight > 0:
              drawRectangle(noteX + quarterScale, holdEndPosition + halfScale, halfScale, holdHeight - halfScale, fade(noteColour, 0.6))
              
              drawRectangle(noteX, holdEndPosition, SpriteUpscale, quarterScale, fade(White, 0.8))
          else:
            let visibleHeight = int32(receptorY) - holdEndPosition
            
            if visibleHeight > 0:
              drawRectangle(
                noteX + quarterScale, 
                holdEndPosition + halfScale,
                halfScale,
                receptorY32 - holdEndPosition - halfScale,
                fade(noteColour, 0.6)
              )
              
              drawRectangle(
                noteX, 
                holdEndPosition,
                SpriteUpscale,
                quarterScale,
                fade(White, 0.8)
              )
        # note head
        if not note.hit:
          drawTexture(inactiveNoteDrawTable[note.columnIndex].texture, noteX, int32(note.position), White)

proc drawGameUI(startX: int, receptorY: int32, totalNotesWidth: int, noteSpacing: int, receptorLineY: int, receptorLineHeight: int, noteTextY: int, chartScrollSpeed: float) =
  clearBackground(BackgroundColor)
  
  let songTitle = currentChart.songTitle
  let titleWidth = measureText(songTitle, 24)
  let titleX = int32((screenWidth - titleWidth) div 2)
  drawText(songTitle, titleX, 20, 24, AccentColor2)
  
  # Record UI
  if isRecording:
    drawRecordingUI(recordedNotes)
  
  # Countdown
  if songPosition < 0:
    let countdownText = $(-int(songPosition) + 1)
    let textWidth = measureText(countdownText, 40)
    let countdownX = int32((screenWidth - textWidth) div 2)
    drawText(countdownText, countdownX, 100, 40, AccentColor)
  else:
    # stats
    drawText(fmt"Time: {songPosition:.2f}s", 10, 40, 20, TextColor)
    
    # Score breakdown
    if not isRecording:
      drawPlayerStats()
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
  
  # end screen fade
  if songFading:
    drawRectangle(0, 0, screenWidth, screenHeight, fade(Black, float32(screenFadeAlpha)))

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

proc updateCombo(rating: HitRating) =
  if rating == hrMiss: #  or rating == hrBad
    # Break combo on bad- hits
    if currentResults.currentCombo > currentResults.maxCombo:
      currentResults.maxCombo = currentResults.currentCombo
    currentResults.currentCombo = 0
  else:
    # Increase combo on good+ hits
    currentResults.currentCombo += 1
    if currentResults.currentCombo > currentResults.maxCombo:
      currentResults.maxCombo = currentResults.currentCombo
  # accuracy
  let totalNotes = currentResults.perfect + currentResults.great + 
                  currentResults.good + currentResults.ok + 
                  currentResults.bad + currentResults.miss
  
  if totalNotes > 0:
    # Weighted accuracy
    let weightedSum = currentResults.perfect.float * 100.0 + 
                     currentResults.great.float * 95.0 + 
                     currentResults.good.float * 75.0 + 
                     currentResults.ok.float * 50.0 + 
                     currentResults.bad.float * 25.0
    currentResults.accuracy = weightedSum / (totalNotes.float * 100.0) * 100.0

proc initRichPresence() =
  let
    applicationId = 1358181398514630958
  
  discordPresence = newDiscordRPC(applicationId)

  try:
    discard discordPresence.connect

    discordPresence.setActivity Activity(
      details: "okzyrox's epic rhythm game",
      state: "on the main menu",
      assets: some ActivityAssets(
        largeImage: "eny",
        largeText: "Playing eny"
      )
    )
  except Exception as e:
    echo "Failed to connect to Discord RPC: ", e.msg

proc main() =
  # load raylib

  initWindow(1280, 720, "eny")
  setTargetFPS(144)
  initAudioDevice()
  setConfigFlags(flags(VsyncHint))
  defer: closeAudioDevice()

  let icon = loadImage("assets/eny/eny.png")
  setWindowIcon(icon)

  # load config & chart
  currentConfig = loadEnyConfig("eny.json")
  if isRecording:
    loadSong(currentConfig.recordingModeSongName)

  # load sprites

  var loadedNotes = loadNoteTextures("assets/image/notesheet.png")
  activeNoteDrawTable = loadedNotes["Active"]
  inactiveNoteDrawTable = loadedNotes["Inactive"]
  
  # draw configs (used for input too)
  screenHeight = getScreenHeight()
  screenWidth = getScreenWidth()

  let noteSpacing = 24
  let totalNotesWidth = (inactiveNoteDrawTable.len * SpriteUpscale) + ((inactiveNoteDrawTable.len - 1) * noteSpacing)
  let startX = (screenWidth - totalNotesWidth) div 2
  let receptorY = screenHeight - SpriteUpscale - 80
  let noteTextY = receptorY + 70
  let receptorLineY = receptorY + 30
  let receptorLineHeight = 4
  
  # update vars
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

  initMenu()
  initRichPresence()

  resetResultsScreenFade()

  while not windowShouldClose():
    updateKeyStates()
    case currentState:
      of GameState.Playing:
        let deltaTime = getFrameTime()
        gameTime += deltaTime
        
        # echo fmt"Game Time: {gameTime:.2f}"
        if currentChart == nil:
          echo "Chart is nil!"
          break

        if (songPosition == 0.0 or chartLength == 0.0) and not isRecording:
          chartLength = getChartSecondsLength(currentChart)
          if chartLength == 0.0:
            echo "Chart length is 0!"
            break
        songPosition = gameTime + currentChart.startTime

        if songPosition >= 0 and not songStarted:
          playMusicStream(currentSong)
          songStarted = true
        
        if songStarted:
          updateMusicStream(currentSong)
          if not isRecording and songPosition > chartLength:
            # stopMusicStream(currentSong)
            # songStarted = false
            # songPosition = 0.0
            # chartLength = 0.0
            # setState(GameState.Results)
            if allNotesCompleted(currentChart) and not songFading:
              songFading = true
              songFadeStartTime = songPosition
              echo "song fade out..."
            
            # fade out
            if songFading:
              let fadeProgress = (songPosition - songFadeStartTime) / songFadeDuration
              
              if fadeProgress <= 1.0:
                let volumeLevel = 1.0 - fadeProgress

                screenFadeAlpha = fadeProgress
                setMusicVolume(currentSong, float32(volumeLevel))
              elif songPosition - songFadeStartTime > songFadeDuration + songEndDelay:
                stopMusicStream(currentSong)
                resultsScreenFadeIn = true
                resultsScreenFadeStartTime = 0.0
                songStarted = false
                songPosition = 0.0
                chartLength = 0.0
                songFading = false
                setState(GameState.Results)
            
        # if songEnded:
        #   break

        # Recording mode
        #  and songPosition >= 0
        if isRecording:
          updateRecording(songPosition)
        
        if isRecording and isKeyPressed(KeyboardKey.G):
          saveRecordedChart(recordedNotes, currentChart.songPath)
          isRecording = false
          songStarted = false
          resetResultsScreenFade()
          stopMusicStream(currentSong)
          initMenu() # reset menu state to reload songs list
          setState(GameState.MainMenu)
        
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
                currentResults.score += points
                
                if not note.isHoldNote:
                  case rating:
                    of hrPerfect: currentResults.perfect += 1
                    of hrGreat: currentResults.great += 1
                    of hrGood: currentResults.good += 1
                    of hrOk: currentResults.ok += 1
                    of hrBad: currentResults.bad += 1
                    of hrMiss: currentResults.miss += 1
                  
                  updateCombo(rating)
                  
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
                var releaseRating = if releaseTimeDiffMs <= -BadWindowMs: hrBad else: getHitRating(releaseTimeDiffMs)
                if releaseRating == hrMiss:
                  releaseRating = hrBad
                let releasePoints = getScorePoints(releaseRating) div 2
                currentResults.score += releasePoints
        
                case releaseRating:
                  of hrPerfect: currentResults.perfect += 1
                  of hrGreat: currentResults.great += 1
                  of hrGood: currentResults.good += 1
                  of hrOk: currentResults.ok += 1
                  of hrBad: currentResults.bad += 1
                  of hrMiss: currentResults.miss += 1
                
                updateCombo(releaseRating)
                
                recentHits.add(HitFeedback(
                  rating: releaseRating,
                  column: note.columnIndex,
                  alpha: 1.0,
                  time: 0.0
                ))
              elif timeToHoldEnd < -BadWindowMs / 1000.0:
                # hold ends naturally
                note.released = true
                currentResults.perfect += 1
                currentResults.score += getScorePoints(hrPerfect) div 2
                
                updateCombo(hrPerfect)
                
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
          
          ## Hit check: Generic notes
          for note in notesToCheck:
            let timeDiffMs = (note.time - songPosition) * 1000.0
            let withinHitWindow = abs(timeDiffMs) <= BadWindowMs
            let pastHitWindow = timeDiffMs < -BadWindowMs
            
            if not note.hit:
              if withinHitWindow and notePressedStates[note.columnIndex]:
                let songTimeThreshold = songPosition - 0.04  # 40ms threshold

                # Only register hit if:
                # 1. new keypress (not holding)
                # 2. havent hit a note in this column recently
                if keyPressedThisFrame[note.columnIndex] and lastHitNotes[note.columnIndex] < songTimeThreshold:
                  note.hit = true
                  lastHitNotes[note.columnIndex] = songPosition
                  let rating = getHitRating(timeDiffMs)
                  let points = getScorePoints(rating)
                  
                  currentResults.score += points
                  
                  case rating:
                    of hrPerfect: currentResults.perfect += 1
                    of hrGreat: currentResults.great += 1
                    of hrGood: currentResults.good += 1
                    of hrOk: currentResults.ok += 1
                    of hrBad: currentResults.bad += 1
                    of hrMiss: currentResults.miss += 1

                  updateCombo(rating)
                  
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
                
                currentResults.miss += 1

                updateCombo(hrMiss)
                
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
                var releaseRating = if releaseTimeDiffMs > BadWindowMs: hrBad else: getHitRating(releaseTimeDiffMs)
                if releaseRating == hrMiss:
                  releaseRating = hrBad
                let releasePoints = getScorePoints(releaseRating) div 2
                
                currentResults.score += releasePoints
                
                case releaseRating:
                  of hrPerfect: currentResults.perfect += 1
                  of hrGreat: currentResults.great += 1
                  of hrGood: currentResults.good += 1
                  of hrOk: currentResults.ok += 1
                  of hrBad: currentResults.bad += 1
                  of hrMiss: currentResults.miss += 1
                
                updateCombo(releaseRating)

                recentHits.add(HitFeedback(
                  rating: releaseRating,
                  column: note.columnIndex,
                  alpha: 1.0,
                  time: 0.0
                ))
              # hold note finished fully
              elif timeToHoldEnd <= 0:
                note.released = true
                currentResults.perfect += 1
                currentResults.score += getScorePoints(hrPerfect) div 2
                
                updateCombo(hrPerfect)

                recentHits.add(HitFeedback(
                  rating: hrPerfect,
                  column: note.columnIndex,
                  alpha: 1.0,
                  time: 0.0
                ))
          
          currentChart.notes.keepItIf(not it.hit or it.position > -200)
        beginDrawing()
        drawGameUI(
          startX, 
          receptorY, 
          totalNotesWidth, 
          noteSpacing, 
          receptorLineY, 
          receptorLineHeight, 
          noteTextY, 
          chartScrollSpeed
        )
        drawDebugInfo()
        endDrawing()
      of GameState.MainMenu:
        updateMenu()
        drawMenu()
      of GameState.Results:
        updateResults()
        drawResults()
      else:
        echo "unhandled game state!"
        break
  closeWindow()

main()
