#include <iostream>
#include <string>
#include <exception>

#ifdef __QNX__
#include <backtrace.h>
#endif

#include "rpc/server.h"
#include "rpc/this_handler.h"

#include "message_broker.h"
#include "utils_manager.h"
#include "common/constants.h"

using utils_wrappers::UtilsManager;

void PrintUsage() {
  std::cout << "\nUsage:" << std::endl;
  std::cout << "------------------------------------------------" << std::endl;
  std::cout << "For default port usage(port 5555): " << std::endl;
  std::cout << "./RemoteTestingAdapterServer" << std::endl;
  std::cout << "------------------------------------------------" << std::endl;
  std::cout << "For custom port usage: " << std::endl;
  std::cout << "./RemoteTestingAdapterServer <port>" << std::endl;
  std::cout << "------------------------------------------------\n"
            << std::endl;
  std::cout << "NOTE: Port must be unsigned integer within 1024 - 65535\n";
}

bool IsUnsignedNumber(const std::string& number) {
  // Checking for negative numbers
  if ('-' == number[0] && isdigit(number[1])) {
    std::cout << "\nNumber is negative!" << std::endl;
    return false;
  }
  // Check that every symbol is a number
  for (const char& c : number) {
    if (!isdigit(c))
      return false;
  }
  return true;
}

void CheckError(const int res) {
  if (constants::error_codes::SUCCESS == res) {
    return;
  }
  std::string stringified_error;
  switch (res) {
    case constants::error_codes::PATH_NOT_FOUND:
      stringified_error = "Connection not found";
      break;
    case constants::error_codes::READ_FAILURE:
      stringified_error = "Reading failure";
      break;
    case constants::error_codes::WRITE_FAILURE:
      stringified_error = "Writing failure";
      break;
    case constants::error_codes::CLOSE_FAILURE:
      stringified_error = "Closing failure";
      break;
    case constants::error_codes::ALREADY_EXISTS:
      stringified_error = "Channel already exists";
      break;
    default:
      stringified_error = strerror(res);
      break;
  }
  const auto err_obj = std::make_pair(res, stringified_error);
  rpc::this_handler().respond_error(err_obj);
}

#ifdef __QNX__
void print_stack_trace(int pid){

  char out[1024];
  bt_addr_t pc[16];
  bt_accessor_t acc;
  bt_memmap_t memmap;

  memset(&memmap,0,sizeof(bt_memmap_t));
  bt_init_accessor(&acc, BT_SELF);
  bt_load_memmap(&acc, &memmap);
  bt_sprn_memmap(&memmap, out, sizeof(out));

  int cnt = bt_get_backtrace(&acc, pc, sizeof(pc)/sizeof(bt_addr_t));
  bt_sprnf_addrs(&memmap, pc, cnt, "%a\n", out, sizeof(out), 0);
  puts(out);
  
  bt_unload_memmap(&memmap);
  bt_release_accessor(&acc);
}

void segfault_sigaction(int sign, siginfo_t *si, void *arg){ 
    print_stack_trace(si->si_pid);
    //** for continue generate core dumped *
    signal(sign, SIG_DFL);
    kill(si->si_pid, sign);
    //**************************************
}
#endif

