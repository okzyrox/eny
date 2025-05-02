import chart, config
import raylib 
import discord_rpc
import std/[os, options]
type
  GameState* = enum
    MainMenu, Playing, Results, Recording

var currentState*: GameState = MainMenu
var currentChart*: Chart
var currentConfig*: EnyConfig
var currentSong*: Music
var discordPresence*: DiscordRPC
var isRecording*: bool = false

proc loadSong*(filePath: string) =
  if isRecording:
    currentChart = new Chart
    currentChart.songPath = filePath
    currentChart.notes = @[]
    
    if not fileExists("content/music/" & currentChart.songPath & ".mp3"):
      echo "Song file not found for recording: ", currentChart.songPath
      quit(1)
      
    currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
    setMusicVolume(currentSong, 0.5)
  # else:
    # var chartSongName = currentConfig.chartToLoad
    # currentChart = loadChart("content/chart/" & chartSongName & ".json")
    # if currentChart == nil:
    #   quit(1)
    # if not fileExists("content/music/" & currentChart.songPath & ".mp3"):
    #   echo "Song file not found: ", currentChart.songPath
    #   quit(1)
    # currentSong = loadMusicStream("content/music/" & currentChart.songPath & ".mp3")
    # setMusicVolume(currentSong, 0.5)

proc setState*(state: GameState) =
  currentState = state
  case state:
    of MainMenu:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "on the main menu",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Playing:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "playing a song",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Results:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "on the results screen",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    of Recording:
      discordPresence.setActivity Activity(
        details: "okzyrox's epic rhythm game",
        state: "recording a chart",
        assets: some ActivityAssets(
          largeImage: "eny",
          largeText: "Playing eny"
        )
      )
    