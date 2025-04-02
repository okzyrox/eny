## eny
## 
## cc: okzyrox
import raylib, raymath
import std/[tables, strutils, strformat, json, options, times, sequtils, algorithm, os]

const
  # Note sprites
  SpriteSize = 16
  SheetSize = 64
  NotesPerRow = SheetSize div SpriteSize
  NotesCount = NotesPerRow * NotesPerRow
  SpriteUpscale = 64
  # base song scroll speed (for 1x)
  ScrollSpeed = 450.0  # Pix/s, mult 0.5x-2.5x in chart data
  # hit thresholds
  PerfectWindowMs = 45.0
  GreatWindowMs = 60.0
  GoodWindowMs = 85.0
  OkWindowMs = 120.0
  BadWindowMs = 135.0

type
  Note = ref object of RootObj
    texture: Texture2D
    index: int

  ChartNote = ref object of RootObj
    columnIndex: int
    time: float
    position: float
    hit: bool
    
  Chart = ref object of RootObj
    notes: seq[ChartNote]
    songPath: string
    startTime: float

  RecordedNote = object
    column: int
    time: float
    
  HitRating = enum
    hrMiss, hrBad, hrOk, hrGood, hrGreat, hrPerfect

proc loadNoteTextures(imagePath: string): Table[string, Table[int, ref Note]] =
  var image = loadImage(imagePath)
  var notes: Table[string, Table[int, ref Note]] = initTable[string, Table[int, ref Note]]()
  notes["Active"] = initTable[int, ref Note]()
  notes["Inactive"] = initTable[int, ref Note]()

  for y in 0..<NotesPerRow:
    if y == 0 or y == 3:
      for x in 0..<NotesPerRow:
        let rect = Rectangle(x: float(x * SpriteSize), y: float(y * SpriteSize), width: float(SpriteSize), height: float(SpriteSize))
        var subImage = imageFromImage(image, rect)
        imageResizeNN(subImage, int32(SpriteUpscale), int32(SpriteUpscale))
        let texture = loadTextureFromImage(subImage)
        let posY = if y == 0: 0 else: 1
        if posY == 0:
          var note: ref Note
          new(note)
          note[] = Note(texture: texture, index: x)
          notes["Inactive"][x] = note
        else:
          var note: ref Note
          new(note)
          note[] = Note(texture: texture, index: x)
          notes["Active"][x] = note

  return notes

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

proc loadChart(filePath: string): Chart =
  let jsonContent = readFile(filePath)
  let jsonNode = parseJson(jsonContent)
  
  var chart = new Chart
  chart.songPath = jsonNode["song"].getStr()
  chart.notes = @[]
  
  for noteNode in jsonNode["notes"]:
    var note = new ChartNote
    note.columnIndex = noteNode["column"].getInt()
    note.time = noteNode["time"].getFloat()
    note.position = 0
    note.hit = false
    chart.notes.add(note)
  
  chart.notes.sort(proc (a, b: ChartNote): int = cmp(a.time, b.time))
  return chart

proc saveRecordedChart(notes: seq[RecordedNote], songName: string) =
  var jsonObj = newJObject()
  jsonObj["title"] = %("recorded chart - at: " & $now())
  jsonObj["song"] = %songName
  #jsonObj["bpm"] = %120 # todo: add some form of camera stuff to the bpm 
  
  var notesArray = newJArray()
  for note in notes:
    var noteObj = newJObject()
    noteObj["column"] = %note.column
    noteObj["time"] = %note.time
    notesArray.add(noteObj)
  
  jsonObj["notes"] = notesArray
  
  let timestamp = now().format("yyyy-MM-dd'T'HH-mm-ss")
  let filePath = "assets/chart/recorded_" & timestamp & ".json"
  
  createDir("assets/chart")
  
  writeFile(filePath, pretty(jsonObj))
  echo "Chart saved to: ", filePath

proc getHitRating(timeDiffMs: float): HitRating =
  let absTimeDiff = abs(timeDiffMs)
  if absTimeDiff <= PerfectWindowMs:
    return hrPerfect
  elif absTimeDiff <= GreatWindowMs:
    return hrGreat
  elif absTimeDiff <= GoodWindowMs:
    return hrGood
  elif absTimeDiff <= OkWindowMs:
    return hrOk
  elif absTimeDiff <= BadWindowMs:
    return hrBad
  else:
    return hrMiss

proc getScorePoints(rating: HitRating): int =
  case rating:
    of hrPerfect: 100
    of hrGreat: 80
    of hrGood: 50
    of hrOk: 30
    of hrBad: 10
    of hrMiss: 0

proc getRatingColor(rating: HitRating): Color =
  case rating:
    of hrPerfect: Color(r: 255, g: 215, b: 0, a: 255)
    of hrGreat: Color(r: 50, g: 205, b: 50, a: 255)
    of hrGood: Color(r: 30, g: 144, b: 255, a: 255)
    of hrOk: Color(r: 255, g: 165, b: 0, a: 255)
    of hrBad: Color(r: 178, g: 34, b: 34, a: 255)
    of hrMiss: Color(r: 169, g: 169, b: 169, a: 255)

var keyboardBinds: Table[KeyboardKey, int] = {
  KeyboardKey.D: 0,
  KeyboardKey.F: 1,
  KeyboardKey.J: 2,
  KeyboardKey.K: 3
}.toTable

var activeNoteDrawTable: Table[int, ref Note]
var inactiveNoteDrawTable: Table[int, ref Note]

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

proc updateKeyStates() =
  for key, index in keyboardBinds:
    notePressedStates[index] = isKeyDown(key)
    keyPressedThisFrame[index] = isKeyPressed(key)

var playerHitCount: Table[int, int] = {
  0: 0,
  1: 0,
  2: 0,
  3: 0
}.toTable

var playerScoreData: Table[string, int] = {
  "perfect": 0,
  "great": 0,
  "good": 0,
  "ok": 0,
  "bad": 0,
  "miss": 0
}.toTable

type
  HitFeedback = object
    rating: HitRating
    column: int
    alpha: float
    time: float

var recentHits: seq[HitFeedback] = @[]

proc main() =
  initWindow(800, 600, "eny")
  setTargetFPS(60)
  initAudioDevice()
  defer: closeAudioDevice()

  var notes = loadNoteTextures("assets/image/notesheet.png")
  activeNoteDrawTable = notes["Active"]
  inactiveNoteDrawTable = notes["Inactive"]

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
  var isRecording = isRecordingMode

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
      for key, index in keyboardBinds:
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
      let recordingText = "RECORDING"
      let textWidth = measureText(recordingText, 20)
      drawText(recordingText, int32(getScreenWidth() - textWidth - 10), 10, 20, Red)
      drawText("Press G to save", int32(getScreenWidth() - measureText("Press G to save", 16) - 10), 35, 16, Red)
      drawText(fmt"Total Notes: {recordedNotes.len}", 10, 70, 20, Black)
    
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
        drawText(fmt"Score: {score}", 10, 70, 20, DarkGreen)
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
    
    #receptor
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
    
    # hit rating
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
    
    # Fallin notes
    if not isRecording:
      for note in chart.notes:
        if not note.hit and note.position > -100:
          let noteX = startX + (note.columnIndex * (SpriteUpscale + noteSpacing))
          drawTexture(inactiveNoteDrawTable[note.columnIndex].texture, int32(noteX), int32(note.position), White)
    
    endDrawing()

  closeWindow()

main()