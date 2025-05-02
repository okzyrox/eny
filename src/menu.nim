import raylib
import discord_rpc
import std/[math, browsers, options]
import menuchart, states, chart

const
  MenuItemHeight = 100
  MenuItemWidth = 600
  MenuItemPadding = 20
  HighlightScale = 1.05
  TitleSize = 60
  TitlePadding = 50
  LogoPulseSpeed = 0.8
  RecordButtonWidth = 160
  RecordButtonHeight = 40

type
  MenuState* = object
    charts*: seq[ChartInfo]
    selectedChart*: int
    scrollOffset*: float
    recordButtonHovered: bool
    authorCreditsHovered: bool

var menuState*: MenuState
var minScroll*: float
var maxScroll*: float
var visibleHeight*: int32
var totalContentHeight*: int

var 
  logoTexture: Texture2D
  logoLoaded = false
  logoScale = 1.0
  logoRotation = -15.0
  logoAlpha = 0.2
  logoScalePulseTime = 0.0
  logoAlphaPulseTime = 0.0

proc initMenu*() =
  menuState.charts = loadAllChartInfo()
  menuState.selectedChart = -1
  menuState.scrollOffset = 0
  menuState.recordButtonHovered = false

  visibleHeight = getScreenHeight() - TitleSize - TitlePadding - 100
  totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  
  minScroll = min(0.0, visibleHeight.float - totalContentHeight.float)
  maxScroll = 0.0

  if not logoLoaded:
    logoTexture = loadTexture("assets/eny/eny.png")
    logoLoaded = true


proc updateMenu*() =
  let mousePos = getMousePosition()

  let recordBtnRect = Rectangle(
    x: float(getScreenWidth() - RecordButtonWidth - 20), 
    y: 20, 
    width: RecordButtonWidth.float, 
    height: RecordButtonHeight.float
  )

  let authorCreditsRect = Rectangle(
    x: 20, 
    y: (getScreenHeight() - 40).float, 
    width: measureText("by okzyrox", 20).float,
    height: 20
  )
  
  menuState.recordButtonHovered = checkCollisionPointRec(mousePos, recordBtnRect)
  menuState.authorCreditsHovered = checkCollisionPointRec(mousePos, authorCreditsRect)
  
  if menuState.recordButtonHovered and isMouseButtonReleased(MouseButton.Left):
    isRecording = true
    currentConfig.isRecordingMode = true
    loadSong(currentConfig.recordingModeSongName)
    setState(GameState.Playing) # temp
    return
  
  if menuState.authorCreditsHovered and isMouseButtonReleased(MouseButton.Left):
    block: openDefaultBrowser("https://www.github.com/okzyrox")

  logoScalePulseTime += getFrameTime() * LogoPulseSpeed
  logoAlphaPulseTime += getFrameTime() * (LogoPulseSpeed * 0.7)
  
  logoScale = 0.95 + 0.1 * (sin(logoScalePulseTime) * 0.5 + 0.5)
  logoAlpha = 0.15 + 0.1 * (sin(logoAlphaPulseTime) * 0.5 + 0.5)
  
  let contentTop = TitleSize + TitlePadding * 2
  let contentBottom = getScreenHeight() - 60  # Leave space at bottom
  let contentHeight = contentBottom - contentTop
  
  let totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  let minScroll = min(0.0, contentHeight.float - totalContentHeight.float)
  let maxScroll = 0.0
  
  let wheel = getMouseWheelMove()
  if wheel != 0:
    menuState.scrollOffset -= wheel * 40
  
  menuState.scrollOffset = clamp(menuState.scrollOffset, minScroll, maxScroll)
  menuState.selectedChart = -1
  let listStartY = contentTop

  for i, chart in menuState.charts:
    let yPos = listStartY + (i * (MenuItemHeight + MenuItemPadding)) + menuState.scrollOffset.int
    
    let isVisible = yPos < contentBottom and (yPos + MenuItemHeight) > contentTop
    
    if not isVisible:
      continue
    
    let rect = Rectangle(
      x: (getScreenWidth() - MenuItemWidth) / 2, 
      y: yPos.float, 
      width: MenuItemWidth.float, 
      height: MenuItemHeight.float
    )
    
    if checkCollisionPointRec(mousePos, rect):
      menuState.selectedChart = i
      if isMouseButtonReleased(MouseButton.Left):
        currentChart = loadChart(menuState.charts[i].path)
        currentChart.startTime = -3.0
        currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
        setMusicVolume(currentSong, 0.5)
        setState(GameState.Playing)
        discordPresence.setActivity Activity(
          details: "okzyrox's epic rhythm game",
          state: "playing " & currentChart.songTitle,
          assets: some ActivityAssets(
            largeImage: "eny",
            largeText: "Playing eny"
          )
        )
        return

