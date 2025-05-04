## eny
## 
## cc: okzyrox
import std/[os, strutils, math, json, tables, strformat, options, algorithm]

# i would use NimYaml however it doesn't support optional fields for yaml objects, 
# since they have to be directly instantiated as a nim object (which doesnt support those)

type
  # we really dont need this, but when i was templating this i made it when converting between the integer miliseconds and float seconds
  # but then it became a bit obsolete but im keeping and still using it cause why not
  NoteData = object
    column: int      # 0-3 lane index
    time: float
    length: float

  QuaverNote = object
    lane: int # 1-4 lane index (Quaver)
    startTime: float
    endTime: Option[float]

proc parseQuaFile(filePath: string): tuple[metadata: Table[string, string], notes: seq[QuaverNote]] =
  let content = readFile(filePath)
  var 
    metadata: Table[string, string] = initTable[string, string]()
    notes: seq[QuaverNote] = @[]
    inHitObjects = false
    currentNotes: Table[int, QuaverNote] = initTable[int, QuaverNote]()
    currentNoteIdx = 0
  
  for line in content.splitLines():
    let trimmedLine = line.strip()
    if trimmedLine.len == 0 or trimmedLine.startsWith("//"):
      continue
    
    if trimmedLine == "HitObjects:":
      inHitObjects = true
      continue
    
    if trimmedLine == "TimingPoints:":
      inHitObjects = false
      continue
    
    # parse notes
    if inHitObjects:
      if trimmedLine.startsWith("- StartTime:"):
        currentNoteIdx += 1
        let value = trimmedLine.split(":", 1)[1].strip()
        let quaverStartTime = parseFloat(value)
        let enyStartTime = quaverStartTime / 1000.0
        
        var note = QuaverNote(
          startTime: enyStartTime,
          lane: 1,
          endTime: none(float)
        )
        currentNotes[currentNoteIdx] = note
      
      if trimmedLine.startsWith("- Lane:") or trimmedLine.startsWith("Lane:"):
        let value = trimmedLine.split(":", 1)[1].strip()
        let quaverLane = parseInt(value)
        # echo value, " ", quaverLane
        var note = currentNotes[currentNoteIdx]
        note.lane = quaverLane
        currentNotes[currentNoteIdx] = note
      
      if trimmedLine.startsWith("- EndTime:") or trimmedLine.startsWith("EndTime:"):
        let value = trimmedLine.split(":", 1)[1].strip()
        let quaverEndTime = parseFloat(value)
        let enyEndTime = quaverEndTime / 1000.0
        
        var note = currentNotes[currentNoteIdx]
        note.endTime = some(round(enyEndTime, 3))
        currentNotes[currentNoteIdx] = note
    
    elif trimmedLine.contains(":") and not inHitObjects:
      let parts = trimmedLine.split(":", 1)
      let key = parts[0].strip()
      let value = parts[1].strip()
      
      metadata[key] = value
  
  for _, note in currentNotes.pairs:
    notes.add(note)
  
  return (metadata: metadata, notes: notes)

const InvalidChars = {'\\', '/', '*', '?', '\"', '<', '>', '|', '\''}
const ReplaceChars = {' ', '-', '_', '.', ':', '[', ']', '(', ')', '{', '}', '`', '~', ','}
proc sanitiseString(input: string): string =

  result = ""
  for c in input:
    if c notin InvalidChars and ord(c) >= 32:
      if c in ReplaceChars:
        if result.len > 0 and result[result.len - 1] != '_':
          result.add('_')
      else:
        result.add(c)
  
  result = result.strip()
  let lastChar = result[result.len - 1]
  if lastChar == '_':
    result = result[0 ..< result.len - 1]

proc convertQuaverToEny(filePath: string) =
  echo "Converting Quaver file: ", filePath
  
  let parsedData = parseQuaFile(filePath)
  let metadata = parsedData.metadata
  let quaverNotes = parsedData.notes
  
  let title = if metadata.hasKey("Title"): metadata["Title"] else: "Unknown"
  
  echo "metadata:"
  echo fmt"  Title: {title}"
  echo fmt"  Total notes: {quaverNotes.len}"
  
  let outputFilename = sanitiseString(title.toLower()) & ".json"
  echo "Output file will be: ", outputFilename
  
  let songName = sanitiseString(title.toLower())
  
  var notes: seq[NoteData] = @[]
  
  for hitObj in quaverNotes:
    let column = hitObj.lane - 1 # eny lanes
    
    if hitObj.endTime.isSome:
      let endTime = hitObj.endTime.get()
      let length = endTime - hitObj.startTime
      notes.add(NoteData(column: column, time: hitObj.startTime, length: length))
    else:
      notes.add(NoteData(column: column, time: hitObj.startTime))
  
  notes.sort(proc (a, b: NoteData): int = cmp(a.time, b.time))
  
  var outputJson = newJObject()
  outputJson["title"] = %("(Quaver): " & title)
  outputJson["song"] = %songName
  outputJson["extra"] = %*{}
  outputJson["extra"]["fromQuaver"] = %true
  if metadata.hasKey("Artist"):
    outputJson["extra"]["artist"] = %metadata["Artist"]
  if metadata.hasKey("Creator"):
    outputJson["extra"]["creator"] = %metadata["Creator"]
  if metadata.hasKey("DifficultyName"):
    outputJson["extra"]["difficulty"] = %metadata["DifficultyName"]
  if metadata.hasKey("Source"):
    outputJson["extra"]["source"] = %metadata["Source"]
  
  var notesArray = newJArray()
  for note in notes:
    var noteObj = newJObject()
    noteObj["column"] = %note.column
    noteObj["time"] = %note.time
    
    if note.length > 0:
      noteObj["length"] = %note.length
    
    notesArray.add(noteObj)
  
  outputJson["notes"] = notesArray
  
  let outputPath = "QuaToEnyConverter/content/chart/" & outputFilename
  createDir("QuaToEnyConverter/content/chart")
  writeFile(outputPath, pretty(outputJson))
  
  echo fmt"Conversion complete! {notes.len} notes converted."
  echo fmt"ensure that '{songName}.mp3' is in your content/music directory"

when isMainModule:
  if paramCount() < 1:
    echo "Usage: qua_to_eny <chart.qua>"
  else:
    let filePath = paramStr(1)
    if not fileExists(filePath):
      echo "Error: Quaver file does not exist: ", filePath
      quit(1)
    
    convertQuaverToEny(filePath)