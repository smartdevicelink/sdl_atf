#pragma once

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

#include "common/custom_types.h"
#include <vector>

namespace lua_lib {
struct RemoteClientLuaWrapper {
  static int create_SDLRemoteClient(lua_State *L);
  static int destroy_SDLRemoteClient(lua_State *L);
  static void registerSDLRemoteClient(lua_State *L);
  static class RemoteClient *get_instance(lua_State *L);
  static std::vector<parameter_type> get_rpc_parameters(lua_State *L);

  static int lua_connected(lua_State *L);
  static int lua_file_call(lua_State *L);
  static int lua_content_call(lua_State *L);
};
} // namespace lua_lib
