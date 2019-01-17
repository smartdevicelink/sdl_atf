#include "qt_impl/lua_lib/sdl_remote_adapter_qt_client_lua_wrapper.h"
#include "lua_lib/sdl_remote_adapter_client_lua_wrapper.h"
#include "rpc/detail/log.h"

extern "C" {

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(Lua_Remote_Library)

int lua_atpanic_handle(lua_State *L){
  LOG_TRACE("Lua panic:{0}",__func__);
  lua_close(L);
  return 0;
}

};

int luaopen_remote(lua_State *L) {
  static const luaL_Reg library_functions[] = {
      {"RemoteClient",
       lua_lib::SDLRemoteClientLuaWrapper::create_SDLRemoteClient},
      {"RemoteTestAdapter",
       lua_lib::SDLRemoteTestAdapterLuaWrapper::create_SDLRemoteTestAdapter},
      {NULL, NULL}};

  luaL_newlib(L, library_functions);
  lua_atpanic(L,lua_lib::lua_atpanic_handle);

  return 1;
}

}
