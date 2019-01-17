#include "sdl_remote_adapter_client.h"

#include <iostream>

#include "common/constants.h"
#include "rpc/detail/log.h"

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(SDLRemoteTestAdapterClient)

SDLRemoteTestAdapterClient::SDLRemoteTestAdapterClient(const std::string& host,
                                                       uint32_t port)
    : connection_(host, port) {
  LOG_INFO("{}",__func__);
  const int timeout_ = 10000;
  connection_.set_timeout(timeout_);
  try {
    LOG_INFO("Check connection: ");
    connection_.call(constants::client_connected);
    LOG_INFO("connection OK");
  } catch (rpc::timeout &t) {
    handleRpcTimeout(t);
  }
}

bool SDLRemoteTestAdapterClient::connected() const {
  LOG_INFO("{} Check connection:",__func__);
  if (rpc::client::connection_state::connected ==
         connection_.get_connection_state()) {
    LOG_INFO("connection OK");
    return true;
  }
  LOG_ERROR("Not connected");
  return false;
}

int SDLRemoteTestAdapterClient::open(const std::string& address,uint32_t port) try {
  LOG_INFO("{0} adress: {1} port: {2} on remote host",__func__,address,port);
  if (connected()) {
    connection_.call(constants::open,address,port);
    LOG_INFO("{0}: Exit with SUCCESS",__func__); 
    return constants::error_codes::SUCCESS;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

int SDLRemoteTestAdapterClient::close(const std::string& address,uint32_t port) try {
  LOG_INFO("{0} adress: {1} port: {2} on remote host",__func__,address,port);
  if (connected()) {
    connection_.call(constants::close,address,port);
    LOG_INFO("{0}: Exit with SUCCESS",__func__); 
    return constants::error_codes::SUCCESS;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

std::pair<std::string, int> SDLRemoteTestAdapterClient::send(
  const std::string& address,uint32_t port,const std::string& data) try {
  LOG_INFO("{0}: data to websocket address: {1} port: {2} \ndata: {3}"
          ,__func__
          ,address
          ,port
          ,data);
  if (connected()) {
    using result = std::pair<std::string, int>;
     result received = connection_.call(constants::send,address,port,data).as<result>();
    LOG_INFO("{0}: result:{1}",__func__,received.second);
    return received;
  }
  LOG_ERROR("No connection");
 return std::make_pair(std::string(), constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(std::string(), handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(std::string(), handleRpcTimeout(t));
}

std::pair<std::string, int> SDLRemoteTestAdapterClient::receive(
  const std::string& address,uint32_t port) try {
  LOG_INFO("{0}: data from websocket address: {1} port: {2}"
          ,__func__
          ,address
          ,port);
  if (connected()) {
    using result = std::pair<std::string, int>;
    result received = connection_.call(
                                  constants::receive
                                  ,address
                                  ,port).as<result>();
    LOG_INFO("{0}: Exit with {1}",__func__,received.second);
    return std::make_pair(received.first, received.second);
  }
  LOG_ERROR("No connection");
  return std::make_pair(std::string(), constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(std::string(), handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(std::string(), handleRpcTimeout(t));
}

int SDLRemoteTestAdapterClient::app_start(const std::string& path,
                                          const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    int result_codes = connection_.call(
                            constants::app_start,
                            path,
                            name
                            )
                            .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);     
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

int SDLRemoteTestAdapterClient::app_stop(const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host",__func__,name);
  if (connected()) {
    int result_codes = connection_.call(
                            constants::app_stop,
                            name)
                            .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);        
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

std::pair<int, int> SDLRemoteTestAdapterClient::app_check_status(const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host",__func__,name);            
  if (connected()) {
    using received = int;
    const received result_codes = connection_.call(
                                        constants::app_check_status,
                                        name)
                                        .as<received>();
    LOG_INFO("{0}: Exit with SUCCESS",__func__);     
    return std::make_pair(result_codes, constants::error_codes::SUCCESS);
  }
  LOG_ERROR("No connection");
  return std::make_pair(0, constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(0, handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(0, handleRpcTimeout(t));
}

std::pair<bool, int> SDLRemoteTestAdapterClient::file_exists(const std::string& path,
                                          const std::string& name) try {
LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    using received = int;
    const received resilt_code = connection_.call(
                                              constants::file_exists,
                                              path,
                                              name)
                                              .as<received>();
    LOG_INFO("{0}: Exit with SUCCESS",__func__);     
    return std::make_pair(bool(!resilt_code),constants::error_codes::SUCCESS);
  }
  LOG_ERROR("No connection");
  return std::make_pair(false, constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(false, handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(false, handleRpcTimeout(t));
}

int SDLRemoteTestAdapterClient::file_update(const std::string& path,
                                            const std::string& name,
                                            const std::string& content) try {
  LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    int result_codes = connection_.call(
                                    constants::file_update,
                                    path,
                                    name,
                                    content
                                    )
                                    .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);    
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

std::pair<std::string, int> SDLRemoteTestAdapterClient::file_content(
                                              const std::string& path,
                                              const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  using namespace constants;
  if (connected()) {
    using result = std::pair<std::string, int>;

    result received = connection_.call(
                                  constants::file_content,
                                  path,
                                  name,
                                  0,
                                  constants::kMaxSizeData
                        ).as<result>();

    if(error_codes::FAILED == received.second){
      LOG_ERROR("{0}:\nExit Get file data from HU Failed!!!",__func__);
      return received;
    }

    std::string tmp_path("/tmp/");
    tmp_path.append(name);

    remove(tmp_path.c_str());

    FILE * hFile = fopen(tmp_path.c_str(),"a");
    if(!hFile){
      LOG_ERROR("{0}:\nExit with Failed: \nCan't created file: {1}"
                ,__func__
                ,tmp_path);
      return std::make_pair(std::string("Can't created file"),error_codes::FAILED);
    }

    if(error_codes::SUCCESS != received.second){

      do{

        fwrite(received.first.c_str(),received.first.length(),1,hFile);

        received = connection_.call(
            constants::file_content,
            path,
            name,
            received.second,
            constants::kMaxSizeData
            ).as<result>();

      }while(error_codes::SUCCESS != received.second);
    }

    fwrite(received.first.c_str(),received.first.length(),1,hFile);
    fclose(hFile);

    LOG_INFO("{0}:\nExit with SUCCESS\nReceived data from path: {1}"
             "\nLength: {2}"
              ,__func__
              ,tmp_path
              ,received.first.length());
    return std::make_pair(tmp_path, received.second);
  }
  LOG_ERROR("No connection");
  return std::make_pair(std::string(), constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(std::string(), handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(std::string(), handleRpcTimeout(t));
}

int SDLRemoteTestAdapterClient::file_delete(const std::string& path,
                                          const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    int result_codes = connection_.call(
                                    constants::file_delete,
                                    path,
                                    name
                                    )
                                    .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);    
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

int SDLRemoteTestAdapterClient::file_backup(const std::string& path,
                                          const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host \nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    int result_codes = connection_.call(
                            constants::file_backup,
                            path,
                            name
                            )
                            .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);    
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

int SDLRemoteTestAdapterClient::file_restore(const std::string& path,
                                          const std::string& name) try {
  LOG_INFO("{0}: {1} on remote host\nPath to file: {2}"
          ,__func__
          ,name
          ,path);
  if (connected()) {
    int result_codes = connection_.call(
                            constants::file_restore,
                            path,
                            name
                            ).as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_codes);    
    return result_codes;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

std::pair<bool, int> SDLRemoteTestAdapterClient::folder_exists(const std::string& path) try {
  LOG_INFO("{0}: {1}",__func__,path);
  if (connected()) {
    using received = int;
    const received result_code = connection_.call(
                                                constants::folder_exists,
                                                path)
                                                .as<received>();
    LOG_INFO("{0}: Exit with SUCCESS",__func__);     
    return std::make_pair(bool(!result_code),constants::error_codes::SUCCESS);
  }
  LOG_ERROR("No connection");
  return std::make_pair(false, constants::error_codes::NO_CONNECTION);
} catch (rpc::rpc_error& e) {
  return std::make_pair(false, handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(false, handleRpcTimeout(t));
}

int SDLRemoteTestAdapterClient::folder_create(const std::string& path) try {
  LOG_INFO("{0}: {1} on remote host",__func__,path);      
  if (connected()) {
    int result_code = connection_.call(
                                    constants::folder_create,
                                    path
                                    ).as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_code);    
    return result_code;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

int SDLRemoteTestAdapterClient::folder_delete(const std::string& path) try {
  LOG_INFO("{0}: {1}  on remote host",__func__,path);
  if (connected()) {
    int result_code = connection_.call(
                                    constants::folder_delete,
                                    path)
                                    .as<int>();
    LOG_INFO("{0}: Exit with {1}",__func__,result_code);    
    return result_code;
  }
  LOG_ERROR("No connection");
  return constants::error_codes::NO_CONNECTION;
} catch (rpc::rpc_error& e) {
  return handleRpcError(e);
} catch (rpc::timeout &t) {
  return handleRpcTimeout(t);
}

std::pair<std::string,int> SDLRemoteTestAdapterClient::command_execute(const std::string & bash_command)try{
  LOG_INFO("{0}: execute_command: {1}",__func__,bash_command);
  using namespace constants;
  if (connected()) {
    using result = std::pair<std::string, int>;

    result received = connection_.call(
                                  constants::command_execute,
                                  bash_command
                                  )
                                  .as<result>();

    LOG_INFO("Result: {0}\nCommand: {1}\nOutput: {2}\n"
            ,received.second
            ,bash_command
            ,received.first);

    return received;
  }
  LOG_ERROR("No connection");
  return std::make_pair(std::string(), constants::error_codes::NO_CONNECTION);

}catch (rpc::rpc_error& e) {
  return std::make_pair(std::string(), handleRpcError(e));
} catch (rpc::timeout &t) {
  return std::make_pair(std::string(), handleRpcTimeout(t));
}

int SDLRemoteTestAdapterClient::handleRpcError(rpc::rpc_error& e) {
  LOG_ERROR("EXCEPTION Occured in function: {}"
            ,e.get_function_name());
  LOG_ERROR("[Error type]: {}",e.what());
  auto err = e.get_error().as<std::pair<int, std::string> >();
  LOG_ERROR("[Error code]: {0} \n[Error description]: {1}"
            ,err.first
            ,err.second);
  return err.first;
}

int SDLRemoteTestAdapterClient::handleRpcTimeout(rpc::timeout& t) {
  LOG_INFO("TIMEOUT expired: {}",t.what());
  return constants::error_codes::TIMEOUT_EXPIRED;
}

}  // namespace lua_lib
