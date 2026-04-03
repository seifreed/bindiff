# Copyright 2011-2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Compatibility helpers for modern IDA SDK layouts.
#
# IDA 9.x renamed some library directories and ships Qt6/PySide6 for IDAPython.
# BinDiff itself is a native plugin, but the build needs an SDK finder that
# understands the 9.x layout and should fail clearly when pointed at an IDA
# installation directory instead of a standalone SDK archive.

if(DEFINED ENV{IDA_SDK_ROOT} AND NOT DEFINED IdaSdk_ROOT_DIR)
  set(IdaSdk_ROOT_DIR "$ENV{IDA_SDK_ROOT}" CACHE PATH "IDA SDK directory")
endif()

if(DEFINED IdaSdk_ROOT_DIR)
  file(TO_CMAKE_PATH "${IdaSdk_ROOT_DIR}" IdaSdk_ROOT_DIR)
  if(EXISTS "${IdaSdk_ROOT_DIR}/src/include/pro.h")
    set(IdaSdk_ROOT_DIR "${IdaSdk_ROOT_DIR}/src")
  endif()
  set(IdaSdk_ROOT_DIR "${IdaSdk_ROOT_DIR}" CACHE PATH "IDA SDK directory" FORCE)

  if(EXISTS "${IdaSdk_ROOT_DIR}/ida.exe" AND
     NOT EXISTS "${IdaSdk_ROOT_DIR}/include/pro.h")
    message(WARNING
      "IdaSdk_ROOT_DIR points to an IDA installation, not a full SDK: "
      "${IdaSdk_ROOT_DIR}\n"
      "For IDA 9.3 builds, use the extracted SDK directory containing "
      "include/pro.h and lib/x64_win_vc_64/ida.lib.")
  endif()

  if(WIN32)
    if(EXISTS "${IdaSdk_ROOT_DIR}/lib/x64_win_vc_64/ida.lib")
      message(STATUS "Detected IDA SDK 9.x library layout")
    elseif(EXISTS "${IdaSdk_ROOT_DIR}/lib/x64_win_vc_64_pro/ida.lib")
      message(STATUS "Detected pre-9.x IDA SDK library layout")
    endif()
  endif()
endif()
