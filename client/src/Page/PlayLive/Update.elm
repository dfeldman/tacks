module Page.PlayLive.Update exposing (..)

import Time exposing (millisecond, second)
import Time exposing (Time)
import Dict exposing (Dict)
import Result exposing (Result(Ok, Err))
import Response exposing (..)
import Model.Shared exposing (..)
import Page.PlayLive.Model exposing (..)
import Page.PlayLive.Decoders as Decoders
import Page.PlayLive.Chat.Update as Chat
import Update.Utils exposing (..)
import ServerApi
import Game.Shared exposing (defaultGame, GameState)
import Game.Steps as Steps
import Game.Outputs as Output
import Game.Inputs as Input
import Task
import WebSocket
import AnimationFrame
import Keyboard.Extra as Keyboard
import Game.Touch as Touch
import Window
import Http


subscriptions : String -> Model -> Sub Msg
subscriptions host model =
    case model.liveTrack of
        DataOk liveTrack ->
            Sub.batch
                [ WebSocket.listen
                    (ServerApi.gameSocket host liveTrack.track.id)
                    Decoders.decodeStringMsg
                , AnimationFrame.times Frame
                , Sub.map KeyboardMsg Keyboard.subscriptions
                , Window.resizes WindowSize
                , Sub.map ChatMsg (Chat.subscriptions host model.chat)
                ]

        _ ->
            Sub.none


mount : String -> Response Model Msg
mount id =
    let
        cmd =
            Cmd.batch
                [ load id
                , Task.perform WindowSize Window.size
                ]
    in
        res initial cmd


update : Player -> String -> Msg -> Model -> Response Model Msg
update player host msg model =
    case msg of
        Load result ->
            case result of
                Ok ( liveTrack, course ) ->
                    Task.perform (InitGameState liveTrack course) Time.now
                        |> res model

                Err e ->
                    res { model | liveTrack = DataErr e } Cmd.none

        InitGameState liveTrack course time ->
            let
                gameState =
                    defaultGame time course player

                newModel =
                    { model | gameState = Just gameState }
                        |> applyLiveTrack liveTrack
            in
                res newModel Cmd.none

        ChatMsg chatMsg ->
            Chat.update (Output.sendToTrackServer host model.liveTrack) chatMsg model.chat
                |> mapBoth (\newChat -> { model | chat = newChat }) ChatMsg

        KeyboardMsg keyboardMsg ->
            if model.chat.focus then
                res model Cmd.none
            else
                let
                    ( newKeyboard, keyboardCmd ) =
                        Keyboard.update keyboardMsg model.keyboard
                in
                    res { model | keyboard = newKeyboard } (Cmd.map KeyboardMsg keyboardCmd)

        TouchMsg touchMsg ->
            res { model | touch = Debug.log "touch" (Touch.update touchMsg model.touch) } Cmd.none

        WindowSize size ->
            res { model | dims = ( size.width, size.height ) } Cmd.none

        RaceUpdate raceInput ->
            case model.gameState of
                Just gameState ->
                    res
                        { model | gameState = Just (Steps.raceInputStep raceInput gameState) }
                        Cmd.none

                Nothing ->
                    res model Cmd.none

        Frame time ->
            case model.gameState of
                Just gameState ->
                    let
                        keyboardInput =
                            Input.merge (Input.keyboardInput model.keyboard) (Input.touchInput model.touch)

                        gameInput =
                            Input.GameInput
                                keyboardInput
                                model.dims

                        newGameState =
                            Steps.frameStep gameInput time gameState

                        serverCmd =
                            Output.sendToTrackServer
                                host
                                model.liveTrack
                                (Output.UpdatePlayer (Output.playerOutput gameState))
                    in
                        if time - model.lastPush > 33 then
                            res { model | gameState = Just newGameState, lastPush = time } serverCmd
                        else
                            res { model | gameState = Just newGameState } Cmd.none

                Nothing ->
                    res model Cmd.none

        SetTab tab ->
            res { model | tab = tab } Cmd.none

        StartRace ->
            let
                start =
                    Output.sendToTrackServer host model.liveTrack Output.StartRace
            in
                res model start

        ExitRace ->
            let
                newModel =
                    { model | gameState = Maybe.map clearCrossedGates model.gameState }

                escape =
                    Output.sendToTrackServer host model.liveTrack Output.EscapeRace
            in
                res newModel escape

        AddGhost runId player ->
            let
                newGhostRuns =
                    Dict.insert runId player model.ghostRuns

                cmd =
                    Output.sendToTrackServer host model.liveTrack (Output.AddGhost runId player)
            in
                res { model | ghostRuns = newGhostRuns } cmd

        RemoveGhost runId ->
            let
                newGhostRuns =
                    Dict.remove runId model.ghostRuns

                cmd =
                    Output.sendToTrackServer host model.liveTrack (Output.RemoveGhost runId)
            in
                res { model | ghostRuns = newGhostRuns } cmd

        UpdateLiveTrack liveTrack ->
            res (applyLiveTrack liveTrack model) Cmd.none

        NoOp ->
            res model Cmd.none


applyLiveTrack : LiveTrack -> Model -> Model
applyLiveTrack ({ track, players, races } as liveTrack) model =
    let
        racePlayers =
            List.concatMap .players races

        inRace p =
            List.member p racePlayers

        freePlayers =
            List.filter (not << inRace) players
    in
        { model | liveTrack = DataOk liveTrack, races = races, freePlayers = freePlayers }


load : String -> Cmd Msg
load id =
    Task.map2 (,) (Http.toTask (ServerApi.getLiveTrack id)) (Http.toTask (ServerApi.getCourse id))
        |> Task.attempt Load


clearCrossedGates : GameState -> GameState
clearCrossedGates ({ playerState } as gameState) =
    { gameState | playerState = { playerState | crossedGates = [] } }