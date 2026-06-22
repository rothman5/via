# Host Clang toolchain. Referenced by id from a platform: `toolchain = "clang"`.
# Returns the uniform toolchain record (same shape as every other toolchain).

{ pkgs }:

{
  pkg = pkgs.clang;
  cross = false;
  cc = "${pkgs.clang}/bin/clang";
  cxx = "${pkgs.clang}/bin/clang++";
}
