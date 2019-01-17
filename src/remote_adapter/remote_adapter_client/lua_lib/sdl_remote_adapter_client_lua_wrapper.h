#pragma once

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

namespace lua_lib {
struct SDLRemoteClientLuaWrapper {
  static int create_SDLRemoteClient(lua_State* L);
  static int destroy_SDLRemoteClient(lua_State* L);
  static void registerSDLRemoteClient(lua_State* L);
  static class SDLRemoteTestAdapterClient* get_instance(lua_State* L);

  static int lua_connected(lua_State* L);

  static int lua_app_start(lua_State* L);
  static int lua_app_stop(lua_State* L);
  static int lua_app_check_status(lua_State* L);

  static int lua_file_exists(lua_State* L);
  static int lua_file_update(lua_State* L);
  static int lua_file_content(lua_State* L);
  static int lua_file_delete(lua_State* L);
  static int lua_file_backup(lua_State* L);
  static int lua_file_restore(lua_State* L);

  static int lua_folder_exists(lua_State* L);
  static int lua_folder_create(lua_State* L);
  static int lua_folder_delete(lua_State* L);

  static int lua_command_execute(lua_State* L);
};
}
