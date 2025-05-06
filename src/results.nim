## eny
## 
## cc: okzyrox
import raylib
import ./[states, utils]

import std/[strformat]


proc updateResults*() =
  if isKeyPressed(Space) or isMouseButtonReleased(Left):
    resetGameState()
    resetResultsScreenFade()
    setState(MainMenu)
  

proc drawResults*() =
  beginDrawing()
  clearBackground(BackgroundColor4)

  drawFText("Results", getScreenWidth() div 2 + 225, 100, 50, AccentColor2)
  
  drawDualText("Score:", $currentResults.score, 200, 200, 30, 10, TextColor, Gold)

  drawDualText("Max Combo:", $currentResults.maxCombo, 200, 250, 30, 10, TextColor, AccentColor2)

  drawDualText("Accuracy:", fmt"{currentResults.accuracy:.2f}%", 200, 300, 30, 10, TextColor, Gold)

  drawDualText("Perfect:", $currentResults.perfect, 200, 350, 30, 10, TextColor, PerfectColor)
  drawDualText("Great:", $currentResults.great, 200, 400, 30, 10, TextColor, GreatColor)
  drawDualText("Good:", $currentResults.good, 200, 450, 30, 10, TextColor, GoodColor)
  drawDualText("OK:", $currentResults.ok, 200, 500, 30, 10, TextColor, OkColor)
  drawDualText("Bad:", $currentResults.bad, 200, 550, 30, 10, TextColor, BadColor)
  drawDualText("Miss:", $currentResults.miss, 200, 600, 30, 10, TextColor, MissColor)

  drawFText("Press SPACE or click to continue", getScreenWidth() div 2, getScreenHeight() - 100, 30, LightGray)

  if resultsScreenFadeIn:
    if resultsScreenFadeStartTime == 0.0:
      resultsScreenFadeStartTime = getTime()  # Or however you track time
    
    let fadeInProgress = (getTime() - resultsScreenFadeStartTime) / ResultsFadeDuration
    
    if fadeInProgress < 1.0:
      screenFadeAlpha = 1.0 - fadeInProgress
      drawRectangle(0, 0, getScreenWidth(), getScreenHeight(), 
                    fade(Black, float32(screenFadeAlpha)))
    else:
      # complete
      resultsScreenFadeIn = false
      screenFadeAlpha = 0.0

  drawDebugInfo()

  
  endDrawing()