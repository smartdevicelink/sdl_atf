#!/usr/bin/env bash

ATF_PATH=.
REPORT_FILE=Report.txt
REPORT_FILE_CONSOLE=Console.txt
DEBUG=false
LINE="====================================================================================================="

# SDL files to back-up
SDL_BACK_UP=("sdl_preloaded_pt.json" "smartDeviceLink.ini" "hmi_capabilities.json" "log4cxx.properties")

# ATF and SDL files/folders to remove before each script run
ATF_CLEAN_UP=("sdl.pid" "mobile*.out")
SDL_CLEAN_UP=("*.log" "app_info.dat" "storage" "ivsu_cache" "../sdl_bin_bk")

# Color modifications
P="\033[0;32m" # GREEN
F="\033[0;31m" # RED
A="\033[0;35m" # MAGENTA
S="\033[0;33m" # YELLOW
N="\033[0m"    # NONE

trap ctrl_c INT

ctrl_c() {
  echo "Scripts processing is cancelled"
  kill_sdl
  copy_logs
  clean_atf_logs
  restore
  clean_backup
  status
  exit 1
}

dbg() { if [ $DEBUG = true ]; then echo "$@"; fi }

log() { echo -e $@; }

logf() { log "$@" | tee >(sed "s/\x1b[^m]*m//g" >> ${REPORT_PATH_TS}/${REPORT_FILE}); }

show_help() {
  echo "Bash .lua test Script Runner"
  echo "Besides execution of scripts it also does auxiliary actions:"
  echo "   - clean up SDL and ATF folders before running of each script"
  echo "   - backup and restore SDL important files"
  echo "   - create report with all required logs for each script"
  echo
  echo "Usage: start.sh SDL TEST [OPTION]..."
  echo
  echo "SDL  - path to SDL binaries"
  echo "TEST - test target, could be one of the following:"
  echo "   - test script"
  echo "   - test set"
  echo "   - folder with test scripts"
  echo "[OPTION] - options supported by ATF:"
  echo "   --sdl-interfaces   - path to SDL APIs"
  echo "   --report-path      - path to report and logs"
  echo
  echo "In case if folder is specified:"
  echo "   - only scripts which name starts with number will be taken into account (e.g. 001, 002 etc.)"
  echo "   - if there are sub-folders scripts will be run recursively"
  echo
  exit 0
}

get_param_from_atf_config() {
  for i in `sed s'/=/ /g' $1 | grep "$2 " | awk '{print $2}'`; do echo $i | sed 's/"//g'; done
}

set_default_params_from_atf_config() {
  local CONFIG_FILE=${ATF_PATH}/modules/config.lua
  REPORT_PATH=$(get_param_from_atf_config ${CONFIG_FILE} "config.reportPath")
  SDL_CORE=$(get_param_from_atf_config ${CONFIG_FILE} "config.pathToSDL")
  SDL_PROCESS_NAME=$(get_param_from_atf_config ${CONFIG_FILE} "config.SDL")
  dbg "Default arguments from ATF config:"
  dbg "  SDL_CORE: "$SDL_CORE
  dbg "  REPORT_PATH: "$REPORT_PATH
  dbg "  SDL_PROCESS_NAME: "$SDL_PROCESS_NAME
}

