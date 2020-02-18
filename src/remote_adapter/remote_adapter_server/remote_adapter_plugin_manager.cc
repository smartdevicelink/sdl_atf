#include "remote_adapter_plugin_manager.h"
#include <boost/filesystem.hpp>
#include <boost/range/iterator_range.hpp>
#include <dlfcn.h>
#include <iostream>
#include <vector>

namespace remote_adapter {

RemoteAdapterPluginManager::RemoteAdapterPluginManager() {}

RemoteAdapterPluginManager::RemoteAdapterPluginManager(
    const std::string &plugins_path) {
  LoadPlugins(plugins_path);
}

template <typename T>
T GetFuncFromLib(void *dl_handle, const std::string &function_name) {
  T exported_func =
      reinterpret_cast<T>(dlsym(dl_handle, function_name.c_str()));
  char *error_string = dlerror();
  if (nullptr != error_string) {
    LOG_ERROR("{0}: Failed to export symbols : {1}", __func__, error_string);
    return nullptr;
  }
  return exported_func;
}

adapter_plugin_ptr RemoteAdapterPluginManager::LoadPlugin(
    const std::string &full_plugin_path) const {
  if (!IsLibraryFile(full_plugin_path)) {
    LOG_INFO("{0}: Skip loading : {1}", __func__, full_plugin_path);
    return adapter_plugin_ptr(nullptr, [](UtilsPlugin *) {});
  }

  void *plugin_handle = dlopen(full_plugin_path.c_str(), RTLD_LAZY);
  if (nullptr == plugin_handle) {
    LOG_ERROR("{0}: dlerror() : {1}", __func__, dlerror());
    LOG_ERROR("{0}: Failed to open lib : {1}", __func__, full_plugin_path);
    return adapter_plugin_ptr(nullptr, [](UtilsPlugin *) {});
  }

  typedef adapter_plugin_ptr (*fn_create_plugin)();
  fn_create_plugin create_plugin =
      GetFuncFromLib<fn_create_plugin>(plugin_handle, "create_plugin");
  if (!create_plugin) {
    LOG_INFO("{0}: No Create function in : {1}", __func__, full_plugin_path);
    dlclose(plugin_handle);
    return adapter_plugin_ptr(nullptr, [](UtilsPlugin *) {});
  }

  typedef void (*fn_delete_plugin)(UtilsPlugin *);
  fn_delete_plugin delete_plugin =
      GetFuncFromLib<fn_delete_plugin>(plugin_handle, "delete_plugin");
  if (!delete_plugin) {
    LOG_INFO("{0}: No Delete function in : {1}", __func__, full_plugin_path);
    dlclose(plugin_handle);
    return adapter_plugin_ptr(nullptr, [](UtilsPlugin *) {});
  }

  auto plugin_destroyer = [delete_plugin, plugin_handle](UtilsPlugin *plugin) {
    LOG_INFO("{0}: Delete Plugin: {1}", __func__, plugin->PluginName());
    delete_plugin(plugin);
    dlclose(plugin_handle);
  };

  return adapter_plugin_ptr(create_plugin().release(), plugin_destroyer);
}

uint32_t
RemoteAdapterPluginManager::LoadPlugins(const std::string &plugins_path) {
  LOG_INFO("{0}: Loading plugins from: {1}", __func__, plugins_path);
  auto list_files = [](const std::string &directory_name) {
    namespace fs = boost::filesystem;
    fs::directory_iterator dir_iter(directory_name);
    std::vector<std::string> listFiles;
    if (!fs::is_directory(directory_name)) {
      return listFiles;
    }
    for (auto &dirent : dir_iter) {
      listFiles.push_back(dirent.path().filename().string());
    }
    return listFiles;
  };

  std::vector<std::string> plugin_files = list_files(plugins_path);
  for (auto &plugin_file : plugin_files) {
    std::string full_name = plugins_path + '/' + plugin_file;
    auto plugin = LoadPlugin(full_name);
    if (!plugin) {
      continue;
    }
    LOG_INFO("{0}: Loaded: {1} plugin from: {2}", __func__,
             plugin->PluginName(), full_name);
    loaded_plugins_.push_back(std::move(plugin));
  }

  return loaded_plugins_.size();
}

bool RemoteAdapterPluginManager::IsLibraryFile(const std::string &file_path) {
  size_t pos = file_path.find_last_of(".");
  if (std::string::npos == pos) {
    return false;
  }
  if (file_path.substr(pos + 1).compare("so") != 0) {
    return false;
  }
  return true;
}

void RemoteAdapterPluginManager::ForEachPlugin(
    std::function<void(UtilsPlugin &)> functor) {
  for (auto &plugin : loaded_plugins_) {
    functor(*plugin);
  }
}
} // namespace remote_adapter
