#include <fstream>

#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "../../utils_manager.h"
#include "constants.h"
#include "custom_types.h"
#include "rpc/client.h"
#include "rpc/server.h"

namespace error_codes = constants::error_codes;
namespace error_msg = constants::error_msg;
using namespace constants;

#define LIBRARY_API extern "C"
LIBRARY_API remote_adapter::adapter_plugin_ptr create_plugin();

static constexpr uint16_t kRpcTestPort = rpc::constants::DEFAULT_PORT;
static constexpr const char *kTestAddress = "127.0.0.1";
static constexpr const char *kAppHelper = "helper";
static constexpr const char *kBackupSuffix = "_origin";

class UtilsManager_Test : public testing::Test {
public:
  UtilsManager_Test() : server_(kTestAddress, kRpcTestPort) {
    utils_manager_ = create_plugin();
    utils_manager_->Bind(server_);
    server_.async_run();
  }

  ~UtilsManager_Test() {
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }

  bool GetPathProperties(std::string *app_path, std::string *app_name);
  response_type StartApp(const std::string &app_path,
                         const std::string &app_name);
  response_type StopApp(const std::string &app_name);
  response_type CheckAppStatus(const std::string &app_name);
  response_type FileBackup(const std::string &file_path,
                           const std::string &file_name);
  response_type FileRestore(const std::string &file_path,
                            const std::string &file_name);
  response_type FileUpdate(const std::string &file_path,
                           const std::string &file_name,
                           const std::string &file_content);
  response_type FileExists(const std::string &file_path,
                           const std::string &file_name);
  response_type FileDelete(const std::string &file_path,
                           const std::string &file_name);
  response_type GetFileContent(const std::string &file_path,
                               const std::string &file_name,
                               const long int &offset,
                               const size_t max_size_content = 0);
  response_type FolderExists(const std::string &folder_path);
  response_type FolderDelete(const std::string &folder_path);
  response_type FolderCreate(const std::string &folder_path);
  response_type ExecuteCommand(const std::string &bash_command);

  rpc::server server_;
  remote_adapter::adapter_plugin_ptr utils_manager_;
};

bool UtilsManager_Test::GetPathProperties(std::string *app_path,
                                          std::string *app_name) {
  char path[PATH_MAX] = {0};
  // This file "/proc/self/exe" contain full path to the executable
  // of the current process
  ssize_t len = readlink("/proc/self/exe", path, PATH_MAX);
  if (-1 == len) {
    return false;
  }
  // Find last backslash and skip
  char *name = strrchr(path, '/');
  if (name) {
    ++name;
    path[name - path - 1] = '\0';
  } else {
    return false;
  }

  if (app_path) {
    *app_path = std::string(path, name - path - 1);
  }

  if (app_name) {
    *app_name = std::string(name, strrchr(name, '_') - name + 1);
    *app_name += kAppHelper;
  }
  LOG_INFO("{0} app_path: {1} app_name: {2}", __func__,
           app_path ? *app_path : "", app_name ? *app_name : "");
  return true;
}

response_type UtilsManager_Test::StartApp(const std::string &app_path,
                                          const std::string &app_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(app_path, param_types::STRING),
      parameter_type(app_name, param_types::STRING)};

  auto app_start = client.async_call(constants::app_start, parameters);

  app_start.wait();

  return app_start.get().as<response_type>();
}

response_type UtilsManager_Test::StopApp(const std::string &app_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(app_name, param_types::STRING)};

  auto app_stop = client.async_call(constants::app_stop, parameters);

  app_stop.wait();

  return app_stop.get().as<response_type>();
}

response_type UtilsManager_Test::CheckAppStatus(const std::string &app_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(app_name, param_types::STRING)};

  auto app_status = client.async_call(constants::app_check_status, parameters);

  app_status.wait();

  return app_status.get().as<response_type>();
}

response_type UtilsManager_Test::FileBackup(const std::string &file_path,
                                            const std::string &file_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING)};

  auto file_backup = client.async_call(constants::file_backup, parameters);

  file_backup.wait();

  return file_backup.get().as<response_type>();
}

response_type UtilsManager_Test::FileRestore(const std::string &file_path,
                                             const std::string &file_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING)};

  auto file_restore = client.async_call(constants::file_restore, parameters);

  file_restore.wait();

  return file_restore.get().as<response_type>();
}

