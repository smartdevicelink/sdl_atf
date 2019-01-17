#pragma once

#include <string>
#include <utility>

#include "rpc/client.h"
#include "rpc/rpc_error.h"

namespace lua_lib {

class SDLRemoteTestAdapterClient {
 public:
  SDLRemoteTestAdapterClient(const std::string& host, uint32_t port);

  /**
   * @brief connected checks if client is connected to server
   * @return true if connected otherwise false
   */
  bool connected() const;

  /**
   * @brief Open channel at the server
   * @param address - host name which should be opened by server
   * @param port - number port which should be opened by server
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int open(const std::string& address, uint32_t port);

  /**
   * @brief Close channel at the server
   * @param address - host name which should be closed by server
   * @param port - number port which should be closed by server   
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int close(const std::string& address, uint32_t port);

  /**
   * @brief Sends data
   * @param address - host name which was open by server
   * @param port - number port which was open by server
   * @param data - data to be send
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception & received data in successful case,
   * otherwise empty string
   */
  std::pair<std::string, int>  send(const std::string& address, uint32_t port, const std::string& data);

   /**
   * @brief Recieve data
   * @param address - host name which was open by server
   * @param port - number port which was open by server
   * @return received data in successful case,
   * otherwise empty string
   */
  std::pair<std::string, int> receive(const std::string& address, uint32_t port);  

  /**
   * @brief Sends start application request to server
   * @param path Path to application
   * @param name Name of application
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int app_start(const std::string& path, const std::string& name);

  /**
   * @brief Sends stop application request to server
   * @param name Name of application
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int app_stop(const std::string& name);

  /**
   * @brief Sends check application status request to server
   * @param name Name of application
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  std::pair<int, int> app_check_status(const std::string& name);

  /**
   * @brief Sends check file existing request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  std::pair<bool, int> file_exists(const std::string& path, const std::string& name);

  /**
   * @brief Sends update file content request to server
   * @param path Path to file
   * @param name Name of file
   * @param content Content of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int file_update(const std::string& path,
                  const std::string& name,
                  const std::string& content);

  /**
   * @brief Sends get file content request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  std::pair<std::string, int> file_content(const std::string& path,
                                           const std::string& name);

  /**
   * @brief Sends delete file request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int file_delete(const std::string& path, const std::string& name);

  /**
   * @brief Sends backup file request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int file_backup(const std::string& path, const std::string& name);

  /**
   * @brief Sends restore backuped file request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int file_restore(const std::string& path, const std::string& name);

  /**
   * @brief Check existance of folder request to server
   * @param path Path to file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  std::pair<bool, int> folder_exists(const std::string& path);

  /**
   * @brief Sends create folder request to server
   * @param path Path to file
   * @param name Name of file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int folder_create(const std::string& path);

  /**
   * @brief Sends delete folder request to server
   * @param path Path to file
   * @return 0 in successful case, 1 - if client is not connected,
   * 2 - in case of exception
   */
  int folder_delete(const std::string& path);

  std::pair<std::string,int> command_execute(const std::string & app_name);

 private:
  int handleRpcError(rpc::rpc_error& e);
  int handleRpcTimeout(rpc::timeout& t);

  rpc::client connection_;
  friend struct SDLRemoteTestAdapterLuaWrapper;
};

}  // namespace lua_lib
