{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Module, which provides database operations for rounds.
module DB.RoundDAO
( DB.RoundDAO.createTables
, getRounds
, insertRound
, getRound
, existsNewRound
) where

import qualified Database.SQLite.Simple as SQL
import           Data.Maybe
import           DB.ScoreDAO
import           DB.SolutionDAO
import           Snap.Snaplet.SqliteSimple
import           Snap.Snaplet
import           Application
import qualified Data.Text as T (concat)
import           DB.Utils
import           Control.Monad
import           Control.Applicative
import           Types.Score
import qualified Types.Round as R
import           Types.Solution
import qualified Data.Foldable as F

-- | Represents a database row of the table round.
data RoundDAO = RoundDAO { roundid :: DatabaseId
                         , roundnr :: Integer
                         , gameid  :: DatabaseId
                         , letters :: String
                         }

instance FromRow RoundDAO where
  fromRow = RoundDAO <$> field <*> field <*> field <*> field

-- | Parses a roundDao to a normal round object.
parseRound :: RoundDAO    -- ^ round database row
           -> Maybe Score -- ^ score of round
           -> [Solution]  -- ^ solutions to a round
           -> R.Round     -- ^ round model
parseRound dao = R.Round (Just $ roundid dao) (Just $ roundnr dao) (letters dao)

-- | Creates the round table.
createTables :: SQL.Connection -- ^ database connection
             -> IO ()        -- ^ nothing
createTables conn =
    createTable conn "round" $
        T.concat [ "CREATE TABLE round ("
                 , "round_id INTEGER PRIMARY KEY, "
                 , "round_nr INTEGER, "
                 , "game_id INTEGER NOT NULL, "
                 , "letters TEXT NOT NULL, "
                 , "FOREIGN KEY(game_id) REFERENCES game(game_id))"
                 ]             
-- | Returns all the rounds of a game.
getRounds :: DatabaseId                 -- ^ database id of the game
          -> Handler App Sqlite [R.Round] -- ^ rounds of the game
getRounds gameId = do
    results <- query "SELECT * FROM round WHERE game_id = ?" (Only gameId)
    mapM buildRound results

-- | Returns round by id.
getRound :: DatabaseId                 -- ^ database id of the round
          -> Handler App Sqlite (Maybe R.Round) -- ^ round
getRound roundId = do
    result <- query "SELECT * FROM round WHERE round_id = ?" (Only roundId)
    case result of
        [resultRound] -> Just <$> buildRound resultRound
        _ -> return Nothing
    
-- | Builds one single round out of a the database row.
buildRound :: RoundDAO                   -- ^ dao which represents a row in the db
           -> Handler App Sqlite R.Round -- ^ normal round object
buildRound dao = do
    roundScore <- getScore $ roundid dao
    solutions <- getSolutions $ roundid dao
    return $ parseRound dao roundScore solutions

-- | Inserts a round in the database.
insertRound :: DatabaseId            -- ^ database id of the game of the round
            -> R.Round                 -- ^ round to insert
            -> Handler App Sqlite () -- ^ nothing
insertRound gameId newRound = do
    let values = (gameId, gameId, R.letters newRound)
    execute "INSERT INTO round (round_nr, game_id, letters) VALUES ((SELECT IFNULL(MAX(round_nr), 0) + 1 FROM round WHERE game_id = ?), ?, ?)" values
    inserted <- query "SELECT * FROM round WHERE round_nr = (SELECT MAX(round_nr) FROM round where game_id = ?)" (Only gameId)
    let roundId = roundid $ head inserted
    mapM_ (insertSolution roundId) $ R.solutions newRound
    let roundScore = R.roundScore newRound
    F.forM_ roundScore (insertScore roundId)
    
-- | Checks for whether a new round exists.
existsNewRound :: DatabaseId              -- ^ database id of the game of the round
               -> Integer                 -- ^ nr of the old round
               -> Handler App Sqlite Bool -- ^ True if new round exists, else False
existsNewRound gameId oldRoundNr = do
    result <- query "SELECT 1 FROM round WHERE game_id = ? AND round_nr > ? LIMIT 1" (gameId, oldRoundNr) :: Handler App Sqlite [Only Integer]
    return $ not (null result)