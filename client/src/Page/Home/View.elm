module Page.Home.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Date
import Date.Format as DateFormat
import Model.Shared exposing (..)
import Route exposing (..)
import Page.Home.Model exposing (..)
import View.Utils as Utils exposing (..)
import View.Layout as Layout
import View.Race as Race
import View.Track as Track
import View.TimeTrial as TimeTrial
import Dialog
import Set


pageTitle : LiveStatus -> Model -> String
pageTitle liveStatus model =
    let
        playersCount =
            List.concatMap liveTrackPlayers liveStatus.liveTracks |> List.length
    in
        if playersCount > 0 then
            "(" ++ toString playersCount ++ ") Home"
        else
            "Home"


view : Context -> Model -> Layout.Site Msg
view ctx model =
    Layout.Site
        "home"
        (Just Layout.Home)
        [ Layout.header
            ctx
            []
            [ h1 [] [ text "Sailing tactics from the sofa" ]
            , p
                [ class "subtitle" ]
                [ text "Tacks is a free regatta simulation game. Engage yourself in a realtime multiplayer race or attempt to break your best time to climb the rankings." ]
            ]
        , Layout.section
            [ class "white inside" ]
            [ div
                [ class "row live-center" ]
                [ div [ class "col-md-8" ] [ renderTimeTrial ctx.player ctx.liveStatus ]
                , div [ class "col-md-4" ] [ activePlayersPane ctx.player ctx.liveStatus model.pokes ]
                ]
            , div
                [ class "row" ]
                [ div [ class "col-md-12" ] [ liveTracks ctx.player ctx.liveStatus ]
                ]
            ]
        , Layout.section
            [ class "grey" ]
            [ h2 [] [ text "Recent races" ]
            , case model.raceReports of
                Loading ->
                    Utils.loading

                DataOk reports ->
                    Race.reports True reportClickHandler reports

                _ ->
                    text ""
            ]
        ]
        (Just (Dialog.view DialogMsg model.dialog (dialogContent model)))


dialogContent : Model -> Dialog.Layout
dialogContent model =
    case model.showDialog of
        Empty ->
            Dialog.emptyLayout

        RankingDialog liveTrack ->
            Track.rankingDialog liveTrack

        ReportDialog raceReport ->
            Race.reportDialog raceReport


renderTimeTrial : Player -> LiveStatus -> Html Msg
renderTimeTrial player liveStatus =
    case liveStatus.liveTimeTrial of
        Just liveTimeTrial ->
            div
                [ class "home-time-trial" ]
                [ h2
                    []
                    [ text "Current time trial" ]
                , TimeTrial.cardView player liveTimeTrial
                  -- , Utils.linkTo
                  --     (Route.ShowTimeTrial liveTimeTrial.timeTrial.id)
                  --     []
                  --     [ text "See all" ]
                ]

        Nothing ->
            text ""


liveTracks : Player -> LiveStatus -> Html Msg
liveTracks player { liveTracks } =
    let
        featuredTracks =
            liveTracks
                |> List.filter (.track >> .featured)
                |> List.map (\lt -> div [ class "col-md-4" ] [ Track.liveTrackBlock rankingClickHandler lt ])
    in
        div
            [ class "live-tracks" ]
            [ h2 [] [ text "Live tracks" ]
            , div [ class "row" ] featuredTracks
            ]


rankingClickHandler : LiveTrack -> Attribute Msg
rankingClickHandler liveTrack =
    onButtonClick (ShowDialog (RankingDialog liveTrack))


reportClickHandler : RaceReport -> Attribute Msg
reportClickHandler report =
    onButtonClick (ShowDialog (ReportDialog report))


activePlayersPane : Player -> LiveStatus -> List Id -> Html Msg
activePlayersPane player { liveTracks, onlinePlayers } pokes =
    let
        activeLiveTracks =
            liveTracks
                |> List.filter (\lt -> not (List.isEmpty lt.players))
                |> List.sortBy (\lt -> List.length lt.players)
                |> List.reverse

        activePlayers =
            activeLiveTracks
                |> List.concatMap .players
                |> List.map .id
                |> Set.fromList

        freePlayers =
            List.filter (\p -> not (Set.member p.id activePlayers)) onlinePlayers

        freePlayersBlock =
            if List.isEmpty onlinePlayers then
                text ""
            else
                div
                    [ class "free-players" ]
                    [ h4 [] [ text "Stand-by" ]
                    , ul
                        [ class "list-unstyled live-players" ]
                        (List.map (freePlayerItem player pokes) freePlayers)
                    ]

        trackPlayersBlock =
            if List.isEmpty activeLiveTracks then
                [ text "" ]
            else
                List.map activeTrackPlayers activeLiveTracks
    in
        div [ class "active-players" ] <|
            h2 [] [ text "Online players" ]
                :: trackPlayersBlock
                ++ [ freePlayersBlock ]


activeTrackPlayers : LiveTrack -> Html Msg
activeTrackPlayers { track, players } =
    Utils.linkTo
        (PlayTrack track.id)
        [ class "active-track-players" ]
        [ h4 [] [ text track.name ]
        , playersList players
        ]


playersList : List Player -> Html Msg
playersList players =
    ul
        [ class "list-unstyled live-players" ]
        (List.map playerItem players)


playerItem : Player -> Html Msg
playerItem player =
    li
        [ class "player" ]
        [ Utils.playerWithAvatar player ]


freePlayerItem : Player -> List Id -> Player -> Html Msg
freePlayerItem logged pokes player =
    let
        poking =
            List.member player.id pokes

        pokable =
            canPoke logged player
    in
        li
            [ classList
                [ ( "player", True )
                , ( "pokable", pokable )
                , ( "poking", poking )
                ]
            ]
            [ Utils.playerWithAvatar player
            , if pokable then
                span
                    [ class "poke"
                    , onClick
                        (if poking then
                            NoOp
                         else
                            Poke player
                        )
                    , title "Poke player"
                    ]
                    [ Utils.mIcon "notifications_active" [] ]
              else
                text ""
            ]
