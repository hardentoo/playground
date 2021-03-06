#!/usr/bin/env stack
{-
  stack --resolver lts-8.17 script
    --package async
    --package bytestring
    --package stm
    --package text
    --
    -Wall -fwarn-tabs
-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

import Control.Applicative ((<|>))
import Control.Concurrent.Async
import Control.Concurrent.STM
import qualified Data.ByteString.Char8 as S8
import Data.Text (Text, pack)
import Data.Text.Encoding (encodeUtf8)

say :: Text -> IO ()
say = S8.putStrLn . encodeUtf8

data TCChan a = TCChan
  { _channel :: TChan a
  , _isClosed :: TVar Bool
  } deriving (Show)

instance Show (TChan a) where
  show _ = "TChan" :: String

instance Show (TVar a) where
  show _ = "TVar" :: String

newTCChan :: IO (TCChan a)
newTCChan = atomically $ TCChan <$> newTChan <*> newTVar False

closeTCChan :: TCChan a -> IO ()
closeTCChan (TCChan _ var) = atomically $ writeTVar var True

writeTCChan :: TCChan a -> a -> STM ()
writeTCChan (TCChan chan var) val = do
  closed <- readTVar var
  if closed
    -- Could use nicer exception types, or return a Bool
    -- to indicate if writing failed.
    then error "Wrote to a closed TCChan"
    else writeTChan chan val

readTCChan :: TCChan a -> STM (Maybe a)
readTCChan (TCChan chan var) =
  (Just <$> readTChan chan) <|>
  (do closed <- readTVar var
      check closed
      return Nothing)

worker :: TCChan Int -> Int -> IO ()
worker chan num = loop
  where
    loop = do
      mi <- atomically $ readTCChan chan
      case mi of
        Nothing -> pure ()
        Just i -> do
          say $ pack $ concat ["Worker #", show num, " received value ", show i]
          loop

main :: IO ()
main = do
  chan <- newTCChan
  putStrLn $ "channel = " ++ show chan
  mapConcurrently (worker chan) [1 .. 5] `concurrently_` do
    mapM_ (atomically . writeTCChan chan) [1 .. 10]
    closeTCChan chan
