{-# language DeriveGeneric #-}
{-# language OverloadedStrings #-}
{-# language RecordWildCards #-}

module Parser where

import Data.Attoparsec.Text.Lazy (Parser)
import Filesystem.Path.CurrentOS (FilePath)
import Data.Map (Map)
import Data.Set (Set)
import Data.Text (Text)
import Data.Vector (Vector)
import Prelude hiding (FilePath)
import Control.Monad (void)
import Data.Monoid ((<>))
import Control.DeepSeq (NFData)
import GHC.Generics (Generic)

import qualified Data.Attoparsec.Text.Lazy
import qualified Filesystem.Path.CurrentOS
import qualified Data.Text
import qualified Data.Text.Lazy
import qualified Data.Map
import qualified Data.Set
import qualified Data.Vector
import qualified Data.Text as T

data Derivation = Derivation
  { outputs   :: Map Text DerivationOutput  -- ^ keyed on symbolic IDs
  , inputDrvs :: Map FilePath (Set Text)
  , inputSrcs :: Set FilePath               -- ^ inputs that are sources
  , platform  :: Text
  , builder   :: Text
  , args      :: Vector Text
  , env       :: Map Text Text
  } deriving (Show, Generic)

instance NFData Derivation

data DerivationOutput = DerivationOutput
    { path     :: FilePath
    , hashAlgo :: Text    -- ^ hash used for expected hash computation
    , hash     :: Text    -- ^ expected hash, may be null
    } deriving (Show, Generic)

instance NFData DerivationOutput

-- | Given a parser for an element, return a parser for a list of elements.
listOf :: Parser a -> Parser [a]
listOf element = do
  void "["
  es <- Data.Attoparsec.Text.Lazy.sepBy element ","
  void "]"
  pure es

vectorOf :: Parser a -> Parser (Vector a)
vectorOf element = do
  es <- listOf element
  pure $ Data.Vector.fromList es

setOf :: Ord a => Parser a -> Parser (Set a)
setOf element = do
  es <- listOf element
  pure $ Data.Set.fromList es

mapOf :: Ord k => Parser (k, v) -> Parser (Map k v)
mapOf keyValue = do
  keyValues <- listOf keyValue
  pure $ Data.Map.fromList keyValues

-- |
-- Slow, char-by-char, string parser.
--
slowString :: Parser Text
slowString = do
  void "\""
  s <- Data.Attoparsec.Text.Lazy.many' char
  void "\""
  pure $ T.pack s
  where
    char :: Parser Char
    char = do
      c1 <- Data.Attoparsec.Text.Lazy.notChar '"'
      case c1 of
        '\\' -> do
          c2 <- Data.Attoparsec.Text.Lazy.anyChar
          pure $ case c2 of
            'n' -> '\n'
            'r' -> '\r'
            't' -> '\t'
            _   -> c2
        _ -> pure c1

-- |
-- Faster string parser. Should be good with Attoparsec.
--
-- Attoparsec warns us to "the Text-oriented parsers whenever
-- possible, e.g. takeWhile1 instead of many1 anyChar. There is
-- about a factor of 100 difference in performance between the
-- two kinds of parser."
--
fastString :: Parser Text
fastString = do
    void "\""
    let predicate c = not (c == '"' || c == '\\')
    let loop = do
            text0 <- Data.Attoparsec.Text.Lazy.takeWhile predicate
            char0 <- Data.Attoparsec.Text.Lazy.anyChar
            text2 <- case char0 of
                '"'  -> return ""
                _    -> do
                    char1 <- Data.Attoparsec.Text.Lazy.anyChar
                    char2 <- case char1 of
                        'n' -> return '\n'
                        'r' -> return '\r'
                        't' -> return '\t'
                        _   -> return char1
                    text1 <- loop
                    return (Data.Text.Lazy.cons char2 text1)
            return (Data.Text.Lazy.fromStrict text0 <> text2)
    text <- loop
    return $ Data.Text.Lazy.toStrict text

string :: Parser Text
string = if False then slowString else fastString

filePath :: Parser FilePath
filePath = do
    text <- string
    case Data.Text.uncons text of
        Just ('/', _) ->
            pure $ Filesystem.Path.CurrentOS.fromText text
        _ ->
            fail ("bad path ‘" <> Data.Text.unpack text <> "’ in derivation")

parseDerivation :: Parser Derivation
parseDerivation = do
    void "Derive("

    let keyValue0 :: Parser (Text, DerivationOutput)
        keyValue0 = do
            void "("
            key <- string
            void ","
            path <- filePath
            void ","
            hashAlgo <- string
            void ","
            hash <- string
            void ")"
            return (key, DerivationOutput {..})

    outputs <- mapOf keyValue0

    void ","

    let keyValue1 = do
         void "("
         key <- filePath
         void ","
         value <- setOf string
         void ")"
         return (key, value)
    inputDrvs <- mapOf keyValue1

    void ","

    inputSrcs <- setOf filePath
    void ","
    platform <- string
    void ","
    builder <- string
    void ","
    args <- vectorOf string
    void ","

    let keyValue2 = do
          void "("
          key <- string
          void ","
          value <- string
          void ")"
          return (key, value)
    env <- mapOf keyValue2

    void ")"

    pure Derivation {..}