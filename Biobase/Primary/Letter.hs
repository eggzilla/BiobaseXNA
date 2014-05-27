{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

-- | A newtype with an attached phenotype which allows us to encode
-- nucleotides and amino acids. Actual seqence-specific functions can be
-- founds in the appropriate modules @AA@ and @Nuc@.

module Biobase.Primary.Letter where

import           Data.Hashable (Hashable)
import           Data.Ix (Ix(..))
import           Data.Vector.Unboxed.Deriving
import           GHC.Base (remInt,quotInt)
import           GHC.Generics (Generic)
import qualified Data.Vector.Unboxed as VU

import           Data.Array.Repa.ExtShape
import           Data.Array.Repa.Index
import           Data.Array.Repa.Shape



-- | A 'Letter' together with its phantom type @t@ encodes bio-sequences.

newtype Letter t = Letter { unLetter :: Int }
                   deriving (Eq,Ord,Generic,Ix)

type Primary t = VU.Vector (Letter t)

-- | Conversion from a large number of sequence-like inputs to primary
-- sequences.

class MkPrimary n t where
    primary :: n -> Primary t



-- *** Instances for 'Letter'.

derivingUnbox "Letter"
  [t| forall a . Letter a -> Int |] [| unLetter |] [| Letter |]

instance Hashable (Letter t)

instance (Shape sh,Show sh) => Shape (sh :. Letter z) where
  rank (sh:._) = rank sh + 1
  zeroDim = zeroDim:.Letter 0
  unitDim = unitDim:.Letter 1 -- TODO does this one make sense?
  intersectDim (sh1:.n1) (sh2:.n2) = intersectDim sh1 sh2 :. min n1 n2
  addDim (sh1:.Letter n1) (sh2:.Letter n2) = addDim sh1 sh2 :. Letter (n1+n2) -- TODO will not necessarily yield a valid Letter
  size (sh1:.Letter n) = size sh1 * n
  sizeIsValid (sh1:.Letter n) = sizeIsValid (sh1:.n)
  toIndex (sh1:.Letter sh2) (sh1':.Letter sh2') = toIndex (sh1:.sh2) (sh1':.sh2')
  fromIndex (ds:.Letter d) n = fromIndex ds (n `quotInt` d) :. Letter r where
                              r | rank ds == 0 = n
                                | otherwise    = n `remInt` d
  inShapeRange (sh1:.n1) (sh2:.n2) (idx:.i) = i>=n1 && i<n2 && inShapeRange sh1 sh2 idx
  listOfShape (sh:.Letter n) = n : listOfShape sh
  shapeOfList xx = case xx of
    []   -> error "empty list in shapeOfList/Primary"
    x:xs -> shapeOfList xs :. Letter x
  deepSeq (sh:.n) x = deepSeq sh (n `seq` x)
  {-# INLINE rank #-}
  {-# INLINE zeroDim #-}
  {-# INLINE unitDim #-}
  {-# INLINE intersectDim #-}
  {-# INLINE addDim #-}
  {-# INLINE size #-}
  {-# INLINE sizeIsValid #-}
  {-# INLINE toIndex #-}
  {-# INLINE fromIndex #-}
  {-# INLINE inShapeRange #-}
  {-# INLINE listOfShape #-}
  {-# INLINE shapeOfList #-}
  {-# INLINE deepSeq #-}

instance (Shape sh, Show sh, ExtShape sh) => ExtShape (sh :. Letter z) where
  subDim (sh1:.Letter n1) (sh2:.Letter n2) = subDim sh1 sh2 :. Letter (n1-n2)
  rangeList (sh1:.Letter n1) (sh2:.Letter n2) = [ sh:.Letter n | sh <- rangeList sh1 sh2, n <- [n1 .. (n1+n2)]]
