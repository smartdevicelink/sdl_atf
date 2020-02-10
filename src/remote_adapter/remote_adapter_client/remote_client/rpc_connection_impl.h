#pragma once
#include "rpc_connection.h"

namespace rpc_connection {

template <typename... Args>
class RpcConnectionImpl : public RpcConnection<Args...> {
public:
  RpcConnectionImpl(const std::string &host, uint32_t port);
  RPCLIB_MSGPACK::object_handle call(std::string const &func_name,
                                     Args... args) override;
  RPCLIB_MSGPACK::object_handle call(std::string const &func_name) override;
  void set_timeout(int64_t value) override;
  rpc::client::connection_state get_connection_state() const override;

private:
  int handle_rpc_error(rpc::rpc_error &e);
  int handle_rpc_timeout(rpc::timeout &t);
  RPCLIB_MSGPACK::object_handle error_pack(const response_type &response) const;

  rpc::client client_;

  RPCLIB_CREATE_LOG_CHANNEL(RpcConnectionImpl)
};

} // namespace rpc_connection
