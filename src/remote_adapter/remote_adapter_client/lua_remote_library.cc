#include "hmi_adapter/lua_lib/hmi_adapter_client_lua_wrapper.h"
#include "remote_client/lua_lib/remote_client_lua_wrapper.h"
#include "rpc/detail/log.h"

extern "C" {

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(Lua_Remote_Library)

int lua_atpanic_handle(lua_State *L) {
  auto err_message = lua_tostring(L, -1);
#ifdef RPCLIB_ENABLE_LOGGING
  LOG_TRACE("Lua panic:{0}", err_message);
#else
  fprintf(stderr, "Lua panic: %s (%s:%d)\n", err_message, __FILE__, __LINE__);
#endif
  lua_close(L);
  return 0;
}

}; // namespace lua_lib

int luaopen_remote(lua_State *L) {
  static const luaL_Reg library_functions[] = {
      {"RemoteClient", lua_lib::RemoteClientLuaWrapper::create_SDLRemoteClient},
      {"RemoteTestAdapter",
       lua_lib::HmiAdapterClientLuaWrapper::create_SDLRemoteTestAdapter},
      {NULL, NULL}};

  luaL_newlib(L, library_functions);
  lua_atpanic(L, lua_lib::lua_atpanic_handle);

  return 1;
}
}
