#!/usr/bin/env bash

ATF_PATH=$(cd "$(dirname "$0")" && pwd)
REPORT_FILE=Report.txt
REPORT_FILE_CONSOLE=Console.txt
DEBUG=false
LINE1=$(printf -- '=%.0s' {1..100})
LINE2=$(printf -- '-%.0s' {1..100})

JOBS=1
FORCE_PARALLELS=false
SAVE_SDL_LOG=yes
SAVE_SDL_CORE_DUMP=yes
COPY_TS=false

THIRD_PARTY="$THIRD_PARTY_INSTALL_PREFIX"
TMP_PATH=/tmp

# Color modifications
P="\033[0;32m" # GREEN
F="\033[0;31m" # RED
A="\033[0;35m" # MAGENTA
S="\033[0;33m" # YELLOW
B="\033[0;34m" # BLUE
N="\033[0m"    # NONE

dbg() {
  if [ $DEBUG = true ]; then echo "DEBUG: $@"; fi
}

log() {
  echo -e "$@";
}

timestamp() {
  echo $(date +%s)
}

seconds2time() {
  T=$1
  D=$((T/60/60/24))
  H=$((T/60/60%24))
  M=$((T/60%60))
  S=$((T%60))
  if [[ ${D} != 0 ]]
  then
     printf '%d days %02d:%02d:%02d' $D $H $M $S
  else
     printf '%02d:%02d:%02d' $H $M $S
  fi
}

remove_color() {
  sed -i "s/\x1b[^m]*m//g" $1
}

show_help() {
  echo "Bash .lua test Script Runner"
  echo
  echo "Usage: start.sh TEST [OPTION]..."
  echo
  echo "TEST - test target, could be one of the following:"
  echo "   - test script"
  echo "   - test set"
  echo "   - folder with test scripts"
  echo
  echo "[OPTION] - one or more options:"
  echo "   --sdl-core               - path to SDL binaries"
  echo "   --config                 - name of configuration"
  echo "   --sdl-api                - path to SDL APIs"
  echo "   --report                 - path to report and logs"
  echo "   --sdl-log [ACTION]       - how to collect SDL logs"
  echo "     'yes' - always save (default), 'no' - do not save, 'fail' - save if script failed or aborted"
  echo "   --sdl-core-dump [ACTION] - how to collect SDL core dumps"
  echo "     'yes' - always save (default), 'no' - do not save, 'fail' - save if script failed or aborted"
  echo "   --parallels              - force to use parallels mode"
  echo "     -j|--jobs n            - number of jobs to start ATF in parallels"
  echo "     --third-party          - path to SDL third party"
  echo "     --tmp                  - path to temporary folder used by parallels"
  echo "     --copy-atf-ts          - force copying of ATF test scripts instead of creating symlinks"
  echo
  echo "In case if folder is specified as a test target:"
  echo "   - only scripts which name starts with number will be taken into account (e.g. 001, 002 etc.)"
  echo "   - if there are sub-folders scripts will be run recursively"
  echo
  echo "Besides execution of .lua scripts Script Runner also does auxiliary actions:"
  echo "   - clean up SDL and ATF folders before running of each script"
  echo "   - backup and restore SDL important files"
  echo "   - create report with all required logs for each script"
  echo
  exit 0
}

get_param_from_atf_config() {
  for i in `sed s'/=/ /g' $1 | grep "$2 " | awk '{print $2}'`; do echo $i | sed 's/"//g'; done
}

