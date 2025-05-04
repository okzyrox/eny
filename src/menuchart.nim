import json, os, strformat
import raylib

type
  ChartInfo* = object
    title*: string
    song*: string
    path*: string
    artist*: string
    creator*: string
    difficultyName*: string
    length*: float
    lengthFormatted*: string

proc formatTime(seconds: float): string =
  let totalSeconds = int(seconds)
  let hours = totalSeconds div 3600
  let minutes = (totalSeconds mod 3600) div 60
  let seconds = totalSeconds mod 60
  if hours > 0:
    return &"{hours:02}:{minutes:02}:{seconds:02}"
  else:
    return &"{minutes:02}:{seconds:02}"

proc loadChartInfo*(filePath: string): ChartInfo =
  let jsonContent = parseFile(filePath)
  
  result.title = jsonContent["title"].getStr("")
  result.song = jsonContent["song"].getStr("")
  result.path = filePath
  
  if jsonContent.hasKey("extra"):
    let extra = jsonContent["extra"]
    if extra.hasKey("artist"):
      result.artist = extra["artist"].getStr("")
    if extra.hasKey("creator"):
      result.creator = extra["creator"].getStr("")
    if extra.hasKey("difficulty"):
      result.difficultyName = extra["difficulty"].getStr("")
  
  var maxTime = 0.0
  for note in jsonContent["notes"]:
    if note.hasKey("time"):
      let time = note["time"].getFloat(0.0)
      if time > maxTime:
        maxTime = time
  
  result.length = maxTime
  if result.length == 0.0:
    result.length = 1.0
  
  result.lengthFormatted = formatTime(result.length)

proc loadAllChartInfo*(): seq[ChartInfo] =
  result = @[]
  for file in walkFiles("content/chart/*.json"):
    try:
      let chartInfo = loadChartInfo(file)
      result.add(chartInfo)
    except:
      echo "Failed to load chart: ", file