parse_arguments() {
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
      --sdl-core)
        SDL_CORE="$ARG_VAL"
      ;;
      --report-path)
        REPORT_PATH="$ARG_VAL"
      ;;
      -h|--help|-help|--h)
        show_help
      ;;
      -*)
        local DLM=""
        if [ -n "$ARG_VAL" ]; then DLM="="; fi
        if [ -n "${OPTIONS}" ]; then OPTIONS="${OPTIONS} "; fi
        OPTIONS="${OPTIONS}${ARG_KEY}${DLM}${ARG_VAL}"
      ;;
      *)
        let NAMELESS_COUNTER=NAMELESS_COUNTER+1
        NAMELESS_ARGS[NAMELESS_COUNTER]="$ARG_VAL"
      ;;
    esac
  done
  # handle nameless arguments
  if [ ${#NAMELESS_ARGS[*]} -eq 1 ]; then
    TEST_TARGET=${NAMELESS_ARGS[1]}
  elif [ ${#NAMELESS_ARGS[*]} -ge 2 ]; then
    SDL_CORE=${NAMELESS_ARGS[1]}
    TEST_TARGET=${NAMELESS_ARGS[2]}
  fi
}

check_arguments() {
  # check presence of mandatory arguments
  if [ -z $SDL_CORE ]; then
    echo "Path to SDL binaries was not specified"
    exit 1
  fi
  if [ -z $TEST_TARGET ]; then
    echo "Test target was not specified"
    exit 1
  fi
  # check if defined path exists
  if [ ! -d $SDL_CORE ]; then
    echo "SDL core binaries was not found by defined path"
    exit 1
  fi
  if [ ! -d $TEST_TARGET ] && [ ! -f $TEST_TARGET ]; then
    echo "Test target was not found by defined path"
    exit 1
  fi
  # add '/' to the end of the path if it missing
  if [ "${SDL_CORE: -1}" = "/" ]; then
    SDL_CORE="${SDL_CORE:0:-1}"
  fi
  if [ "${TEST_TARGET: -1}" = "/" ]; then
    TEST_TARGET="${TEST_TARGET:0:-1}"
  fi
  dbg "Updated arguments:"
  dbg "  SDL_CORE: "$SDL_CORE
  dbg "  TEST_TARGET: "$TEST_TARGET
  dbg "  REPORT_PATH: "$REPORT_PATH
  dbg "  OPTIONS: "$OPTIONS
}

backup() {
  log "Back-up SDL files"
  for FILE in ${SDL_BACK_UP[*]}; do cp -n ${SDL_CORE}/${FILE} ${SDL_CORE}/_${FILE}; done
}

restore() {
  log "Restoring SDL files from back-up"
  for FILE in ${SDL_BACK_UP[*]}; do cp -f ${SDL_CORE}/_${FILE} ${SDL_CORE}/${FILE}; done
}

clean_backup() {
  log "Cleaning up back-up SDL files"
  for FILE in ${SDL_BACK_UP[*]}; do rm -f ${SDL_CORE}/_${FILE}; done
  log ${LINE}
}

await() {
  local PID=$1
  local TIMEOUT=$2
  local TIME_LEFT=0
  while true
  do
    if ! ps -p $PID > /dev/null; then
      return 0
    fi
    if [ $TIME_LEFT -lt $TIMEOUT ]; then
      let TIME_LEFT=TIME_LEFT+1
      sleep 1
    else
      echo "Timeout ($TIMEOUT sec) expired. Force killing: ${PID} ..."
      kill -s SIGKILL ${PID}
      sleep 0.5
      return 0
    fi
  done
}

kill_sdl() {
  local PIDS=$(ps -ao user:20,pid,command | grep -e "^$(whoami).*$SDL_PROCESS_NAME" | grep -v grep | awk '{print $2}')
  for PID in $PIDS
  do
    local PID_INFO=$(pstree -sg $PID | head -n 1 | grep -vE "docker|containerd")
    if [ ! -z "$PID_INFO" ]; then
      log "'$SDL_PROCESS_NAME' is running, PID: $PID, terminating ..."
      kill -s SIGTERM $PID
      await $PID 5
      log "Done"
    fi
  done
}

create_report_folder() {
  TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
  REPORT_PATH_TS=${REPORT_PATH}/${TIMESTAMP}
  mkdir -p ${REPORT_PATH_TS}
}

copy_logs() {
  local REPORT_DIR_PTRNS=("SDLLogs*" "ATFLogs*" "XMLReports*")
  for PTRN in ${REPORT_DIR_PTRNS[@]}; do
    for DIR in $(find ${REPORT_PATH} -name "$PTRN"); do
      for FILE in $(find $DIR -type f); do
        cp $FILE ${REPORT_PATH_TS_SCRIPT}/
      done
    done
  done
}

clean_atf_logs() {
  local REPORT_DIR_PTRNS=("SDLLogs*" "ATFLogs*" "XMLReports*")
  for DIR in ${REPORT_DIR_PTRNS[@]}; do
    rm -rf ${REPORT_PATH}/$DIR
  done
}

clean() {
  log "Cleaning up ATF folder"
  for FILE in ${ATF_CLEAN_UP[*]}; do rm -rf ${ATF_PATH}/${FILE}; done
  log "Cleaning up SDL folder"
  for FILE in ${SDL_CLEAN_UP[*]}; do rm -rf ${SDL_CORE}/${FILE}; done
}

run() {
  local SCRIPT=$1
  local NUM_OF_SCRIPTS=$2
  local ISSUE=$3

  log ${LINE}

  let ID=ID+1

  log "Processing script: ${ID}(${NUM_OF_SCRIPTS}) ["\
    "${P}PASSED: ${#LIST_PASSED[@]}, "\
    "${F}FAILED: ${#LIST_FAILED[@]}, "\
    "${A}ABORTED: ${#LIST_ABORTED[@]}, "\
    "${S}SKIPPED: ${#LIST_SKIPPED[@]}"\
    "${N}]"

  kill_sdl

  clean

  clean_atf_logs

  restore

  local ID_SFX=$(printf "%0${#NUM_OF_SCRIPTS}d" $ID)

  REPORT_PATH_TS_SCRIPT=${REPORT_PATH_TS}/${ID_SFX}
  mkdir ${REPORT_PATH_TS_SCRIPT}

  local OPTIONS="--sdl-core=${SDL_CORE} --report-path=${REPORT_PATH} $OPTIONS"
  dbg "OPTIONS: "$OPTIONS

  ./bin/interp modules/launch.lua \
    $SCRIPT \
    $OPTIONS \
    | tee >(sed "s/\x1b[^m]*m//g" > ${REPORT_PATH_TS_SCRIPT}/${REPORT_FILE_CONSOLE})

  local RESULT_CODE=${PIPESTATUS[0]}
  local RESULT_STATUS="NOT_DEFINED"

  case "${RESULT_CODE}" in
    0)
      RESULT_STATUS="PASSED"
      LIST_PASSED[ID]="$ID_SFX|$SCRIPT|$ISSUE"
    ;;
    1)
      RESULT_STATUS="ABORTED"
      LIST_ABORTED[ID]="$ID_SFX|$SCRIPT|$ISSUE"
    ;;
    2)
      RESULT_STATUS="FAILED"
      LIST_FAILED[ID]="$ID_SFX|$SCRIPT|$ISSUE"
    ;;
    4)
      RESULT_STATUS="SKIPPED"
      LIST_SKIPPED[ID]="$ID_SFX|$SCRIPT|$ISSUE"
    ;;
  esac

  log "SCRIPT STATUS: " ${RESULT_STATUS}

  kill_sdl

  copy_logs

  clean_atf_logs

  log
}

