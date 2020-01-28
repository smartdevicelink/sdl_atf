#pragma once

#include <string>
#include <utility>
#include <vector>

#include "rpc/rpc_error.h"
#include "rpc_connection.h"

#include "common/custom_types.h"

namespace lua_lib {

using connection_ptr = rpc_connection::connection_ptr;

class RemoteClient {
public:
  RemoteClient(connection_ptr connection);

  /**
   * @brief connected checks if client is connected to server
   * @return true if connected otherwise false
   */
  bool connected() const;

  /**
   * @brief Call RPC on server (it returns file)
   * @param rpc_name Name of RPC to call
   * @param parameters Collection which contains parameters
   * @return Pair of path to file and result code
   */
  response_type file_call(const std::string &rpc_name,
                          std::vector<parameter_type> parameters);

  /**
   * @brief Call RPC on server (it returns string)
   * @param rpc_name Name of RPC to call
   * @param parameters Collection which contains parameters
   * @return Pair of string content and result code
   */
  response_type content_call(const std::string &rpc_name,
                             const std::vector<parameter_type> &parameters);

private:
  connection_ptr connection_;
  friend struct HmiAdapterClientLuaWrapper;
};

} // namespace lua_lib
