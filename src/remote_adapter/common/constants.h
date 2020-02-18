#pragma once

#include <string>

namespace constants {
static std::string client_connected = "client_connected";
static std::string app_start = "app_start";
static std::string app_stop = "app_stop";
static std::string app_check_status = "app_check_status";
static std::string file_backup = "file_backup";
static std::string file_restore = "file_restore";
static std::string file_update = "file_update";
static std::string file_exists = "file_exists";
static std::string file_content = "file_content";
static std::string file_delete = "file_delete";
static std::string folder_exists = "folder_exists";
static std::string folder_create = "folder_create";
static std::string folder_delete = "folder_delete";
static std::string command_execute = "command_execute";
static std::string open_handle = "open";
static std::string close_handle = "close";
static std::string send = "send";
static std::string receive = "receive";

static const size_t kMaxSizeData = 1048576; // 1MB
static const std::string kTmpPath = "/tmp/";

namespace stat_app_codes {
static const int CRASHED = -1;
static const int NOT_RUNNING = 0;
static const int RUNNING = 1;
} // namespace stat_app_codes

namespace param_types {
enum type { NIL = 0, INT, DOUBLE, BOOLEAN, STRING };
}

namespace error_codes {
static const int SUCCESS = 0;
static const int FAILED = -1;
static const int READ_FAILURE = -2;
static const int WRITE_FAILURE = -3;
static const int PATH_NOT_FOUND = -4;
static const int CLOSE_FAILURE = -5;
static const int OPEN_FAILURE = -6;
static const int NO_CONNECTION = -7;
static const int EXCEPTION_THROWN = -8;
static const int TIMEOUT_EXPIRED = -9;
static const int ALREADY_EXISTS = -10;
} // namespace error_codes

namespace error_msg {
static const char *const kIncorrNumberParams = "Incorrect number of parameters";
static const char *const kBadTypeValue = "Bad type of the value";
} // namespace error_msg
} // namespace constants
