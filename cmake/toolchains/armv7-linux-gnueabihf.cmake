# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Cross-compilation toolchain for ARMv7 hard-float (NEON) on Ubuntu/Debian.
#
# Requires these packages installed on the build host:
#   gcc-arm-linux-gnueabihf  g++-arm-linux-gnueabihf  gfortran-arm-linux-gnueabihf
#
# Target libraries (e.g. libopenblas-dev:armhf) are installed via apt
# multiarch to /usr/lib/arm-linux-gnueabihf/.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR armv7l)

set(CMAKE_C_COMPILER   arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_Fortran_COMPILER arm-linux-gnueabihf-gfortran)

# Cross-compiler sysroot
set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf)

# Never look for host-side tools inside the sysroot.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Look for target libraries/headers/packages only inside the sysroot.
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