response_type UtilsManager_Test::FileUpdate(const std::string &file_path,
                                            const std::string &file_name,
                                            const std::string &file_content) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING),
      parameter_type(file_content, param_types::STRING)};

  auto file_update = client.async_call(constants::file_update, parameters);

  file_update.wait();

  return file_update.get().as<response_type>();
}
response_type UtilsManager_Test::FileExists(const std::string &file_path,
                                            const std::string &file_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING)};

  auto file_exists = client.async_call(constants::file_exists, parameters);

  file_exists.wait();

  return file_exists.get().as<response_type>();
}
response_type UtilsManager_Test::FileDelete(const std::string &file_path,
                                            const std::string &file_name) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING)};

  auto file_delete = client.async_call(constants::file_delete, parameters);

  file_delete.wait();

  return file_delete.get().as<response_type>();
}

response_type UtilsManager_Test::GetFileContent(const std::string &file_path,
                                                const std::string &file_name,
                                                const long int &offset,
                                                const size_t max_size_content) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(file_path, param_types::STRING),
      parameter_type(file_name, param_types::STRING),
      parameter_type(std::to_string(offset), param_types::INT),
      parameter_type(std::to_string(max_size_content), param_types::INT)};

  auto file_content = client.async_call(constants::file_content, parameters);

  file_content.wait();

  return file_content.get().as<response_type>();
}

response_type UtilsManager_Test::FolderExists(const std::string &folder_path) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(folder_path, param_types::STRING)};

  auto folder_exists = client.async_call(constants::folder_exists, parameters);

  folder_exists.wait();

  return folder_exists.get().as<response_type>();
}
response_type UtilsManager_Test::FolderDelete(const std::string &folder_path) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(folder_path, param_types::STRING)};

  auto folder_delete = client.async_call(constants::folder_delete, parameters);

  folder_delete.wait();

  return folder_delete.get().as<response_type>();
}
response_type UtilsManager_Test::FolderCreate(const std::string &folder_path) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(folder_path, param_types::STRING)};

  auto folder_create = client.async_call(constants::folder_create, parameters);

  folder_create.wait();

  return folder_create.get().as<response_type>();
}
response_type
UtilsManager_Test::ExecuteCommand(const std::string &bash_command) {
  rpc::client client(kTestAddress, kRpcTestPort);

  std::vector<parameter_type> parameters = {
      parameter_type(bash_command, param_types::STRING)};

  auto command_execute =
      client.async_call(constants::command_execute, parameters);

  command_execute.wait();

  return command_execute.get().as<response_type>();
}

TEST_F(UtilsManager_Test, CreatePlugin_Expect_TRUE) {
  auto utils_manager = create_plugin();
  EXPECT_TRUE(utils_manager);
}

TEST_F(UtilsManager_Test, DeletePlugin_Expect_TRUE) {
  auto utils_manager = create_plugin();
  utils_manager.reset();
  EXPECT_TRUE(!utils_manager);
}

TEST_F(UtilsManager_Test, Check_TypeId_Expect_EQ) {
  using namespace utils_wrappers;
  using namespace remote_adapter;
  UtilsPlugin *utils_manager_1 = new UtilsManager();
  auto utils_manager_2 = create_plugin();
  EXPECT_EQ(typeid(utils_manager_1), typeid(utils_manager_2.get()));
  delete utils_manager_1;
}

