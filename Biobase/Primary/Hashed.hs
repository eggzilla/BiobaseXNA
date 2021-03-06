
-- | Fast hash functions for 'Primary' sequences. This function maps
-- primary sequences to a continuous set of Ints @[0 ..]@ where the maximum
-- is dependent on the input length. This allows us to map short sequences
-- into contiguous memory locations. Useful for, say, energy lookup tables.

module Biobase.Primary.Hashed where

import           Data.Ix
import           Data.Primitive.Types
import           Data.Vector.Unboxed.Deriving
import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Generic.Mutable as VGM
import qualified Data.Vector.Unboxed as VU

import           Biobase.Primary.Letter



-- | The hash of a primary sequence.

newtype HashedPrimary t n = HashedPrimary { unHashedPrimary :: Int }
  deriving (Eq,Ord,Ix,Read,Show,Enum,Bounded)

derivingUnbox "HashedPrimary"
  [t| forall t n . HashedPrimary t n -> Int |] [| unHashedPrimary |] [| HashedPrimary |]

-- | Given a piece of primary sequence information, reduce it to an index.
-- The empty input produces an index of 0.

mkHashedPrimary :: forall t n . (VU.Unbox (Letter t n), Bounded (Letter t n), Enum (Letter t n)) => Primary t n -> HashedPrimary t n
mkHashedPrimary = HashedPrimary . fst . VU.foldl' f (0, 1) where
  f (z, c) n = (z + c * (fromEnum n +1), c * (fromEnum (maxBound :: Letter t n) + 1))
{-# INLINE mkHashedPrimary #-}

-- | Turn a hash back into a sequence. Will fail if the resulting sequence
-- has more than 100 elements.

hash2primary :: forall t n . (VU.Unbox (Letter t n), Bounded (Letter t n), Enum (Letter t n)) => HashedPrimary t n -> Primary t n
hash2primary (HashedPrimary h) = VU.unfoldrN l f h where
  m = fromEnum (maxBound :: Letter t n) +1
  l = VU.length . VU.takeWhile (>0) . VU.iterateN 100 (`div` m) $ h
  f k = if k>0 then Just (toEnum $ ((k-1) `mod` m) , (k-1) `div` m)
               else Nothing
{-# INLINE hash2primary #-}