process() {
  ID=0
  local EXT=${TEST_TARGET: -3}
  if [ $EXT = "txt" ]; then
    while read -r ROW; do
      if [ ${ROW:0:1} = ";" ]; then continue; fi
      local script=$(echo $ROW | awk '{print $1}')
      local issue=$(echo $ROW | awk '{print $2}')
      local total_num_of_scripts=$(cat $TEST_TARGET | egrep -v -c '^;')
      run $script $total_num_of_scripts $issue
    done < "$TEST_TARGET"
  elif [ $EXT = "lua" ]; then
    run $TEST_TARGET 1
  else
    local LIST=($(find $TEST_TARGET -iname "[0-9]*.lua" | sort))
    for ROW in ${LIST[@]}; do
      run $ROW ${#LIST[@]}
    done
  fi
  log ${LINE}
}

status() {
  logf "TOTAL: " $ID
  logf "${P}PASSED: " ${#LIST_PASSED[@]} "${N}"
  # for i in ${LIST_PASSED[@]}; do logf "${i//|/ }"; done
  logf "${F}FAILED: " ${#LIST_FAILED[@]} "${N}"
  for i in ${LIST_FAILED[@]}; do logf "${i//|/ }"; done
  logf "${A}ABORTED: " ${#LIST_ABORTED[@]} "${N}"
  for i in ${LIST_ABORTED[@]}; do logf "${i//|/ }"; done
  logf "${S}SKIPPED: " ${#LIST_SKIPPED[@]} "${N}"
  for i in ${LIST_SKIPPED[@]}; do logf "${i//|/ }"; done
  logf ${LINE}
  log
}

log_test_run_details() {
  logf ${LINE}
  logf "SDL: " $SDL_CORE
  logf "Test target: " $TEST_TARGET
  logf ${LINE}
}

set_default_params_from_atf_config

parse_arguments "$@"

check_arguments

create_report_folder

log_test_run_details

backup

process

restore

clean_backup

status
