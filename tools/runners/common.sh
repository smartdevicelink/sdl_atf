#!/usr/bin/env bash

# SDL files to back-up
SDL_BACK_UP=("sdl_preloaded_pt.json" "smartDeviceLink.ini" "hmi_capabilities.json" "log4cxx.properties")

# ATF and SDL files/folders to remove before each script run
ATF_CLEAN_UP=("sdl.pid" "mobile*.out")
SDL_CLEAN_UP=("*.log" "app_info.dat" "storage" "ivsu_cache" "../sdl_bin_bk")

logf() { log "$@" | tee -a ${REPORT_PATH_TS}/${REPORT_FILE}; }

status() {
  logf ${LINE1}
  logf "Test target:" $TEST_TARGET
  logf ${LINE2}
  for i in ${LIST_TOTAL[@]}; do logf "${i}"; done
  logf ${LINE2}
  logf "TOTAL:" $ID
  logf "${P}PASSED:" ${#LIST_PASSED[@]} "${N}"
  logf "${F}FAILED:" ${#LIST_FAILED[@]} "${N}"
  logf "${A}ABORTED:" ${#LIST_ABORTED[@]} "${N}"
  logf "${S}SKIPPED:" ${#LIST_SKIPPED[@]} "${N}"
  logf ${LINE2}
  logf "Execution time:" $(seconds2time $(($ts_finish - $ts_start)))
  logf ${LINE1}
  log
  remove_color ${REPORT_PATH_TS}/${REPORT_FILE}
}

process() {
  ID=0
  local EXT=${TEST_TARGET: -3}
  if [ $EXT = "txt" ]; then
    local ROWS=$(sed -E '/^;($|[^.])/d' $TEST_TARGET)
    local total_num_of_scripts=$(echo "$ROWS" | wc -l | awk '{print $1}')
    while read -r ROW; do
      local script=$(echo $ROW | awk '{print $1}')
      local issue=$(echo $ROW | awk '{print $2}')
      run $script $total_num_of_scripts $issue
    done <<< "$ROWS"
  elif [ $EXT = "lua" ]; then
    run $TEST_TARGET 1
  else
    local LIST=($(find $TEST_TARGET -iname "[0-9]*.lua" | sort))
    for ROW in ${LIST[@]}; do
      run $ROW ${#LIST[@]}
    done
  fi
}

run_atf() {
  local SCRIPT=$1
  local NUM_OF_SCRIPTS=$2
  local ISSUE=$3

  local ID_SFX=$(printf "%0${#NUM_OF_SCRIPTS}d" $ID)
  if [ -n "$TEST_ID" ]; then ID_SFX=$TEST_ID; fi

  REPORT_PATH_TS_SCRIPT=${REPORT_PATH_TS}/${ID_SFX}
  mkdir ${REPORT_PATH_TS_SCRIPT}

  local RESULT_CODE=4
  local RESULT_STATUS="NOT_DEFINED"

  if [ ${SCRIPT:0:1} != ";" ]; then

    # Link file descriptors: #6 - stdout, #7 - stderr
    exec 6>&1 7>&2
    # Redirect all output to console and file
    exec > >(tee -a -i ${REPORT_PATH_TS_SCRIPT}/${REPORT_FILE_CONSOLE})
    # Redirect stderr to stdout
    exec 2>&1
    sleep .1
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./lib
    ./ATF modules/launch.lua $SCRIPT $OPTIONS

    RESULT_CODE=$?

    # Restore stdout, stderr and close file descriptors #6 and #7
    exec 1>&6 6>&- 2>&7 7>&-

  fi

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

  local total="$ID_SFX:\t$RESULT_STATUS\t$SCRIPT"
  if [ -n $ISSUE ]; then total="${total}\t$ISSUE"; fi
  LIST_TOTAL[ID]="${total}"

  log "SCRIPT STATUS:" ${RESULT_STATUS}
}

run() {
  local SCRIPT=$1
  local NUM_OF_SCRIPTS=$2
  local ISSUE=$3

  log ${LINE1}

  let ID=ID+1

  log "Processing script: ${ID}/${NUM_OF_SCRIPTS} ["\
    "${P}PASSED: ${#LIST_PASSED[@]}, "\
    "${F}FAILED: ${#LIST_FAILED[@]}, "\
    "${A}ABORTED: ${#LIST_ABORTED[@]}, "\
    "${S}SKIPPED: ${#LIST_SKIPPED[@]}"\
    "${N}]"

  kill_sdl

  clean_atf_folder

  clean_sdl_folder

  clean_atf_logs

  restore

  run_atf $SCRIPT $NUM_OF_SCRIPTS $ISSUE

  kill_sdl

  copy_logs

  clean_atf_logs

  log
}

clean_atf_logs() {
  local REPORT_DIR_PTRNS=("SDLLogs" "ATFLogs" "XMLReports")
  for DIR in ${REPORT_DIR_PTRNS[@]}; do
    rm -rf ${REPORT_PATH}/$DIR*
  done
}

clean_atf_folder() {
  log "Cleaning up ATF folder"
  for FILE in ${ATF_CLEAN_UP[*]}; do rm -rf ${ATF_PATH}/${FILE}; done
}

clean_sdl_folder() {
  log "Cleaning up SDL folder"
  for FILE in ${SDL_CLEAN_UP[*]}; do rm -rf ${SDL_CORE}/${FILE}; done
}

copy_sdl_logs() {
  local SDL_LOG=$SDL_CORE/SmartDeviceLinkCore.log
  if [ $SAVE_SDL_LOG = true ] && [ -f $SDL_LOG ]; then
    cp $SDL_LOG ${REPORT_PATH_TS_SCRIPT}/
  fi
  if [ $SAVE_SDL_CORE_DUMP = true ] && [ "$(ls -A /tmp/corefiles 2> /dev/null)" ]; then
    mv /tmp/corefiles/* ${REPORT_PATH_TS_SCRIPT}/
  fi
}

copy_logs() {
  local REPORT_DIR_PTRNS=("SDLLogs" "ATFLogs" "XMLReports")
  for PTRN in ${REPORT_DIR_PTRNS[@]}; do
    for DIR in $(find "${REPORT_PATH}" -name "$PTRN*"); do
      for FILE in $(find $DIR -type f); do
        cp $FILE ${REPORT_PATH_TS_SCRIPT}/
      done
    done
  done
  if [ -f ${REPORT_PATH_TS_SCRIPT}/${REPORT_FILE_CONSOLE} ]; then
    remove_color ${REPORT_PATH_TS_SCRIPT}/${REPORT_FILE_CONSOLE}
  fi
  copy_sdl_logs
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

backup() {
  log ${LINE1}
  log "Back-up SDL files"
  for FILE in ${SDL_BACK_UP[*]}; do cp -n ${SDL_CORE}/${FILE} ${SDL_CORE}/_${FILE}; done
}

restore() {
  log "Restoring SDL files from back-up"
  for FILE in ${SDL_BACK_UP[*]}; do cp -f ${SDL_CORE}/_${FILE} ${SDL_CORE}/${FILE}; done
}

clean_backup() {
  log ${LINE1}
  log "Cleaning up back-up SDL files"
  for FILE in ${SDL_BACK_UP[*]}; do rm -f ${SDL_CORE}/_${FILE}; done
}

ctrl_c() {
  echo "Scripts processing is cancelled"
  kill_sdl
  copy_logs
  clean_atf_folder
  clean_sdl_folder
  clean_atf_logs
  ts_finish=$(timestamp)
  restore
  clean_backup
  status
  exit 1
}

function StartUp() {
  ts_start=$(timestamp)
  trap ctrl_c INT
  backup
}

function Run() {
  process
}

function TearDown() {
  ts_finish=$(timestamp)
  restore
  clean_backup
  status
}
