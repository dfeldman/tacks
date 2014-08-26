module Game where

import Geo (..)
import Json
import Dict

{-- Part 2: Model the game ----------------------------------------------------

What information do you need to represent the entire game?

Tasks: Redefine `GameState` to represent your particular game.
       Redefine `defaultGame` to represent your initial game state.

For example, if you want to represent many objects that just have a position,
your GameState might just be a list of coordinates and your default game might
be an empty list (no objects at the start):

    type GameState = { objects : [(Float,Float)] }
    defaultGame = { objects = [] }

------------------------------------------------------------------------------}

data GateLocation = Downwind | Upwind
type Gate = { y: Float, width: Float, location: GateLocation }
type Island = { location : Point, radius : Float }
type Course = { upwind: Gate, downwind: Gate, laps: Int, markRadius: Float, islands: [Island], bounds: (Point, Point) }

data ControlMode = FixedDirection | FixedWindAngle

type Boat = { position: Point, direction: Float, velocity: Float, windAngle: Float, 
              windOrigin: Float, windSpeed: Float,
              center: Point, controlMode: ControlMode, tackTarget: Maybe Float,
              passedGates: [(GateLocation, Time)] }

type Opponent = { position : { x: Float, y: Float}, direction: Float, velocity: Float, passedGates: [Time] }

type Gust = { position : Point, radius : Float, speedImpact : Float, originDelta : Float }
type Wind = { origin : Float, speed : Float, gustsCount : Int, gusts : [Gust] }

type GameState = { wind: Wind, boat: Boat, opponents: [Opponent],
                   course: Course, leaderboard: [String], 
                   startDuration : Time, countdown: Time }

type RaceState = { boats : [Boat] }

startLine : Gate
startLine = { y = -100, width = 100, location = Downwind }

upwindGate : Gate
upwindGate = { y = 1000, width = 100, location = Upwind }

islands : [Island]
islands = [ { location = (250, 300), radius = 100 },
            { location = (50, 700), radius = 80 },
            { location = (-200, 500), radius = 60 } ]

course : Course
course = { upwind = upwindGate, downwind = startLine, laps = 3, markRadius = 5,
           islands = islands, bounds = ((800,1200), (-800,-400)) }

boat : Boat
boat = { position = (0,-200), direction = 0, velocity = 0, windAngle = 0, 
         windOrigin = 0, windSpeed = 0,
         center = (0,0), controlMode = FixedDirection, tackTarget = Nothing,
         passedGates = [] }

wind : Wind
wind = { origin = 0, speed = 10, gustsCount = 0, gusts = [] }


defaultGame : GameState
defaultGame = { wind = wind, boat = boat, opponents = [],
                course = course, leaderboard = [],
                startDuration = (30*second), countdown = 0 }

getGateMarks : Gate -> (Point,Point)
getGateMarks gate = ((-gate.width / 2, gate.y), (gate.width / 2, gate.y))

findNextGate : Boat -> Int -> Maybe GateLocation
findNextGate boat laps =
  let c = (length boat.passedGates)
      i = c `mod` 2
  in
    if | c == 0            -> Nothing
       | c == laps * 2 + 1 -> Nothing
       | i == 0            -> Just Downwind 
       | otherwise         -> Just Upwind

boatToOpponent : Boat -> Opponent
boatToOpponent ({position, direction, velocity} as boat) =
  let (x,y) = position
      gates = map snd boat.passedGates
  in  { position = {x = x, y = y}, direction = direction, velocity = velocity, passedGates = gates }  