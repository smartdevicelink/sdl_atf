#include <exception>
#include <iostream>
#include <string>
#include <unistd.h>

#ifdef __QNX__
#include <backtrace.h>
#endif

#include "rpc/server.h"
#include "rpc/this_handler.h"

#include "common/constants.h"
#include "common/custom_types.h"
#include "remote_adapter_plugin_manager.h"

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

bool IsUnsignedNumber(const std::string &number) {
  // Checking for negative numbers
  if ('-' == number[0] && isdigit(number[1])) {
    std::cout << "\nNumber is negative!" << std::endl;
    return false;
  }
  // Check that every symbol is a number
  for (const char &c : number) {
    if (!isdigit(c))
      return false;
  }
  return true;
}

#ifdef __QNX__
void print_stack_trace(int pid) {

  char out[1024];
  bt_addr_t pc[16];
  bt_accessor_t acc;
  bt_memmap_t memmap;

  memset(&memmap, 0, sizeof(bt_memmap_t));
  bt_init_accessor(&acc, BT_SELF);
  bt_load_memmap(&acc, &memmap);
  bt_sprn_memmap(&memmap, out, sizeof(out));

  int cnt = bt_get_backtrace(&acc, pc, sizeof(pc) / sizeof(bt_addr_t));
  bt_sprnf_addrs(&memmap, pc, cnt, "%a\n", out, sizeof(out), 0);
  puts(out);

  bt_unload_memmap(&memmap);
  bt_release_accessor(&acc);
}

void segfault_sigaction(int sign, siginfo_t *si, void *arg) {
  print_stack_trace(si->si_pid);
  //** for continue generate core dumped *
  signal(sign, SIG_DFL);
  kill(si->si_pid, sign);
  //**************************************
}
#endif

void msleep(int millisec) {
  struct timespec req = {0};
  req.tv_sec = 0;
  req.tv_nsec = millisec * 1000000L;
  nanosleep(&req, (struct timespec *)NULL);
}

int main(int argc, char *argv[]) {

#ifdef __QNX__
  struct sigaction sa;
  memset(&sa, 0, sizeof(struct sigaction));
  sigemptyset(&sa.sa_mask);
  sa.sa_sigaction = segfault_sigaction;
  sa.sa_flags = SA_SIGINFO;
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

    char cwd[PATH_MAX] = {"./"};
    getcwd(cwd, sizeof(cwd));

    remote_adapter::RemoteAdapterPluginManager plugin_manager(cwd);

    rpc::server srv(port);

    srv.bind(constants::client_connected, []() {
      std::cout << "Client connected" << std::endl;
      return response_type(std::string(), constants::error_codes::SUCCESS);
    });

    plugin_manager.ForEachPlugin(
        [&srv](remote_adapter::UtilsPlugin &plugin) { plugin.Bind(srv); });

    srv.suppress_exceptions(true);
    // Run the server loop with 1 worker threads.
    srv.async_run();
    while (true) {
      msleep(10);
    }
  } catch (std::exception &e) {
    std::cout << "Error: " << e.what() << std::endl;
    std::cout << "Exception occured" << std::endl;
    PrintUsage();
  }
  return 0;
}
