## eny
## 
## cc: okzyrox
import raylib
import std/[tables]

const
  # Note sprites
  SpriteSize = 16
  SheetSize = 64
  NotesPerRow = SheetSize div SpriteSize
  NotesCount = NotesPerRow * NotesPerRow
  SpriteUpscale* = 64

type
  Note* = ref object of RootObj
    texture*: Texture2D
    index*: int

proc loadNoteTextures*(imagePath: string): Table[string, Table[int, ref Note]] =
  var image = loadImage(imagePath)
  var notes: Table[string, Table[int, ref Note]] = initTable[string, Table[int, ref Note]]()
  notes["Active"] = initTable[int, ref Note]()
  notes["Inactive"] = initTable[int, ref Note]()

  for y in 0..<NotesPerRow:
    if y == 0 or y == 3:
      for x in 0..<NotesPerRow:
        let rect = Rectangle(x: float(x * SpriteSize), y: float(y * SpriteSize), width: float(SpriteSize), height: float(SpriteSize))
        var subImage = imageFromImage(image, rect)
        imageResizeNN(subImage, int32(SpriteUpscale), int32(SpriteUpscale))
        let texture = loadTextureFromImage(subImage)
        let posY = if y == 0: 0 else: 1
        if posY == 0:
          var note: ref Note
          new(note)
          note[] = Note(texture: texture, index: x)
          notes["Inactive"][x] = note
        else:
          var note: ref Note
          new(note)
          note[] = Note(texture: texture, index: x)
          notes["Active"][x] = note

  return notes