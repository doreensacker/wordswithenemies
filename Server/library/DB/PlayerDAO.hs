{-# LANGUAGE OverloadedStrings #-}

-- | Module, which provides database operations for players.
module DB.PlayerDAO
( createTables
, savePlayer
, getPlayer
, insertWaitingPlayer
, getTwoWaitingPlayers
, dropFromQueue
) where

import qualified Database.SQLite.Simple as S
import           Snap.Snaplet.SqliteSimple
import           Snap.Snaplet
import qualified Data.Text as T
import           Types.Player
import           DB.Utils
import           Application
import           Data.Maybe
import qualified Data.Foldable as F

-- | Creates the player and the queue table.
createTables :: S.Connection -- ^ database connection
             -> IO ()        -- ^ nothing
createTables conn = do
    createTable conn "player" $
        T.concat [ "CREATE TABLE player ("
                 , "player_id INTEGER PRIMARY KEY, "
                 , "nickname TEXT NOT NULL)"
                 ]
    createTable conn "queue" $
        T.concat [ "CREATE TABLE queue ("
                 , "id INTEGER PRIMARY KEY, "
                 , "waiting_player INTEGER, "
                 , "FOREIGN KEY(waiting_player) REFERENCES player(player_id))"
                 ]

-- | Saves a player to the database.                 
savePlayer :: Player                    -- ^ player to insert
           -> Handler App Sqlite Player -- ^ inserted player including id
savePlayer (Player _ nickname) = do
    execute "INSERT INTO player (nickname) VALUES (?)" (Only nickname)
    [savedPlayer] <- query "SELECT * FROM player WHERE player_id = (SELECT max(player_id) FROM player WHERE nickname = ?)" (Only nickname)
    F.mapM_ insertWaitingPlayer $ playerId savedPlayer
    return savedPlayer

-- | Gets a player with a specific id from the database.
getPlayer :: DatabaseId                 -- ^ id of the player
          -> Handler App Sqlite (Maybe Player)  -- ^ wanted player
getPlayer idOfPlayer = do
    result <- query "SELECT * FROM player WHERE player_id = ?" (Only idOfPlayer)
    case result of 
        [] -> return Nothing
        [p] -> return $ Just p

-- | Inserts a player in the waiting queue.
insertWaitingPlayer :: DatabaseId            -- ^ Id of the waiting player
                    -> Handler App Sqlite () -- ^ Nothing
insertWaitingPlayer player_id = 
    execute "INSERT INTO queue (waiting_player) VALUES (?)" (Only player_id)

-- | Returns a maximum of two player out of the waiting queue.
-- | Take care: Can also be less then two players.
getTwoWaitingPlayers :: Handler App Sqlite [Player] -- ^ 0 to 2 players out of the waiting queue
getTwoWaitingPlayers = do
    result <- query_ "SELECT waiting_player FROM queue LIMIT 2"
    players <- mapM getPlayer $ extracted result
    return $ map fromJust players
    where 
      extracted = map fromOnly

-- | Drops players from waiting queue.
dropFromQueue :: [Player]              -- ^ Player to drop.
              -> Handler App Sqlite () -- ^ nothing
dropFromQueue =
    mapM_ (execute "DELETE FROM queue WHERE waiting_player = ?" . Only . playerId)