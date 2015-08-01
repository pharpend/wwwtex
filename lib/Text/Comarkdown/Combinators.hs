-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later
-- version.
-- 
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
-- details.
-- 
-- You should have received a copy of the GNU General Public License along with
-- this program.  If not, see <http://www.gnu.org/licenses/>.

-- | 
-- Module      : Text.Comarkdown.Combinators
-- Description : Fancy combinators for comarkdown
-- Copyright   : Copyright 2015 Peter Harpending
-- License     : GPL-3
-- Maintainer  : peter@harpending.org
-- Stability   : experimental
-- Portability : portable

module Text.Comarkdown.Combinators
       ((!), module Text.Comarkdown.Combinators) where

import Text.Comarkdown.Parser
import Text.Comarkdown.Types

import Control.Exceptional
import Control.Monad.State
import Data.HashMap.Lazy ((!))
import qualified Data.HashMap.Lazy as H
import Data.Traversable (for)
import Data.Vector (Vector)
import qualified Data.Vector as V
import Text.Parsec
import Text.Pandoc

-- * Missing operators from other modules

-- |Alias for 'mappend'
infixl 5 <+>
(<+>) :: Monoid m => m -> m -> m
(<+>) = mappend

-- * Comarkdown combinators!

-- |Compile pure markdown text into a pandoc
md :: String -> DocumentM Pandoc
md = fromPandoc' . readMarkdown def

-- |Run a Document, return the resulting Pandoc
runDocument :: DocumentM x -> IO Pandoc
runDocument d = do (pd, _) <- runStateT compileD nullDocument
                   return pd
  where compileD =
          do d
             compile

-- |Parse a String into the current document.
-- 
-- The source name is required for error messages
parse :: (MonadState Document m,MonadIO m)
      => SourceName -> String -> m ()
parse sn bs =
  do doc <- get
     exceptionalDocument <- liftIO $ parse' doc sn bs
     mDocument <- runExceptional exceptionalDocument
     put mDocument

-- |Parse a String, given an existing document (with definitions and stuff),
-- the name of the source, and a Bytestring to parse.
parse' :: Document -> SourceName -> String -> IO (Exceptional Document)
parse' doc sn bs =
  runParserT documentParser doc sn bs >>=
  return .
  \case
    Left parseError -> fail (show parseError)
    Right parts -> return (doc {docParts = mappend (docParts doc) parts})

-- |Parse a file into the current document
parseFile :: (MonadState Document m, MonadIO m) => FilePath -> m ()
parseFile fp =
  do doc <- get
     excNewDoc <- liftIO (parseFile' doc fp)
     mNewDoc <- runExceptional excNewDoc
     put mNewDoc


-- |Runs 'parse\'' on the contents of a file, using the 'FilePath' as the
-- 'SourceName'
parseFile' :: Document -> FilePath -> IO (Exceptional Document)
parseFile' doc fp =
  do contents <- readFile fp
     parse' doc fp contents

-- |Attempt to take the current document and make a 'Pandoc' from it. There are
-- a number of errors that could occur. For a version that catches errors, use
-- 'compile\''.
-- 
-- > compile = fmap toCf get >>= runExceptional . compile'
compile :: DocumentM Pandoc
compile =
  do cf <- fmap toCf get
     parts <- runParts cf
     return (foldl mappend mempty parts)
  where runParts
          :: CompilerForm -> DocumentM (Vector Pandoc)
        runParts compilerForm =
          for (cfParts compilerForm) $
          \case
            -- If it's a comment, we don't want any output, so produce
            -- 'mempty'
            Comment _ -> return mempty
            -- If it's text to be inserted literally (i.e. not macro-expanded
            -- or whatever), then just send it straight to Pandoc
            Ignore txt ->
              fromPandoc'
                (readMarkdown def txt)
            -- If it's a command call...
            CommandCall cmdnom mkvs ->
              -- Lookup the command to make sure it exists...
              case H.lookup cmdnom (cfCommands compilerForm) of
                -- If the command doesn't exist, then throw an error
                Nothing ->
                  fail (mappend "Command not found: " cmdnom)
                -- If it does exist, then attempt to run the command call
                Just cmd ->
                  do argumentMap <- runExceptional (mkArgMap mkvs (cmdArguments cmd))
                     cmdFunction cmd argumentMap
            -- We're essentially doing the same thing with the environment call,
            -- except the semantics are slightly different, because the minimum
            -- arity is 1.
            EnvironmentCall envnom txt mkvs ->
              case H.lookup envnom (cfEnvironments compilerForm) of
                Nothing ->
                  fail (mappend "Environment not found: " envnom)
                Just env ->
                  do argumentMap <- runExceptional (mkArgMap mkvs (envArguments env))
                     envFunction env txt argumentMap

