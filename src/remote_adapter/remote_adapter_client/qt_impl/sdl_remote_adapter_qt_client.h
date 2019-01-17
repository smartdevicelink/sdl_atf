#pragma once

#include <QObject>

#include <string>
#include <utility>
#include <memory>
#include <vector>
#include <thread>
#include <future>

#include "sdl_remote_adapter_client.h"

namespace lua_lib {
struct TCPParams{
  const std::string host;
  const int port;
};

class SDLRemoteTestAdapterReceiveThread;

class SDLRemoteTestAdapterQtClient : public QObject {
Q_OBJECT

public:
  SDLRemoteTestAdapterQtClient(SDLRemoteTestAdapterClient* client_ptr
                               ,TCPParams& tcp_params
                               ,QObject* parent = Q_NULLPTR);

  ~SDLRemoteTestAdapterQtClient();

  /**
  * @brief Connect client to server and open queue with custom parameters
  */
  void connect();

  /**
  * @brief Sends data to mqueue opened by server
  * @param data - data to be send to mqueue
  * @return 0 in successful case, 1 - if client is not connected,
  * 2 - in case of exception
  */
  int send(const std::string& data);

  // /**
  // * @brief Reads data from mqueue opened by server
  // * @return received data in successful case,
  // * otherwise empty string
  // */
  std::pair<std::string, int> receive();

signals:
  void textMessageReceived(const QString &message);
  void bytesWritten(qint64 data);
  void connected();
  void disconnected();

private:
  /**
  * @brief Perform actions in case underlying client is disconnected
  */
  void connectionLost();

  bool isconnected_ = false;
  TCPParams tcp_params_;
  SDLRemoteTestAdapterClient* remote_adapter_client_ptr_;
  std::unique_ptr<std::thread> listener_ptr_;
  std::promise<void> exitSignal_;
  std::future<void> future_;
};

} // namespace lua_lib
