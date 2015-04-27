module Main (main) where

import           Language.Haskell.HLint (hlint)
import           System.Exit            (exitFailure, exitSuccess)

arguments :: [String]
arguments = [ "executable"
            , "library"
            , "test-suite" ]

main :: IO ()
main = do
    hints <- hlint $ "--utf8" : arguments
    if null hints then exitSuccess else exitFailure