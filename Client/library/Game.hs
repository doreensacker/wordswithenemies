module Game where 

import           System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import           System.Exit (exitSuccess)
import           Network.PlayerClient
import           Network.GameClient
import           Data.Maybe
import           GHC.Conc (threadDelay)
import           Types.Player
import           Types.Game
import           Types.Round
import qualified Types.Solution as S
import qualified Types.Score as Score

welcomeMessage :: String
welcomeMessage = "Welcome to Words with Enemies\n\n \
                 \Please choose one of the following options:\n\
                 \[s]: Start game \t [h]: Help \t [q]: Quit"

waitingMessage :: String
waitingMessage = "Searching for a Teammate ..."

play :: IO ()
play = do 
    hSetBuffering stdout NoBuffering
    putStrLn welcomeMessage
    option <- getLine
    handleOption (option)

handleOption :: String -> IO ()
handleOption option
    | option == "q" = exitSuccess
    | option == "h" = help
    | option == "s" = enterName
    | otherwise = play
                
help :: IO ()
help = do 
    putStrLn "Help: \n\
    \5 Turns Each turn the two user are given random letters \n\
    \The two user must submit a dictionary checked word derived from these letters \n\
    \The words are compared. The winner of the duel is determined by whoever has the most left over letters.\n\
    \1 point is awarded for each left over letter.\
    \At the end of 5 turns who ever gets the most points wins the game."
    play

enterName :: IO ()
enterName = do
    hSetBuffering stdout NoBuffering
    putStrLn "Please enter your nickname:"
    nickname <- getLine
    handleNickname nickname

handleNickname :: String -> IO ()
handleNickname name 
    | null name = do
        putStrLn "Sorry, this is not a valid nickname!"
        enterName
    | otherwise = do
        player <- createPlayer name
        putStrLn $ show player
        checkForGame $ fromJust player

checkForGame :: Player -> IO ()
checkForGame player = do
    putStrLn waitingMessage
    game <- loopForGame player
    startGame player game

loopForGame :: Player -> IO Game
loopForGame player = do 
    game <- getStatus player
    if (isNothing game)
        then do 
            threadDelay 1000000
            loopForGame player
    else return $ fromJust game
 
teammateMessage :: String
teammateMessage = "Your Teammate is "
    
startGame :: Player -> Game -> IO ()
startGame self game = do
    let teammate = name $ head $ filter (/= self) (player game)
    putStrLn $ teammateMessage ++ teammate
    playRound self game

lettersMessage :: String
lettersMessage = "Please form a word out of the following letters"

maxRoundNr :: Game -> Integer
maxRoundNr game = maximum $ map (\round -> fromJust $ roundNr round) $ rounds game

playRound :: Player -> Game -> IO ()
playRound self game = do
    let round = head $ filter (\round -> (fromJust $ roundNr round) == (maxRoundNr game)) $ rounds game
    putStrLn lettersMessage
    putStrLn $ letters round
    userSolution <- getLine
    postSolution (S.Solution Nothing userSolution self) game
    newGame <- loopForRound round game
    let lastRound = head $ filter (\round -> (fromJust $ roundNr round) == ((maxRoundNr newGame)-1)) $ rounds newGame
    if (iDidWin self lastRound)
        then
            putStrLn $ "You won! You scored " ++ (scoreRound lastRound) ++ " points."
        else
            putStrLn $ "I'm sorry, you lost. Your teammate scored " ++ (scoreRound lastRound) ++ " points."
    putStrLn $ "Your total score is now " ++ myTotalScore self newGame
    putStrLn $ "The totalscore of you teammate is now " ++ teammateTotalScore self newGame
    if (status newGame == False)
        then 
            playRound self newGame
        else do
            putStrLn "This is the end of the game. Thanks for playing! Want to go again?"
            play
            
            

loopForRound :: Round -> Game -> IO Game
loopForRound lastRound game = do 
    newGame <- getGameWithNewRound lastRound game
    if (isNothing newGame)
        then do 
            threadDelay 1000000
            loopForRound lastRound game
        else return $ fromJust newGame
        
iDidWin :: Player -> Round -> Bool
iDidWin self round =  
    (Score.player $ fromJust $ roundScore round) == self

scoreRound :: Round -> String
scoreRound round = 
    show $ Score.score $ fromJust $ roundScore round
    
myTotalScore :: Player -> Game -> String
myTotalScore self game = 
    show $ foldl (+) 0 wonScores
     where wonScores = map (\round -> if ((Score.player $ fromJust $ roundScore round) == self) then Score.score $ fromJust $ roundScore round else 0) $ rounds game

teammateTotalScore :: Player -> Game -> String
teammateTotalScore self game = 
    show $ foldl (+) 0 wonScores
    where wonScores = map (\round -> if ((Score.player $ fromJust $ roundScore round) /= self) then Score.score $ fromJust $ roundScore round else 0) $ rounds game
