module Game where 

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import System.Exit (exitSuccess)
import Network.PlayerClient
import Network.GameClient
import Data.Maybe
import GHC.Conc
import Types.Player
import Types.Game
import Types.Round

welcomeMessage :: String
welcomeMessage = "Welcome to Words with Enemies\n\n \
                 \Please choose one of the following options:\n\
                 \[s]: Start game \t [h]: Help \t [q]: Quit"

waitingMessage :: String
waitingMessage = "Searching for a Teammate"

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
    playRound game

lettersMessage :: String
lettersMessage = "Please form a word out of the following letters"

playRound :: Game -> IO ()
playRound game = do
    putStrLn lettersMessage
    let round = head $ rounds game
    putStrLn $ letters round
    solution <- getLine
    postSolution solution game