#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "../../message_broker.h"
#include "constants.h"
#include "custom_types.h"
#include "rpc/client.h"
#include "rpc/detail/response.h"
#include "rpc/rpc_error.h"
#include "rpc/server.h"

namespace beast = boost::beast;
namespace websocket = beast::websocket;
namespace net = boost::asio;
using tcp = boost::asio::ip::tcp;

namespace error_codes = constants::error_codes;
namespace error_msg = constants::error_msg;
using namespace constants;

#define LIBRARY_API extern "C"
LIBRARY_API remote_adapter::adapter_plugin_ptr create_plugin();

static constexpr uint16_t kRpcTestPort = rpc::constants::DEFAULT_PORT;
static constexpr uint16_t kMsgTestPort = 7070;
static constexpr const char *kTestAddress = "127.0.0.1";
static constexpr const char *kSendData = "Send Data Test";

typedef std::vector<std::promise<void>> array_signal;

class MessageBroker_Test : public testing::Test {
public:
  MessageBroker_Test() : signals_(3) {}

  response_type OpenConnection(rpc::client &client);
  response_type CloseConnection(rpc::client &client);
  response_type Send(rpc::client &client);
  response_type Receive(rpc::client &client);

  array_signal signals_;

  static std::mutex mtx;
  static std::condition_variable cv;

  static void Accept(array_signal &signals);
  static void Session(tcp::socket &socket, array_signal &signals);

  static void Wait();
  static void Notify();
};

std::mutex MessageBroker_Test::mtx;
std::condition_variable MessageBroker_Test::cv;

response_type MessageBroker_Test::OpenConnection(rpc::client &client) {

  std::vector<parameter_type> parameters = {
      parameter_type(kTestAddress, param_types::STRING),
      parameter_type(std::to_string(kMsgTestPort), param_types::INT)};

  auto open_handle = client.async_call(constants::open_handle, parameters);

  open_handle.wait();

  return open_handle.get().as<response_type>();
}

response_type MessageBroker_Test::CloseConnection(rpc::client &client) {

  std::vector<parameter_type> parameters = {
      parameter_type(kTestAddress, param_types::STRING),
      parameter_type(std::to_string(kMsgTestPort), param_types::INT)};

  auto close_handle = client.async_call(constants::close_handle, parameters);

  close_handle.wait();

  return close_handle.get().as<response_type>();
}

response_type MessageBroker_Test::Send(rpc::client &client) {

  std::vector<parameter_type> parameters = {
      parameter_type(kTestAddress, param_types::STRING),
      parameter_type(std::to_string(kMsgTestPort), param_types::INT),
      parameter_type(kSendData, param_types::STRING)};

  auto send_handle = client.async_call(constants::send, parameters);

  send_handle.wait();

  return send_handle.get().as<response_type>();
}

response_type MessageBroker_Test::Receive(rpc::client &client) {

  std::vector<parameter_type> parameters = {
      parameter_type(kTestAddress, param_types::STRING),
      parameter_type(std::to_string(kMsgTestPort), param_types::INT)};

  auto recive_handle = client.async_call(constants::receive, parameters);

  recive_handle.wait();

  return recive_handle.get().as<response_type>();
}

void MessageBroker_Test::Accept(array_signal &signals) {

  auto const address = net::ip::make_address(kTestAddress);
  auto const port = kMsgTestPort;

  net::io_context ioc{1};
  tcp::acceptor acceptor{ioc, {address, port}};
  tcp::socket socket{ioc};

  signals[0].set_value();

  acceptor.accept(socket);

  Session(socket, signals);
}

void MessageBroker_Test::Session(tcp::socket &socket, array_signal &signals) {

  websocket::stream<tcp::socket> ws{std::move(socket)};
  // Accept the websocket handshake
  ws.accept();

  signals[1].set_value();

  beast::flat_buffer buffer;
  ws.read(buffer);
  // Echo the message back
  ws.text(ws.got_text());
  ws.write(buffer.data());

  signals[2].set_value();

  Wait();
}

