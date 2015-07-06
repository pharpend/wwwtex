{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Trustworthy #-}

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

-- |Tests for parsing of Header{1..5} values
module HeaderSpec where

import Helper

import qualified Data.Text.Lazy as T
import Text.Comarkdown
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec =
  parallel $
  do context "Recognizing bare headers" $
       do context "Markdown syntax" $
            do context "ATX (crunch) syntax" $
                 do atxHeader1
                    atxHeader2
                    atxHeader3
                    atxHeader4
                    atxHeader5
                    atxHeader6
               context "Setext (= and -) syntax" $
                 do setextHeader1
                    setextHeader2

-- |Parsing of bare 'Header1's using the following syntax
-- 
-- > # This is a header
atxHeader1 :: Spec
atxHeader1 =
  context "Header1" $
  specify (unwords ["A single '#'"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h1 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput =
             mconcat ["#",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header1 h)]

-- |Parsing of bare 'Header2's using the following syntax
-- 
-- > ## This is a header
atxHeader2 :: Spec
atxHeader2 =
  context "Header2" $
  specify (unwords ["Two '#'s"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h2 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput = mconcat ["##",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header2 h)]

-- |Parsing of bare 'Header3's using the following syntax
-- 
-- > ### This is a header
atxHeader3 :: Spec
atxHeader3 =
  context "Header3" $
  specify (unwords ["Three '#'s"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h3 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput = mconcat ["###",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header3 h)]

-- |Parsing of bare 'Header4's using the following syntax
-- 
-- > #### This is a header
atxHeader4 :: Spec
atxHeader4 = 
  context "Header4" $
  specify (unwords ["Four '#'s"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h4 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput = mconcat ["####",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header4 h)]

-- |Parsing of bare 'Header5's using the following syntax
-- 
-- > ##### This is a header
atxHeader5 :: Spec
atxHeader5 =
  context "Header5" $
  specify (unwords ["Five '#'s"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h5 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput = mconcat ["#####",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header5 h)]



-- |Parsing of bare 'Header6's using the following syntax
-- 
-- > ###### This is a header
atxHeader6 :: Spec
atxHeader6 =
  context "Header6" $
  specify (unwords ["Six '#'s"
                   ,"++ a non-zero number of spaces"
                   ,"++ a non-empty ATX-compliant header"
                   ,"++ an arbitrary number of spaces"
                   ,"++ an arbitrary number of '#'s"
                   ,"++ an arbitrary number of spaces"
                   ,"should be an h6 containing the ATX-compliant header"]) $
  property $
  \(HSpace s,ATXNE h,HSpace t,Nat k,HSpace u) ->
    do let testInput = mconcat ["######",s,h,t,T.pack (replicate k '#'),u]
       parseResult <- parse "test" testInput
       parseResult `shouldBe` Right [Markdown (Header6 h)]


-- |Parsing of bare 'Header1's using the following syntax:
-- 
-- > This is a header
-- > ===============
setextHeader1 :: Spec
setextHeader1 =
  context "Header1" $
  specify "An arbitrary non-empty, non-double-breaking string, which does not contain any '='s, followed by a row of '='s should be an h1" $
  property $
  \(Setext1 s) ->
    do parseResult <-
         parse "test" (mappend s "\n====")
       parseResult `shouldBe` Right [Markdown (Header1 s)]

-- |Parsing of bare 'Header2's using the following syntax:
-- 
-- > This is a header
-- > ---------------
setextHeader2 :: Spec
setextHeader2 = 
  context "Header2" $
    return ()