proc drawMenu*() =
  beginDrawing()
  clearBackground(Color(r: 15, g: 15, b: 25, a: 255))

  if logoLoaded:
    let screenWidth = getScreenWidth()
    let screenHeight = getScreenHeight()
    
    let logoWidth = float(logoTexture.width) * logoScale
    let logoHeight = float(logoTexture.height) * logoScale
    
    let logoX = float(screenWidth) - logoWidth * 0.7
    let logoY = float(screenHeight) - logoHeight * 0.7
    
    drawTexture(
      logoTexture,
      Rectangle(x: 0, y: 0, width: float(logoTexture.width), height: float(logoTexture.height)),
      Rectangle(x: logoX, y: logoY, width: logoWidth, height: logoHeight),
      Vector2(x: logoWidth/4, y: logoHeight/4 - 125),
      logoRotation,
      fade(White, logoAlpha)
    )
  
  
  let titleText = "Eny"
  let titleWidth = len(titleText) * 20
  drawText(titleText, (getScreenWidth() div 2 - titleWidth div 2).int32, TitlePadding, TitleSize, Pink)

  # record btn
  let recordBtnRect = Rectangle(
    x: float(getScreenWidth() - RecordButtonWidth - 20), 
    y: 20, 
    width: RecordButtonWidth.float, 
    height: RecordButtonHeight.float
  )
  if menuState.recordButtonHovered:
    drawRectangle(recordBtnRect, Color(r: 230, g: 41, b: 55, a: 230))
  else:
    drawRectangle(recordBtnRect, Color(r: 200, g: 41, b: 55, a: 180))
  
  drawText("Record", recordBtnRect.x.int32 + 20, recordBtnRect.y.int32 + 10, 20, White)

  let contentTop = float(TitleSize + TitlePadding * 2)
  let contentBottom = getScreenHeight() - 60 
  let contentHeight = contentBottom - contentTop.int32
  
  let containerRect = Rectangle(
    x: (getScreenWidth() - MenuItemWidth - 40) / 2,
    y: contentTop - 10.0,
    width: MenuItemWidth.float + 40,
    height: contentHeight.float + 20
  )
  drawRectangleRoundedLines(containerRect, 0.05, 10, 2, fade(White, 0.3))
  
  let totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  let minScroll = min(0.0, contentHeight.float - totalContentHeight.float)
  
  let listStartY = contentTop
  
  beginScissorMode(
    containerRect.x.int32, 
    containerRect.y.int32, 
    containerRect.width.int32, 
    containerRect.height.int32
  )
  
  # Draw song list
  for i, chart in menuState.charts:
    var yPos = listStartY.int + (i * (MenuItemHeight + MenuItemPadding)) + menuState.scrollOffset.int
    
    let isVisible = yPos < contentBottom + MenuItemHeight and (yPos + MenuItemHeight) > (contentTop - MenuItemHeight).int
    
    if not isVisible:
      continue
    
    var width = MenuItemWidth.float
    var height = MenuItemHeight.float
    var xPos = (getScreenWidth() - width.int32) / 2
    
    if menuState.selectedChart == i:
      width *= HighlightScale
      height *= HighlightScale
      xPos = (getScreenWidth() - width.int32) / 2
      var temp = (height - MenuItemHeight) / 2
      yPos -= temp.int32
    
    let rect = Rectangle(x: xPos, y: yPos.float, width: width, height: height)
    
    if menuState.selectedChart == i:
      drawRectangleRounded(rect, 0.5, 10, colorAlpha(DarkPurple, 0.8))
    else:
      drawRectangleRounded(rect, 0.5, 10, colorAlpha(DarkPurple, 0.5))
    drawRectangleRoundedLines(rect, 0.5, 10, White)
    
    let title = if chart.title.len > 0: chart.title else: "Unknown Title"
    let artist = if chart.artist.len > 0: "Artist: " & chart.artist else: ""
    let creator = if chart.creator.len > 0: "Charter: " & chart.creator else: ""
    
    drawText(title, xPos.int32 + 20, yPos.int32 + 15, 24, White)
    
    if artist.len > 0:
      drawText(artist, xPos.int32 + 20, yPos.int32 + 45, 18, LightGray)
    
    if creator.len > 0:
      drawText(creator, xPos.int32 + 20, yPos.int32 + 70, 18, LightGray)
    
    if chart.difficultyName.len > 0:
      let diffText = chart.difficultyName
      let diffWidth = measureText(diffText, 20)
      drawText(diffText, xPos.int32 + width.int32 - diffWidth.int32 - 20, yPos.int32 + 15, 20.int32, Yellow)
  
  endScissorMode()
  
  if totalContentHeight > contentHeight:
    if menuState.scrollOffset > minScroll:
      drawText("DOWN", getScreenWidth() div 2 - 10, contentBottom + 10, 30, colorAlpha(White, 0.6))
    
    if menuState.scrollOffset < 0:
      drawText("UP", getScreenWidth() div 2 - 10, (contentTop - 30).int32, 30, colorAlpha(White, 0.6))
  
  if menuState.authorCreditsHovered:
    drawText("by okzyrox!!!", 20, getScreenHeight() - 40, 20, Purple)
  else:
    drawText("by okzyrox!", 20, getScreenHeight() - 40, 20, LightGray)
  
  drawText("v0.1.0", getScreenWidth() - 100, getScreenHeight() - 40, 20, LightGray)
  drawText("Press ESC to exit", 20, 20, 20, LightGray)

  endDrawing()