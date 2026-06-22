# Host GCC toolchain. Referenced by id from a platform: `toolchain = "gcc"`.
# Returns the uniform toolchain record (same shape as every other toolchain).

{ pkgs }:

{
  pkg = pkgs.gcc;
  cross = false;
  cc = "${pkgs.gcc}/bin/gcc";
  cxx = "${pkgs.gcc}/bin/g++";
}
