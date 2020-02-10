#pragma once

#include "remote_adapter_plugin.h"
#include <signal.h>
#include <string>
#include <sys/procfs.h>
#include <vector>

namespace utils_wrappers {

#ifndef __QNX__
typedef int procfs_info;
#endif

class UtilsManager : public remote_adapter::UtilsPlugin {
public:
  void Bind(rpc::server &server) override;
  std::string PluginName() override;

  /*
   * @brief Run of application
   *
   * @param app_path full path to the application folder
   * @param app_name app name
   * @return code from error_codes namespace, SUCCESS or FAILED
   */
  static int StartApp(const std::string &app_path, const std::string &app_name);
  /*
   * @brief Stop of application
   *
   * @param app_name app name
   * @return code from error_codes namespace, SUCCESS or FAILED
   */
  static int StopApp(const std::string &app_name, const int sig = SIGTERM);
  /*
   * @brief Check application status
   *
   * @param app_name app name
   * @return code from stat_app_codes namespace, NOT_RUNNING,RUNNING or CRASHED
   */
  static int CheckAppStatus(const std::string &app_name);
  /*
   * @brief Create backup of given file
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @return code from error_codes namespace, SUCCESS or FAILED
   */
  static int FileBackup(const std::string &file_path,
                        const std::string &file_name);
  /*
   * @brief Restore backup of given file
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @return code from error_codes namespace, SUCCESS or FAILED
   */
  static int FileRestore(const std::string &file_path,
                         const std::string &file_name);
  /*
   * @brief Update file contents
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @param file_content file contents
   * @return code from error_codes namespace, SUCCESS or FAILED
   */
  static int FileUpdate(const std::string &file_path,
                        const std::string &file_name,
                        const std::string &file_content);
  /*
   * @brief Check file availability
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @return code from error_codes namespace,  SUCCESS - if file exist,
   * otherwise FAILED
   */
  static int FileExists(const std::string &file_path,
                        const std::string &file_name);
  /*
   * @brief File deletion
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @return code from error_codes namespace, SUCCESS if successful, otherwise
   * FAILED
   */
  static int FileDelete(const std::string &file_path,
                        const std::string &file_name);
  /*
   * @brief Get file contents
   *
   * @param file_path full path to the file folder
   * @param file_name file name
   * @param offset  number of bytes from beginning of file,
   *        this parameter is modified during function call
   *        it contains file offset for next function call
   *        if the end of the file is not reached
   *        or error code SUCCESS if it is reached
   * @param max_size_content maximum size in bytes to be read at one time
   * @return file contents, set FAILED code from error_codes namespace to
   * offset, in case of failure
   */
  static std::string GetFileContent(const std::string &file_path,
                                    const std::string &file_name,
                                    long int &offset,
                                    const size_t max_size_content = 0);
  /*
   * @brief Check folder availability
   *
   * @param folder_path full path to the folder
   * @return code from error_codes namespace,  SUCCESS - if
   * folder exist, otherwise FAILED
   */
  static int FolderExists(const std::string &folder_path);
  /*
   * @brief Folder deletion
   *
   * @param folder_path full path to the folder
   * @return code from error_codes namespace, SUCCESS if
   * successful, otherwise FAILED
   */
  static int FolderDelete(const std::string &folder_path);
  /*
   * @brief Folder creation
   *
   * @param folder_path full path to the folder
   * @return code from error_codes namespace, SUCCESS if
   * successful, otherwise FAILED
   */
  static int FolderCreate(const std::string &folder_path);

  /*
   * @brief Run the bash command
   *
   * @param bash_command bash command
   * @return pair
   *         first - command outputcode
   *         second - code from error_codes namespace
   * SUCCESS if successful, otherwise FAILED
   */
  static std::pair<std::string, int>
  ExecuteCommand(const std::string &bash_command);

private:
  static std::vector<int> GetAppPids(const std::string &app_name);
  static std::string GetAppStatus(int pid, int *num_threads = 0);
  static int KillApp(const pid_t app_pid, const int sig,
                     const char *app_name = 0);
  static bool AppExists(const pid_t app_pid);
  static std::string JoinPath(const std::string &path,
                              const std::string &part_path);
};

} // namespace utils_wrappers
