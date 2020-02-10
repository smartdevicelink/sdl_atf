#include "utils_manager.h"
#ifdef __QNX__
#include <sys/debug.h>
#include <sys/syspage.h>
#else
#include <libgen.h>
#endif
#include <boost/lexical_cast.hpp>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fstream>
#include <spawn.h>
#include <stdexcept>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../../common/constants.h"
#include "../../common/custom_types.h"
#include "rpc/detail/log.h"

#ifndef __QNX__
extern char **environ; // need for posix_spawn
#endif

namespace utils_wrappers {

const char *const kBackupSuffix = "_origin";

using namespace constants;

RPCLIB_CREATE_LOG_CHANNEL(UtilsManager)

//-----Monitor of the running applications until they
// terminates-----------------------------
static void *thread_monitor_app(void *pid) {
  if (!pid) {
    return 0;
  }

  pid_t app_pid = *(static_cast<pid_t *>(pid));
  delete static_cast<pid_t *>(pid);

  int status = 0;

  do {

    if (0 > waitpid(app_pid, &status, WUNTRACED | WCONTINUED)) {
      break;
    }

    if (WIFEXITED(status)) {
      LOG_INFO("app_id:{0} exited, status:{1}=%d\n", app_pid,
               WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
      LOG_INFO("app_id:{0} killed by signal:{1}", app_pid, WTERMSIG(status));
    } else if (WIFSTOPPED(status)) {
      LOG_INFO("app_id:{0} stopped by signal:{1}", app_pid, WSTOPSIG(status));
    } else if (WIFCONTINUED(status)) {
      LOG_INFO("app_id:{0} continued", app_pid);
    }

  } while (!WIFEXITED(status) && !WIFSIGNALED(status));

  return 0;
}
//------------------------------------------------------------------------------
template <const constants::param_types::type nType, typename ParameterType,
          typename Type>
bool GetValue(ParameterType &parameter, Type &value) {

  if (nType != parameter.second) {
    return false;
  }

  try {
    value = boost::lexical_cast<Type>(parameter.first);
  } catch (const boost::bad_lexical_cast &e) {
    LOG_ERROR("{0}: {1}", __func__, e.what());
    return false;
  }

  return true;
}

template <typename... Args> bool IsAllValid(Args &&... args) {
  auto all_value = {std::forward<Args>(args)...};
  for (const auto &value : all_value) {
    if (!value) {
      return false;
    }
  }
  return true;
}
//------------------------------------------------------------------------------
void UtilsManager::Bind(rpc::server &server) {

  server.bind(
      constants::app_start, [](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string app_path, app_name;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], app_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], app_name);

        if (false == IsAllValid(is_path, is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::StartApp(app_path, app_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::app_stop, [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string app_name;
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[0], app_name);

        if (false == IsAllValid(is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::StopApp(app_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::app_check_status,
      [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string app_name;
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[0], app_name);

        if (false == IsAllValid(is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::CheckAppStatus(app_name);
        return response_type(std::to_string(res), error_codes::SUCCESS);
      });

  server.bind(
      constants::file_backup,
      [](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);

        if (false == IsAllValid(is_path, is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FileBackup(file_path, file_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::file_restore,
      [](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);

        if (false == IsAllValid(is_path, is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FileRestore(file_path, file_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::file_update,
      [](const std::vector<parameter_type> &parameters) {
        if (3 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name, file_content;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);
        bool is_content = GetValue<constants::param_types::STRING>(
            parameters[2], file_content);

        if (false == IsAllValid(is_path, is_name, is_content)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }

        const int res =
            UtilsManager::FileUpdate(file_path, file_name, file_content);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::file_exists,
      [](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);

        if (false == IsAllValid(is_path, is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FileExists(file_path, file_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::file_delete,
      [](const std::vector<parameter_type> &parameters) {
        if (2 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);

        if (false == IsAllValid(is_path, is_name)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FileDelete(file_path, file_name);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::file_content,
      [](const std::vector<parameter_type> &parameters) {
        if (4 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string file_path, file_name;
        long int offset;
        size_t max_size_content;
        bool is_path =
            GetValue<constants::param_types::STRING>(parameters[0], file_path);
        bool is_name =
            GetValue<constants::param_types::STRING>(parameters[1], file_name);
        bool is_offset =
            GetValue<constants::param_types::INT>(parameters[2], offset);
        bool is_size = GetValue<constants::param_types::INT>(parameters[3],
                                                             max_size_content);

        if (false == IsAllValid(is_path, is_name, is_offset, is_size)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        std::string file_content = UtilsManager::GetFileContent(
            file_path, file_name, offset, max_size_content);

        return response_type(file_content, offset);
      });

  server.bind(
      constants::folder_exists,
      [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string folder_path;
        bool is_path = GetValue<constants::param_types::STRING>(parameters[0],
                                                                folder_path);

        if (false == IsAllValid(is_path)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FolderExists(folder_path);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::folder_delete,
      [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string folder_path;
        bool is_path = GetValue<constants::param_types::STRING>(parameters[0],
                                                                folder_path);

        if (false == IsAllValid(is_path)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FolderDelete(folder_path);
        return response_type(std::string(),
                             res ? constants::error_codes::FAILED
                                 : constants::error_codes::SUCCESS);
      });

  server.bind(
      constants::folder_create,
      [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string folder_path;
        bool is_path = GetValue<constants::param_types::STRING>(parameters[0],
                                                                folder_path);

        if (false == IsAllValid(is_path)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        const int res = UtilsManager::FolderCreate(folder_path);
        return response_type(std::string(), res);
      });

  server.bind(
      constants::command_execute,
      [](const std::vector<parameter_type> &parameters) {
        if (1 != parameters.size()) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kIncorrNumberParams);
          return response_type(error_msg::kIncorrNumberParams,
                               error_codes::FAILED);
        }

        std::string bash_command;
        bool is_command = GetValue<constants::param_types::STRING>(
            parameters[0], bash_command);

        if (false == IsAllValid(is_command)) {
          LOG_ERROR("{0}: {1}", __func__, error_msg::kBadTypeValue);
          return response_type(error_msg::kBadTypeValue, error_codes::FAILED);
        }
        auto receive_result = UtilsManager::ExecuteCommand(bash_command);

        return receive_result;
      });
}
std::string UtilsManager::PluginName() { return "RemoteUtilsManager"; }
int UtilsManager::StartApp(const std::string &app_path,
                           const std::string &app_name) {
  LOG_INFO("{0}: {1}", __func__, app_name);

  char cwd[PATH_MAX] = {0};
  getcwd(cwd, sizeof(cwd));
  chdir(app_path.c_str());

  char *const argv[] = {strdup(app_name.c_str()), NULL};

  pid_t app_pid = error_codes::FAILED;
  posix_spawn(&app_pid, argv[0], NULL, NULL, argv, environ);

  chdir(cwd);
  free(argv[0]);

  if (error_codes::FAILED != app_pid) {
    if (0 == kill(app_pid, 0)) {
      pthread_t thread_id;
      pid_t *app_pid_ptr = new pid_t(app_pid);
      int result =
          pthread_create(&thread_id, 0, &thread_monitor_app, app_pid_ptr);
      if (0 != result) {
        delete app_pid_ptr;
      }

      return constants::error_codes::SUCCESS;
    }
  }

  LOG_ERROR("{}", strerror(errno));
  return error_codes::FAILED;
}

int UtilsManager::StopApp(const std::string &app_name, const int sig) {
  LOG_INFO("{0}: {1}", __func__, app_name);

  auto pid_list = GetAppPids(app_name);
  bool is_all_killed = true;

  for (const auto &app_pid : pid_list) {
    if (error_codes::FAILED == KillApp(app_pid, sig, app_name.c_str())) {
      is_all_killed = false;
    }
  }

  if (is_all_killed) {
    return error_codes::SUCCESS;
  }

  is_all_killed = true;
  for (const auto &app_pid : pid_list) {
    if (AppExists(app_pid)) {
      if (error_codes::FAILED == KillApp(app_pid, SIGKILL, app_name.c_str())) {
        is_all_killed = false;
      }
    }
  }

  return is_all_killed ? error_codes::SUCCESS : error_codes::FAILED;
}

int UtilsManager::CheckAppStatus(const std::string &app_name) {
  LOG_INFO("{}", __func__);
  auto pid_list = GetAppPids(app_name);
  if (0 == pid_list.size()) {
    LOG_INFO("{} is NOT_RUNNING", app_name);
    return stat_app_codes::NOT_RUNNING;
  }

  int num_threads = 0;
  int pid_num_threads = 0;

  for (const auto &app_pid : pid_list) {
    GetAppStatus(app_pid, &pid_num_threads);
    num_threads += pid_num_threads;
  }

  LOG_INFO("{0} has: {1} thread", app_name, num_threads);
  if (num_threads > 1) {
    LOG_INFO("{0} is RUNNING\n", app_name);
    return stat_app_codes::RUNNING;
  }
  LOG_INFO("{} is CRASHED\n", app_name);
  return stat_app_codes::CRASHED;
}

int UtilsManager::FileBackup(const std::string &file_path,
                             const std::string &file_name) {
  LOG_INFO("{}", __func__);
  std::string file_dest_path =
      JoinPath(file_path, file_name).append(kBackupSuffix);

  std::ifstream src(JoinPath(file_path, file_name).c_str(), std::ios::binary);
  std::ofstream dest(file_dest_path.c_str(), std::ios::binary);
  dest << src.rdbuf();

  return src && dest ? error_codes::SUCCESS : error_codes::FAILED;
}

int UtilsManager::FileRestore(const std::string &file_path,
                              const std::string &file_name) {
  LOG_INFO("{}", __func__);
  std::string file_src_path =
      JoinPath(file_path, file_name).append(kBackupSuffix);

  std::ifstream src(file_src_path.c_str(), std::ios::binary);
  std::ofstream dest(JoinPath(file_path, file_name).c_str(), std::ios::binary);
  dest << src.rdbuf();

  FileDelete(file_path, std::string(file_name).append(kBackupSuffix));

  return src && dest ? error_codes::SUCCESS : error_codes::FAILED;
}

int UtilsManager::FileUpdate(const std::string &file_path,
                             const std::string &file_name,
                             const std::string &file_content) {
  LOG_INFO("{}", __func__);
  std::ofstream ofs(JoinPath(file_path, file_name).c_str(),
                    std::ofstream::binary);
  ofs << file_content.c_str();
  return ofs ? error_codes::SUCCESS : error_codes::FAILED;
}

int UtilsManager::FileExists(const std::string &file_path,
                             const std::string &file_name) {
  LOG_INFO("{}", __func__);
  struct stat stat_buff;
  return 0 == (stat(JoinPath(file_path, file_name).c_str(), &stat_buff))
             ? error_codes::SUCCESS
             : error_codes::FAILED;
}

int UtilsManager::FileDelete(const std::string &file_path,
                             const std::string &file_name) {
  LOG_INFO("{}", __func__);
  if (remove(JoinPath(file_path, file_name).c_str()) != 0) {
    return error_codes::FAILED;
  }
  return error_codes::SUCCESS;
}

std::string UtilsManager::GetFileContent(const std::string &file_path,
                                         const std::string &file_name,
                                         long int &offset,
                                         const size_t max_size_content) {
  LOG_INFO("{}", __func__);
  FILE *file = fopen(JoinPath(file_path, file_name).c_str(), "rb");
  if (!file) {
    LOG_ERROR("Unable to open file: {}", JoinPath(file_path, file_name));
    offset = error_codes::FAILED;
    return std::string();
  }

  fseek(file, 0, SEEK_END);
  unsigned long file_len = ftell(file) - offset;
  fseek(file, offset, SEEK_SET);
  LOG_INFO("File offset: {0} rest size of the file: {1}", offset, file_len);
  if (max_size_content) {
    file_len = max_size_content > file_len ? file_len : max_size_content;
  }

  char *buffer = (char *)malloc(file_len);
  if (!buffer) {
    LOG_TRACE("Memory error!");
    fclose(file);
    offset = error_codes::FAILED;
    return std::string();
  }

  fread(buffer, file_len, 1, file);
  fseek(file, 0, SEEK_END);

  size_t read = file_len;
  file_len = ftell(file);
  fclose(file);

  offset = (read + offset) == file_len ? error_codes::SUCCESS : read + offset;

  std::string file_content(buffer, read);

  LOG_INFO("New file offset: {}", offset);
  free(buffer);
  return file_content;
}

int UtilsManager::FolderExists(const std::string &folder_path) {
  LOG_INFO("{}", __func__);
  struct stat stat_buff;
  return 0 == (stat(folder_path.c_str(), &stat_buff)) ? error_codes::SUCCESS
                                                      : error_codes::FAILED;
}

int UtilsManager::FolderDelete(const std::string &folder_path) {
  LOG_INFO("{}", __func__);
  DIR *dir = opendir(folder_path.c_str());
  size_t path_len = folder_path.length();
  int res = -1;

  if (dir) {
    struct dirent *ent_dir;
    res = 0;

    while (!res && (ent_dir = readdir(dir))) {
      char *buf;
      size_t len;

      if (!strcmp(ent_dir->d_name, ".") || !strcmp(ent_dir->d_name, "..")) {
        continue;
      }

      res = -1;
      len = path_len + strlen(ent_dir->d_name) + 2;
      buf = static_cast<char *>(malloc(len));

      if (buf) {
        struct stat statbuf;
        snprintf(buf, len, "%s/%s", folder_path.c_str(), ent_dir->d_name);

        if (!stat(buf, &statbuf)) {
          if (S_ISDIR(statbuf.st_mode)) {
            res = FolderDelete(buf);
          } else {
            res = unlink(buf);
          }
        }

        free(buf);
      }
    }
    closedir(dir);
  }

  if (!res) {
    res = rmdir(folder_path.c_str());
  }

  return res;
}

int UtilsManager::FolderCreate(const std::string &folder_path) {
  LOG_INFO("{}", __func__);
  const int dir_err =
      mkdir(folder_path.c_str(), S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
  if (-1 == dir_err) {
    printf("\nError creating directory: %s", folder_path.c_str());
    return error_codes::FAILED;
  }
  return error_codes::SUCCESS;
}

std::pair<std::string, int>
UtilsManager::ExecuteCommand(const std::string &bash_command) {
  LOG_INFO("{0}: {1}", __func__, bash_command);
  std::string command_output;
  char buffer[128] = {0};
  FILE *pipe = popen(bash_command.c_str(), "r");
  if (!pipe) {
    return std::make_pair(command_output, error_codes::FAILED);
  }

  try {

    while (!feof(pipe)) {
      if (fgets(buffer, 128, pipe) != NULL) {
        command_output += buffer;
      }
    }

  } catch (...) {
    pclose(pipe);
    command_output.clear();
    return std::make_pair(command_output, error_codes::FAILED);
  }

  int term_status = pclose(pipe);
  term_status =
      (-1 != term_status) ? WEXITSTATUS(term_status) : error_codes::FAILED;

  term_status = (0 == term_status) ? error_codes::SUCCESS : error_codes::FAILED;

  return std::make_pair(command_output, term_status);
}

std::vector<int> UtilsManager::GetAppPids(const std::string &app_name) {

  struct dirent *dirent;
  DIR *dir;
  int app_pid;

  if (!(dir = opendir("/proc"))) {
    fprintf(stderr, "\ncouldn't open /proc, errno %d\n", errno);
    perror(NULL);
    return std::vector<int>();
  }

  std::vector<int> pid_list;

  while (dirent = readdir(dir)) {
    if (isdigit(*dirent->d_name)) {
      app_pid = atoi(dirent->d_name);
      if (0 == app_name.compare(GetAppStatus(app_pid))) {
        pid_list.push_back(app_pid);
      }
    }
  }

  closedir(dir);

  return pid_list;
}

std::string UtilsManager::GetAppStatus(int app_pid, int *num_threads) {

  char paths[PATH_MAX];
#ifdef __QNX__
  int fd;
  static struct {
    procfs_debuginfo info;
    char buff[BUFSIZ];
  } name;

  sprintf(paths, "/proc/%d/as", app_pid);

  if ((fd = open(paths, O_RDONLY)) == -1) {
    return "";
  }

  if (devctl(fd, DCMD_PROC_MAPDEBUG_BASE, &name, sizeof(name), 0) != EOK) {
    if (app_pid == 1) {
      strcpy(name.info.path, "/(procnto)");
    } else {
      strcpy(name.info.path, "/(n/a)");
    }
  }

  if (num_threads) {
    procfs_info proc_info;
    int sts = devctl(fd, DCMD_PROC_INFO, &proc_info, sizeof(procfs_info), NULL);
    if (sts != EOK) {
      *num_threads = 0;
      fprintf(stderr, "\n%s: DCMD_PROC_INFO pid %d errno %d (%s)",
              strrchr(name.info.path, '/') + 1, app_pid, errno,
              strerror(errno));
    } else {
      *num_threads = proc_info.num_threads;
    }
  }

  close(fd);

  if (char *app_name = strrchr(name.info.path, '/')) {
    return std::string(app_name + 1);
  }

  return std::string(name.info.path);

#else

  if (num_threads) {
    *num_threads = 0;

    struct dirent *dirent;
    DIR *dir;

    // The number of entries in /proc/pid/task
    // is the number of threads in the process
    sprintf(paths, "/proc/%d/task", app_pid);

    if (dir = opendir(paths)) {
      while (dirent = readdir(dir)) {
        if (isdigit(*dirent->d_name)) {
          // Count the number of threads for the application
          ++(*num_threads);
        }
      }
      closedir(dir);
    }
  }

  // This file(/proc/pid/cmdline) contains command line arguments.
  // The first is the name of the application.
  sprintf(paths, "/proc/%d/cmdline", app_pid);
  if (FILE *file = fopen(paths, "r")) {
    size_t size = fread(paths, sizeof(char), sizeof(paths), file);
    fclose(file);
    if (size > 0) {
      if ('\n' == paths[size - 1]) {
        paths[size - 1] = '\0';
      }
      // Find last backslash
      if (char *app_name = strrchr(paths, '/')) {
        // Get name of application and skipping backslash
        return std::string(app_name + 1);
      }
      return std::string(paths);
    }
  }
  return "";
#endif
}

int UtilsManager::KillApp(const pid_t app_pid, const int sig,
                          const char *app_name) {

  errno = 0;
  if (0 == kill(app_pid, sig)) {
    LOG_INFO("Succes kill pid: {0} app: {1}\n", app_pid,
             app_name ? app_name : "");
    return constants::error_codes::SUCCESS;
  }

  if (false == AppExists(app_pid)) {
    LOG_INFO("Succes kill pid: {0} app: {1}\n", app_pid,
             app_name ? app_name : "");
    return constants::error_codes::SUCCESS;
  }

  switch (errno) {
  case EAGAIN:
    LOG_ERROR("Failed kill pid: {0} app: {1} "
              "Insufficient system resources are"
              "available to deliver the signal.",
              app_pid, app_name ? app_name : "");
    break;
  case EINVAL:
    LOG_ERROR("Failed kill pid: {0} app: {1} "
              "The sig is invalid.",
              app_pid, app_name ? app_name : "");
    break;
  case EPERM:
    LOG_ERROR("Failed kill pid: {0} app: {1} "
              "The process doesn't have permission to"
              "send this signal to any receiving process.",
              app_pid, app_name ? app_name : "");
    break;
  case ESRCH:
    LOG_ERROR("Failed kill pid: {0} app: {1} "
              "The given pid doesn't exist.\n",
              app_pid, app_name ? app_name : "");
    break;
  default:
    LOG_ERROR("Failed kill pid: {0} app: {1} "
              "Unknown error in errno\n",
              app_pid, app_name ? app_name : "");
  }

  return constants::error_codes::FAILED;
}

bool UtilsManager::AppExists(const pid_t app_pid) {

  struct stat stat_buff;
  char proc_path[PATH_MAX];

  sprintf(proc_path, "/proc/%d", app_pid);

  return 0 == (stat(proc_path, &stat_buff));
}

std::string UtilsManager::JoinPath(const std::string &path,
                                   const std::string &part_path) {

  std::string full_path = path;

  if ('/' != full_path[full_path.length() - 1]) {
    full_path += '/';
  }

  return full_path.append(part_path);
}

#define LIBRARY_API extern "C"

LIBRARY_API void delete_plugin(remote_adapter::UtilsPlugin *plugin) {
  delete plugin;
}

LIBRARY_API remote_adapter::adapter_plugin_ptr create_plugin() {
  return remote_adapter::adapter_plugin_ptr(new UtilsManager(), delete_plugin);
};

} // namespace utils_wrappers
