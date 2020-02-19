#include "remote_client/lua_lib/remote_client_lua_wrapper.h"

#include <iostream>

#include "remote_client/remote_client.h"
#include "remote_client/rpc_connection_impl.h"
#include "rpc/detail/log.h"

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(RemoteClientLuaWrapper)

int RemoteClientLuaWrapper::create_SDLRemoteClient(lua_State *L) {
  LOG_INFO("{0}", __func__);
  luaL_checktype(L, 1, LUA_TTABLE);
  // Index -1(top) - server port
  // Index -2 - server ip
  // index -3 - Library table

  auto port = lua_tointeger(L, -1);
  auto ip = lua_tostring(L, -2);
  lua_pop(L, 2); // Remove 2 values from top of the stack
  // Index -1(top) - Library table

  try {
    using namespace rpc_connection;
    connection_ptr connection(new RpcConnectionImpl<rpc_parameter>(ip, port));
    RemoteClient *client = new RemoteClient(std::move(connection));

    // Allocate memory for a pointer to client object
    RemoteClient **s =
        (RemoteClient **)lua_newuserdata(L, sizeof(RemoteClient *));
    // Index -1(top) - instance userdata
    // Index -2 - Library table

    *s = client;
  } catch (std::exception &e) {
    std::cout << "Exception occurred: " << e.what() << std::endl;
    lua_pushnil(L);
    // Index -1(top) - nil
    // Index -2 - Library table

    return 1;
  }

  RemoteClientLuaWrapper::registerSDLRemoteClient(L);
  LOG_INFO("{0}", __func__);
  // Index -1 (top) - registered SDLRemoteClient metatable
  // Index -2 - instance userdata
  // Index -3 - Library table

  lua_setmetatable(L, -2); // Set class table as metatable for instance userdata
  // Index -1(top) - instance userdata
  // Index -2 - Library table

  return 1;
}

int RemoteClientLuaWrapper::destroy_SDLRemoteClient(lua_State *L) {
  LOG_INFO("{0}", __func__);
  auto instance = get_instance(L);
  delete instance;
  return 0;
}

void RemoteClientLuaWrapper::registerSDLRemoteClient(lua_State *L) {
  LOG_INFO("{0}", __func__);
  static const luaL_Reg SDLRemoteClientFunctions[] = {
      {"connected", RemoteClientLuaWrapper::lua_connected},
      {"call", RemoteClientLuaWrapper::lua_content_call},
      {"file_call", RemoteClientLuaWrapper::lua_file_call},
      {NULL, NULL}};

  luaL_newmetatable(L, "RemoteClient");
  // Index -1(top) - SDLRemoteTestAdapter metatable

  lua_newtable(L);
  // Index -1(top) - created table
  // Index -2 : SDLRemoteTestAdapter metatable

  luaL_setfuncs(L, SDLRemoteClientFunctions, 0);
  // Index -1(top) - table with SDLRemoteClientFunctions
  // Index -2 : SDLRemoteClient metatable

  lua_setfield(L, -2,
               "__index"); // Setup created table as index lookup for  metatable
  // Index -1(top) - SDLRemoteTestAdapter metatable

  lua_pushcfunction(L, RemoteClientLuaWrapper::destroy_SDLRemoteClient);
  // Index -1(top) - destroy_SDLRemoteClient function pointer
  // Index -2 - SDLRemoteClient metatable

  lua_setfield(L, -2,
               "__gc"); // Set garbage collector function to metatable
  // Index -1(top) - SDLRemoteTestAdapter metatable
}

RemoteClient *RemoteClientLuaWrapper::get_instance(lua_State *L) {
  LOG_INFO("{0}", __func__);
  // Index 1 - userdata instance

  RemoteClient **user_data =
      reinterpret_cast<RemoteClient **>(luaL_checkudata(L, 1, "RemoteClient"));

  if (nullptr == user_data) {
    return nullptr;
  }
  return *user_data; //*((RemoteClient**)ud);
}

std::vector<parameter_type>
RemoteClientLuaWrapper::get_rpc_parameters(lua_State *L) {
  LOG_INFO("{0}", __func__);
  // Index -1(top) - array of tables of parameters { type + value }
  size_t parameters_count = lua_rawlen(L, -1);
  std::vector<parameter_type> parameters;
  for (int i = 1; i <= parameters_count; i++) {
    lua_rawgeti(L, -1, i);
    lua_getfield(L, -1, "type");
    lua_getfield(L, -2, "value");
    int type = lua_tointeger(L, -2);
    std::string value = lua_tostring(L, -1);
    parameters.push_back(std::make_pair(value, type));
    lua_pop(L, 3);
  }

  return parameters;
}

int RemoteClientLuaWrapper::lua_connected(lua_State *L) {
  LOG_INFO("{0}", __func__);
  // Index -1(top) - userdata instance

  RemoteClient *instance = get_instance(L);
  bool connected = instance->connected();
  lua_pushboolean(L, connected);
  return 1;
}

int RemoteClientLuaWrapper::lua_content_call(lua_State *L) {
  LOG_INFO("{0}", __func__);
  // Index -1(top) - table rpc parameters
  // Index -2 - string rpc name
  // Index -3 - userdata instance

  RemoteClient *instance = get_instance(L);
  const std::string rpc_name = lua_tostring(L, -2);
  const std::vector<parameter_type> parameters = get_rpc_parameters(L);
  const response_type data_and_error =
      instance->content_call(rpc_name, parameters);
  lua_pushinteger(L, data_and_error.second);
  lua_pushstring(L, data_and_error.first.c_str());
  return 2;
}

int RemoteClientLuaWrapper::lua_file_call(lua_State *L) {
  LOG_INFO("{0}", __func__);
  // Index -1(top) - table rpc parameters
  // Index -2 - string rpc name
  // Index -3 - userdata instance

  RemoteClient *instance = get_instance(L);
  const std::string rpc_name = lua_tostring(L, -2);
  const std::vector<parameter_type> parameters = get_rpc_parameters(L);
  const response_type data_and_error =
      instance->file_call(rpc_name, parameters);
  lua_pushinteger(L, data_and_error.second);
  lua_pushstring(L, data_and_error.first.c_str());
  return 2;
}

} // namespace lua_lib