-- |This creates a command. This will error out if the command already exists.
newCommand :: MonadState Document m
           => CommandName
           -> [CommandName]
           -> DocString
           -> [Argument]
           -> StringFunction
           -> m ()
newCommand primaryName alternateNames commandDocumentation commandArguments commandFunction =
  do oldState <- get
     let newcmd =
           Command primaryName
                   (V.fromList alternateNames)
                   commandDocumentation
                   (V.fromList commandArguments)
                   commandFunction
         oldcmds = definedCommands oldState
         -- Form a uniform list of all of the existing aliases and primary
         -- command names.
         oldTokens =
           foldl (\stuff cmd ->
                    mappend stuff
                            (V.cons (cmdPrimary cmd)
                                    (cmdAliases cmd)))
                 mempty
                 oldcmds
         -- Check to make sure neither the primary command name or the aliases
         -- are already in use. This collects the error messages.
         errorMessages =
           foldl (\accum token' ->
                    if token' `elem` oldTokens
                       then V.snoc accum
                                   (mappend token'
                                            " is already in use by another command.")
                       else accum)
                 mempty
                 (V.cons (cmdPrimary newcmd)
                         (cmdAliases newcmd))
     -- If we don't have any error messages, then continue on
     if V.null errorMessages
        then put (oldState {definedCommands = V.cons newcmd oldcmds})
        -- Otherwise, fail
        else fail (mconcat ["There were errors while trying to make the command "
                           ,cmdPrimary newcmd
                           ,". They are all listed here:"
                           ,mconcat (V.toList (fmap (mappend "\n    ") errorMessages))])

-- |This creates a environment. This will error out if the environment already exists.
newEnvironment :: MonadState Document m
               => EnvironmentName
               -> [EnvironmentName]
               -> DocString
               -> [Argument]
               -> (String -> StringFunction)
               -> m ()
newEnvironment primaryName alternateNames environmentDocumentation environmentArguments environmentFunction =
  do oldState <- get
     let newenv =
           Environment primaryName
                       (V.fromList alternateNames)
                       environmentDocumentation
                       (V.fromList environmentArguments)
                       environmentFunction
         oldenvs = definedEnvironments oldState
         -- Form a uniform list of all of the existing aliases and primary
         -- environment names.
         oldTokens =
           foldl (\stuff env ->
                    mappend stuff
                            (V.cons (envPrimary env)
                                    (envAliases env)))
                 mempty
                 oldenvs
         -- Check to make sure neither the primary environment name or the aliases
         -- are already in use. This collects the error messages.
         errorMessages =
           foldl (\accum token' ->
                    if token' `elem` oldTokens
                       then V.snoc accum
                                   (mappend token'
                                            " is already in use by another environment.")
                       else accum)
                 mempty
                 (V.cons (envPrimary newenv)
                         (envAliases newenv))
     -- If we don't have any error messages, then continue on
     if V.null errorMessages
        then put (oldState {definedEnvironments = V.cons newenv oldenvs})
        else
             -- Otherwise, fail
             fail
               (mconcat ["There were errors while trying to make the environment "
                        ,envPrimary newenv
                        ,". They are all listed here:"
                        ,mconcat (V.toList (fmap (mappend "\n    ") errorMessages))])

-- |Internal function to switch from pandoc's error type into the DocumentM
-- type.
fromPandoc' :: Either PandocError Pandoc -> DocumentM Pandoc
fromPandoc' =
  \case
    Left err -> fail (show err)
    Right x -> return x
