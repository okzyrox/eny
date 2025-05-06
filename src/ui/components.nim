import raylib
import ../[states, utils]

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
      subtitle1prefix*: string
      subtitle1*: string
      subtitle2prefix*: string
      subtitle2*: string
      rightText*: string
      miscText*: string
      selected*: bool
      data*: string
      titleSize*: int32 = 24
      miscTextSize*: int32 = 18 
      subtitleSize*: int32 = 18
      rightTextSize*: int32 = 20
      listItemBgColor*: Color
      listItemHoverColor*: Color
      selectedColor*: Color
      listItemTextColor*: Color
      subtitleColor*: Color
      subtitleSuffixColor*: Color
      rightTextColor*: Color
      miscTextColor*: Color
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

proc newListItem*(x, y: float, width, height: float, title, subtitle1prefix, subtitle1, subtitle2prefix, subtitle2, rightText, miscText, data: string,
                 listItemBgColor, listItemHoverColor, selectedColor, listItemTextColor, subtitleColor, subtitleSuffixColor, rightTextColor, miscTextColor: Color): Interactable =
  result = Interactable(
    kind: ikListItem,
    bounds: Rectangle(x: x, y: y, width: width, height: height),
    title: title,
    subtitle1prefix: subtitle1prefix,
    subtitle1: subtitle1,
    subtitle2prefix: subtitle2prefix,
    subtitle2: subtitle2,
    rightText: rightText,
    miscText: miscText,
    data: data,
    listItemBgColor: listItemBgColor,
    listItemHoverColor: listItemHoverColor,
    selectedColor: selectedColor,
    listItemTextColor: listItemTextColor,
    subtitleColor: subtitleColor,
    subtitleSuffixColor: subtitleSuffixColor,
    rightTextColor: rightTextColor,
    miscTextColor: miscTextColor
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
      drawRectangleRoundedLines(self.bounds, 0.5, 10, White)
      if self.hovered:
        drawRectangleRounded(self.bounds, 0.5, 10, self.hoverColor)
      else:
        drawRectangleRounded(self.bounds, 0.5, 10, self.bgColor)
        
      let textWidth = measureText(self.label, self.fontSize)
      let textX = self.bounds.x + (self.bounds.width - textWidth.float) / 2
      let textY = self.bounds.y + (self.bounds.height - self.fontSize.float) / 2
      
      drawFText(self.label, textX.int32, textY.int32, self.fontSize, self.textColor)
      
    of ikTextLabel:
      let text = if self.hovered: self.hoverText else: self.normalText
      let color = if self.hovered: self.textHoverColor else: self.textNormalColor
      
      drawFText(text, self.bounds.x.int32, self.bounds.y.int32, self.textSize, color)
      
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
          
          drawFText(self.title, 
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
          drawFText(self.title, 
                  (self.bounds.x + 20).int32, 
                  (self.bounds.y + 15).int32, 
                  self.titleSize, 
                  self.listItemTextColor)
      else:
        # title without scrolling
        drawFText(trimmedTitle, 
                (self.bounds.x + 20).int32, 
                (self.bounds.y + 15).int32, 
                self.titleSize, 
                self.listItemTextColor)
       
      if self.subtitle1.len > 0:    
        drawDualText("noto-sans-cjk", self.subtitle1prefix, self.subtitle1, 
                    (self.bounds.x + 20).int32, 
                    (self.bounds.y + 45).int32, 
                    self.subtitleSize, 
                    8, 
                    self.subtitleColor, 
                    self.subtitleSuffixColor)
      
      if self.subtitle2.len > 0:
        drawDualText(self.subtitle2prefix, self.subtitle2, 
                    (self.bounds.x + 20).int32, 
                    (self.bounds.y + 70).int32, 
                    self.subtitleSize, 
                    8, 
                    self.subtitleColor, 
                    self.subtitleSuffixColor)
      
      if self.miscText.len > 0:
        let miscTextWidth = measureText(self.miscText, self.miscTextSize)
        let centerX = (self.bounds.x + (self.bounds.width / 2) - (miscTextWidth / 2)).int32
        drawFText(self.miscText, 
                centerX, 
                (self.bounds.y + self.bounds.height - self.miscTextSize.float - 10).int32, 
                self.miscTextSize, 
                self.miscTextColor)
      
      if self.rightText.len > 0:
        let rightTextWidth = measureText(self.rightText, self.rightTextSize)
        drawFText(self.rightText, 
                (self.bounds.x + self.bounds.width - rightTextWidth.float - 20).int32, 
                (self.bounds.y + 70).int32, 
                self.rightTextSize, 
                self.rightTextColor)