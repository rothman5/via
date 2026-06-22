# ViaToolchain — the entry CMAKE_TOOLCHAIN_FILE. COMPILER SELECTION ONLY.
#
# It sets which compiler binary to use (and the bare essentials to make a cross
# build work) and NOTHING else: no -mcpu, no chip define, no linker script.
# Arch/device options (cflags/ldflags/defines) come from the manifest, declared
# by the app on its platform. Keeping this file compiler-only is what lets
# GCC<->Clang swap on one device untouched, and what keeps the core arch-agnostic.
#
# Driven by cache vars the Nix builder passes:
#   VIA_SYSTEM_NAME / VIA_SYSTEM_PROCESSOR  (cross target; absent => host)
#   VIA_CC / VIA_CXX / VIA_ASM              (compiler binaries)
#   VIA_OBJCOPY / VIA_SIZE                  (binutils for image/size steps)

if(DEFINED VIA_SYSTEM_NAME)
  set(CMAKE_SYSTEM_NAME "${VIA_SYSTEM_NAME}")
endif()
if(DEFINED VIA_SYSTEM_PROCESSOR)
  set(CMAKE_SYSTEM_PROCESSOR "${VIA_SYSTEM_PROCESSOR}")
endif()

if(DEFINED VIA_CC)
  set(CMAKE_C_COMPILER "${VIA_CC}")
endif()
if(DEFINED VIA_CXX)
  set(CMAKE_CXX_COMPILER "${VIA_CXX}")
endif()
if(DEFINED VIA_ASM)
  set(CMAKE_ASM_COMPILER "${VIA_ASM}")
endif()
if(DEFINED VIA_OBJCOPY)
  set(CMAKE_OBJCOPY "${VIA_OBJCOPY}" CACHE FILEPATH "objcopy")
endif()
if(DEFINED VIA_SIZE)
  set(CMAKE_SIZE "${VIA_SIZE}" CACHE FILEPATH "size")
endif()

# Bare-metal / freestanding targets: don't try to link a full executable during
# the compiler check (there's no linker script yet), and don't search the host
# sysroot for libraries/headers.
if(CMAKE_SYSTEM_NAME STREQUAL "Generic")
  set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
endif()
