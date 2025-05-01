import raylib
import states

import std/[math, strutils, strformat]

type
  GameResults* = object
    score*: int
    maxCombo*: int
    accuracy*: float
    perfect*: int
    great*: int
    good*: int
    ok*: int
    bad*: int
    miss*: int

var currentResults*: GameResults
var accuracy: float = 0.0

proc updateResults*() =
  if isKeyPressed(Space) or isMouseButtonPressed(Left):
    currentState = GameState.MainMenu
  
  accuracy = round(currentResults.accuracy * 100, 2)

var screenWidth = getScreenWidth()
var screenHeight = getScreenHeight()

proc drawResults*() =
  beginDrawing()
  clearBackground(Black)

  drawText("Results", screenWidth div 2 + 225, 100, 50, White)
  
  drawText("Score:", 200, 200, 30, White)
  drawText($currentResults.score, 400, 200, 30, Gold)
  
  drawText("Max Combo:", 200, 250, 30, White)
  drawText($currentResults.maxCombo, 400, 250, 30, White)
  
  drawText("Accuracy:", 200, 300, 30, White)
  drawText(fmt"{accuracy}%", 400, 300, 30, White)
  
  drawText("Perfect:", 200, 350, 30, White)
  drawText($currentResults.perfect, 400, 350, 30, Gold)

  drawText("Great:", 200, 400, 30, White)
  drawText($currentResults.great, 400, 400, 30, Green)

  drawText("Good:", 200, 450, 30, White)
  drawText($currentResults.good, 400, 450, 30, Yellow)

  drawText("OK:", 200, 500, 30, White)
  drawText($currentResults.ok, 400, 500, 30, Orange)

  drawText("Bad:", 200, 550, 30, White)
  drawText($currentResults.bad, 400, 550, 30, Red)

  drawText("Miss:", 200, 600, 30, White)
  drawText($currentResults.miss, 400, 600, 30, DarkGray)
  
  drawText("Press SPACE or click to continue", screenWidth div 2 - 200, screenHeight - 100, 30, LightGray)

  endDrawing()