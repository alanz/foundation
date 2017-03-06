{-# LANGUAGE OverloadedStrings #-}
module Foundation.IO.Handle.Windows
    ( ioPtrRetryLoop
    , ioRead
    , ioWrite
    ) where

import           Foundation.Internal.Base
import           Foundation.Internal.Types
import           Foundation.Numerical
import           Foreign.C.Types
import           System.Posix.Internals
import           Foundation.System.Bindings.Hs (sysHsCoreGetErrno)
import           Foundation.System.Bindings.Windows
import qualified Prelude (fromIntegral)
import           Foundation.IO.Handle.Common

type BytesToRead = CUInt
type BytesRead = CInt

ioRead :: CInt -> Ptr Word8 -> BytesToRead -> IO BytesRead
ioRead = c_read

ioWrite :: CInt -> Ptr Word8 -> BytesToRead -> IO BytesRead
ioWrite = c_write

ioPtrRetryLoop :: (Ptr Word8 -> BytesToRead -> IO BytesRead)
               -> Ptr Word8
               -> Size Word8
               -> IO (Size Word8)
ioPtrRetryLoop ioFct ptr sz = loop ptr sz
  where
    cuintOfSize (Size r) = Prelude.fromIntegral r

    loop !p !remaining
        | remaining == 0   = return sz
        | otherwise        = do
            ssz <- ioFct p (cuintOfSize remaining)
            if ssz == -1
                then do
                    err <- sysHsCoreGetErrno
                    case err of
                        _ | err == sysPosix_EAGAIN      -> loop p remaining
                          | err == sysPosix_EINTR       -> loop p remaining
                          | err == sysPosix_EWOULDBLOCK -> loop p remaining
                          | otherwise                   -> throwIO (HandleIOError "io" err)
                else if ssz == 0
                        then return (sz - remaining)
                        else
                            let got = Size $ Prelude.fromIntegral ssz
                             in loop (p `plusPtrSize` got) (remaining - got)
