import raylib
from ../states import TitleSize, TitlePadding, LongTitleLength

type
  InteractableKind* = enum
    ikButton, ikTextLabel, ikListItem
    
  Interactable* = ref object of RootObj
    bounds*: Rectangle
    hovered*: bool
    clicked*: bool
    enabled*: bool = true
    case kind*: InteractableKind
    of ikButton:
      label*: string
      fontSize*: int32 = 20
      bgColor*: Color
      hoverColor*: Color
      textColor*: Color
    of ikTextLabel:
      text*: string
      normalText*: string
      hoverText*: string
      url*: string
      textSize*: int32 = 20
      textNormalColor*: Color 
      textHoverColor*: Color
    of ikListItem:
      title*: string
      subtitle1*: string
      subtitle2*: string
      rightText*: string
      selected*: bool
      data*: string
      titleSize*: int32 = 24
      subtitleSize*: int32 = 18
      rightTextSize*: int32 = 20
      listItemBgColor*: Color
      listItemHoverColor*: Color
      selectedColor*: Color
      listItemTextColor*: Color
      subtitleColor*: Color
      rightTextColor*: Color
      isLongTitle*: bool
      titleScrollPos*: float = 0.0
      titleScrollDir*: int = 1  # 1 = right, -1 = left
      titleScrollSpeed*: float = 40.0
      titleScrollPause*: float = 0.0

proc newButton*(x, y: float, width, height: float, label: string, 
                bgColor, hoverColor, textColor: Color): Interactable =
  result = Interactable(
    kind: ikButton,
    bounds: Rectangle(x: x, y: y, width: width, height: height),
    label: label,
    bgColor: bgColor,
    hoverColor: hoverColor,
    textColor: textColor
  )

proc newTextLabel*(x, y: float, normalText, hoverText: string, url: string, 
                  textNormalColor, textHoverColor: Color, textSize: int32 = 20): Interactable =
  let textWidth = measureText(normalText, textSize)
  result = Interactable(
    kind: ikTextLabel,
    bounds: Rectangle(x: x, y: y, width: textWidth.float, height: textSize.float),
    normalText: normalText,
    hoverText: hoverText,
    url: url,
    textSize: textSize,
    textNormalColor: textNormalColor,
    textHoverColor: textHoverColor
  )

proc newListItem*(x, y: float, width, height: float, title, subtitle1, subtitle2, rightText, data: string,
                 listItemBgColor, listItemHoverColor, selectedColor, listItemTextColor, subtitleColor, rightTextColor: Color): Interactable =
  result = Interactable(
    kind: ikListItem,
    bounds: Rectangle(x: x, y: y, width: width, height: height),
    title: title,
    subtitle1: subtitle1,
    subtitle2: subtitle2,
    rightText: rightText,
    data: data,
    listItemBgColor: listItemBgColor,
    listItemHoverColor: listItemHoverColor,
    selectedColor: selectedColor,
    listItemTextColor: listItemTextColor,
    subtitleColor: subtitleColor,
    rightTextColor: rightTextColor
  )

proc update*(self: Interactable, mousePos: Vector2): bool =
  if not self.enabled:
    return false
    
  let prevHovered = self.hovered
  self.hovered = checkCollisionPointRec(mousePos, self.bounds)
  self.clicked = self.hovered and isMouseButtonReleased(MouseButton.Left)

  if self.kind == ikListItem:
    if not self.hovered and prevHovered:
      self.titleScrollPos = 0.0
      self.titleScrollPause = 0.0
  
  return self.clicked

proc draw*(self: Interactable) =
  if not self.enabled:
    return
    
  case self.kind:
    of ikButton:
      # Draw button
      if self.hovered:
        drawRectangle(self.bounds, self.hoverColor)
      else:
        drawRectangle(self.bounds, self.bgColor)
        
      let textWidth = measureText(self.label, self.fontSize)
      let textX = self.bounds.x + (self.bounds.width - textWidth.float) / 2
      let textY = self.bounds.y + (self.bounds.height - self.fontSize.float) / 2
      
      drawText(self.label, textX.int32, textY.int32, self.fontSize, self.textColor)
      
    of ikTextLabel:
      let text = if self.hovered: self.hoverText else: self.normalText
      let color = if self.hovered: self.textHoverColor else: self.textNormalColor
      
      drawText(text, self.bounds.x.int32, self.bounds.y.int32, self.textSize, color)
      
    of ikListItem:
      let bgColor = if self.selected: self.selectedColor
                   elif self.hovered: self.listItemHoverColor 
                   else: self.listItemBgColor
      
      drawRectangleRounded(self.bounds, 0.5, 10, bgColor)
      drawRectangleRoundedLines(self.bounds, 0.5, 10, White)

      let visibleWidth = self.bounds.width - 40  # 20px padding
      let trimmedTitle = if self.title.len >= LongTitleLength: self.title.substr(0, LongTitleLength-1) & "..." else: self.title
      if self.isLongTitle and self.hovered:
        
        let titleWidth = float(measureText(self.title, self.titleSize))
        
        if titleWidth > visibleWidth:
          let titleClipRect = Rectangle(
            x: self.bounds.x + 20,
            y: self.bounds.y + 15,
            width: visibleWidth,
            height: self.titleSize.float
          )
          
          # save current scissor state - instead of nesting scissors
          endScissorMode()
          
          beginScissorMode(
            titleClipRect.x.int32,
            titleClipRect.y.int32,
            titleClipRect.width.int32,
            titleClipRect.height.int32
          )
          
          drawText(self.title, 
                  (self.bounds.x + 20 - self.titleScrollPos).int32, 
                  (self.bounds.y + 15).int32, 
                  self.titleSize, 
                  self.listItemTextColor)
          
          endScissorMode()
          
          # reapply scissor from drawMenu
          let contentTop = float(TitleSize + TitlePadding * 2)
          let contentBottom = getScreenHeight() - 60
          beginScissorMode(
            0,
            contentTop.int32,
            getScreenWidth(),
            (contentBottom - contentTop.int32).int32
          )
        else:
          # Title fits no need for scrolling
          drawText(self.title, 
                  (self.bounds.x + 20).int32, 
                  (self.bounds.y + 15).int32, 
                  self.titleSize, 
                  self.listItemTextColor)
      else:
        # title without scrolling
        drawText(trimmedTitle, 
                (self.bounds.x + 20).int32, 
                (self.bounds.y + 15).int32, 
                self.titleSize, 
                self.listItemTextColor)
       
      if self.subtitle1.len > 0:
        drawText(self.subtitle1, 
                (self.bounds.x + 20).int32, 
                (self.bounds.y + 45).int32, 
                self.subtitleSize, 
                self.subtitleColor)
      
      if self.subtitle2.len > 0:
        drawText(self.subtitle2, 
                (self.bounds.x + 20).int32, 
                (self.bounds.y + 70).int32, 
                self.subtitleSize, 
                self.subtitleColor)
      
      if self.rightText.len > 0:
        let rightTextWidth = measureText(self.rightText, self.rightTextSize)
        drawText(self.rightText, 
                (self.bounds.x + self.bounds.width - rightTextWidth.float - 20).int32, 
                (self.bounds.y + 70).int32, 
                self.rightTextSize, 
                self.rightTextColor)