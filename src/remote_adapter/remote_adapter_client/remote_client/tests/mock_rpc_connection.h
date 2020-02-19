#pragma once
#include "gmock/gmock.h"

#include "rpc_connection.h"

namespace test {

using rpc_connection::rpc_parameter;
using rpc_connection::RpcConnection;

class MockRpcConnection : public RpcConnection<rpc_parameter> {
public:
  MOCK_METHOD2(call, RPCLIB_MSGPACK::object_handle(std::string const &func_name,
                                                   rpc_parameter parameter));
  MOCK_METHOD1(call,
               RPCLIB_MSGPACK::object_handle(std::string const &func_name));
  MOCK_METHOD1(set_timeout, void(int64_t value));
  MOCK_CONST_METHOD0(get_connection_state, rpc::client::connection_state());
};

} // namespace test
