#!/usr/bin/env bash

source tools/runners/common.sh

# Overwrite functions which are unavailable for remote configuration
dummy() { :; }

kill_sdl() {
  dummy
}

clean_sdl_folder() {
  dummy
}

copy_sdl_logs() {
  dummy
}

backup() {
  dummy
}

clean_backup() {
  dummy
}

restore() {
  dummy
}
