#include "rpc_connection_impl.h"
#include "common/constants.h"
#include <sstream>

namespace rpc_connection {

template class RpcConnectionImpl<rpc_parameter>;

template <typename... Args>
RpcConnectionImpl<Args...>::RpcConnectionImpl(const std::string &host,
                                              uint32_t port)
    : client_(host, port) {}

template <typename... Args>
RPCLIB_MSGPACK::object_handle
RpcConnectionImpl<Args...>::call(std::string const &func_name,
                                 Args... args) try {
  return client_.call(func_name, args...);
} catch (rpc::rpc_error &e) {
  return error_pack(response_type(e.what(), handleRpcError(e)));
} catch (rpc::timeout &t) {
  return error_pack(response_type(t.what(), handleRpcTimeout(t)));
}

template <typename... Args>
RPCLIB_MSGPACK::object_handle
RpcConnectionImpl<Args...>::call(std::string const &func_name) try {
  return client_.call(func_name);
} catch (rpc::rpc_error &e) {
  return error_pack(response_type(e.what(), handleRpcError(e)));
} catch (rpc::timeout &t) {
  return error_pack(response_type(t.what(), handleRpcTimeout(t)));
}

template <typename... Args>
void RpcConnectionImpl<Args...>::set_timeout(int64_t value) {
  client_.set_timeout(value);
}

template <typename... Args>
rpc::client::connection_state
RpcConnectionImpl<Args...>::get_connection_state() const {
  return client_.get_connection_state();
}

template <typename... Args>
int RpcConnectionImpl<Args...>::handleRpcError(
    rpc::rpc_error &handle_rpc_error) {
  LOG_ERROR("EXCEPTION Occured in function: {}",
            handle_rpc_error.get_function_name());
  LOG_ERROR("[Error type]: {}", handle_rpc_error.what());
  auto err = handle_rpc_error.get_error().as<std::pair<int, std::string>>();
  LOG_ERROR("[Error code]: {0} \n[Error description]: {1}", err.first,
            err.second);
  return err.first;
}

template <typename... Args>
int RpcConnectionImpl<Args...>::handleRpcTimeout(
    rpc::timeout &handle_rpc_timeout) {
  LOG_ERROR("TIMEOUT expired: {}", handle_rpc_timeout.what());
  return constants::error_codes::TIMEOUT_EXPIRED;
}

template <typename... Args>
RPCLIB_MSGPACK::object_handle
RpcConnectionImpl<Args...>::error_pack(const response_type &response) const {
  std::stringstream sbuf;
  RPCLIB_MSGPACK::pack(sbuf, response);

  RPCLIB_MSGPACK::object_handle obj_handle;
  RPCLIB_MSGPACK::unpack(obj_handle, sbuf.str().data(), sbuf.str().size(), 0);

  return obj_handle;
}

} // namespace rpc_connection
