## eny
## 
## cc: okzyrox
import raylib

const
  # hit thresholds
  PerfectWindowMs* = 45.0
  GreatWindowMs* = 60.0
  GoodWindowMs* = 80.0
  OkWindowMs* = 100.0
  BadWindowMs* = 115.0

const
  # hit feedback colors
  PerfectColor* = Color(r: 255, g: 215, b: 0, a: 255)
  GreatColor* = Color(r: 50, g: 205, b: 50, a: 255)
  GoodColor* = Color(r: 30, g: 144, b: 255, a: 255)
  OkColor* = Color(r: 255, g: 165, b: 0, a: 255)
  BadColor* = Color(r: 178, g: 34, b: 34, a: 255)
  MissColor* = Color(r: 169, g: 169, b: 169, a: 255)

type
  HitRating* = enum
    hrMiss, hrBad, hrOk, hrGood, hrGreat, hrPerfect
  
  HitFeedback* = object
    rating*: HitRating
    column*: int
    alpha*: float
    time*: float

proc getHitRating*(timeDiffMs: float): HitRating =
  let absTimeDiff = abs(timeDiffMs)
  if absTimeDiff <= PerfectWindowMs:
    return hrPerfect
  elif absTimeDiff <= GreatWindowMs:
    return hrGreat
  elif absTimeDiff <= GoodWindowMs:
    return hrGood
  elif absTimeDiff <= OkWindowMs:
    return hrOk
  elif absTimeDiff <= BadWindowMs:
    return hrBad
  else:
    return hrMiss

proc getScorePoints*(rating: HitRating): int =
  case rating:
    of hrPerfect: 100
    of hrGreat: 80
    of hrGood: 50
    of hrOk: 30
    of hrBad: 10
    of hrMiss: 0

proc getRatingColor*(rating: HitRating): Color =
  case rating:
    of hrPerfect: PerfectColor
    of hrGreat: GreatColor
    of hrGood: GoodColor
    of hrOk: OkColor
    of hrBad: BadColor
    of hrMiss: MissColor