import std/[strutils, strformat]

import raylib

const
  BackgroundColor* = Color(r: 48, g: 25, b: 52, a: 255)
  BackgroundColor2* = Color(r: 30, g: 10, b: 20, a: 255)
  BackgroundColor3* = Color(r: 15, g: 15, b: 25, a: 255)
  BackgroundColor4* = Color(r: 41, g: 8, b: 47, a: 255)
  AccentColor* = Color(r: 230, g: 230, b: 250, a: 255)
  AccentColor2* = Color(r: 207, g: 159, b: 255, a: 255)
  TextColor* = Color(r: 239, g: 209, b: 229, a: 255)
  MiscTextColor* = Color(r: 150, g: 150, b: 150, a: 255)
  EnyPink* = Color(r: 229, g: 88, b: 170 , a: 255)

const
  # hit feedback colors
  PerfectColor* = Color(r: 255, g: 215, b: 0, a: 255)
  GreatColor* = Color(r: 50, g: 205, b: 50, a: 255)
  GoodColor* = Color(r: 30, g: 144, b: 255, a: 255)
  OkColor* = Color(r: 255, g: 165, b: 0, a: 255)
  BadColor* = Color(r: 178, g: 34, b: 34, a: 255)
  MissColor* = Color(r: 169, g: 169, b: 169, a: 255)

proc drawDualText*(text1, text2: string, x, y: int32, textSize: int32, spacing: int32, color1, color2: Color) =
  let textWidth1 = measureText(text1, textSize)
  
  drawText(text1, x, y, textSize, color1)
  drawText(text2, (x + textWidth1 + spacing), y, textSize, color2)

proc formatTime*(seconds: float): string =
  let totalSeconds = int(seconds)
  let hours = totalSeconds div 3600
  let minutes = (totalSeconds mod 3600) div 60
  let seconds = totalSeconds mod 60
  if hours > 0:
    return &"{hours:02}:{minutes:02}:{seconds:02}"
  else:
    return &"{minutes:02}:{seconds:02}"