#pragma once

#include "remote_adapter_plugin.h"
#include "rpc/detail/log.h"
#include <boost/asio/bind_executor.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/strand.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/websocket.hpp>
#include <future>
#include <memory>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

namespace msg_wrappers {

using tcp = boost::asio::ip::tcp;
using io_context = boost::asio::io_context;
namespace websocket = boost::beast::websocket;

template <class Session> class WebsocketListener;

class WebsocketSession;

template <class TCPListener = WebsocketListener<WebsocketSession>>
class MessageBroker : public remote_adapter::UtilsPlugin {
public:
  typedef struct ListenerContext {
    // The io_context is required for all I/O
    io_context ioc_;
    std::shared_ptr<TCPListener> listener_;
    std::vector<std::thread> thread_list_;
    std::promise<void> exit_signal_;
    std::future<void> future_;
    ListenerContext(const int threads, const tcp::endpoint &endpoint)
        : ioc_(threads),
          listener_(std::make_shared<TCPListener>(ioc_, endpoint)) {
      thread_list_.reserve(threads);
      future_ = exit_signal_.get_future();
    }
  } Context;
  typedef std::shared_ptr<Context> ContextSPtr;
  typedef std::map<tcp::endpoint, ContextSPtr> ContextMap;
  typedef std::map<tcp::endpoint, std::queue<std::string>> MessageMap;
  typedef std::pair<std::string, int> ReceiveResult;

  MessageBroker(){};
  ~MessageBroker();

  void Bind(rpc::server &server) override;
  std::string PluginName() override;

private:
  void FlushPendingMsg(Context *context, const tcp::endpoint &endpoint);
  Context *MakeContext(const std::string &address, const int port, int threads);
  Context *GetContext(const std::string &address, const int port);
  tcp::endpoint MakeEndpoint(const std::string &address, int port);

  ContextMap listener_context_;
  MessageMap msg_queue_;

  int OpenConnection(const std::string &address, const int port,
                     const int threads = 2);
  int CloseConnection(const std::string &address, const int port);
  ReceiveResult Send(const std::string &address, const int port,
                     const std::string &sData);
  ReceiveResult Receive(const std::string &address, const int port);

  MessageBroker(const MessageBroker &) = delete;
  MessageBroker &operator=(const MessageBroker &) = delete;
  MessageBroker(MessageBroker &&) = delete;
  MessageBroker &operator=(MessageBroker &&) = delete;

  RPCLIB_CREATE_LOG_CHANNEL(MessageBroker)
};

template class MessageBroker<WebsocketListener<WebsocketSession>>;

class WebsocketSession : public std::enable_shared_from_this<WebsocketSession> {
public:
  // Take ownership of the socket
  explicit WebsocketSession(tcp::socket socket);
  WebsocketSession(const WebsocketSession &) = delete;
  WebsocketSession &operator=(const WebsocketSession &) = delete;
  WebsocketSession(WebsocketSession &&) = delete;
  WebsocketSession &operator=(WebsocketSession &&) = delete;
  /*
   * @brief Accept the websocket handshake and
   * start the asynchronous operation.
   *
   * @param host the name of the remote host
   */
  void Run(const std::string &host);
  /*
   * @brief This function is used to write a complete message.
   *
   * @param data string containing the message to send
   * @return code from error_codes namespace, SUCCESS or WRITE_FAILURE
   */
  int Write(const std::string &data);
  /*
   * @brief This function is used to get a complete message from message queue
   *
   * @return complete message from message queue
   */
  std::string GetMessage();
  /*
   * @brief This function is used to asynchronously send
   * a close frame on the stream
   */
  void Close();
  /*
   * @brief The stream is open after a successful handshake, and when no error
   * has occurred.
   *
   * @return true if the stream is open
   */
  bool IsOpen();

private:
  void AsyncRead();
  void OnRead(boost::system::error_code ec, std::size_t bytes_transferred);

  void OnClose(boost::system::error_code ec);

  websocket::stream<tcp::socket> ws_;
  boost::asio::strand<boost::asio::io_context::executor_type> strand_;
  boost::beast::multi_buffer read_buffer_;
  std::queue<std::string> msg_queue_;
  std::mutex msg_queue_lock_;

  RPCLIB_CREATE_LOG_CHANNEL(WebsocketSession)
};

template <class Session = WebsocketSession>
class WebsocketListener
    : public std::enable_shared_from_this<WebsocketListener<Session>> {
public:
  explicit WebsocketListener(boost::asio::io_context &ioc,
                             tcp::endpoint endpoint);
  WebsocketListener(const WebsocketListener &) = delete;
  WebsocketListener &operator=(const WebsocketListener &) = delete;
  WebsocketListener(WebsocketListener &&) = delete;
  WebsocketListener &operator=(WebsocketListener &&) = delete;
  /*
   * @brief Look up the domain name and start the asynchronous operation.
   */
  void Run();
  /*
   * @brief Stop the io_context object's event processing loop
   * and close the WebSocket connection
   */
  void Stop();
  /*
   * @brief This function is used to access read, write operations.
   *
   * @return object related to host and port
   */
  Session &GetSession();

private:
  void DoResolve();
  void OnResolve(boost::system::error_code ec,
                 tcp::resolver::results_type results);

  tcp::resolver resolver_;
  tcp::socket socket_;
  tcp::endpoint endpoint_;
  std::shared_ptr<Session> session_;

  RPCLIB_CREATE_LOG_CHANNEL(WebsocketListener)
};

template class WebsocketListener<WebsocketSession>;

} // namespace msg_wrappers