TEST_F(UtilsManager_Test, StartApp_Expect_SUCCES) {
  std::string app_path, app_name;
  const bool res = GetPathProperties(&app_path, &app_name);
  EXPECT_TRUE(res);

  auto response = StartApp(app_path, app_name);

  StopApp(app_name);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(UtilsManager_Test, StartApp_Expect_FAILED) {
  std::string file_path;
  const bool res = GetPathProperties(&file_path, nullptr);
  EXPECT_TRUE(res);

  auto response = StartApp(file_path, "fake_app");

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(UtilsManager_Test, StopApp_Expect_SUCCES) {
  std::string app_path, app_name;
  const bool res = GetPathProperties(&app_path, &app_name);
  EXPECT_TRUE(res);

  StartApp(app_path, app_name);

  auto response = StopApp(app_name);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(UtilsManager_Test, CheckAppStatus_Expect_NOT_RUNNING) {
  std::string app_name;
  const bool res = GetPathProperties(nullptr, &app_name);
  EXPECT_TRUE(res);

  auto response = CheckAppStatus(app_name);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(std::to_string(stat_app_codes::NOT_RUNNING), response.first);
}

TEST_F(UtilsManager_Test, CheckAppStatus_Expect_RUNNING) {
  std::string app_path, app_name;
  const bool res = GetPathProperties(&app_path, &app_name);
  EXPECT_TRUE(res);

  StartApp(app_path, app_name);

  auto response = CheckAppStatus(app_name);

  StopApp(app_name);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(std::to_string(stat_app_codes::RUNNING), response.first);
}

TEST_F(UtilsManager_Test, CheckAppStatus_Expect_CRASHED) {
  std::string app_path, app_name;
  const bool res = GetPathProperties(&app_path, &app_name);
  EXPECT_TRUE(res);

  StartApp(app_path, app_name);

  std::this_thread::sleep_for(std::chrono::milliseconds(600));

  auto response = CheckAppStatus(app_name);

  StopApp(app_name);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(std::to_string(stat_app_codes::CRASHED), response.first);
}

TEST_F(UtilsManager_Test, FileBackup_Expect_SUCCESS) {
  std::string file_path;
  const bool res = GetPathProperties(&file_path, nullptr);
  EXPECT_TRUE(res);

  FileUpdate(file_path, kAppHelper, kAppHelper);

  auto response = FileBackup(file_path, kAppHelper);

  FileDelete(file_path, kAppHelper);

  struct stat stat_buff;
  EXPECT_EQ(0, stat((file_path + "/" + kAppHelper + kBackupSuffix).c_str(),
                    &stat_buff));

  auto file_content =
      GetFileContent(file_path, std::string(kAppHelper) + kBackupSuffix, 0);

  FileDelete(file_path, std::string(kAppHelper) + kBackupSuffix);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(file_content.first, kAppHelper);
}

TEST_F(UtilsManager_Test, FileRestore_Expect_SUCCESS) {
  std::string file_path;
  const bool res = GetPathProperties(&file_path, nullptr);
  EXPECT_TRUE(res);

  FileUpdate(file_path, kAppHelper, kAppHelper);
  FileBackup(file_path, kAppHelper);
  FileDelete(file_path, kAppHelper);

  auto response = FileRestore(file_path, kAppHelper);

  struct stat stat_buff;
  EXPECT_EQ(0, stat((file_path + "/" + kAppHelper).c_str(), &stat_buff));

  auto file_content = GetFileContent(file_path, kAppHelper, 0);

  FileDelete(file_path, kAppHelper);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
  EXPECT_EQ(file_content.first, kAppHelper);
}

TEST_F(UtilsManager_Test, FolderExists_Expect_FAILED) {
  auto response = FolderExists("missing_folder");

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(UtilsManager_Test, FolderExists_Expect_SUCCESS) {
  std::string folder_path;
  const bool res = GetPathProperties(&folder_path, nullptr);
  EXPECT_TRUE(res);

  auto response = FolderExists(folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(UtilsManager_Test, FolderDelete_Expect_FAILED) {
  auto response = FolderDelete("missing_folder");

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(UtilsManager_Test, FolderDelete_Expect_SUCCESS) {
  std::string folder_path;
  const bool res = GetPathProperties(&folder_path, nullptr);
  EXPECT_TRUE(res);

  folder_path.append("/Test_ForderDelete");

  FolderCreate(folder_path);

  auto response = FolderDelete(folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(UtilsManager_Test, FolderCreate_Expect_FAILED) {
  std::string folder_path;
  const bool res = GetPathProperties(&folder_path, nullptr);
  EXPECT_TRUE(res);

  auto response = FolderCreate(folder_path);

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}

TEST_F(UtilsManager_Test, FolderCreate_Expect_SUCCESS) {
  std::string folder_path;
  const bool res = GetPathProperties(&folder_path, nullptr);
  EXPECT_TRUE(res);

  folder_path.append("/Test_ForderCreate");

  auto response = FolderCreate(folder_path);

  FolderDelete(folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);
}

TEST_F(UtilsManager_Test, ExecuteCommand_Expect_SUCCESS) {
  std::string folder_path;
  const bool res = GetPathProperties(&folder_path, nullptr);
  EXPECT_TRUE(res);

  folder_path.append("/Test_ExecuteCommand");

  auto response = FolderCreate(folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);

  response = FolderExists(folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);

  response = ExecuteCommand("rm -rf " + folder_path);

  EXPECT_EQ(constants::error_codes::SUCCESS, response.second);

  response = FolderExists(folder_path);

  EXPECT_EQ(constants::error_codes::FAILED, response.second);
}
