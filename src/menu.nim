## eny
## 
## cc: okzyrox
import raylib
# import discord_rpc
import std/[math, browsers, os, tables]
import ./[menuchart, states, chart, utils]
import ui/components

const
  MenuItemHeight = 100
  MenuItemWidth = 600
  MenuItemPadding = 20
  HighlightScale = 1.05
  LogoPulseSpeed = 0.8
  RecordButtonWidth = 160
  RecordButtonHeight = 40

type
  MenuState* = object
    charts*: seq[ChartInfo]
    selectedChart*: int
    scrollOffset*: float
    interactables*: seq[Interactable]  # Store all UI components
  MusicFadeState* = enum
    fsNone, fsFadeIn, fsFadeOut

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

  previewSong: Music
  currentPreviewId: int = -1
  previewFadeVolume: float = 0.0
  previewFadeState: MusicFadeState = fsNone
  previewFadeTimer: float = 0.0
  previewFadeDuration: float = 0.85

  existsPaths: seq[string] = @[]

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
    let artist = if chart.artist.len > 0: chart.artist else: "" # "Artist: " & 
    let creator = if chart.creator.len > 0: chart.creator else: "" # "Charter: " & 
    
    let listItem = newListItem(
      (getScreenWidth() - MenuItemWidth) / 2,
      yPos.float,
      MenuItemWidth.float,
      MenuItemHeight.float,
      title,
      "Artist:",
      artist,
      "Charter:",
      creator,
      chart.difficultyName,
      chart.lengthFormatted,
      chart.path,
      colorAlpha(BackgroundColor, 0.5),
      colorAlpha(BackgroundColor, 0.8),
      colorAlpha(BackgroundColor, 0.8),
      AccentColor2,
      MiscTextColor,
      AccentColor,
      TextColor,
      MiscTextColor
    )

    if title.len > LongTitleLength:
      listItem.isLongTitle = true
    
    menuState.interactables.add(listItem)
    songListItems.add(listItem)

proc initMenu*() =
  menuState.charts = loadAllChartInfo()
  menuState.selectedChart = -1
  menuState.scrollOffset = 0

  for chart in menuState.charts:
    if not existsPaths.contains(chart.path):
      if fileExists(chart.path):
        existsPaths.add(chart.path)
      else:
        echo "Chart file not found: ", chart.path
        continue

  visibleHeight = getScreenHeight() - TitleSize - TitlePadding - 100
  totalContentHeight = menuState.charts.len * (MenuItemHeight + MenuItemPadding)
  
  minScroll = min(0.0, visibleHeight.float - totalContentHeight.float)
  maxScroll = 0.0

  if not logoLoaded:
    logoTexture = loadTexture("assets/eny/eny.png")
    logoLoaded = true
  
  if currentPreviewId >= 0:
    stopMusicStream(previewSong)
    currentPreviewId = -1
    previewFadeVolume = 0.0
    previewFadeState = fsNone
    
  createInteractables()

