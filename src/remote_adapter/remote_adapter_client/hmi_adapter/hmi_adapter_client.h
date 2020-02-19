#pragma once

#include <QObject>

#include <future>
#include <memory>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "common/custom_types.h"
#include "remote_client/remote_client.h"

namespace lua_lib {

class HmiAdapterClient : public QObject {
  Q_OBJECT

public:
  HmiAdapterClient(RemoteClient *client_ptr,
                   std::vector<parameter_type> &connection_parameters,
                   QObject *parent = Q_NULLPTR);

  ~HmiAdapterClient();

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
  int send(const std::string &data);

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

  bool is_connected_ = false;
  std::vector<parameter_type> connection_parameters_;
  RemoteClient *remote_adapter_client_ptr_;
  std::unique_ptr<std::thread> listener_ptr_;
  std::promise<void> exit_signal_;
  std::future<void> future_;
};

} // namespace lua_lib
