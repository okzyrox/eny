import raylib
import states

import std/[math, strformat]

var accuracy: float = 0.0

proc updateResults*() =
  if isKeyPressed(Space) or isMouseButtonReleased(Left):
    resetGameState()
    setState(MainMenu)
  
  accuracy = round(currentResults.accuracy * 100, 2)

var screenWidth = getScreenWidth()
var screenHeight = getScreenHeight()

proc drawResults*() =
  beginDrawing()
  clearBackground(BackgroundColor4)

  drawText("Results", screenWidth div 2 + 225, 100, 50, AccentColor2)
  
  drawText("Score:", 200, 200, 30, TextColor)
  drawText($currentResults.score, 400, 200, 30, Gold)
  
  drawText("Max Combo:", 200, 250, 30, TextColor)
  drawText($currentResults.maxCombo, 400, 250, 30, White)
  
  drawText("Accuracy:", 200, 300, 30, TextColor)
  drawText(fmt"{accuracy}%", 400, 300, 30, White)
  
  drawText("Perfect:", 200, 350, 30, TextColor)
  drawText($currentResults.perfect, 400, 350, 30, Gold)

  drawText("Great:", 200, 400, 30, TextColor)
  drawText($currentResults.great, 400, 400, 30, Green)

  drawText("Good:", 200, 450, 30, TextColor)
  drawText($currentResults.good, 400, 450, 30, Yellow)

  drawText("OK:", 200, 500, 30, TextColor)
  drawText($currentResults.ok, 400, 500, 30, Orange)

  drawText("Bad:", 200, 550, 30, TextColor)
  drawText($currentResults.bad, 400, 550, 30, Red)

  drawText("Miss:", 200, 600, 30, TextColor)
  drawText($currentResults.miss, 400, 600, 30, DarkGray)
  
  drawText("Press SPACE or click to continue", screenWidth div 2 - 200, screenHeight - 100, 30, LightGray)

  drawDebugInfo()
  endDrawing()