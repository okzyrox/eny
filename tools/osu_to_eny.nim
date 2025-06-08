## eny
## 
## cc: okzyrox
## osu!mania to eny converter
import std/[os, strutils, json, tables, strformat, options, algorithm, sequtils, sugar]

type
  HitObjectType = enum
    Note, Hold

  HitObject = object
    x: int # x pos (column)
    y: int # y pos (useless)
    time: float # start ms
    case kind: HitObjectType
    of Note: discard
    of Hold: endTime: float  # End time for hold notes

  TimingPoint = object
    time: float # ms start
    beatLength: float # ms per beat (negative for vel)
    meter: int # time sig
    uninherited: bool # bpm change?
    kiaiMode: bool # kiai time?
    velocity: float # slider vel mult 
    bpm: Option[float] # bpm (otherwise derived)

  OsuManiaBeatmap = object
    general: Table[string, string]
    metadata: Table[string, string]
    difficulty: Table[string, string]
    timingPoints: seq[TimingPoint]
    hitObjects: seq[HitObject]
    keyCount: int

proc parseBeatmap(filePath: string): OsuManiaBeatmap =
  result = OsuManiaBeatmap(
    general: initTable[string, string](),
    metadata: initTable[string, string](),
    difficulty: initTable[string, string](),
    timingPoints: @[],
    hitObjects: @[]
  )
  
  var currentSection = ""
  
  for line in lines(filePath):
    let trimmedLine = line.strip()
    if trimmedLine.len == 0 or trimmedLine.startsWith("//"):
      continue
    
    # section headers
    if trimmedLine.startsWith("[") and trimmedLine.endsWith("]"):
      currentSection = trimmedLine[1..^2]  #section name
      continue
    
    case currentSection
    of "General":
      let parts = trimmedLine.split(":", 1)
      if parts.len == 2:
        result.general[parts[0].strip()] = parts[1].strip()
        
        # is actually osu!mania
        if parts[0].strip() == "Mode" and parts[1].strip() != "3":
          echo "Warning: This .osu file is not an osu!mania map (Mode is not `3`)"
    
    of "Metadata":
      let parts = trimmedLine.split(":", 1)
      if parts.len == 2:
        result.metadata[parts[0].strip()] = parts[1].strip()
    
    of "Difficulty":
      let parts = trimmedLine.split(":", 1)
      if parts.len == 2:
        result.difficulty[parts[0].strip()] = parts[1].strip()
        
        # key count from CircleSize
        if parts[0].strip() == "CircleSize":
          result.keyCount = parseInt(parts[1].strip())
    
    of "TimingPoints":
      let fields = trimmedLine.split(',')
      if fields.len >= 2:
        var tp = TimingPoint()
        tp.time = parseFloat(fields[0].strip()) / 1000.0
        tp.beatLength = parseFloat(fields[1].strip())
        
        # meter if exists
        if fields.len > 2:
          tp.meter = parseInt(fields[2].strip())
        else:
          tp.meter = 4 # otherwise: 4/4
        
        # uniherited?
        if fields.len > 6:
          tp.uninherited = fields[6].strip() == "1"
        
        # kiai?
        if fields.len > 7:
          let effects = parseInt(fields[7].strip())
          tp.kiaiMode = (effects and 0b1) != 0
        
        # derived values
        if tp.beatLength > 0 and tp.uninherited:
          tp.bpm = some(60000.0 / tp.beatLength)
          tp.velocity = 1.0
        else:
          tp.velocity = abs(100.0 / tp.beatLength)
        
        result.timingPoints.add(tp)
    
    of "HitObjects":
      let fields = trimmedLine.split(',')
      if fields.len >= 4:
        let x = parseInt(fields[0].strip())
        let y = parseInt(fields[1].strip())
        let time = parseFloat(fields[2].strip()) / 1000.0
        let typeValue = parseInt(fields[3].strip())
        
        if (typeValue and 0b10000000) != 0: # hold note (bit 7)
          var hold = HitObject(
            kind: Hold,
            x: x,
            y: y,
            time: time
          )
          
          if fields.len >= 6:
            let endTimeStr = fields[5].split(':')[0]
            hold.endTime = parseFloat(endTimeStr) / 1000.0  # sec
          
          result.hitObjects.add(hold)
        else: # generic note
          result.hitObjects.add(HitObject(
            kind: Note,
            x: x,
            y: y,
            time: time
          ))

