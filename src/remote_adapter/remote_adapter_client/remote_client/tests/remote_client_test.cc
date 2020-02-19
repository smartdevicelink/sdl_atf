#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "common/constants.h"
#include "mock_rpc_connection.h"
#include "remote_client.h"

namespace test {

static constexpr const char *kRpcName = "Test_RPC";
static const rpc_parameter kEmptyParameter;

using rpc_connection::connection_ptr;

using ::testing::_;
using ::testing::ByMove;
using ::testing::Return;
using ::testing::ReturnRef;

class RemoteClient_Test : public testing::Test {
public:
  RPCLIB_MSGPACK::object_handle
  response_pack(const response_type &response) const {
    std::stringstream sbuf;
    RPCLIB_MSGPACK::pack(sbuf, response);

    RPCLIB_MSGPACK::object_handle obj_handle;
    RPCLIB_MSGPACK::unpack(obj_handle, sbuf.str().data(), sbuf.str().size(), 0);

    return obj_handle;
  }

  MockRpcConnection *CreateRpcConnection();

  std::unique_ptr<lua_lib::RemoteClient> remote_client_;
};

MockRpcConnection *RemoteClient_Test::CreateRpcConnection() {
  MockRpcConnection *mock = new MockRpcConnection();
  EXPECT_CALL(*mock, set_timeout(10000));
  EXPECT_CALL(*mock, call(constants::client_connected))
      .WillOnce(Return(ByMove(response_pack(
          response_type(std::string(), constants::error_codes::SUCCESS)))));
  return mock;
}

TEST_F(RemoteClient_Test, Connected_Expect_False) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::disconnected));

  const bool bConnect = remote_client_->connected();

  EXPECT_EQ(false, bConnect);
}

TEST_F(RemoteClient_Test, Connected_Expect_True) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));

  const bool bConnect = remote_client_->connected();

  EXPECT_EQ(true, bConnect);
}

TEST_F(RemoteClient_Test, Content_Call_Expect_NO_CONNECTION) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::disconnected));

  auto response = remote_client_->content_call(kRpcName, kEmptyParameter);

  EXPECT_EQ(constants::error_codes::NO_CONNECTION, response.second);
}

TEST_F(RemoteClient_Test, Content_Call_Expect_SUCCESS) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, kEmptyParameter))
      .WillOnce(Return(ByMove(response_pack(
          response_type(std::string(), constants::error_codes::SUCCESS)))));

  auto response = remote_client_->content_call(kRpcName, kEmptyParameter);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(RemoteClient_Test, File_Call_Expect_NO_CONNECTION) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::disconnected));

  auto response = remote_client_->file_call(kRpcName, kEmptyParameter);

  EXPECT_EQ(constants::error_codes::NO_CONNECTION, response.second);
}

TEST_F(RemoteClient_Test, File_Call_Expect_Response_FAILED) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  rpc_parameter parameters(kEmptyParameter);

  parameters.push_back(
      std::make_pair(std::to_string(0), constants::param_types::INT));
  parameters.push_back(std::make_pair(std::to_string(constants::kMaxSizeData),
                                      constants::param_types::INT));

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(
          response_type(std::string(), constants::error_codes::FAILED)))));

  auto response = remote_client_->file_call(kRpcName, kEmptyParameter);

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(RemoteClient_Test, File_Call_With_Bad_File_Name_Expect_FAILED) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  rpc_parameter parameters = {
      std::make_pair("", constants::param_types::STRING),
      std::make_pair(".", constants::param_types::STRING),
      std::make_pair(std::to_string(0), constants::param_types::INT),
      std::make_pair(std::to_string(constants::kMaxSizeData),
                     constants::param_types::INT)};

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(
          response_type(std::string(), constants::error_codes::SUCCESS)))));

  auto response = remote_client_->file_call(
      kRpcName, rpc_parameter(parameters.begin(), parameters.begin() + 2));

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(RemoteClient_Test, File_Call_Without_Offset_Expect_SUCCESS) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  rpc_parameter parameters = {
      std::make_pair("", constants::param_types::STRING),
      std::make_pair(kRpcName, constants::param_types::STRING),
      std::make_pair(std::to_string(0), constants::param_types::INT),
      std::make_pair(std::to_string(constants::kMaxSizeData),
                     constants::param_types::INT)};

  std::string tmp_path(constants::kTmpPath);
  tmp_path.append(parameters[1].first);

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(
          response_type(kRpcName, constants::error_codes::SUCCESS)))));

  auto response = remote_client_->file_call(
      kRpcName, rpc_parameter(parameters.begin(), parameters.begin() + 2));

  EXPECT_EQ(tmp_path, response.first);
  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(RemoteClient_Test, File_Call_With_1_Offset_Expect_SUCCESS) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  rpc_parameter parameters = {
      std::make_pair("", constants::param_types::STRING),
      std::make_pair(kRpcName, constants::param_types::STRING),
      std::make_pair(std::to_string(0), constants::param_types::INT),
      std::make_pair(std::to_string(constants::kMaxSizeData),
                     constants::param_types::INT)};

  std::string tmp_path(constants::kTmpPath);
  tmp_path.append(parameters[1].first);

  const int offset = 10;

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(response_type(kRpcName, offset)))));

  parameters[parameters.size() - 2] =
      std::make_pair(std::to_string(offset), constants::param_types::INT);

  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(
          response_type(kRpcName, constants::error_codes::SUCCESS)))));

  auto response = remote_client_->file_call(
      kRpcName, rpc_parameter(parameters.begin(), parameters.begin() + 2));

  EXPECT_EQ(tmp_path, response.first);
  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(RemoteClient_Test, File_Call_With_2_Offset_Expect_SUCCESS) {
  MockRpcConnection *mock_connection = CreateRpcConnection();

  remote_client_.reset(
      new lua_lib::RemoteClient(connection_ptr(mock_connection)));

  rpc_parameter parameters = {
      std::make_pair("", constants::param_types::STRING),
      std::make_pair(kRpcName, constants::param_types::STRING),
      std::make_pair(std::to_string(0), constants::param_types::INT),
      std::make_pair(std::to_string(constants::kMaxSizeData),
                     constants::param_types::INT)};

  std::string tmp_path(constants::kTmpPath);
  tmp_path.append(parameters[1].first);

  const int offset_1 = 10;
  const int offset_2 = 20;

  EXPECT_CALL(*mock_connection, get_connection_state())
      .WillOnce(Return(rpc::client::connection_state::connected));
  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(
          Return(ByMove(response_pack(response_type(kRpcName, offset_1)))));

  parameters[parameters.size() - 2] =
      std::make_pair(std::to_string(offset_1), constants::param_types::INT);

  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(
          Return(ByMove(response_pack(response_type(kRpcName, offset_2)))));

  parameters[parameters.size() - 2] =
      std::make_pair(std::to_string(offset_2), constants::param_types::INT);

  EXPECT_CALL(*mock_connection, call(kRpcName, parameters))
      .WillOnce(Return(ByMove(response_pack(
          response_type(kRpcName, constants::error_codes::SUCCESS)))));

  auto response = remote_client_->file_call(
      kRpcName, rpc_parameter(parameters.begin(), parameters.begin() + 2));

  EXPECT_EQ(tmp_path, response.first);
  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

} // namespace test
