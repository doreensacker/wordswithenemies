{-# LANGUAGE OverloadedStrings #-}

module Api.PlayerSite where

import 			 Snap.PrettySnap
import 			 Data.Aeson
import qualified Data.ByteString.Char8 as B
import 			 Types.Player
import 			 Snap.Core
import 			 Snap.Snaplet
import 			 Snap.Snaplet.SqliteSimple
import 			 Snap.Util.FileServe
import 			 Snap.Snaplet.Auth
import 			 Snap.Snaplet.Auth.Backends.SqliteSimple
import 			 DB.PlayerDb
import 			 DB.Dictionary
import 			 Api.PlayerApp
import 			 Data.Maybe (fromJust)
import 			 Application

routes :: [(B.ByteString, Handler App PlayerApp())]
routes = [ (""          , method POST createPlayer)
         , (":id/status", method GET  getStatus)
         ]
         
apiInit :: SnapletInit App PlayerApp
apiInit = makeSnaplet "playerApi" "handles users" Nothing $ do
          addRoutes routes
          return PlayerApp
         
createPlayer :: Handler App PlayerApp ()
createPlayer = do
          body <- readRequestBody 2048
          setStatusCode 201
          dBResult <- withTop playerDb (savePlayer $ decodeBody body)
          setBody $ dBResult

getStatus :: Handler App PlayerApp ()
getStatus = do
		  userId <- getParam "id"
		--  game <- getGame userId
		  -- setBody game
		  setStatusCode 200