int main(int argc, char* argv[]) {

  UtilsManager::StopApp("SmartDeviceLink");

#ifdef __QNX__
  struct sigaction sa;
  memset(&sa, 0, sizeof(struct sigaction));
  sigemptyset(&sa.sa_mask);  
  sa.sa_sigaction = segfault_sigaction;
  sa.sa_flags   = SA_SIGINFO;
  sigaction(SIGSEGV, &sa, NULL);
#endif

  uint16_t port = 5555;
  if (2 == argc) {
    const std::string number = argv[1];
    if (IsUnsignedNumber(number)) {
      const uint16_t arg_port = std::atoi(number.c_str());
      port = 0 != arg_port ? arg_port : port;
    } else {
      PrintUsage();
      return 1;
    }
  }

  if (argc > 2) {
    PrintUsage();
    return 1;
  }
  std::cout << "Listen on " << port << std::endl;
  try {

    UtilsManager::ExecuteCommand("fuser -k " + (std::to_string(port) + "/tcp"));

    rpc::server srv(port);

    msg_wrappers::MessageBroker<> message_broker;

    srv.bind(constants::client_connected,
             []() {
               std::cout << "Client connected" << std::endl;
             });

     srv.bind(constants::open,
             [&message_broker](std::string address,
                               const int port) {
               const int res = message_broker.OpenConnection(
                   address,port);
               CheckError(res);
             });

    srv.bind(constants::close,
             [&message_broker](std::string address,
                               const int port) {
               const int res = message_broker.CloseConnection(
                   address,port);
               CheckError(res);
             });

    srv.bind(constants::send,
             [&message_broker](std::string address,
                               const int port,
                               std::string data) {
               const auto receive_result = message_broker.Send(
                   address,port,data);
               return receive_result;
             });

    srv.bind(constants::receive,
             [&message_broker](std::string address,
                               const int port) {
                const auto receive_result = message_broker.Receive(
                    address,port);
               return receive_result;
             });

    srv.bind(constants::app_start,
             [](std::string app_path,std::string app_name){
               const int res = UtilsManager::StartApp(
                                                  app_path,
                                                  app_name);
               return res;
             });

    srv.bind(constants::app_stop,
             [](std::string app_name){
               const int res = UtilsManager::StopApp(app_name);
               return res;
             });

    srv.bind(constants::app_check_status,
             [](std::string app_name){
               const int res = UtilsManager::CheckStatusApp(app_name);
               return res;
             });

    srv.bind(constants::file_backup,
             [](std::string file_path,std::string file_name){
               const int res = UtilsManager::FileBackup(
                                                  file_path,
                                                  file_name);
               return res;
             });

     srv.bind(constants::file_restore,
             [](std::string file_path,std::string file_name){
               const int res = UtilsManager::FileRestore(
                                                file_path,
                                                file_name);
               return res;
             });

    srv.bind(constants::file_update,
             [](std::string file_path,
                std::string file_name,
                std::string file_content){

                  const int res = UtilsManager::FileUpdate(
                                                    file_path,
                                                    file_name,
                                                    file_content);
                  return res;
             });

    srv.bind(constants::file_exists,
             [](std::string file_path,std::string file_name){
               const int res = UtilsManager::FileExists(
                                                    file_path,
                                                    file_name);
               return res;
             });

    srv.bind(constants::file_delete,
             [](std::string file_path,std::string file_name){
               const int res = UtilsManager::FileDelete(
                                                    file_path,
                                                    file_name);
               return res;
             });

    srv.bind(constants::file_content,
             [](std::string file_path,
                std::string file_name,
                size_t offset,
                size_t max_size_content){

                  std::string file_content =
                           UtilsManager::GetFileContent(
                                          file_path,
                                          file_name,
                                          offset,
                                          max_size_content
                                          );

                  return std::make_pair(
                                  file_content,
                                  offset
                                  );
             });

    srv.bind(constants::folder_exists,
             [](std::string folder_path){
               const int res = UtilsManager::FolderExists(
                                                    folder_path);
               return res;
             });





    srv.bind(constants::folder_delete,
             [](std::string folder_path){
               const int res = UtilsManager::FolderDelete(
                                                    folder_path);
               return res ?
                constants::error_codes::FAILED
                :
                constants::error_codes::SUCCESS;
             });

    srv.bind(constants::folder_create,
             [](std::string folder_path){
               const int res =
                  UtilsManager::FolderCreate(folder_path);
               return res;
             });

    srv.bind(constants::command_execute,
             [](std::string bash_command){

                auto receive_result =
                            UtilsManager::ExecuteCommand(bash_command);

                return receive_result;

             });


    srv.suppress_exceptions(true);
    // Run the server loop with 1 worker threads.
    srv.async_run();
    std::cin.ignore();
  } catch (std::exception& e) {
    std::cout << "Error: " << e.what() << std::endl;
    std::cout << "Exception occured" << std::endl;
    PrintUsage();
  }

  return 0;
}