const InvalidChars = {'\\', '/', '*', '?', '\"', '<', '>', '|', '\''}
const ReplaceChars = {' ', '-', '_', '.', ':', '[', ']', '(', ')', '{', '}', '`', '~', ','}

proc sanitizeString(input: string): string =
  result = ""
  for c in input:
    if c notin InvalidChars and ord(c) >= 32:
      if c in ReplaceChars:
        if result.len > 0 and result[result.len - 1] != '_':
          result.add('_')
      else:
        result.add(c)
  
  result = result.strip()
  if result.len > 0 and result[result.len - 1] == '_':
    result = result[0 ..< result.len - 1]
  
  if result.len == 0:
    result = "unknown"

proc convertToEnyFormat(beatmap: OsuManiaBeatmap): JsonNode =
  let title = if beatmap.metadata.hasKey("Title"): beatmap.metadata["Title"] else: "Unknown"
  let artist = if beatmap.metadata.hasKey("Artist"): beatmap.metadata["Artist"] else: "Unknown"
  let version = if beatmap.metadata.hasKey("Version"): beatmap.metadata["Version"] else: ""
  let creator = if beatmap.metadata.hasKey("Creator"): beatmap.metadata["Creator"] else: "Unknown"
  let source = if beatmap.metadata.hasKey("Source"): beatmap.metadata["Source"] else: ""
  
  let fullTitle = fmt"{title}"
  let songName = sanitizeString(fmt"{title}".toLower())
  
  var result = newJObject()
  result["title"] = %("(osu!mania): " & fullTitle)
  result["song"] = %songName
  result["extra"] = %*{
    "game": "OSU_MANIA",
    "artist": artist,
    "creator": creator,
    "difficulty": version,
    "source": source,
    "keyCount": beatmap.keyCount
  }
  
  var notesArray = newJArray()
  
  # sort hit objects by time
  var allNotes = beatmap.hitObjects
  allNotes.sort(proc (a, b: HitObject): int = cmp(a.time, b.time))
  
  # find X positions to get column mapping
  var xPositions = collect(newSeq):
    for obj in allNotes: obj.x
  xPositions = deduplicate(xPositions)
  xPositions.sort()
  
  for obj in allNotes:
    var noteObj = newJObject()
    
    # X position to col (0-based)
    let columnIdx = xPositions.find(obj.x)
    noteObj["column"] = %columnIdx
    noteObj["time"] = %obj.time
    
    # length for hold
    if obj.kind == Hold:
      let length = obj.endTime - obj.time
      noteObj["length"] = %length
    
    notesArray.add(noteObj)
  
  result["notes"] = notesArray
  return result

proc convertOsuManiaToEny(filePath: string) =
  echo "Converting osu!mania file: ", filePath
  
  let beatmap = parseBeatmap(filePath)
  
  # check if its mania
  if beatmap.general.getOrDefault("Mode", "0") != "3":
    echo "Error: This is not an osu!mania beatmap"
    quit(1)
  
  let title = beatmap.metadata.getOrDefault("Title", "Unknown")
  let artist = beatmap.metadata.getOrDefault("Artist", "Unknown")
  let version = beatmap.metadata.getOrDefault("Version", "")
  
  echo "metadata:"
  echo fmt"  Song: {artist} - {title} [{version}]"
  echo fmt"  Key count: {beatmap.keyCount}"
  echo fmt"  Total notes: {beatmap.hitObjects.len}"
  
  let enyJson = convertToEnyFormat(beatmap)
  let songName = enyJson["song"].getStr
  let outputFilename = songName & ".json"
  
  let outputPath = "OsuToEnyConverter/content/chart/" & outputFilename
  createDir("OsuToEnyConverter/content/chart")
  writeFile(outputPath, pretty(enyJson))
  
  let totalNotes = beatmap.hitObjects.len
  let holdNotes = beatmap.hitObjects.countIt(it.kind == Hold)
  let regularNotes = totalNotes - holdNotes
  
  echo "Conversion complete! {totalNotes} notes converted"
  echo fmt"Make sure that '{songName}.mp3' is in your content/music directory"

when isMainModule:
  if paramCount() < 1:
    echo "Usage: osu_to_eny <chart.osu>"
  else:
    let filePath = paramStr(1)
    if not fileExists(filePath):
      echo "Error: Mania File does not exist: ", filePath
      quit(1)
    
    convertOsuManiaToEny(filePath)