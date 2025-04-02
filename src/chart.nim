## eny
## 
## cc: okzyrox
import raylib
import std/[json, times, algorithm, os]

type
  ChartNote* = ref object of RootObj
    columnIndex*: int
    time*: float
    position*: float
    hit*: bool
    
  Chart* = ref object of RootObj
    notes*: seq[ChartNote]
    songPath*: string
    startTime*: float

  RecordedNote* = object
    column*: int
    time*: float

proc loadChart*(filePath: string): Chart =
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

proc saveRecordedChart*(notes: seq[RecordedNote], songName: string) =
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