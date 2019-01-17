#include "message_broker.h"
#include <algorithm>
#include <functional>
#include <iostream>
#include <string>
#include <boost/asio/connect.hpp>
#include "common/constants.h"

namespace msg_wrappers{

namespace error_codes = constants::error_codes;

//------------------------------------------------------------------------------
// Report a failure
void Fail(boost::system::error_code ec, char const* what){
    LOG_ERROR("{0}: {1}",what,ec.message());    
}

// //------------------------------------------------------------------------------
 WebsocketSession::WebsocketSession(tcp::socket socket)
        : ws_(std::move(socket))
        , strand_(ws_.get_executor())
{
    LOG_INFO("{0}",__func__);
}

    // Start the asynchronous operation
void  WebsocketSession::Run(const std::string & host){
    LOG_INFO("{0}",__func__);

    boost::system::error_code ec;
    ws_.handshake(host, "/",ec);
    if(ec){
        Fail(ec,"WebsocketSession::Run handshake");
    }

    AsyncRead();
}

void WebsocketSession::AsyncRead(){
    LOG_INFO("{0}",__func__);

    ws_.async_read(
        read_buffer_,
        boost::asio::bind_executor(
            strand_,
            std::bind(
                &WebsocketSession::OnRead,
                shared_from_this(),
                std::placeholders::_1,
                std::placeholders::_2)));
}

void WebsocketSession::OnRead(
        boost::system::error_code ec,
        std::size_t bytes_transferred)
{
    LOG_INFO("{0}",__func__);

    boost::ignore_unused(bytes_transferred);

    if(ec){
        Fail(ec,"WebsocketSession::AsyncRead");
        return;
    }

    if(read_buffer_.size()){
        std::unique_lock<std::mutex> msg_guard(msg_queue_lock_,std::defer_lock);
        msg_guard.lock();
        msg_queue_.push(boost::beast::buffers_to_string(read_buffer_.data()));
        LOG_INFO("{0} msg:{1}",__func__,msg_queue_.back());
        msg_guard.unlock();
        // Clear the buffer
        read_buffer_.consume(read_buffer_.size());
    }

    AsyncRead();
}

int WebsocketSession::Write(const std::string& sData){
    LOG_INFO("{0} data:{1}",__func__,sData);

    boost::system::error_code ec;
    ws_.write(boost::asio::buffer(sData),ec);

    if(ec){
        Fail(ec,"WebsocketSession::Write");
        return error_codes::WRITE_FAILURE;
    }

    LOG_INFO("{0}: Succes",__func__);
    return error_codes::SUCCESS;
}

void WebsocketSession::Close(){
    LOG_INFO("{0}",__func__);

     // Close the WebSocket connection
     ws_.async_close(websocket::close_code::normal,
        std::bind(
                &WebsocketSession::OnClose,
                shared_from_this(),
                std::placeholders::_1));
}

void WebsocketSession::OnClose(boost::system::error_code ec){
     LOG_INFO("{0}",__func__);
     if(ec){
         return Fail(ec,"WebsocketSession::AsyncClose");
     }
}

std::string WebsocketSession::GetMessage(){
    LOG_INFO("{0}",__func__);

    if(msg_queue_.empty()){
        return std::string();
    }

    std::unique_lock<std::mutex> msg_guard(msg_queue_lock_,std::defer_lock);
    msg_guard.lock();
    std::string msg = msg_queue_.front();
    msg_queue_.pop();
    msg_guard.unlock();

    return msg;
}

bool WebsocketSession::IsOpen(){
    return ws_.is_open();
}

// //------------------------------------------------------------------------------
template<class Session>
WebsocketListener<Session>::WebsocketListener(
        boost::asio::io_context& ioc,
        tcp::endpoint endpoint)
        : resolver_(ioc)
        , socket_(ioc)
        ,endpoint_(endpoint)
{
    LOG_INFO("{0} adress:{1} port:{2}",__func__,endpoint.address().to_string(),endpoint.port());
}

template<class Session>
void WebsocketListener<Session>::Run(){
    LOG_INFO("{0}",__func__);

    if(socket_.is_open()){
        return;
    }

    DoResolve();
}

template<class Session>
void WebsocketListener<Session>::Stop(){
    LOG_INFO("{0}",__func__);
    resolver_.get_io_context().stop();
    if(session_handler_.use_count()){
        session_handler_->Close();
    }
}

template<class Session>
void WebsocketListener<Session>::DoResolve(){
    LOG_INFO("{0}",__func__);

    //Look up the domain name
    resolver_.async_resolve(
        endpoint_.address().to_string(),
        std::to_string(endpoint_.port()),
        std::bind(
            &WebsocketListener::OnResolve,
            this->shared_from_this(),
            std::placeholders::_1,
            std::placeholders::_2));
}

template<class Session>
void WebsocketListener<Session>::OnResolve(
    boost::system::error_code ec,
    tcp::resolver::results_type results)
{
    LOG_INFO("{0}",__func__);

    if(ec){
        return Fail(ec, "OnResolve");
    }

    boost::system::error_code er;
    boost::asio::connect(socket_, results.begin(), results.end(),er);
    if(er){
        Fail(er, "WebsocketListener::OnResolve connect");
        resolver_.cancel();
        if(resolver_.get_io_context().stopped()){
            return;
        }
        return DoResolve();
    }

    // Create the session and run it
    session_handler_ = std::make_shared<Session>(std::move(socket_));
    session_handler_->Run(endpoint_.address().to_string());
}

template<class Session>
Session& WebsocketListener<Session>::GetSession(){    
    LOG_INFO("{0}",__func__);

    if(session_handler_){
        return *(session_handler_).get();
    }

    LOG_ERROR("{0} Session can't created returned dummy_socket",__func__);

    static boost::asio::io_context ioc{1};
    tcp::socket dummy_socket(ioc);

    session_handler_ = std::make_shared<Session>(std::move(dummy_socket));

    return *(session_handler_).get();
}

// //------------------------------------------------------------------------------
template<class TCPListener>
MessageBroker<TCPListener>::~MessageBroker(){
    LOG_INFO("{0}",__func__);

    for(auto & handle : aHandles_){
        CloseConnection(handle.first.address().to_string(),handle.first.port());
    }
}

template<class TCPListener>
typename MessageBroker<TCPListener>::status MessageBroker<TCPListener>::OpenConnection(
    const std::string& sAddress,const int port,const int threads)
{
    LOG_INFO("{0}: address:{1} Port:{2} Threads:{3}",__func__,sAddress,port,threads);

    if(GetContext(sAddress,port)){//this check needed for correct running test sets
        CloseConnection(sAddress,port);
    }

    Context * context = MakeContext(sAddress,port,threads);

    if(nullptr == context){
        LOG_ERROR("{0}: ALREADY_EXISTS address:{1} Port:{2} Threads:{3}",__func__,sAddress,port,threads);             
        return error_codes::ALREADY_EXISTS;
    }

    context->listener_->Run();

    auto & io_context = context->ioc_;
    auto & aThreads = context->aThreads_;
    auto & future = context->future_;

    // Run the I/O service on the requested number of threads
    for(auto i = threads ? threads : 1; i > 0; --i){
       aThreads.emplace_back(
           [&io_context,&future]
            {
                while(future.wait_for(std::chrono::milliseconds(1)) == std::future_status::timeout){
                    io_context.run();
                }
            }
        );
    }

    return error_codes::SUCCESS;
}

template<class TCPListener>
typename MessageBroker<TCPListener>::status MessageBroker<TCPListener>::CloseConnection(
    const std::string& sAddress,const int port)
{
    LOG_INFO("{0}: address:{1} port:{2}",__func__,sAddress,port);

    const ConnectionIdent connectIdent = MakeConnectIdent(sAddress,port);

    auto itHandler = aHandles_.find(connectIdent);

    if(aHandles_.end() == itHandler){
        return error_codes::NO_CONNECTION;
    }

    if(0 == itHandler->second.use_count()){
        return error_codes::NO_CONNECTION;
    }

    Context * context = itHandler->second.get();

    context->exitSignal_.set_value();
    context->listener_->Stop();

    auto & aThreads = context->aThreads_;
    for(auto & thread : aThreads){
        thread.join();
    }

    aHandles_.erase(itHandler);

    unprocessed_msg_.erase(connectIdent);

    return error_codes::SUCCESS;
}

template<class TCPListener>
typename MessageBroker<TCPListener>::ReceiveResult MessageBroker<TCPListener>::Send(
    const std::string& sAddress,const int port,const std::string& sData)
{
    LOG_INFO("{0}: to address:{1} port:{2} data:{3}",__func__,sAddress,port,sData);

    Context* context = GetContext(sAddress,port);

    if(nullptr == context){
        return  std::make_pair(std::string(),int(error_codes::NO_CONNECTION));
    }

    auto & session = context->listener_->GetSession();

    if(session.IsOpen()){
        int result = session.Write(sData);
        return std::make_pair(session.GetMessage(),result);
    }

    unprocessed_msg_[MakeConnectIdent(sAddress,port)].push(sData);
    return std::make_pair(std::string(),error_codes::WRITE_FAILURE);
}

template<class TCPListener>
typename MessageBroker<TCPListener>::ReceiveResult MessageBroker<TCPListener>::Receive(
    const std::string& sAddress,const int port)
{
    LOG_INFO("{0}: from address:{1} port:{2}",__func__,sAddress,port);

    Context* context = GetContext(sAddress,port);

    if(nullptr == context){
        return std::make_pair<std::string,int>("",int(error_codes::NO_CONNECTION));
    }

    SendUnprocessedMsg(context,MakeConnectIdent(sAddress,port));

    std::string msg = context->listener_->GetSession().GetMessage();

    return std::make_pair(msg,int(error_codes::SUCCESS));
}

template<class TCPListener>
void MessageBroker<TCPListener>::SendUnprocessedMsg(Context* context,const ConnectionIdent & connect_ident){
    LOG_INFO("{0}",__func__);

    auto & unpr_msg = unprocessed_msg_[connect_ident];

    if(unpr_msg.empty()){
        return;
    }

    if(nullptr == context){
        return;
    }

    auto & session = context->listener_->GetSession();

    if(false ==session.IsOpen()){
        return;
    }

    while(false == unpr_msg.empty()){  
        if(error_codes::SUCCESS != session.Write(unpr_msg.front())){
            break;
        }
        unpr_msg.pop();
    }
}
template<class TCPListener>
typename MessageBroker<TCPListener>::Context* MessageBroker<TCPListener>::MakeContext(
    const std::string& sAddress,const int port,int threads)
{
    LOG_INFO("{0}",__func__);

    const ConnectionIdent connectIdent = MakeConnectIdent(sAddress,port);    

    threads = std::max<int>(1,threads);

    auto result = aHandles_.insert(std::make_pair(connectIdent,std::make_shared<Context>(threads,connectIdent)));   

    if(result.second){
        return result.first->second.get();
    }

    return nullptr;
}

template<class TCPListener>
typename MessageBroker<TCPListener>::Context* MessageBroker<TCPListener>::GetContext(
    const std::string& sAddress,const int port)
{
    LOG_INFO("{0}",__func__);

    const ConnectionIdent connectIdent = MakeConnectIdent(sAddress,port);

    const auto itHandler = aHandles_.find(connectIdent);

    if(itHandler != aHandles_.end()){
        return itHandler->second.get();
    }

    return nullptr;
}

template<class TCPListener>
typename MessageBroker<TCPListener>::ConnectionIdent MessageBroker<TCPListener>::MakeConnectIdent(
    const std::string& sAddress,const int port)    
{
    LOG_INFO("{0}",__func__);

    auto const address = boost::asio::ip::make_address(sAddress.c_str());

    return ConnectionIdent{address, port};
}

};
