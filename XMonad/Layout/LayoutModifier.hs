{-# OPTIONS_GHC -fglasgow-exts #-} -- For deriving Data/Typeable
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses, PatternGuards #-}

-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Layout.LayoutModifier
-- Copyright    : (c) David Roundy <droundy@darcs.net>
-- License      : BSD
--
-- Maintainer   : David Roundy <droundy@darcs.net>
-- Stability    : unstable
-- Portability  : portable
--
-- A module for writing easy Llayouts and layout modifiers
-----------------------------------------------------------------------------

module XMonad.Layout.LayoutModifier (
    -- * Usage
    -- $usage
    LayoutModifier(..), ModifiedLayout(..)
    ) where

import XMonad
import XMonad.StackSet ( Stack )

-- $usage
-- Use LayoutModifier to help write easy Layouts.
--
-- LayouModifier defines a class 'LayoutModifier'. Each method as a
-- default implementation.
--
-- For usage examples you can see "XMonad.Layout.WorkspaceDir",
-- "XMonad.Layout.Magnifier", "XMonad.Layout.NoBorder",

class (Show (m a), Read (m a)) => LayoutModifier m a where
    handleMess :: m a -> SomeMessage -> X (Maybe (m a))
    handleMess m mess | Just Hide <- fromMessage mess             = doUnhook
                      | Just ReleaseResources <- fromMessage mess = doUnhook
                      | otherwise = return $ pureMess m mess
     where doUnhook = do unhook m; return Nothing
    handleMessOrMaybeModifyIt :: m a -> SomeMessage -> X (Maybe (Either (m a) SomeMessage))
    handleMessOrMaybeModifyIt m mess = do mm' <- handleMess m mess
                                          return (Left `fmap` mm')
    pureMess :: m a -> SomeMessage -> Maybe (m a)
    pureMess _ _ = Nothing
    redoLayout :: m a -> Rectangle -> Stack a -> [(a, Rectangle)]
               -> X ([(a, Rectangle)], Maybe (m a))
    redoLayout m r s wrs = do hook m; return $ pureModifier m r s wrs
    pureModifier :: m a -> Rectangle -> Stack a -> [(a, Rectangle)]
                 -> ([(a, Rectangle)], Maybe (m a))
    pureModifier _ _ _ wrs = (wrs, Nothing)
    emptyLayoutMod :: m a -> Rectangle -> [(a, Rectangle)]
                   -> X ([(a, Rectangle)], Maybe (m a))
    emptyLayoutMod _ _ _ = return ([], Nothing)
    hook :: m a -> X ()
    hook _ = return ()
    unhook :: m a -> X ()
    unhook _ = return ()
    modifierDescription :: m a -> String
    modifierDescription = const ""

instance (LayoutModifier m a, LayoutClass l a) => LayoutClass (ModifiedLayout m l) a where
    doLayout (ModifiedLayout m l) r s =
        do (ws, ml') <- doLayout l r s
           (ws', mm') <- redoLayout m r s ws
           let ml'' = case mm' of
                      Just m' -> Just $ (ModifiedLayout m') $ maybe l id ml'
                      Nothing -> ModifiedLayout m `fmap` ml'
           return (ws', ml'')
    emptyLayout (ModifiedLayout m l) r =
        do (ws, ml') <- emptyLayout l r
           (ws',mm') <- emptyLayoutMod m r ws
           let ml'' = case mm' of
                      Just m' -> Just $ (ModifiedLayout m') $ maybe l id ml'
                      Nothing -> ModifiedLayout m `fmap` ml'
           return (ws', ml'')
    handleMessage (ModifiedLayout m l) mess =
        do mm' <- handleMessOrMaybeModifyIt m mess
           ml' <- case mm' of
                  Just (Right mess') -> handleMessage l mess'
                  _ -> handleMessage l mess
           return $ case mm' of
                    Just (Left m') -> Just $ (ModifiedLayout m') $ maybe l id ml'
                    _ -> (ModifiedLayout m) `fmap` ml'
    description (ModifiedLayout m l) = modifierDescription m <> description l
     where "" <> x = x
           x <> y = x ++ " " ++ y

data ModifiedLayout m l a = ModifiedLayout (m a) (l a) deriving ( Read, Show )
