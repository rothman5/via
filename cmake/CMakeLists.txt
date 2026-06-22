# Via generic project (the "driver" entry point).
#
# This is the CMake source root for every Via build. It is NOT edited by app
# authors — it is invoked by the Nix builder (or the `via` CLI) with a rendered
# `via_manifest.cmake` describing the artifact, and an app source directory.
#
#   cmake -S <this dir> -B build \
#         -DVIA_MANIFEST=<path>/via_manifest.cmake \
#         -DVIA_APP_DIR=<path to app>
#
# When the app ships its own apps/<name>/CMakeLists.txt, the builder points
# CMake there instead; this file is the no-CMakeLists default path.

cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED VIA_MANIFEST)
  message(FATAL_ERROR "Via: -DVIA_MANIFEST=<via_manifest.cmake> is required")
endif()
if(NOT DEFINED VIA_APP_DIR)
  message(FATAL_ERROR "Via: -DVIA_APP_DIR=<app source dir> is required")
endif()

# Rendered, resolved values from the manifest (set() calls only — no TOML parsing
# happens in CMake).
include("${VIA_MANIFEST}")

project("${VIA_APP}" C CXX ASM)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}")
include(ViaDriver)

via_build_artifact()
