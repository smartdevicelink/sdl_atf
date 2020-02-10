#include <iostream>

#include "common/constants.h"
#include "hmi_adapter/hmi_adapter_client.h"
#include "rpc/detail/log.h"

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(HmiAdapterClient)

namespace error_codes = constants::error_codes;

HmiAdapterClient::HmiAdapterClient(
    RemoteClient *client_ptr,
    std::vector<parameter_type> &connection_parameters, QObject *parent)
    : QObject(parent), connection_parameters_(connection_parameters) {
  LOG_INFO("{0}", __func__);

  remote_adapter_client_ptr_ = client_ptr;
  try {
    future_ = exit_signal_.get_future();
  } catch (std::future_error &e) {
    std::cerr << __func__ << " " << e.what() << "\n" << std::flush;
  }
}

HmiAdapterClient::~HmiAdapterClient() {
  LOG_INFO("{0}", __func__);
  if (listener_ptr_) {
    try {
      exit_signal_.set_value();
    } catch (std::future_error &e) {
      std::cerr << __func__ << " " << e.what() << "\n" << std::flush;
    }
    listener_ptr_->join();
  }

  if (is_connected_) {
    remote_adapter_client_ptr_->content_call(constants::close_handle,
                                             connection_parameters_);
  }
}

void HmiAdapterClient::connect() {
  LOG_INFO("{0}", __func__);
  if (is_connected_ || listener_ptr_) {
    LOG_INFO("{0} Is already connected", __func__);
    response_type result = remote_adapter_client_ptr_->content_call(
        constants::open_handle, connection_parameters_);
    if (error_codes::SUCCESS == result.second) {
      emit connected();
    }
    return;
  }

  response_type result = remote_adapter_client_ptr_->content_call(
      constants::open_handle, connection_parameters_);

  if (error_codes::SUCCESS == result.second) {
    try {
      is_connected_ = true;
      emit connected();
      auto &future = future_;
      listener_ptr_.reset(new std::thread([this, &future] {
        try {
          while (future.wait_for(std::chrono::milliseconds(25)) ==
                 std::future_status::timeout) {
            this->receive();
          }
        } catch (std::future_error &e) {
          std::cerr << "Exception in: " << __func__ << " " << e.what() << "\n"
                    << std::flush;
        } catch (...) {
          std::cerr << "Unknown Exception in: " << __func__ << "\n"
                    << std::flush;
        }
      }));
    } catch (std::exception &e) {
      std::cerr << __func__ << " " << e.what() << "\n" << std::flush;
    } catch (...) {
      std::cerr << "Unknown Exception in: " << __func__ << "\n" << std::flush;
    }
  }
}

int HmiAdapterClient::send(const std::string &data) {
  LOG_INFO("{0}", __func__);
  if (is_connected_) {
    std::vector<parameter_type> parameters(connection_parameters_);
    parameters.push_back(std::make_pair(data, constants::param_types::STRING));
    response_type result =
        remote_adapter_client_ptr_->content_call(constants::send, parameters);
    if (error_codes::SUCCESS == result.second) {
      emit bytesWritten(data.length());
      if (result.first.length()) {
        QString receivedData(result.first.c_str());
        emit textMessageReceived(receivedData);
      }
    } else if (error_codes::NO_CONNECTION == result.second) {
      connectionLost();
    }
    return result.second;
  }
  LOG_ERROR("{0}: Websocket was not connected", __func__);
  return error_codes::NO_CONNECTION;
}

response_type HmiAdapterClient::receive() {
  if (is_connected_) {
    response_type result = remote_adapter_client_ptr_->content_call(
        constants::receive, connection_parameters_);
    if (error_codes::SUCCESS == result.second) {
      if (result.first.length()) {
        QString receivedData(result.first.c_str());
        emit textMessageReceived(receivedData);
      }
    } else if (error_codes::NO_CONNECTION == result.second) {
      connectionLost();
    }
    return result;
  }
  LOG_ERROR("{0}: Websocket was not connected", __func__);
  return std::make_pair(std::string(), error_codes::NO_CONNECTION);
}

void HmiAdapterClient::connectionLost() {
  LOG_INFO("{0}", __func__);
  if (is_connected_) {
    is_connected_ = false;
    emit disconnected();
  }
}

} // namespace lua_lib
