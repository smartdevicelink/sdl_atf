#include "message_broker.h"
#include "constants.h"
#include "custom_types.h"
#include "rpc/this_handler.h"
#include <algorithm>
#include <boost/asio/connect.hpp>
#include <boost/lexical_cast.hpp>
#include <functional>
#include <iostream>
#include <string>

namespace msg_wrappers {

namespace error_codes = constants::error_codes;
namespace error_msg = constants::error_msg;

void CheckError(const int res) {
  if (constants::error_codes::SUCCESS == res) {
    return;
  }
  std::string stringified_error;
  switch (res) {
  case constants::error_codes::PATH_NOT_FOUND:
    stringified_error = "Connection not found";
    break;
  case constants::error_codes::READ_FAILURE:
    stringified_error = "Reading failure";
    break;
  case constants::error_codes::WRITE_FAILURE:
    stringified_error = "Writing failure";
    break;
  case constants::error_codes::CLOSE_FAILURE:
    stringified_error = "Closing failure";
    break;
  case constants::error_codes::ALREADY_EXISTS:
    stringified_error = "Channel already exists";
    break;
  default:
    stringified_error = strerror(res);
    break;
  }
  const auto err_obj = std::make_pair(stringified_error, res);
  rpc::this_handler().respond_error(err_obj);
}

template <const constants::param_types::type nType, typename ParameterType,
          typename Type>
bool GetValue(ParameterType &paramter, Type &value) {

  if (nType != paramter.second) {
    return false;
  }

  try {
    value = boost::lexical_cast<Type>(paramter.first);
  } catch (const boost::bad_lexical_cast &e) {
    LOG_ERROR("{0}: {1}", __func__, e.what());
    return false;
  }

  return true;
}

template <typename... Args> bool IsAllValid(Args &&... args) {
  auto all_value = {std::forward<Args>(args)...};
  for (const auto &value : all_value) {
    if (!value) {
      return false;
    }
  }
  return true;
}
//------------------------------------------------------------------------------
// Report a failure
void Fail(boost::system::error_code ec, char const *what) {
  LOG_ERROR("{0}: {1}", what, ec.message());
}

// //------------------------------------------------------------------------------
WebsocketSession::WebsocketSession(tcp::socket socket)
    : ws_(std::move(socket)), strand_(ws_.get_executor()) {
  LOG_INFO("{0}", __func__);
}

// Start the asynchronous operation
void WebsocketSession::Run(const std::string &host) {
  LOG_INFO("{0}", __func__);

  boost::system::error_code ec;
  ws_.handshake(host, "/", ec);
  if (ec) {
    Fail(ec, "WebsocketSession::Run handshake");
  }

  AsyncRead();
}

void WebsocketSession::AsyncRead() {
  LOG_INFO("{0}", __func__);

  ws_.async_read(
      read_buffer_,
      boost::asio::bind_executor(
          strand_, std::bind(&WebsocketSession::OnRead, shared_from_this(),
                             std::placeholders::_1, std::placeholders::_2)));
}

void WebsocketSession::OnRead(boost::system::error_code ec,
                              std::size_t bytes_transferred) {
  LOG_INFO("{0}", __func__);

  boost::ignore_unused(bytes_transferred);

  if (ec) {
    Fail(ec, "WebsocketSession::AsyncRead");
    return;
  }

  if (read_buffer_.size()) {
    std::unique_lock<std::mutex> msg_guard(msg_queue_lock_, std::defer_lock);
    msg_guard.lock();
    msg_queue_.push(boost::beast::buffers_to_string(read_buffer_.data()));
    LOG_INFO("{0} msg:{1}", __func__, msg_queue_.back());
    msg_guard.unlock();
    // Clear the buffer
    read_buffer_.consume(read_buffer_.size());
  }

  AsyncRead();
}

int WebsocketSession::Write(const std::string &data) {
  LOG_INFO("{0} data:{1}", __func__, data);

  boost::system::error_code ec;
  ws_.write(boost::asio::buffer(data), ec);

  if (ec) {
    Fail(ec, "WebsocketSession::Write");
    return error_codes::WRITE_FAILURE;
  }

  LOG_INFO("{0}: Succes", __func__);
  return error_codes::SUCCESS;
}

void WebsocketSession::Close() {
  LOG_INFO("{0}", __func__);

  // Close the WebSocket connection
  ws_.async_close(websocket::close_code::normal,
                  std::bind(&WebsocketSession::OnClose, shared_from_this(),
                            std::placeholders::_1));
}

void WebsocketSession::OnClose(boost::system::error_code ec) {
  LOG_INFO("{0}", __func__);
  if (ec) {
    return Fail(ec, "WebsocketSession::AsyncClose");
  }
}

std::string WebsocketSession::GetMessage() {
  LOG_INFO("{0}", __func__);

  if (msg_queue_.empty()) {
    return std::string();
  }

  std::unique_lock<std::mutex> msg_guard(msg_queue_lock_, std::defer_lock);
  msg_guard.lock();
  std::string msg = msg_queue_.front();
  msg_queue_.pop();
  msg_guard.unlock();

  return msg;
}

bool WebsocketSession::IsOpen() { return ws_.is_open(); }

// //------------------------------------------------------------------------------
template <class Session>
WebsocketListener<Session>::WebsocketListener(boost::asio::io_context &ioc,
                                              tcp::endpoint endpoint)
    : resolver_(ioc), socket_(ioc), endpoint_(endpoint) {
  LOG_INFO("{0} adress:{1} port:{2}", __func__, endpoint.address().to_string(),
           endpoint.port());
}

template <class Session> void WebsocketListener<Session>::Run() {
  LOG_INFO("{0}", __func__);

  if (socket_.is_open()) {
    return;
  }

  DoResolve();
}

template <class Session> void WebsocketListener<Session>::Stop() {
  LOG_INFO("{0}", __func__);
  resolver_.get_io_context().stop();
  if (session_.use_count()) {
    session_->Close();
  }
}

template <class Session> void WebsocketListener<Session>::DoResolve() {
  LOG_INFO("{0}", __func__);

  // Look up the domain name
  resolver_.async_resolve(
      endpoint_.address().to_string(), std::to_string(endpoint_.port()),
      std::bind(&WebsocketListener::OnResolve, this->shared_from_this(),
                std::placeholders::_1, std::placeholders::_2));
}

template <class Session>
void WebsocketListener<Session>::OnResolve(
    boost::system::error_code ec, tcp::resolver::results_type results) {
  LOG_INFO("{0}", __func__);

  if (ec) {
    return Fail(ec, "OnResolve");
  }

  boost::system::error_code er;
  boost::asio::connect(socket_, results.begin(), results.end(), er);
  if (er) {
    Fail(er, "WebsocketListener::OnResolve connect");
    resolver_.cancel();
    if (resolver_.get_io_context().stopped()) {
      return;
    }
    return DoResolve();
  }

  // Create the session and run it
  session_ = std::make_shared<Session>(std::move(socket_));
  session_->Run(endpoint_.address().to_string());
}

template <class Session> Session &WebsocketListener<Session>::GetSession() {
  LOG_INFO("{0}", __func__);

  if (session_) {
    return *(session_).get();
  }

  LOG_ERROR("{0} Session can't created return dummy_socket", __func__);

  static boost::asio::io_context ioc{1};
  tcp::socket dummy_socket(ioc);

  session_ = std::make_shared<Session>(std::move(dummy_socket));

  return *(session_).get();
}

// //------------------------------------------------------------------------------
template <class TCPListener> MessageBroker<TCPListener>::~MessageBroker() {
  LOG_INFO("{0}", __func__);

  for (auto &context : listener_context_) {
    CloseConnection(context.first.address().to_string(), context.first.port());
  }
}

template <class TCPListener>
void MessageBroker<TCPListener>::Bind(rpc::server &server) {

  server.bind(
      constants::open_handle,
      [this](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string address;
        int port;
        bool is_address =
            GetValue<constants::param_types::STRING>(parameters[0], address);
        bool is_port =
            GetValue<constants::param_types::INT>(parameters[1], port);

        if (false == IsAllValid(is_address, is_port)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }

        const int res = this->OpenConnection(address, port);
        CheckError(res);

        return response_type(std::string(), res);
      });

  server.bind(
      constants::close_handle,
      [this](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string address;
        int port;
        bool is_address =
            GetValue<constants::param_types::STRING>(parameters[0], address);
        bool is_port =
            GetValue<constants::param_types::INT>(parameters[1], port);

        if (false == IsAllValid(is_address, is_port)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }

        const int res = this->CloseConnection(address, port);
        CheckError(res);

        return response_type(std::string(), res);
      });

  server.bind(
      constants::send, [this](const std::vector<parameter_type> &parameters) {
        if (3 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string address, data;
        int port;
        bool is_address =
            GetValue<constants::param_types::STRING>(parameters[0], address);
        bool is_port =
            GetValue<constants::param_types::INT>(parameters[1], port);
        bool is_data =
            GetValue<constants::param_types::STRING>(parameters[2], data);

        if (false == IsAllValid(is_address, is_port, is_data)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }

        const auto receive_result = this->Send(address, port, data);
        return receive_result;
      });

  server.bind(
      constants::receive,
      [this](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string address;
        int port;
        bool is_address =
            GetValue<constants::param_types::STRING>(parameters[0], address);
        bool is_port =
            GetValue<constants::param_types::INT>(parameters[1], port);

        if (false == IsAllValid(is_address, is_port)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }

        const auto receive_result = this->Receive(address, port);
        return receive_result;
      });
}

template <class TCPListener>
std::string MessageBroker<TCPListener>::PluginName() {
  return "RemoteMessageBroker";
}

template <class TCPListener>
int MessageBroker<TCPListener>::OpenConnection(const std::string &address,
                                               const int port,
                                               const int threads) {
  LOG_INFO("{0}: address:{1} Port:{2} Threads:{3}", __func__, address, port,
           threads);

  if (GetContext(address,
                 port)) { // this check needed for correct running test sets
    CloseConnection(address, port);
  }

  Context *context = MakeContext(address, port, threads);

  if (nullptr == context) {
    LOG_ERROR("{0}: ALREADY_EXISTS address:{1} Port:{2} Threads:{3}", __func__,
              address, port, threads);
    return error_codes::ALREADY_EXISTS;
  }

  context->listener_->Run();

  auto &io_context = context->ioc_;
  auto &thread_list = context->thread_list_;
  auto &future = context->future_;

  // Run the I/O service on the requested number of threads
  for (auto i = threads ? threads : 1; i > 0; --i) {
    thread_list.emplace_back([&io_context, &future] {
      while (future.wait_for(std::chrono::milliseconds(1)) ==
             std::future_status::timeout) {
        io_context.run();
      }
    });
  }

  return error_codes::SUCCESS;
}

template <class TCPListener>
int MessageBroker<TCPListener>::CloseConnection(const std::string &address,
                                                const int port) {
  LOG_INFO("{0}: address:{1} port:{2}", __func__, address, port);

  const tcp::endpoint endpoint = MakeEndpoint(address, port);

  auto it_context = listener_context_.find(endpoint);

  if (listener_context_.end() == it_context) {
    return error_codes::NO_CONNECTION;
  }

  if (0 == it_context->second.use_count()) {
    return error_codes::NO_CONNECTION;
  }

  Context *context = it_context->second.get();

  context->exit_signal_.set_value();
  context->listener_->Stop();

  auto &thread_list = context->thread_list_;
  for (auto &thread : thread_list) {
    thread.join();
  }

  listener_context_.erase(it_context);

  msg_queue_.erase(endpoint);

  return error_codes::SUCCESS;
}

template <class TCPListener>
typename MessageBroker<TCPListener>::ReceiveResult
MessageBroker<TCPListener>::Send(const std::string &address, const int port,
                                 const std::string &sData) {
  LOG_INFO("{0}: to address:{1} port:{2} data:{3}", __func__, address, port,
           sData);

  Context *context = GetContext(address, port);

  if (nullptr == context) {
    return std::make_pair(std::string(), int(error_codes::NO_CONNECTION));
  }

  auto &session = context->listener_->GetSession();

  if (session.IsOpen()) {
    int result = session.Write(sData);
    return std::make_pair(session.GetMessage(), result);
  }

  msg_queue_[MakeEndpoint(address, port)].push(sData);
  return std::make_pair(std::string(), error_codes::WRITE_FAILURE);
}

template <class TCPListener>
typename MessageBroker<TCPListener>::ReceiveResult
MessageBroker<TCPListener>::Receive(const std::string &address,
                                    const int port) {
  LOG_INFO("{0}: from address:{1} port:{2}", __func__, address, port);

  Context *context = GetContext(address, port);

  if (nullptr == context) {
    return std::make_pair<std::string, int>("",
                                            int(error_codes::NO_CONNECTION));
  }

  FlushPendingMsg(context, MakeEndpoint(address, port));

  std::string msg = context->listener_->GetSession().GetMessage();

  return std::make_pair(msg, int(error_codes::SUCCESS));
}

template <class TCPListener>
void MessageBroker<TCPListener>::FlushPendingMsg(
    Context *context, const tcp::endpoint &endpoint) {
  LOG_INFO("{0}", __func__);

  auto &unpr_msg = msg_queue_[endpoint];

  if (unpr_msg.empty()) {
    return;
  }

  if (nullptr == context) {
    return;
  }

  auto &session = context->listener_->GetSession();

  if (false == session.IsOpen()) {
    return;
  }

  while (false == unpr_msg.empty()) {
    if (error_codes::SUCCESS != session.Write(unpr_msg.front())) {
      break;
    }
    unpr_msg.pop();
  }
}
template <class TCPListener>
typename MessageBroker<TCPListener>::Context *
MessageBroker<TCPListener>::MakeContext(const std::string &address,
                                        const int port, int threads) {
  LOG_INFO("{0}", __func__);

  const tcp::endpoint endpoint = MakeEndpoint(address, port);

  threads = std::max<int>(1, threads);

  auto result = listener_context_.insert(
      std::make_pair(endpoint, std::make_shared<Context>(threads, endpoint)));

  if (result.second) {
    return result.first->second.get();
  }

  return nullptr;
}

template <class TCPListener>
typename MessageBroker<TCPListener>::Context *
MessageBroker<TCPListener>::GetContext(const std::string &address,
                                       const int port) {
  LOG_INFO("{0}", __func__);

  const tcp::endpoint endpoint = MakeEndpoint(address, port);

  auto const it_context = listener_context_.find(endpoint);

  if (it_context != listener_context_.end()) {
    return it_context->second.get();
  }

  return nullptr;
}

template <class TCPListener>
tcp::endpoint
MessageBroker<TCPListener>::MakeEndpoint(const std::string &address,
                                         const int port) {
  LOG_INFO("{0}", __func__);

  auto const ip_address = boost::asio::ip::make_address(address.c_str());

  return tcp::endpoint{ip_address, port};
}

#define LIBRARY_API extern "C"

LIBRARY_API void delete_plugin(remote_adapter::UtilsPlugin *plugin) {
  delete plugin;
}

LIBRARY_API remote_adapter::adapter_plugin_ptr create_plugin() {
  return remote_adapter::adapter_plugin_ptr(new MessageBroker<>(),
                                            delete_plugin);
};

}; // namespace msg_wrappers
