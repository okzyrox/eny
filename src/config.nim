## eny
## 
## cc: okzyrox
import raylib
import std/[json, os, json]

type
  EnyConfig* = object
    chartToLoad*: string
    # recording
    isRecordingMode*: bool
    recordingModeSongName*: string

    # play
    scrollSpeed*: float

proc `%`*(config: EnyConfig): JsonNode =
  var jsonObj = newJObject()
  jsonObj["chartToLoad"] = %config.chartToLoad
  jsonObj["recordingMode"] = %config.isRecordingMode
  jsonObj["recordingModeSong"] = %config.recordingModeSongName
  jsonObj["scrollSpeed"] = %config.scrollSpeed
  return jsonObj

proc loadEnyConfig*(filePath: string): EnyConfig =
  if not fileExists(filePath):
    echo "Config file not found, creating a new one."
    var defaultConfig = EnyConfig(
      chartToLoad: "recordedtest",
      isRecordingMode: false,
      recordingModeSongName: "testsong1",
      scrollSpeed: 1.5
    )
    var jsonObj = %defaultConfig
    writeFile(filePath, pretty(jsonObj))
    return defaultConfig
  else:
    let jsonContent = readFile(filePath)
    let jsonNode = parseJson(jsonContent)

    var config = EnyConfig()
    config.chartToLoad = jsonNode["chartToLoad"].getStr()
    config.isRecordingMode = jsonNode["recordingMode"].getBool()
    config.recordingModeSongName = jsonNode["recordingModeSong"].getStr()
    config.scrollSpeed = jsonNode["scrollSpeed"].getFloat()

    return config