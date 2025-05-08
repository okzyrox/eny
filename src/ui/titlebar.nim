## eny
## 
## cc: okzyrox

import std/[options]

import raylib
import ../utils

const 
  TitleBarHeight* = 28
  TitleBarPadding* = 10
  ButtonSize* = 20
  ButtonSpacing* = 8

type
  TitleBarButton = enum
    tbMinimize, tbMaximize, tbClose
  
  TitleBar* = object
    windowTitle*: string
    isDragging*: bool
    dragStartPos*: Vector2
    windowStartPos*: Vector2 
    hoveredButton*: Option[TitleBarButton] = none(TitleBarButton)
    titleBarRect*: Rectangle
    minimizeRect*: Rectangle
    maximizeRect*: Rectangle
    closeRect*: Rectangle
    lastScreenWidth*: int = 0

proc newTitleBar*(title: string): TitleBar =
  result.windowTitle = title
  result.isDragging = false
  result.dragStartPos = Vector2(x: 0, y: 0)
  result.windowStartPos = Vector2(x: 0, y: 0)
  result.hoveredButton = none(TitleBarButton)
  result.titleBarRect = Rectangle(
    x: 0, 
    y: 0, 
    width: getScreenWidth().float, 
    height: TitleBarHeight.float
  )
  result.closeRect = Rectangle(
    x: float(getScreenWidth() - ButtonSize - TitleBarPadding),
    y: (TitleBarHeight - ButtonSize) / 2,
    width: ButtonSize.float,
    height: ButtonSize.float
  )
  result.maximizeRect = Rectangle(
    x: result.closeRect.x - ButtonSize - ButtonSpacing,
    y: result.closeRect.y,
    width: ButtonSize.float,
    height: ButtonSize.float
  )
  result.minimizeRect = Rectangle(
    x: result.maximizeRect.x - ButtonSize - ButtonSpacing,
    y: result.closeRect.y,
    width: ButtonSize.float,
    height: ButtonSize.float
  )
  
  result

proc setTitle*(titlebar: var TitleBar, title: string) =
  titlebar.windowTitle = title

proc updateButtonPositions(titlebar: var TitleBar) =
  let currentWidth = getScreenWidth()
  if titlebar.lastScreenWidth != currentWidth:
    titlebar.lastScreenWidth = currentWidth
    titlebar.titleBarRect.width = currentWidth.float
    
    titlebar.closeRect.x = float(currentWidth - ButtonSize - TitleBarPadding)
    titlebar.maximizeRect.x = titlebar.closeRect.x - ButtonSize - ButtonSpacing
    titlebar.minimizeRect.x = titlebar.maximizeRect.x - ButtonSize - ButtonSpacing

proc update*(titlebar: var TitleBar) =
  updateButtonPositions(titlebar)
  let mousePos = getMousePosition()
  
  if checkCollisionPointRec(mousePos, titlebar.minimizeRect):
    titlebar.hoveredButton = some(tbMinimize)
  elif checkCollisionPointRec(mousePos, titlebar.maximizeRect):
    titlebar.hoveredButton = some(tbMaximize)
  elif checkCollisionPointRec(mousePos, titlebar.closeRect):
    titlebar.hoveredButton = some(tbClose)
  else:
    titlebar.hoveredButton = none(TitleBarButton)
  
  if isMouseButtonReleased(MouseButton.Left):
    if titlebar.hoveredButton.isSome:
      case titlebar.hoveredButton.get():
        of tbMinimize:
          minimizeWindow()
        of tbMaximize:
          if isWindowMaximized():
            restoreWindow()
          else:
            maximizeWindow()
        of tbClose:
          closeWindow()
  
  # dragging
  let inDragArea = checkCollisionPointRec(mousePos, titlebar.titleBarRect) and 
                  not checkCollisionPointRec(mousePos, titlebar.minimizeRect) and
                  not checkCollisionPointRec(mousePos, titlebar.maximizeRect) and
                  not checkCollisionPointRec(mousePos, titlebar.closeRect)
  
  if inDragArea:
    if isMouseButtonPressed(MouseButton.Left):
      # Start
      titlebar.isDragging = true
      titlebar.dragStartPos = mousePos
      let winPos = getWindowPosition()
      titlebar.windowStartPos = Vector2(x: winPos.x, y: winPos.y)
    
    elif isMouseButtonDown(MouseButton.Left) and titlebar.isDragging:
      # Continue
      let deltaX = mousePos.x - titlebar.dragStartPos.x
      let deltaY = mousePos.y - titlebar.dragStartPos.y
      
      let newX = titlebar.windowStartPos.x + deltaX
      let newY = titlebar.windowStartPos.y + deltaY
      setWindowPosition(newX.int32, newY.int32)
  
  # End
  if isMouseButtonReleased(MouseButton.Left) and titlebar.isDragging:
    titlebar.isDragging = false

proc draw*(titlebar: TitleBar) =
  drawRectangle(titlebar.titleBarRect, fade(BackgroundColor3, 0.9))
  drawLine(0, TitleBarHeight, getScreenWidth(), TitleBarHeight, fade(AccentColor, 0.5))
  
  drawFText(titlebar.windowTitle, TitleBarPadding, ((TitleBarHeight - 20) / 2).int32, 20, TextColor)
  
  # buttons
  let closeColor = if titlebar.hoveredButton.isSome and titlebar.hoveredButton.get() == tbClose: 
                     Color(r: 232, g: 17, b: 35, a: 255) 
                   else: 
                     fade(White, 0.7)
  
  let maximizeColor = if titlebar.hoveredButton.isSome and titlebar.hoveredButton.get() == tbMaximize: 
                        fade(White, 0.9) 
                      else: 
                        fade(White, 0.7)
  
  let minimizeColor = if titlebar.hoveredButton.isSome and titlebar.hoveredButton.get() == tbMinimize: 
                        fade(White, 0.9) 
                      else: 
                        fade(White, 0.7)
  
  # close button (X)
  let cx = titlebar.closeRect.x + titlebar.closeRect.width / 2
  let cy = titlebar.closeRect.y + titlebar.closeRect.height / 2
  let size = 6.0
  
  drawLine(
    Vector2(x: cx - size, y: cy - size),
    Vector2(x: cx + size, y: cy + size),
    2.0,
    closeColor
  )
  
  drawLine(
    Vector2(x: cx - size, y: cy + size),
    Vector2(x: cx + size, y: cy - size),
    2.0,
    closeColor
  )
  
  # maximize
  let squareSize = 10.0
  drawRectangleLines(
    Rectangle(
      x: titlebar.maximizeRect.x + (titlebar.maximizeRect.width - squareSize) / 2,
      y: titlebar.maximizeRect.y + (titlebar.maximizeRect.height - squareSize) / 2,
      width: squareSize,
      height: squareSize
    ),
    1.0,
    maximizeColor
  )
  
  # minimize
  let lineSize = 10.0
  drawLine(
    Vector2(
      x: titlebar.minimizeRect.x + (titlebar.minimizeRect.width - lineSize) / 2,
      y: titlebar.minimizeRect.y + titlebar.minimizeRect.height / 2
    ),
    Vector2(
      x: titlebar.minimizeRect.x + (titlebar.minimizeRect.width + lineSize) / 2,
      y: titlebar.minimizeRect.y + titlebar.minimizeRect.height / 2
    ),
    2.0,
    minimizeColor
  )

proc adjustForTitleBar*(y: int): int =
  return y + TitleBarHeight