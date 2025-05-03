## eny
## 
## cc: okzyrox
import raylib
import std/[json, os]

type
  EnyConfig* = object
    # recording
    recordingModeSongName*: string

    # play
    scrollSpeed*: float

    # keybinds
    keybinds*: seq[string]

proc `%`*(config: EnyConfig): JsonNode =
  var jsonObj = newJObject()
  jsonObj["recordingModeSong"] = %config.recordingModeSongName
  jsonObj["scrollSpeed"] = %config.scrollSpeed
  let keybindsNode = newJArray()
  for keybind in config.keybinds:
    keybindsNode.add(%keybind)
  jsonObj["keybinds"] = keybindsNode
  return jsonObj

proc loadEnyConfig*(filePath: string): EnyConfig =
  if not fileExists(filePath):
    echo "Config file not found, creating a new one."
    var defaultConfig = EnyConfig(
      recordingModeSongName: "princess_of_winter",
      scrollSpeed: 1.8,
      keybinds: @["D", "F", "J", "K"]
    )
    var jsonObj = %defaultConfig
    writeFile(filePath, pretty(jsonObj))
    return defaultConfig
  else:
    let jsonContent = readFile(filePath)
    let jsonNode = parseJson(jsonContent)

    var config = EnyConfig()
    config.recordingModeSongName = jsonNode["recordingModeSong"].getStr()
    config.scrollSpeed = jsonNode["scrollSpeed"].getFloat()
    config.keybinds = @[]
    for keybindNode in jsonNode["keybinds"]:
      config.keybinds.add(keybindNode.getStr())

    return config

proc getKeyFromKeybind*(keybind: string): KeyboardKey =
  case keybind:
    of "A": return KeyboardKey.A
    of "B": return KeyboardKey.B
    of "C": return KeyboardKey.C
    of "D": return KeyboardKey.D
    of "E": return KeyboardKey.E
    of "F": return KeyboardKey.F
    of "G": return KeyboardKey.G
    of "H": return KeyboardKey.H
    of "I": return KeyboardKey.I
    of "J": return KeyboardKey.J
    of "K": return KeyboardKey.K
    of "L": return KeyboardKey.L
    of "M": return KeyboardKey.M
    of "N": return KeyboardKey.N
    of "O": return KeyboardKey.O
    of "P": return KeyboardKey.P
    of "Q": return KeyboardKey.Q
    of "R": return KeyboardKey.R
    of "S": return KeyboardKey.S
    of "T": return KeyboardKey.T
    of "U": return KeyboardKey.U
    of "V": return KeyboardKey.V
    of "W": return KeyboardKey.W
    of "X": return KeyboardKey.X
    of "Y": return KeyboardKey.Y
    of "Z": return KeyboardKey.Z
    # numbers
    of "0": return KeyboardKey.Zero
    of "1": return KeyboardKey.One
    of "2": return KeyboardKey.Two
    of "3": return KeyboardKey.Three
    of "4": return KeyboardKey.Four
    of "5": return KeyboardKey.Five
    of "6": return KeyboardKey.Six
    of "7": return KeyboardKey.Seven
    of "8": return KeyboardKey.Eight
    of "9": return KeyboardKey.Nine
    
    # special
    of "SPACE": return KeyboardKey.Space
    of "ENTER": return KeyboardKey.Enter
    of "ESCAPE": return KeyboardKey.Escape
    of "TAB": return KeyboardKey.Tab
    of "BACKSPACE": return KeyboardKey.Backspace
    of "DELETE": return KeyboardKey.Delete
    of "UP": return KeyboardKey.Up
    of "DOWN": return KeyboardKey.Down
    of "LEFT": return KeyboardKey.Left
    of "RIGHT": return KeyboardKey.Right

    else: return KeyboardKey.Null # i cba to do them all, nobody is using underscore for input trust
