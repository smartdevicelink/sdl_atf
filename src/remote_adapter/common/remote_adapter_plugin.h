#pragma once
#include "rpc/server.h"
#include <functional>
#include <memory>

namespace remote_adapter {

template <typename T>
using plugin_ptr = std::unique_ptr<T, std::function<void(T *)>>;

class UtilsPlugin;
typedef plugin_ptr<UtilsPlugin> adapter_plugin_ptr;

class UtilsPlugin {
public:
  UtilsPlugin() {}
  virtual ~UtilsPlugin() {}
  virtual void Bind(rpc::server &server) = 0;
  virtual std::string PluginName() = 0;

private:
  UtilsPlugin(const UtilsPlugin &) = delete;
  UtilsPlugin(UtilsPlugin &&) = delete;
  UtilsPlugin &operator=(const UtilsPlugin &) = delete;
  UtilsPlugin &operator=(UtilsPlugin &&) = delete;
};
} // namespace remote_adapter
