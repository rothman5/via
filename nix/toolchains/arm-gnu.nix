# GNU Arm Embedded toolchain (arm-none-eabi-*), for bare-metal cross builds.
# Referenced by id from a platform: `toolchain = "arm-gnu"`. Returns the uniform
# toolchain record; `cross = true` adds the cross-compilation fields the engine
# threads into the CMake toolchain file (system name/processor + the binutils).

{ pkgs }:

let
  bin = "${pkgs.gcc-arm-embedded}/bin";
  prefix = "arm-none-eabi-";
in
{
  pkg = pkgs.gcc-arm-embedded;
  # Derived from the pinned package, so an `arm-gnu@<v>` manifest validates
  # against what nixpkgs actually provides rather than a hand-copied string.
  version = pkgs.gcc-arm-embedded.version;
  cross = true;
  systemName = "Generic";
  systemProcessor = "arm";
  cc = "${bin}/${prefix}gcc";
  cxx = "${bin}/${prefix}g++";
  asm = "${bin}/${prefix}gcc";
  objcopy = "${bin}/${prefix}objcopy";
  size = "${bin}/${prefix}size";

  # Bare-metal libc/spec selection. These are newlib/arm-gcc specific, so they
  # live on the toolchain (not the driver) — a clang toolchain would supply its
  # own equivalent, keeping the firmware link policy compiler-neutral and the
  # GCC<->Clang swap manifest-free.
  baremetalLdflags = [ "--specs=nano.specs" "--specs=nosys.specs" ];
}
