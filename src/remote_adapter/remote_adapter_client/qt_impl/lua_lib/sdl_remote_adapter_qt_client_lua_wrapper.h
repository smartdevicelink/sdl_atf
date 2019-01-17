#pragma once

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <vector>

namespace lua_lib {

struct SDLRemoteTestAdapterLuaWrapper {
  static int create_SDLRemoteTestAdapter(lua_State* L);
  static int destroy_SDLRemoteTestAdapter(lua_State* L);
  static void registerSDLRemoteTestAdapter(lua_State* L);
  static class SDLRemoteTestAdapterQtClient* get_instance(lua_State* L);
 
  static struct TCPParams build_TCPParams(lua_State* L);

  static int lua_connect(lua_State* L);
  static int lua_write(lua_State* L);
};

} // namespace lua_lib
