module Game.Grid where

import Game.Core as Core
import Models exposing (..)

import Dict exposing (Dict)

hexRadius = 30
hexHeight = hexRadius * 2
hexWidth = (sqrt 3) / 2 * hexHeight
hexDims = (hexWidth, hexHeight)

currentTile : Grid -> Point -> Maybe TileKind
currentTile grid p =
  let
    (i, j) = pointToHexCoords p
  in
    (Dict.get i grid) `Maybe.andThen` (Dict.get j)

createTile : TileKind -> Coords -> Grid -> Grid
createTile kind (i,j) grid =
  let
    updateRow : Maybe GridRow -> GridRow
    updateRow maybeRow =
      case maybeRow of
        Just row ->
          Dict.insert j kind row
        Nothing ->
          Dict.singleton j kind
  in
    Dict.insert i (updateRow (Dict.get i grid)) grid

deleteTile : Coords -> Grid -> Grid
deleteTile (i, j) grid =
  let
    deleteInRow maybeRow =
      case maybeRow of
        Just row ->
          Dict.remove j row
        Nothing ->
          Dict.empty
  in
    Dict.insert i (deleteInRow (Dict.get i grid)) grid


hexCoordsToPoint : Coords -> Point
hexCoordsToPoint (i, j) =
  let
    x = hexRadius * (sqrt 3) * (toFloat i + toFloat j / 2)
    y = hexRadius * 3 / 2 * toFloat j
  in
    (x, y)

pointToHexCoords : Point -> Coords
pointToHexCoords (x, y) =
  let
    i = (x * (sqrt 3) / 3 - y / 3) / hexRadius
    j = y * (2 / 3) / hexRadius
  in
    hexRound (i, j)

hexRound : (Float, Float) -> Coords
hexRound =
  hexToCube >> cubeRound >> cubeToHex

cubeRound : Cube Float -> Cube Int
cubeRound (x, y, z) =
  let
    rx = round x
    ry = round y
    rz = round z

    xDiff = abs (toFloat rx - x)
    yDiff = abs (toFloat ry - y)
    zDiff = abs (toFloat rz - z)
  in
    if | xDiff > yDiff && xDiff > zDiff -> (-ry-rz, ry, rz)
       | yDiff > zDiff                  -> (rx, -rx-rz, rz)
       | otherwise                      -> (rx, ry, -rx-ry)

cubeToHex : Cube number -> (number, number)
cubeToHex (x, y, z) =
  (x, y)

hexToCube : (number, number) -> Cube number
hexToCube (i, j) =
  (i, j, -i-j)

getTilesList : Grid -> List Tile
getTilesList grid =
  let
    rows : List (Int, GridRow)
    rows =
      Dict.toList grid

    mapRow : (Int, GridRow) -> List Tile
    mapRow (i, row) =
      List.map (mapTile i) (Dict.toList row)

    mapTile : Int -> (Int, TileKind) -> Tile
    mapTile i (j, kind) =
      Tile kind (i, j)
  in
    List.concatMap mapRow rows