void MessageBroker_Test::Wait() {
  std::unique_lock<std::mutex> lck(mtx);
  cv.wait(lck);
}

void MessageBroker_Test::Notify() {
  std::unique_lock<std::mutex> lck(mtx);
  cv.notify_all();
}

TEST_F(MessageBroker_Test, CreatePlugin_Expect_TRUE) {
  auto message_broker = create_plugin();
  EXPECT_TRUE(message_broker);
}

TEST_F(MessageBroker_Test, DeletePlugin_Expect_TRUE) {
  auto message_broker = create_plugin();
  message_broker.reset();
  EXPECT_TRUE(!message_broker);
}

TEST_F(MessageBroker_Test, Check_TypeId_Expect_EQ) {
  using namespace msg_wrappers;
  using namespace remote_adapter;
  UtilsPlugin *message_broker_1 = new MessageBroker<>();
  auto message_broker_2 = create_plugin();
  EXPECT_EQ(typeid(message_broker_1), typeid(message_broker_2.get()));
  delete message_broker_1;
}

TEST_F(MessageBroker_Test, OpenConnection_Expect_SUCCESS) {

  auto message_broker = create_plugin();
  EXPECT_TRUE(message_broker);

  rpc::server server(kTestAddress, kRpcTestPort);

  message_broker->Bind(server);

  server.async_run();

  rpc::client client(kTestAddress, kRpcTestPort);

  auto response = OpenConnection(client);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(MessageBroker_Test, CloseConnection_Expect_NO_CONNECTION) {

  auto message_broker = create_plugin();
  EXPECT_TRUE(message_broker);

  rpc::server server(kTestAddress, kRpcTestPort);

  message_broker->Bind(server);

  server.async_run();

  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(kTestAddress, param_types::STRING),
      parameter_type(std::to_string(kMsgTestPort), param_types::INT)};

  auto close_handle = client.async_call(constants::close_handle, parameters);
  close_handle.wait();

  try {
    auto response = close_handle.get().as<response_type>();
    ADD_FAILURE() << "Expect rpc::rpc_error with error code NO_CONNECTION";
  } catch (rpc::rpc_error &e) {
    auto err = e.get_error().as<response_type>();
    EXPECT_EQ(constants::error_codes::NO_CONNECTION, err.second);
  }
}

TEST_F(MessageBroker_Test, CloseConnection_Expect_SUCCESS) {
  std::future<void> accept = signals_[0].get_future();
  std::future<void> handshake = signals_[1].get_future();

  auto accept_thread =
      std::async(std::launch::async, Accept, std::ref(signals_));

  auto message_broker = create_plugin();
  EXPECT_TRUE(message_broker);

  rpc::server server(kTestAddress, kRpcTestPort);
  message_broker->Bind(server);

  server.async_run();

  rpc::client client(kTestAddress, kRpcTestPort);

  accept.wait();

  OpenConnection(client);

  handshake.wait();

  auto response = CloseConnection(client);

  Notify();

  accept_thread.wait();

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(MessageBroker_Test, TransferData_Expect_SUCCESS) {
  std::future<void> accept = signals_[0].get_future();
  std::future<void> handshake = signals_[1].get_future();
  std::future<void> write = signals_[2].get_future();

  auto accept_thread =
      std::async(std::launch::async, Accept, std::ref(signals_));

  auto message_broker = create_plugin();
  EXPECT_TRUE(message_broker);

  rpc::server server(kTestAddress, kRpcTestPort);

  message_broker->Bind(server);

  server.async_run();

  rpc::client client(kTestAddress, kRpcTestPort);

  accept.wait();

  auto response = OpenConnection(client);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);

  // Accept the websocket handshake
  handshake.wait();

  response = Send(client);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);

  write.wait();

  std::this_thread::sleep_for(std::chrono::milliseconds(50));

  response = Receive(client);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(kSendData, response.first);

  response = CloseConnection(client);

  Notify();

  accept_thread.wait();

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}
