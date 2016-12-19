module Page.PlayLive.Model exposing (..)

import Time exposing (Time)
import Dict exposing (Dict)
import Model.Shared exposing (..)
import Game.Shared exposing (GameState, WithGameControl)
import Game.Inputs as Input
import Game.Touch as Touch exposing (Touch)
import Keyboard.Extra as Keyboard
import Page.PlayLive.Chat.Model as Chat
import Window
import Set


type alias Model =
    WithGameControl
        { liveTrack : HttpData LiveTrack
        , gameState : Maybe GameState
        , lastPush : Time
        , keyboard : Keyboard.Model
        , touch : Touch
        , dims : ( Int, Int )
        , tab : Tab
        , races : List Race
        , freePlayers : List Player
        , live : Bool
        , ghostRuns : Dict String Player
        , chat : Chat.Model
        }


type Tab
    = NoTab
    | LiveTab
    | RankingsTab
    | HelpTab


initial : Model
initial =
    { liveTrack = Loading
    , gameState = Nothing
    , lastPush = 0
    , keyboard = Keyboard.Model Set.empty
    , touch = Touch.initial
    , dims = ( 1, 1 )
    , tab = NoTab
    , races = []
    , freePlayers = []
    , live = False
    , ghostRuns = Dict.empty
    , chat = Chat.initial
    }


type Msg
    = Load (HttpResult ( LiveTrack, Course ))
    | InitGameState LiveTrack Course Time
    | UpdateLiveTrack LiveTrack
    | KeyboardMsg Keyboard.Msg
    | TouchMsg Touch.Msg
    | ChatMsg Chat.Msg
    | WindowSize Window.Size
    | RaceUpdate Input.RaceInput
    | Frame Time
    | SetTab Tab
    | StartRace
    | ExitRace
    | AddGhost String Player
    | RemoveGhost String
    | NoOp