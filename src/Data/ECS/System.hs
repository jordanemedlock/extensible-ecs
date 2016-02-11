{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RankNTypes #-}
module Data.ECS.System where
import qualified Data.Vault.Strict as Vault
import Data.Vault.Strict (Key)
import Control.Lens
import Control.Monad.State
import Data.Maybe
import Data.ECS.Types

registerSystem :: MonadState ECS m => Key a -> a -> m ()
registerSystem = setSystem

setSystem :: MonadState ECS m => Key a -> a -> m ()
setSystem systemKey system = wldSystems %= Vault.insert systemKey system

withSystem :: MonadState ECS m => Key a -> (a -> m b) -> m (Maybe b)
withSystem systemKey action = do
    systems <- use wldSystems
    forM (Vault.lookup systemKey systems) action

viewSystem :: MonadState ECS m => Key s -> Lens' s a -> m a
viewSystem systemKey viewLens = view viewLens <$> getSystem systemKey

getSystem :: MonadState ECS m => Key b -> m b
getSystem systemKey = do
    systems <- use wldSystems
    return (fromMaybe missingSystem (Vault.lookup systemKey systems))
    where missingSystem = error "Error: getSystem couldn't find a system for the given key!"

withSystem_ :: MonadState ECS m => Key a -> (a -> m b) -> m ()
withSystem_ systemKey = void . withSystem systemKey

modifySystem :: MonadState ECS m => Key s -> (s -> m (s, b)) -> m b
modifySystem systemKey action = do
    system <- getSystem systemKey
    (newSystem, b) <- action system
    setSystem systemKey newSystem
    return b

modifySystem_ :: MonadState ECS m => Key a -> (a -> m a) -> m ()
modifySystem_ systemKey action = void $ modifySystem systemKey (fmap (,()) . action)

modifySystemState :: MonadState ECS m => Key s -> StateT s m b -> m b
modifySystemState systemKey action = modifySystem systemKey $ \system -> do
    (r, newState) <- runStateT action system
    return (newState, r)
