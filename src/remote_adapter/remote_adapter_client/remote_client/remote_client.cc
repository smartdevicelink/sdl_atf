#include "remote_client.h"

#include <iostream>

#include "common/constants.h"
#include "rpc/detail/log.h"

namespace lua_lib {

RPCLIB_CREATE_LOG_CHANNEL(RemoteClient)

RemoteClient::RemoteClient(connection_ptr connection)
    : connection_(std::move(connection)) {
  LOG_INFO("{}", __func__);
  const int timeout_ = 10000;
  connection_->set_timeout(timeout_);

  LOG_INFO("Check connection: ");

  auto response =
      connection_->call(constants::client_connected).as<response_type>();

  if (constants::error_codes::SUCCESS != response.second) {
    LOG_ERROR("{}", response.first);
  } else {
    LOG_INFO("connection OK");
  }
}

bool RemoteClient::connected() const {
  LOG_INFO("{} Check connection:", __func__);
  if (rpc::client::connection_state::connected ==
      connection_->get_connection_state()) {
    LOG_INFO("connection OK");
    return true;
  }
  LOG_ERROR("Not connected");
  return false;
}

response_type RemoteClient::file_call(const std::string &rpc_name,
                                      std::vector<parameter_type> parameters) {
  LOG_INFO("{0}: of: {1} with {2} parameters", __func__, rpc_name,
           parameters.size());

  namespace error_codes = constants::error_codes;

  if (connected()) {
    parameters.push_back(
        std::make_pair(std::to_string(0), constants::param_types::INT));
    parameters.push_back(std::make_pair(std::to_string(constants::kMaxSizeData),
                                        constants::param_types::INT));
    response_type response =
        connection_->call(rpc_name, parameters).as<response_type>();

    if (0 > response.second) {
      LOG_ERROR("{0}:\nExit Get file data from HU Failed!!!", __func__);
      return response;
    }

    std::string tmp_path(constants::kTmpPath);
    tmp_path.append(parameters[1].first);

    remove(tmp_path.c_str());

    FILE *hFile = fopen(tmp_path.c_str(), "a");
    if (!hFile) {
      LOG_ERROR("{0}:\nExit with Failed: \nCan't create file: {1}", __func__,
                tmp_path);
      return std::make_pair(std::string("Can't create file"),
                            error_codes::FAILED);
    }
    // A response which includes a non-zero offset indicates
    // that there is more data to read
    if (0 < response.second) {
      auto remains_bytes = response.second;
      size_t offset_parameter_idx = parameters.size() - 2;
      do {
        fwrite(response.first.c_str(), response.first.length(), 1, hFile);

        parameters[offset_parameter_idx] = std::make_pair(
            std::to_string(remains_bytes), constants::param_types::INT);
        response = connection_->call(rpc_name, parameters).as<response_type>();
        remains_bytes = response.second;
        if (0 > response.second) {
          fclose(hFile);
          remove(tmp_path.c_str());
          return std::make_pair(std::string(), error_codes::FAILED);
        }
      } while (remains_bytes > 0);
    }

    fwrite(response.first.c_str(), response.first.length(), 1, hFile);
    fclose(hFile);

    LOG_INFO("{0}:\nExit with SUCCESS\nReceived data from path: {1}", __func__,
             tmp_path);
    return std::make_pair(tmp_path, error_codes::SUCCESS);
  }

  LOG_ERROR("No connection");
  return std::make_pair(std::string(), error_codes::NO_CONNECTION);
}

response_type
RemoteClient::content_call(const std::string &rpc_name,
                           const std::vector<parameter_type> &parameters) {
  LOG_INFO("{0}: of: {1} with {2} parameters", __func__, rpc_name,
           parameters.size());

  if (connected()) {
    response_type response =
        connection_->call(rpc_name, parameters).as<response_type>();
    LOG_INFO("{0}: Exit with {1}", __func__, response.second);
    return response;
  }

  LOG_ERROR("No connection");
  return std::make_pair(std::string(), constants::error_codes::NO_CONNECTION);
}

} // namespace lua_lib
