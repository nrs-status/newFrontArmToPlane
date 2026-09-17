{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | tell: a CLI tool to submit entries to the 'nodes' table of the 'doc'
-- PostgreSQL database.
--
-- Usage:
--   tell <body>               add an entry, filling out only "body"
--   tell <tags> <body>        add an entry, filling out "body" and "tags"
--   echo <body> | tell        read the body from stdin
--   echo <body> | tell <tags>
--
-- Options:
--   -t --title      value for the "title" column
--   -f --fuzzyaux   value for the "fuzzyaux" column
--
-- On success prints a TSV line: <id>\t<creationdate>
module Main (main) where

import           Control.Exception          (SomeException, try)
import           Control.Monad              (unless, void)
import           Data.List                  (any)
import           Data.Text                  (unpack)
import           Data.Text                  (Text, pack)
import           Database.PostgreSQL.Simple (Connection, Only (..), connectPostgreSQL,
                                             execute_, query)
import           Options.Applicative
import           System.Exit                (ExitCode (..), exitWith)
import           System.IO                  (hIsTerminalDevice, hPutStrLn, stderr, stdin)

-- | Parsed command line options.
data Opts = Opts
  { optTitle    :: Maybe String
  , optFuzzyAux :: Maybe String
  , optArgs     :: [String]
  }

optsParser :: Parser Opts
optsParser = Opts
  <$> optional (strOption
        (  long "title"
        <> short 't'
        <> metavar "TITLE"
        <> help "value for the \"title\" column" ))
  <*> optional (strOption
        (  long "fuzzyaux"
        <> short 'f'
        <> metavar "FUZZY"
        <> help "value for the \"fuzzyaux\" column" ))
  <*> many (argument str (metavar "[TAGS] [BODY]"))

optsInfo :: ParserInfo Opts
optsInfo = info (optsParser <**> helper)
  (  fullDesc
  <> progDesc "add an entry to the nodes table of the doc database"
  <> header "tell - submit entries to doc.nodes" )

-- | Determine (tags, body) from the positional arguments and stdin.
--
-- Rules:
--   * two positional args:  first is TAGS, second is BODY
--   * one positional arg:
--       - stdin is a terminal        -> it is the BODY
--       - stdin is piped:
--           * contains whitespace    -> it is the BODY (tags may never
--                                       contain whitespace)
--           * no whitespace          -> it is the TAGS, body read from stdin
--   * no positional args: body is read from stdin (tags empty)
resolveTagsAndBody :: Opts -> Bool -> String -> IO (Maybe Text, Text)
resolveTagsAndBody o piped stdinData =
  case optArgs o of
    [] -> do
      unless piped $ failWith "no body given (pass it as an argument or pipe it)"
      unless (not (null stdinData)) $ failWith "empty body"
      pure (Nothing, pack stdinData)
    [a]
      | not piped           -> pure (Nothing, pack a)
      | hasWhitespace a     -> pure (Nothing, pack a)
      | otherwise           -> pure (Just (pack a), pack stdinData)
    [tags, body] -> do
      validateTags tags
      pure (Just (pack tags), pack body)
    _ -> failWith "too many arguments (expected at most: <tags> <body>)"

-- | Tags must not contain whitespace.
validateTags :: String -> IO ()
validateTags tags =
  unless (not (null tags) && not (hasWhitespace tags)) $
    failWith "tags argument must be non-empty and contain no whitespace"

hasWhitespace :: String -> Bool
hasWhitespace = any (`elem` (" \t\n\r\f\v" :: String))

failWith :: String -> IO a
failWith msg = do
  hPutStrLn stderr ("tell: " ++ msg)
  exitWith (ExitFailure 1)

-- | Insert the entry and print "<id>\t<creationdate>".
insertEntry :: Connection -> Maybe Text -> Maybe Text -> Text -> Maybe Text -> IO ()
insertEntry conn title tags body fuzzyaux = do
  rows <- query conn
    "INSERT INTO nodes (id, title, tags, body, fuzzyaux, creationdate) \
    \VALUES (COALESCE((SELECT MAX(id) FROM nodes), 0) + 1, ?, ?, ?, ?, \
    \        to_char(localtimestamp, 'YYYY-MM-DD HH24:MI:SS')) \
    \RETURNING id, creationdate"
    (title, tags, Just body, fuzzyaux)
  case rows of
    [(nid, creationDate :: Text)] ->
      putStrLn (show (nid :: Int) ++ "\t" ++ unpack creationDate)
    _ -> failWith "unexpected database response"

main :: IO ()
main = do
  o <- execParser optsInfo
  piped <- not <$> hIsTerminalDevice stdin
  stdinData <- if piped then getContents else pure ""
  (tags, body) <- resolveTagsAndBody o piped stdinData
  let title    = pack <$> optTitle o
      fuzzyaux = pack <$> optFuzzyAux o
  result <- try $ do
    conn <- connectPostgreSQL "dbname=doc"
    insertEntry conn title tags body fuzzyaux
  case result of
    Right () -> pure ()
    Left (e :: SomeException) -> do
      hPutStrLn stderr ("tell: database error: " ++ show e)
      exitWith (ExitFailure 1)