proc handleSongPreview(hoveredIndex: int) =
  if previewCooldownTime > 0:
    previewCooldownTime -= getFrameTime()
  
  let hoveredSongPath = if hoveredIndex >= 0 and hoveredIndex < menuState.charts.len: 
                         menuState.charts[hoveredIndex].song 
                       else: ""
  
  if hoveredSongPath == "" and currentPreviewSong != "" and previewMusicActive:
    if previewFadeState != fsFadeOut:
      previewFadeState = fsFadeOut
      previewFadeTimer = 0.0
  
  elif previewCooldownTime <= 0 and hoveredSongPath != currentPreviewSong:
    previewCooldownTime = previewCooldownDuration
    if previewMusicActive and previewMusicCache.hasKey(currentPreviewSong):
      previewFadeState = fsFadeOut
      previewFadeTimer = 0.0
    
    if hoveredSongPath != "":
      if not previewMusicCache.hasKey(hoveredSongPath):
        # Load n cache music
        let musicPath = "content/music/" & hoveredSongPath & ".mp3"
        if fileExists(musicPath):
          previewMusicCache[hoveredSongPath] = loadMusicStream(musicPath)
          
          setMusicVolume(previewMusicCache[hoveredSongPath], 0.0)
          
          # good preview point (30s in or 1/3 song)
          let totalLength = getMusicTimeLength(previewMusicCache[hoveredSongPath])
          let previewPoint = min(30.0, totalLength / 3.0)
          seekMusicStream(previewMusicCache[hoveredSongPath], previewPoint)
      
      if previewMusicCache.hasKey(hoveredSongPath):
        playMusicStream(previewMusicCache[hoveredSongPath])
        let currentPlaybackTime = getMusicTimePlayed(previewMusicCache[hoveredSongPath])
        let totalLength = getMusicTimeLength(previewMusicCache[hoveredSongPath])
        let previewPoint = min(30.0, totalLength / 3.0)
        if currentPlaybackTime < previewPoint:
          seekMusicStream(previewMusicCache[hoveredSongPath], previewPoint)
        previewMusicActive = true
        previewFadeState = fsFadeIn
        previewFadeTimer = 0.0
    
    currentPreviewSong = hoveredSongPath
  
  if previewMusicActive and previewMusicCache.hasKey(currentPreviewSong):
    updateMusicStream(previewMusicCache[currentPreviewSong])
    previewFadeTimer += getFrameTime()
    
    case previewFadeState:
      of fsFadeIn:
        previewFadeVolume = min(0.5, previewFadeTimer / previewFadeDuration)
        if previewFadeTimer >= previewFadeDuration:
          previewFadeState = fsNone
          previewFadeVolume = 0.5
          
      of fsFadeOut:
        previewFadeVolume = max(0.0, 0.5 - (previewFadeTimer / previewFadeDuration))
        if previewFadeTimer >= previewFadeDuration:
          stopMusicStream(previewMusicCache[currentPreviewSong])
          previewMusicActive = false
          previewFadeState = fsNone
          previewFadeVolume = 0.0
          
          if hoveredSongPath == "":
            currentPreviewSong = ""
          
      of fsNone:
        discard
    
    if previewMusicActive and previewMusicCache.hasKey(currentPreviewSong):
      setMusicVolume(previewMusicCache[currentPreviewSong], previewFadeVolume)

proc cleanupPreviewCache*() =
  if previewMusicActive and previewMusicCache.hasKey(currentPreviewSong):
    stopMusicStream(previewMusicCache[currentPreviewSong])
    previewMusicActive = false
  
  previewMusicCache = initTable[string, Music]()
  currentPreviewSong = ""

proc cleanupMenu*() =
  if previewMusicActive and previewMusicCache.hasKey(currentPreviewSong):
    stopMusicStream(previewMusicCache[currentPreviewSong])
    previewMusicActive = false
  
  # Reset preview state
  previewFadeState = fsNone
  previewFadeVolume = 0.0
  currentPreviewSong = ""

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
  
  var hoveredSongIndex = -1

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
    
    if item.isLongTitle:
      if item.hovered:
        let titleWidth = measureText(item.title, item.titleSize)
        let visibleWidth = int32(item.bounds.width - 40)  # 20px padding on each side
        
        if titleWidth > visibleWidth:
          if item.titleScrollPause > 0:
            item.titleScrollPause -= getFrameTime()
          else:
            item.titleScrollPos += item.titleScrollSpeed * float(item.titleScrollDir) * getFrameTime()
            
            # reverse if needed
            if item.titleScrollDir > 0 and int32(item.titleScrollPos) >= (titleWidth - visibleWidth + 20):
              item.titleScrollDir = -1  # scroll back
              item.titleScrollPause = 0.8
            elif item.titleScrollDir < 0 and item.titleScrollPos <= 0:
              item.titleScrollDir = 1
              item.titleScrollPause = 0.8
      else:
        # Reset scroll
        item.titleScrollPos = 0
        item.titleScrollDir = 1
        item.titleScrollPause = 0
  
  for i, interactable in menuState.interactables:
    if interactable.update(mousePos):
      case interactable.kind:
        of ikButton:
          if interactable == recordButton:
            isRecording = true
            cleanupMenu()
            cleanupPreviewCache()
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
            cleanupMenu()
            cleanupPreviewCache()
            resetGameState()
            currentChart = loadChart(interactable.data)
            currentChart.startTime = -3.0
            currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
            setMusicVolume(currentSong, 0.5)
            setState(GameState.Playing)
            return
    if interactable.kind == ikListItem:
      if interactable.hovered:
        let index = songListItems.find(interactable)
        if index >= 0:
          hoveredSongIndex = index

  handleSongPreview(hoveredSongIndex)
  
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