parse_arguments() {
  dbg "Func" "parse_arguments" "Enter"
  if [ $# -eq 0 ]; then
    show_help
  fi

  local ARGS=("$@")
  local COUNTER=0
  local NAMELESS_COUNTER=0
  local NAMELESS_ARGS
  while [ $COUNTER -lt $# ]
  do
    local ARG=${ARGS[$COUNTER]}
    let COUNTER=COUNTER+1
    local NEXT_ARG=${ARGS[$COUNTER]}

    if [[ $SKIP_NEXT -eq 1 ]]; then
      SKIP_NEXT=0
      continue
    fi

    local ARG_KEY=""
    local ARG_VAL=""
    if [[ "$ARG" =~ ^\- ]]; then
      # if the format is: -key=value
      if [[ "$ARG" =~ \= ]]; then
        ARG_VAL=$(echo "$ARG" | cut -d'=' -f2)
        ARG_KEY=$(echo "$ARG" | cut -d'=' -f1)
        SKIP_NEXT=0
      # if the format is: -key value
      elif [[ ! "$NEXT_ARG" =~ ^\- ]]; then
        ARG_KEY="$ARG"
        ARG_VAL="$NEXT_ARG"
        SKIP_NEXT=1
      # if the format is: -key (a boolean flag)
      elif [[ "$NEXT_ARG" =~ ^\- ]] || [[ -z "$NEXT_ARG" ]]; then
        ARG_KEY="$ARG"
        ARG_VAL=""
        SKIP_NEXT=0
      fi
    # if the format has not flag, just a value
    else
      ARG_KEY=""
      ARG_VAL="$ARG"
      SKIP_NEXT=0
    fi

    case "$ARG_KEY" in
      --config)
        CONFIG="$ARG_VAL"
      ;;
      --sdl-core)
        SDL_CORE="$ARG_VAL"
      ;;
      --report)
        REPORT_PATH="$ARG_VAL"
      ;;
      --sdl-api)
        SDL_API="$ARG_VAL"
      ;;
      -j|--jobs)
        JOBS="$ARG_VAL"
      ;;
      --third-party)
        THIRD_PARTY="$ARG_VAL"
      ;;
      --parallels)
        FORCE_PARALLELS=true
      ;;
      --tmp)
        TMP_PATH="$ARG_VAL"
      ;;
      --sdl-log)
        SAVE_SDL_LOG="$ARG_VAL"
      ;;
      --sdl-core-dump)
        SAVE_SDL_CORE_DUMP="$ARG_VAL"
      ;;
      --copy-atf-ts)
        COPY_TS=true
      ;;
      -h|--help|-help|--h)
        show_help
      ;;
      --test-id)
        TEST_ID="$ARG_VAL"
      ;;
      -*|--*)
        echo "Unknown option '$ARG_KEY'"
        exit 1
      ;;
      *)
        let NAMELESS_COUNTER=NAMELESS_COUNTER+1
        NAMELESS_ARGS[NAMELESS_COUNTER]="$ARG_VAL"
      ;;
    esac
  done
  # handle nameless arguments
  if [ ${#NAMELESS_ARGS[*]} -gt 0 ]; then
    TEST_TARGET=${NAMELESS_ARGS[1]}
  fi
  dbg "Func" "parse_arguments" "Exit"
}

print_parameters() {
  dbg "= Parameters ($1):"
  dbg "TEST_TARGET: "$TEST_TARGET
  dbg "REPORT_PATH: "$REPORT_PATH
  dbg "SDL_PROCESS_NAME: "$SDL_PROCESS_NAME
  dbg "SDL_CORE: "$SDL_CORE
  dbg "SDL_API: "$SDL_API
  dbg "IS_REMOTE_ENABLED: "$IS_REMOTE_ENABLED
  dbg "SAVE_SDL_LOG: "$SAVE_SDL_LOG
  dbg "SAVE_SDL_CORE_DUMP: "$SAVE_SDL_CORE_DUMP
}

check_environment() {
  dbg "Func" "check_environment" "Enter"
  local dirs=("test_scripts" "test_sets" "files" "user_modules")
  for dir in ${dirs[@]}; do
    if [ ! -d "$dir" ]; then
      echo "Required folder '$dir' is not available"
      exit 1
    fi
  done
  dbg "Func" "check_environment" "Exit"
}

check_arguments() {
  dbg "Func" "check_arguments" "Enter"
  if [ -z $TEST_TARGET ]; then
    echo "Test target was not specified"
    exit 1
  fi
  if [ "${TEST_TARGET: -1}" = "/" ]; then
    TEST_TARGET="${TEST_TARGET:0:-1}"
  fi
  if [ -n $JOBS ] && [ -z "${JOBS##*[!0-9]*}" ]; then
    echo "Invalid number of jobs was specified within --jobs option"
    exit 1
  fi
  if [ ! -d ${ATF_PATH}/modules/configuration/${CONFIG} ]; then
    echo "Invalid configuration was specified within --config option"
    exit 1
  fi
  if ( [ $FORCE_PARALLELS = true ] || [ $JOBS -gt 1 ] ) && [ -z "$(docker images | grep 'atf_worker')" ]; then
    echo "Required docker image 'atf_worker' is not available"
    exit 1
  fi
  if [ -z $SAVE_SDL_LOG ]; then
    echo "ACTION was not specified within --sdl-log option"
    exit 1
  fi
  if [ -z $SAVE_SDL_CORE_DUMP ]; then
    echo "ACTION was not specified within --sdl-core-dump option"
    exit 1
  fi
  dbg "Func" "check_arguments" "Exit"
}

set_param() {
  local var=$1
  local param=$2
  local config=$3
  local value=$(get_param_from_atf_config ${config} ${param})
  if [ -z "${!var}" ] && [ -n "$value" ]; then declare -g -- "$var=$value"; fi
}

build_parameters() {
  dbg "Func" "build_parameters" "Enter"

  print_parameters "arguments"

  # load parameters from specific config
  if [ -n "$CONFIG" ]; then
    local CONFIG_PATH=${ATF_PATH}/modules/configuration/${CONFIG}
    set_param SDL_PROCESS_NAME "config.SDL" ${CONFIG_PATH}/base_config.lua
    set_param REPORT_PATH "config.reportPath" ${CONFIG_PATH}/base_config.lua
    set_param SDL_CORE "config.pathToSDL" ${CONFIG_PATH}/base_config.lua
    set_param SDL_API "config.pathToSDLInterfaces" ${CONFIG_PATH}/base_config.lua
    set_param IS_REMOTE_ENABLED "config.remoteConnection.enabled" ${CONFIG_PATH}/connection_config.lua
    print_parameters "specific config"
  fi

  # load parameters from base config
  local CONFIG_PATH=${ATF_PATH}/modules/configuration
  set_param SDL_PROCESS_NAME "config.SDL" ${CONFIG_PATH}/base_config.lua
  set_param REPORT_PATH "config.reportPath" ${CONFIG_PATH}/base_config.lua
  set_param SDL_CORE "config.pathToSDL" ${CONFIG_PATH}/base_config.lua
  set_param SDL_API "config.pathToSDLInterfaces" ${CONFIG_PATH}/base_config.lua
  set_param IS_REMOTE_ENABLED "config.remoteConnection.enabled" ${CONFIG_PATH}/connection_config.lua
  print_parameters "base config"

  dbg "TEST_ID: "$TEST_ID

  dbg "Func" "build_parameters" "Exit"
}

check_parameters() {
  dbg "Func" "check_parameters" "Enter"
  if [ -z $SDL_PROCESS_NAME ]; then
    echo "SDL process name was not specified"
    exit 1
  fi
  if [ -z $REPORT_PATH ]; then
    echo "Report path was not specified"
    exit 1
  fi
  if [ -z $SDL_CORE ]; then
    echo "Path to SDL binaries was not specified"
    exit 1
  fi
  if [ ! -d $SDL_API ]; then
    echo "Invalid path to APIs was specified"
    exit 1
  fi
  if [ ! -d $SDL_CORE ] && [ $IS_REMOTE_ENABLED = false ]; then
    echo "Invalid path to SDL binaries was specified"
    exit 1
  fi
  dbg "Func" "check_parameters" "Exit"
}

build_atf_options() {
  dbg "Func" "build_atf_options" "Enter"
  OPTIONS=""
  if [ -n "$CONFIG" ]; then OPTIONS="$OPTIONS --config=${CONFIG}"; fi
  if [ -n "$SDL_CORE" ]; then OPTIONS="$OPTIONS --sdl-core=${SDL_CORE}"; fi
  if [ -n "$REPORT_PATH" ]; then OPTIONS="$OPTIONS --report-path=${REPORT_PATH}"; fi
  if [ -n "$SDL_API" ]; then OPTIONS="$OPTIONS --sdl-interfaces=${SDL_API}"; fi
  if [ $IS_REMOTE_ENABLED = true ] && [ $SAVE_SDL_LOG = yes ]; then OPTIONS="$OPTIONS --storeFullSDLLogs"; fi

  dbg "= OPTIONS:"$OPTIONS
  dbg "Func" "build_atf_options" "Exit"
}

create_report_folder() {
  dbg "Func" "create_report_folder" "Enter"
  REPORT_PATH_TS=${REPORT_PATH}/$(date +"%Y-%m-%d_%H-%M-%S.%3N")
  mkdir -p ${REPORT_PATH_TS}
  mkdir -p /tmp/corefiles
  dbg "Func" "create_report_folder" "Exit"
}

load_runner() {
  dbg "Func" "load_runner" "Enter"
  if [ $IS_REMOTE_ENABLED = true ]; then
    dbg "= Mode: Remote"
    source tools/runners/remote.sh
  elif [ $JOBS -gt 1 ] || [ $FORCE_PARALLELS = true ]; then
    dbg "= Mode: Parallels"
    source tools/runners/parallels.sh
  else
    dbg "= Mode: Regular"
    source tools/runners/common.sh
  fi
  dbg "Func" "load_runner" "Exit"
}

check_environment

parse_arguments "$@"

check_arguments

build_parameters

check_parameters

build_atf_options

create_report_folder

load_runner

StartUp

Run

TearDown
