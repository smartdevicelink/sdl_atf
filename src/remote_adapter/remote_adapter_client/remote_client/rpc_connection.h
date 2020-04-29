#pragma once
#include "common/custom_types.h"
#include "rpc/client.h"
#include "rpc/rpc_error.h"

namespace rpc_connection {

template <typename... Args> class RpcConnection;

typedef std::vector<parameter_type> rpc_parameter;
typedef std::unique_ptr<RpcConnection<rpc_parameter>> connection_ptr;

template <typename... Args> class RpcConnection {
public:
  virtual ~RpcConnection() {}
  /*
   * @brief Calls a function with the given name and arguments (if any).
   * throws rpc::rpc_error if the server responds with an error.
   *
   * @param func_name The name of the function to call on the server.
   * @param args A variable number of arguments to pass to the called
   * function.
   *
   * @param Args The types of the arguments. Each type in this parameter
   * pack have to be serializable by msgpack.
   *
   * @returns A RPCLIB_MSGPACK::object containing the result of the function (if
   * any). To obtain a typed value, use the msgpack API.
   */
  virtual RPCLIB_MSGPACK::object_handle call(std::string const &func_name,
                                             Args... args) = 0;
  virtual RPCLIB_MSGPACK::object_handle call(std::string const &func_name) = 0;
  /*
   * @brief Sets the timeout of this client in milliseconds.
   *
   * @param value timeout is applied to synchronous calls. If the timeout
   * expires without receiving a response from the server, rpc::timeout
   * exception will be thrown.
   */
  virtual void set_timeout(int64_t value) = 0;
  /*
   * @brief Returns the current connection state.
   */
  virtual rpc::client::connection_state get_connection_state() const = 0;
};

} // namespace rpc_connection
