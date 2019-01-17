#pragma once

#include <thread>
#include <mutex>
#include <memory>
#include <vector>
#include <queue> 
#include <future>
#include <boost/beast/core.hpp>
#include <boost/beast/websocket.hpp>
#include <boost/asio/bind_executor.hpp>
#include <boost/asio/strand.hpp>
#include <boost/asio/ip/tcp.hpp>
#include "rpc/detail/log.h"


namespace msg_wrappers{

using tcp = boost::asio::ip::tcp;
using io_context =  boost::asio::io_context;
namespace websocket = boost::beast::websocket;

template<class Session>
class WebsocketListener;

class WebsocketSession;

template<class TCPListener = WebsocketListener<WebsocketSession> >
class MessageBroker{
public:
    typedef std::shared_ptr<TCPListener>  HandleListener;
    typedef std::vector<std::thread>      ArrayThreads;
    typedef tcp::endpoint ConnectionIdent;
    typedef struct ListenerContext{
        // The io_context is required for all I/O
        io_context ioc_;
        HandleListener listener_;
        ArrayThreads   aThreads_;
        std::promise<void> exitSignal_;
        std::future<void> future_;
        ListenerContext(const int threads, const ConnectionIdent& connectIdent):
            ioc_(threads)
            ,listener_(std::make_shared<TCPListener>(ioc_, connectIdent))
            {
                aThreads_.reserve(threads);
                future_ = exitSignal_.get_future();
            }
        }Context;
    typedef std::shared_ptr<Context> HandleContext;
    typedef std::map<ConnectionIdent,HandleContext> HandlesListeners;
    typedef std::map<ConnectionIdent,std::queue<std::string> >  UnprocessedMessage;
    typedef int status;
    typedef std::pair<std::string, int> ReceiveResult;

    MessageBroker(){};
    MessageBroker(const MessageBroker&) = delete;
    MessageBroker& operator=(const MessageBroker&) = delete;
    MessageBroker(MessageBroker&&) = delete;
    MessageBroker& operator=(MessageBroker&&) = delete;

    ~MessageBroker();

    status        OpenConnection(const std::string& sAddress, const int port, const int threads = 2);
    status        CloseConnection(const std::string& sAddress, const int port);
    ReceiveResult Send(const std::string& sAddress, const int port, const std::string& sData);
    ReceiveResult Receive(const std::string& sAddress, const int port);

private:
    void SendUnprocessedMsg(Context* context, const ConnectionIdent & connect_ident);
    Context* MakeContext(const std::string& sAddress, const int port, int threads);
    Context* GetContext(const std::string& sAddress, const int port);
    ConnectionIdent MakeConnectIdent(const std::string& sAddress, int port);

    HandlesListeners aHandles_;
    UnprocessedMessage unprocessed_msg_;

    RPCLIB_CREATE_LOG_CHANNEL(MessageBroker)
};

template class MessageBroker<WebsocketListener<WebsocketSession> >;

class WebsocketSession : public std::enable_shared_from_this<WebsocketSession>
{
public:
   // Take ownership of the socket
    explicit
    WebsocketSession(tcp::socket socket);
    WebsocketSession(const WebsocketSession&) = delete;
    WebsocketSession& operator=(const WebsocketSession&) = delete;
    WebsocketSession(WebsocketSession&&) = delete;
    WebsocketSession& operator=(WebsocketSession&&) = delete;

    void Run(const std::string & host);
    int Write(const std::string& sData);
    std::string GetMessage();
    void Close();
    bool IsOpen();

private:
    void AsyncRead();
    void OnRead(
        boost::system::error_code ec,
        std::size_t bytes_transferred);

    void OnClose(boost::system::error_code ec);

    websocket::stream<tcp::socket> ws_;
    boost::asio::strand<
        boost::asio::io_context::executor_type> strand_;
    boost::beast::multi_buffer read_buffer_;
    std::queue<std::string> msg_queue_;
    std::mutex msg_queue_lock_;

    RPCLIB_CREATE_LOG_CHANNEL(WebsocketSession)
};

template<class Session = WebsocketSession>
class WebsocketListener : public std::enable_shared_from_this<WebsocketListener<Session> >
{
public:
    explicit
    WebsocketListener(
        boost::asio::io_context& ioc,
        tcp::endpoint endpoint);
    WebsocketListener(const WebsocketListener&) = delete;
    WebsocketListener& operator=(const WebsocketListener&) = delete;
    WebsocketListener(WebsocketListener&&) = delete;
    WebsocketListener& operator=(WebsocketListener&&) = delete;


    void Run();
    void Stop();
    void DoResolve();
    void OnResolve(boost::system::error_code ec,
                   tcp::resolver::results_type results); 

    Session& GetSession();

private:
    tcp::resolver resolver_;
    tcp::socket socket_;
    tcp::endpoint endpoint_;
    std::shared_ptr<Session> session_handler_;

    RPCLIB_CREATE_LOG_CHANNEL(WebsocketListener)
};

template class WebsocketListener<WebsocketSession>;

}
