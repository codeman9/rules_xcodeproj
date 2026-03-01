#!/bin/bash

# Linker wrapper for rules_xcodeproj Build with Bazel mode.
# Named "clang.ld" so the Xcode Preview system's linker argument parser
# recognizes it as a clang-compatible driver (Xcode 16+).
#
# Regular builds: Bazel already linked, so we write a dummy dependency_info
# file and exit.
#
# Preview invocations (-###, thunk linking, etc.): pass through to real clang.
#
# Debug dylib builds (ENABLE_DEBUG_DYLIB=YES): Xcode 16+ creates three link
# tasks for executable targets that support previews:
#   1. *.debug.dylib   — dylib containing compiled code
#   2. *__preview.dylib — empty interposition dylib
#   3. stub executor   — small binary that loads the debug dylib
# We pass through for (1) and (2) so real clang creates valid Mach-O files.
# For (3), the stub executor link writes dummy dep_info as usual since Bazel's
# real binary is already staged via output groups.

set -euo pipefail

# Extract developer_dir from -isysroot
developer_dir=""
prev_arg=""
for arg in "$@"; do
  if [[ "$prev_arg" == "-isysroot" ]]; then
    developer_dir="${arg/\/Platforms\/*/}"
    break
  fi
  prev_arg="$arg"
done

# Fallback developer_dir
if [[ -z "$developer_dir" ]]; then
  developer_dir="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
  developer_dir="${developer_dir%/Toolchains/*}"
  developer_dir="${developer_dir%/usr/*}"
fi

real_clang="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

# Single pass: detect passthrough flags and dependency_info path.
# Passthrough flags must be checked before dependency_info because -###
# invocations also contain *_dependency_info.dat in their arguments.
passthrough=0
dep_info_file=""
for arg in "$@"; do
  case "$arg" in
  -\#\#\#|-v|--version|-version_details)
    passthrough=1
    ;;
  *.preview-thunk.dylib|*.debug.dylib|*__preview.dylib)
    passthrough=1
    ;;
  *_dependency_info.dat)
    dep_info_file="$arg"
    ;;
  esac
done

if [[ $passthrough -eq 1 ]]; then
  exec "$real_clang" "$@"
fi

if [[ -n "$dep_info_file" ]]; then
  ld_version=$(ld -v 2>&1 | grep ^@)
  printf "\0%s\0" "$ld_version" > "$dep_info_file"
  exit 0
fi

# Fallback: pass through to real clang
exec "$real_clang" "$@"
