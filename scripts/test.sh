#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${EDGE_LUA_LIBS:?Set EDGE_LUA_LIBS to the extracted official lua_libs-api_v21 directory}"
export LUA_PATH="$PWD/src/?.lua;$EDGE_LUA_LIBS/?.lua;$EDGE_LUA_LIBS/?/init.lua;${LUA_PATH:-;;}"
"${LUA:-lua5.4}" tests/test_driver.lua

"${LUA:-lua5.4}" tests/test_startup.lua
