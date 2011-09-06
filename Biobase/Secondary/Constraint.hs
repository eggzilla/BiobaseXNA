{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE StandaloneDeriving #-}

module Biobase.Secondary.Constraint where

import Data.Char (toLower)
import Data.Primitive.Types
import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Generic.Mutable as VGM
import qualified Data.Vector.Unboxed as VU

import Data.PrimitiveArray
import Data.PrimitiveArray.Ix

import Biobase.Secondary.Diagrams



-- | We can create a constraint from different sources

class MkConstraint a where
  mkConstraint :: a -> Constraint

-- | A constraint is nothing more than a vector of constraint characters
-- together with a possible pairing for each character.

newtype Constraint = Constraint {unConstraint :: VU.Vector (Char,Int)}
  deriving (Show,Read,Eq)

bonusCC = VU.fromList "()<>|"
{-# NOINLINE bonusCC #-}

nobonusCC = VU.fromList ".x"
{-# NOINLINE nobonusCC #-}

-- | Given a 'Constraint', create an NxN matrix with bonus energies. These
-- energies can be included in all pair-creating functions and will disallow or
-- strongly favor certain pairings, while others will receive neither bonus nor
-- malus.
--
-- In case, a pair (i,j) is annotated as both, bonus- and malus-receiving, it
-- will be set to receive a malus. This can happen, if something like "<" would
-- give a bonus, but "x" gives a malus (and other cases).
--
-- TODO and again, we should parametrize over "Energy", "Score", etc (that is,
-- Prim a)

bonusTable :: Double -> Double -> Constraint -> PrimArray (Int,Int) Double
bonusTable bonus malus (Constraint constraint) = arr where
  arr = fromAssocs (0,0) (n,n) 0 $ bonusBr ++ bonusAn ++ bonusBa ++ malusBr ++ malusAn ++ malusX
  n = VU.length constraint -1
  infixl 1 `xor`
  xor a b = a && not b || not a && b
  -- "()" bonus energies
  bonusBr = [ ((i,j),bonus)
            | (i,('(',j)) <- zip [0..] $ VU.toList constraint
            ]
  malusBr = [ ((i,j),malus)
            | i <- [0..n]
            , j <- [i..n]
            , let bi = constraint VU.! i
            , let bj = constraint VU.! j
            , fst bi == '(' && snd bi /= j || fst bj == ')' && snd bj /= i
            ]
  bonusAn = [ ((i,j),bonus)
            | i<-[0..n]
            , fst (constraint VU.! i) == '<'
            , j<-[i+1..n]
            ] ++
            [ ((i,j),bonus)
            | j<-[0..n]
            , fst (constraint VU.! j) == '>'
            , i<-[0..j-1]
            ]
  malusAn = [ ((i,j),malus)
            | i<-[0..n]
            , j<-[i+1..n]
            , fst (constraint VU.! j) == '<'
            ] ++
            [ ((i,j),malus)
            | i<-[0..n]
            , j<-[i+1..n]
            , fst (constraint VU.! i) == '>'
            ]
  bonusBa = [ ((i,j),bonus)
            | i<-[0..n]
            , j<-[i+1..n]
            , fst (constraint VU.! i) == '|' || fst (constraint VU.! j) == '|'
            ]
  malusX  = [ ((i,j),malus)
            | i<-[0..n]
            , j<-[i+1..n]
            , fst (constraint VU.! i) == 'x' || fst (constraint VU.! j) == 'x'
            ]

{-
testC = putStrLn $ f as where
  f [] = ""
  f xs = show (take 9 xs) ++ "\n" ++ f (drop 9 xs)
  as = toList $ bonusTable (1) 2 (mkConstraint "(<<..x|>)")
-}

-- * Instances

instance MkConstraint String where
  mkConstraint xs = mkConstraint . VU.fromList . map toLower $ xs

instance MkConstraint (VU.Vector Char) where
  mkConstraint cs = Constraint $ VU.zip cs ks where
    (D1S ks) = mkD1S cs
