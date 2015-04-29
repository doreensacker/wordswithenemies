{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module DB.PlayerDb where

import           Control.Applicative
import           Control.Monad
import qualified Database.SQLite.Simple as S
import           Snap.Snaplet
import           Snap.Snaplet.SqliteSimple
import qualified Data.Text as T
import           Types.Player
import           Application

tableExists :: S.Connection -> String -> IO Bool
tableExists con tableName = do
    r <- S.query con "SELECT name FROM sqlite_master WHERE type='table' AND name=?" (Only tableName)
    case r of
         [Only (_ :: String)] -> return True
         _ -> return False
    
createTables :: S.Connection -> IO ()
createTables conn = do
  schemaCreated <- tableExists conn "player"
  unless schemaCreated $
    S.execute_ conn
      (S.Query $
       T.concat [ "CREATE TABLE player ("
                , "player_id INTEGER PRIMARY KEY, "
                , "nickname TEXT NOT NULL)"])

                
savePlayer :: Player -> Handler App Sqlite [Player]
savePlayer (Player _ name) = do
     execute "INSERT INTO player (nickname) VALUES (?)" (Only (name))
     result <- query "SELECT * FROM player WHERE nickname = ? AND player_id = (SELECT max(player_id) FROM player WHERE nickname = ?)" (name, name)
     return result
