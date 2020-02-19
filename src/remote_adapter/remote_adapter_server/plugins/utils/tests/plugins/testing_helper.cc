#include <csignal>
#include <future>
#include <iostream>
#include <string.h>

void sig_term_handler(int signum, siginfo_t *info, void *ptr) { exit(signum); }

void catch_sigterm() {
  static struct sigaction _sigact;

  memset(&_sigact, 0, sizeof(_sigact));
  _sigact.sa_sigaction = sig_term_handler;
  _sigact.sa_flags = SA_SIGINFO;

  sigaction(SIGTERM, &_sigact, NULL);
}

void empty_thread() {
  std::this_thread::sleep_for(std::chrono::milliseconds(500));
}

int main(int argc, char *argv[]) {
  catch_sigterm();

  auto accept = std::async(std::launch::async, empty_thread);
  accept.wait();
  // for check test status CRASHED
  std::this_thread::sleep_for(std::chrono::milliseconds(500));

  return 0;
}
