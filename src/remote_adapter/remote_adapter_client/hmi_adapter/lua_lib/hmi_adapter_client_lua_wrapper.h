#pragma once

extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

#include "common/custom_types.h"
#include <vector>

namespace lua_lib {

struct HmiAdapterClientLuaWrapper {
  static int create_SDLRemoteTestAdapter(lua_State *L);
  static int destroy_SDLRemoteTestAdapter(lua_State *L);
  static void registerSDLRemoteTestAdapter(lua_State *L);
  static class HmiAdapterClient *get_instance(lua_State *L);

  static struct std::vector<parameter_type> build_TCPParams(lua_State *L);

  static int lua_connect(lua_State *L);
  static int lua_write(lua_State *L);
};

} // namespace lua_lib
