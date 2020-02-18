#pragma once
#include "common/remote_adapter_plugin.h"
#include <string>

namespace remote_adapter {

class RemoteAdapterPluginManager {
  typedef void *dl_handle;
  typedef std::vector<adapter_plugin_ptr> plugins_ptr;

public:
  RemoteAdapterPluginManager();
  RemoteAdapterPluginManager(const std::string &plugins_path);
  adapter_plugin_ptr LoadPlugin(const std::string &full_plugin_path) const;
  uint32_t LoadPlugins(const std::string &plugins_path);
  void ForEachPlugin(std::function<void(UtilsPlugin &)> functor);
  static bool IsLibraryFile(const std::string &file_path);

private:
  plugins_ptr loaded_plugins_;

  RPCLIB_CREATE_LOG_CHANNEL(RemoteAdapterPluginManager)
};
} // namespace remote_adapter
