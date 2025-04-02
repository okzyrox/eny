## eny
## 
## cc: okzyrox
import raylib

const
  # hit thresholds
  PerfectWindowMs* = 40.0
  GreatWindowMs* = 65.0
  GoodWindowMs* = 90.0
  OkWindowMs* = 120.0
  BadWindowMs* = 135.0

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
    of hrPerfect: Color(r: 255, g: 215, b: 0, a: 255)
    of hrGreat: Color(r: 50, g: 205, b: 50, a: 255)
    of hrGood: Color(r: 30, g: 144, b: 255, a: 255)
    of hrOk: Color(r: 255, g: 165, b: 0, a: 255)
    of hrBad: Color(r: 178, g: 34, b: 34, a: 255)
    of hrMiss: Color(r: 169, g: 169, b: 169, a: 255)