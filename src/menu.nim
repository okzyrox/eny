import raylib
import discord_rpc
import std/[math, browsers, options]
import menuchart, states, chart
import ui/components

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
    interactables*: seq[Interactable]  # Store all UI components

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
  
  recordButton: Interactable
  authorLabel: Interactable
  songListItems: seq[Interactable]

proc createInteractables() =
  menuState.interactables = @[]
  songListItems = @[]
  
  recordButton = newButton(
    float(getScreenWidth() - RecordButtonWidth - 20),
    20.0,
    RecordButtonWidth.float,
    RecordButtonHeight.float,
    "Record",
    Color(r: 200, g: 41, b: 55, a: 180),
    Color(r: 230, g: 41, b: 55, a: 230),
    White
  )
  menuState.interactables.add(recordButton)
  
  authorLabel = newTextLabel(
    20.0,
    (getScreenHeight() - 40).float,
    "by okzyrox!",
    "by okzyrox!!!",
    "https://www.github.com/okzyrox",
    MiscTextColor,
    AccentColor2,
    20
  )
  menuState.interactables.add(authorLabel)
  
  let contentTop = TitleSize + TitlePadding * 2
  
  for i, chart in menuState.charts:
    let yPos = contentTop + (i * (MenuItemHeight + MenuItemPadding)) + menuState.scrollOffset.int
    let title = if chart.title.len > 0: chart.title else: "Unknown Title"
    let artist = if chart.artist.len > 0: "Artist: " & chart.artist else: ""
    let creator = if chart.creator.len > 0: "Charter: " & chart.creator else: ""
    
    let listItem = newListItem(
      (getScreenWidth() - MenuItemWidth) / 2,
      yPos.float,
      MenuItemWidth.float,
      MenuItemHeight.float,
      title,
      artist,
      creator,
      chart.difficultyName,
      chart.path,
      colorAlpha(BackgroundColor, 0.5),
      colorAlpha(BackgroundColor, 0.8),
      colorAlpha(BackgroundColor, 0.8),
      AccentColor2,
      MiscTextColor,
      Yellow
    )
    
    menuState.interactables.add(listItem)
    songListItems.add(listItem)

proc initMenu*() =
  menuState.charts = loadAllChartInfo()
  menuState.selectedChart = -1
  menuState.scrollOffset = 0

  visibleHeight = getScreenHeight() - TitleSize - TitlePadding - 100
  totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  
  minScroll = min(0.0, visibleHeight.float - totalContentHeight.float)
  maxScroll = 0.0

  if not logoLoaded:
    logoTexture = loadTexture("assets/eny/eny.png")
    logoLoaded = true
    
  createInteractables()

proc updateMenu*() =
  let mousePos = getMousePosition()
  
  # logo animation
  logoScalePulseTime += getFrameTime() * LogoPulseSpeed
  logoAlphaPulseTime += getFrameTime() * (LogoPulseSpeed * 0.7)
  
  logoScale = 0.95 + 0.1 * (sin(logoScalePulseTime) * 0.5 + 0.5)
  logoAlpha = 0.15 + 0.1 * (sin(logoAlphaPulseTime) * 0.5 + 0.5)
  
  # Update scrolling
  let contentTop = TitleSize + TitlePadding * 2
  let contentBottom = getScreenHeight() - 60
  let contentHeight = contentBottom - contentTop
  
  let totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  let minScroll = min(0.0, contentHeight.float - totalContentHeight.float)
  let maxScroll = 0.0
  
  let wheel = getMouseWheelMove()
  if wheel != 0:
    menuState.scrollOffset -= wheel * 40
  
  menuState.scrollOffset = clamp(menuState.scrollOffset, minScroll, maxScroll)
  
  let listStartY = contentTop
  for i, item in songListItems:
    let yPos = listStartY + (i * (MenuItemHeight + MenuItemPadding)) + menuState.scrollOffset.int
    item.bounds.y = yPos.float
    
    # scaling effect when hovered
    if item.hovered:
      item.bounds.width = MenuItemWidth.float * HighlightScale
      item.bounds.height = MenuItemHeight.float * HighlightScale
      item.bounds.x = (getScreenWidth().float32 - item.bounds.width) / 2
      let heightDiff = (item.bounds.height - MenuItemHeight.float) / 2
      item.bounds.y -= heightDiff
    else:
      item.bounds.width = MenuItemWidth.float
      item.bounds.height = MenuItemHeight.float
      item.bounds.x = (getScreenWidth().float32 - item.bounds.width) / 2
  
  for i, interactable in menuState.interactables:
    if interactable.update(mousePos):
      case interactable.kind:
        of ikButton:
          if interactable == recordButton:
            isRecording = true
            loadSong(currentConfig.recordingModeSongName)
            setState(GameState.Playing)
            return
            
        of ikTextLabel:
          # Author clicked
          if interactable == authorLabel:
            openDefaultBrowser(interactable.url)
            
        of ikListItem:
          # Song item clicked
          let index = songListItems.find(interactable)
          if index >= 0:
            resetGameState()
            currentChart = loadChart(interactable.data)
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
  
  menuState.selectedChart = -1
  for i, item in songListItems:
    if item.hovered:
      menuState.selectedChart = i
      break

proc drawMenu*() =
  beginDrawing()
  clearBackground(BackgroundColor2)
  
  # logo
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
  drawText(titleText, (getScreenWidth() div 2 - titleWidth div 2).int32, TitlePadding, TitleSize, EnyPink)
  
  let contentTop = float(TitleSize + TitlePadding * 2)
  let contentBottom = getScreenHeight() - 60 
  let contentHeight = contentBottom - contentTop.int32
  
  let containerRect = Rectangle(
    x: (getScreenWidth() - MenuItemWidth - 40) / 2,
    y: contentTop - 10.0,
    width: MenuItemWidth.float + 40,
    height: contentHeight.float + 20
  )
  
  drawRectangleRoundedLines(containerRect, 0.05, 10, 2, fade(AccentColor, 0.3))
  
  # scroll indicators
  let totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  if totalContentHeight > contentHeight:
    if menuState.scrollOffset > minScroll:
      drawText("DOWN", getScreenWidth() div 2 - 10, contentBottom + 10, 30, colorAlpha(White, 0.6))
    
    if menuState.scrollOffset < 0:
      drawText("UP", getScreenWidth() div 2 - 10, (contentTop - 30).int32, 30, colorAlpha(White, 0.6))
  
  beginScissorMode(
    containerRect.x.int32, 
    containerRect.y.int32, 
    containerRect.width.int32, 
    containerRect.height.int32
  )
  
  # Draw song list
  for i, item in songListItems:
    let yPos = item.bounds.y
    let isVisible = yPos < contentBottom.float32 + MenuItemHeight and (yPos + item.bounds.height) > (contentTop - MenuItemHeight)
    
    if isVisible:
      if item.kind == ikListItem:
        item.selected = menuState.selectedChart == songListItems.find(item)
      
      item.draw()
  
  endScissorMode()
  
  recordButton.draw()
  authorLabel.draw()
  
  drawText("v0.1.0", getScreenWidth() - 100, getScreenHeight() - 40, 20, EnyPink)
  drawText("Press ESC to exit", 20, 20, 20, MiscTextColor)

  drawDebugInfo()
  endDrawing()