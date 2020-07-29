#!/usr/bin/env bash

#############################################################

_tmp_dir="$TMP_PATH/prepared_env"
_sdl_prepared=$_tmp_dir/sdl

_path_sdl="$SDL_CORE"
_path_atf="$ATF_PATH"
_test_result_path="$REPORT_PATH_TS"
_testfile="$TEST_TARGET"
_path_sdl_api="$SDL_API"
_path_3rd_party="$THIRD_PARTY"
_save_sdl_log="$SAVE_SDL_LOG"
_save_sdl_core_dump="$SAVE_SDL_CORE_DUMP"
_copy_ts="$COPY_TS"
_path_to_atf_parallels="$_path_atf/atf_parallels"
_test_id_file=.test_id

#############################################################

_queue_reference=queue_ref.tmp.txt
_queue=queue.tmp.txt

_overall_test_number=0
_total_passed=0
_total_failed=0
_total_aborted=0
_total_skipped=0

function prepare_num_of_workers {
  local num=$(wc -l $_queue | awk '{print $1}')
  echo "Number of scripts to execute: "$num
  echo "Max number of jobs: "$JOBS
  _number_of_workers=$JOBS
  if [ "$num" -lt "$JOBS" ]; then
    _number_of_workers=$num
  fi

  echo "Number of workers: "$_number_of_workers
}

function prepare_sdl {
  #
  #   Preparation for SDL.
  #     1) SDL has to be copied to tmp dir
  #     2) Copy libs to bin directory
  #

  if [ -d "$_sdl_prepared" ]; then
    rm -r "$_sdl_prepared"
  fi
  mkdir $_sdl_prepared

  cp -r $_path_sdl $_sdl_prepared

  if [ ! -z "$_path_3rd_party" ]; then
    LD_LIBRARY_PATH=$_path_3rd_party/lib:$_path_3rd_party/x86_64/lib:$LD_LIBRARY_PATH \
    ldd $_sdl_prepared/bin/smartDeviceLinkCore \
    | grep "$_path_3rd_party/lib\|$_path_3rd_party/x86_64/lib" \
    | awk '{print $3}' \
    | xargs -L1 -I LIB cp LIB $_sdl_prepared/bin
  fi
}

function rm_dir_if_exists {
  #
  #   Helper function to check whether dir or symlink to dir exists and, if it is,
  #    to remove the directory.
  #

  if [ -L "$1" ]; then
    rm "$1"
  elif [ -d "$1" ]; then
    rm -r "$1"
  fi
}

function prepare_atf {
  #
  #   Preparations for ATF.
  #     1) ATF is copied to tmp dir (not to break an existing one)
  #     2) Copy required dirs from sdl_atf_test_scripts to sdl_atf
  #     3) Copy interfaces (MOBILE_API.xml, HMI_API.xml) to atf data dir
  #     4) Set required properties to ATF configuration file.
  #

  atf_tmp_dir=$_tmp_dir/atf
  atf_tmp_ts_dir=$_tmp_dir/atf_ts

  if [ -d "$atf_tmp_dir" ]; then
    rm -r $atf_tmp_dir
  fi
  mkdir $atf_tmp_dir

  if [ ! -d "$_path_atf" ]; then
    log "Wrong path to ATF: '$_path_atf'"
    exit 1
  fi
  rsync -a $_path_atf/* $atf_tmp_dir/ --exclude TestingReports --exclude $_test_result_path

  local dirs=("test_scripts" "test_sets" "files" "user_modules")
  for dir in ${dirs[@]}; do
    rm_dir_if_exists $atf_tmp_dir/$dir
  done

  if [ -d "$atf_tmp_ts_dir" ]; then
    rm -r $atf_tmp_ts_dir
  fi
  mkdir $atf_tmp_ts_dir

  for dir in ${dirs[@]}; do
    cp -r $(realpath ./$dir) $atf_tmp_ts_dir/
  done

  if [ -n "$_path_sdl_api" ]; then cp $_path_sdl_api/*.xml $atf_tmp_dir/data; fi

  local config_file=$atf_tmp_dir/modules/configuration/base_config.lua
  sed -i '/^config.pathToSDL\ =/c\config.pathToSDL="/home/developer/sdl/bin"' $config_file
  sed -i '/^config.pathToSDLInterfaces\ =/c\config.pathToSDLInterfaces="/home/developer/sdl/atf/data"' $config_file
  sed -i '/^config.reportPath\ =/c\config.reportPath="/home/developer/sdl/TestingReports"' $config_file
}

function prepare_queue {
  #
  #   Preparation of the queue with a list of scripts to be executed
  #

  if [ -f "$_queue" ];then
    rm $_queue
  fi

  if [ -f "$_queue_reference" ];then
    rm $_queue_reference
  fi

  if [ -f $_testfile ]; then
    extension="${_testfile##*.}"
    if [ $extension = "lua" ]; then
      echo "$_testfile" > $_queue
    elif [ $extension = "txt" ]; then
      cp $_testfile $_queue
    else
      log "Test target extention can not be recognized: '$_testfile'"
      exit 1
    fi
  elif [ -d $_testfile ]; then
    find $_testfile -iname "[0-9]*.lua" | sort > $_queue
    if [ ! -s $_queue ]; then
      rm $_queue
      log "Failed to find any test scripts in: '$_testfile'"
      exit 1
    fi
  else
    log "Unsupported test target format: '$_testfile'"
    exit 1
  fi

  sed -E '/^;($|[^.])/d' -i $_queue
  cp $_queue $_queue_reference
}

function common {
  # remove tmp dir if exists
  if [ -d "$_tmp_dir" ]; then
    rm -r "$_tmp_dir"
  fi
  rm -f "$_test_id_file"

  mkdir $_tmp_dir

  prepare_queue
  prepare_num_of_workers

  prepare_sdl
  prepare_atf
}

function mktemptdir {
  #
  #   Create temporary folder with SDL, ATF and Test Scripts
  #

  tmpdirname=$(mktemp --suffix=_worker --tmpdir=$_tmp_dir -d)

  mkdir -p $tmpdirname/bin

  cp $_sdl_prepared/bin/hmi_capabilities.json $tmpdirname/bin/
  cp $_sdl_prepared/bin/log4cxx.properties $tmpdirname/bin/
  cp $_sdl_prepared/bin/*.pem $tmpdirname/bin/
  cp $_sdl_prepared/bin/sdl_preloaded_pt.json $tmpdirname/bin/
  cp $_sdl_prepared/bin/smartDeviceLink.ini $tmpdirname/bin/

  ln -s ../../sdl_ext/bin/audio.8bit.wav $tmpdirname/bin/audio.8bit.wav
  ln -s ../../sdl_ext/bin/build_config.txt $tmpdirname/bin/build_config.txt
  ln -s ../../sdl_ext/bin/smartDeviceLinkCore $tmpdirname/bin/smartDeviceLinkCore

  for f in $(find $_sdl_prepared/bin/ -name "lib*"); do
    ln -s ../../sdl_ext/bin/$(basename $f) $tmpdirname/bin/
  done

  cp -r $atf_tmp_dir $tmpdirname/

  if [ "$_copy_ts" = true ]; then
    cp -r $atf_tmp_ts_dir/test_scripts $tmpdirname/$(basename $atf_tmp_dir)/
    cp -r $atf_tmp_ts_dir/test_sets $tmpdirname/$(basename $atf_tmp_dir)/
    cp -r $atf_tmp_ts_dir/user_modules $tmpdirname/$(basename $atf_tmp_dir)/
    cp -r $atf_tmp_ts_dir/files $tmpdirname/$(basename $atf_tmp_dir)/
  else
    ln -s ../../atf_ts/test_scripts $tmpdirname/$(basename $atf_tmp_dir)
    ln -s ../../atf_ts/test_sets $tmpdirname/$(basename $atf_tmp_dir)
    ln -s ../../atf_ts/user_modules $tmpdirname/$(basename $atf_tmp_dir)
    ln -s ../../atf_ts/files $tmpdirname/$(basename $atf_tmp_dir)
  fi

  echo $tmpdirname
}

function wait_screen_termination {
  while screen -ls | grep -q ${_tmp_workers// /\\|}
  do
    sleep 1
  done
}

function wait_screen_termination_with_progress {
  while screen -ls | grep -q ${_tmp_workers// /\\|}
  do
    sleep 1
    show_progress
  done
}

function show_progress {
  new_state=$(diff -N <(sed -e '$a\' $_queue) <(sed -e '$a\' $_queue_reference) | tail -n +2 | awk {'print $2'})
  processed=$(diff <(echo "$new_state") <(echo "$_last_state") | tail -n +2 | awk '{print $2}')

  if [ -z "$processed" ]; then
    return
  fi

  for item in $processed
  do
    log $item
  done
  _last_state=$new_state
}

function clean_up {
  rm -r $_tmp_dir
  rm $_queue
  rm $_queue_reference
  rm $_test_id_file
}

#############################################################
#   Report generator
#############################################################

function process_report {
  #   overall_report_file - defined in generate_total_report()

  local curr_report_file=$1; shift
  local dir_number=$1; shift

  local test_target=$(cat $curr_report_file | grep "Test target:" | awk '{print $3}')

  local total_tests=$(cat $curr_report_file | grep "TOTAL:" | awk '{print $2}')
  local passed_tests=$(cat $curr_report_file | grep "PASSED:" | awk '{print $2}')
  local failed_tests=$(cat $curr_report_file | grep "FAILED:" | awk '{print $2}')
  local aborted_tests=$(cat $curr_report_file | grep "ABORTED:" | awk '{print $2}')
  local skipped_tests=$(cat $curr_report_file | grep "SKIPPED:" | awk '{print $2}')

  ((_overall_test_number+=total_tests))
  ((_total_passed+=passed_tests))
  ((_total_failed+=failed_tests))
  ((_total_aborted+=aborted_tests))
  ((_total_skipped+=skipped_tests))

  if [[ $passed_tests == 1 ]]; then
    echo -e "$dir_number:\t$test_target\tPASSED" >> $overall_report_file
  elif [[ $failed_tests == 1 ]]; then
    echo -e "$dir_number:\t$test_target\tFAILED" >> $overall_report_file
  elif [[ $aborted_tests == 1 ]]; then
    echo -e "$dir_number:\t$test_target\tABORTED" >> $overall_report_file
  elif [[ $skipped_tests == 1 ]]; then
    echo -e "$dir_number:\t$test_target\tSKIPPED" >> $overall_report_file
  else
    echo -e "$dir_number:\t$test_target\tPARSING ERROR" >> $overall_report_file
    return 1
  fi

  return 0
}

function generate_total_report {
  env_dir=$1; shift

  testing_report_dir=$env_dir/TestingReports
  mkdir $testing_report_dir

  total_number_of_tests=$(find $env_dir/*/TestingReports/* -maxdepth 0 -type d | wc -l)

  overall_report_file=$testing_report_dir/Report.txt

  touch $overall_report_file

  for worker in $(ls $env_dir | grep _worker)
  do
    if [ ! -d $env_dir/$worker/TestingReports ]; then
      continue;
    fi
    for item in $(ls $env_dir/$worker/TestingReports)
    do
      local abs_path=$env_dir/$worker/TestingReports/$item
      local dir_number=$(basename $(find $abs_path -maxdepth 1 -type d | sort -r | head -n 1))
      local dir_number_lead_zeroes=$(printf "%0${#total_number_of_tests}d" $dir_number)
      process_report $abs_path/Report.txt $dir_number_lead_zeroes
      process_report_status=$?

      local current_test_dirname=$testing_report_dir/$dir_number_lead_zeroes
      mv $abs_path/$dir_number $current_test_dirname
      if [ $process_report_status != 0 ]; then
        mv $abs_path/Report.txt $current_test_dirname/
      fi
      rm -r $abs_path
    done
    rm -r $env_dir/$worker/TestingReports
  done

  sort -o $overall_report_file $overall_report_file

  echo "$(echo ${LINE2} | cat - $overall_report_file)" > $overall_report_file
  echo "$(echo 'Test target:' $_testfile | cat - $overall_report_file)" > $overall_report_file
  echo "$(echo ${LINE1} | cat - $overall_report_file)" > $overall_report_file

  echo ${LINE2} >> $overall_report_file
  echo "TOTAL: $_overall_test_number" >> $overall_report_file
  echo "PASSED: $_total_passed" >> $overall_report_file
  echo "FAILED: $_total_failed" >> $overall_report_file
  echo "ABORTED: $_total_aborted" >> $overall_report_file
  echo "SKIPPED: $_total_skipped" >> $overall_report_file
  echo ${LINE2} >> $overall_report_file
  echo "Execution time:" $(seconds2time $(($ts_finish - $ts_start))) >> $overall_report_file
  echo ${LINE1} >> $overall_report_file

  mv $testing_report_dir/* $_test_result_path/
}

#############################################################

function int_handler {
  echo "Please, wait for subprocesses to be stopped"

  # Stop handling sigint
  trap - INT

  for worker in $_tmp_workers
  do
    session_pid=$(screen -ls | grep $worker | awk '{print $1}')
    screen -S $session_pid -X stuff $'\003'
  done
  wait_screen_termination

  TearDown
  exit 1
}

function StartUp() {
  ts_start=$(timestamp)
  trap 'int_handler' INT

  log "Test target: $_testfile"

  common
}

_tmp_workers=""
function Run() {
  log "Running workers..."
  for (( a = 0; a < $_number_of_workers; a++ )); do
    tmpdirname=$(mktemptdir)
    screen_basename=$(basename $tmpdirname)
    screen -d -m -S $screen_basename \
      $_path_to_atf_parallels/loop.sh \
      $_sdl_prepared \
      $tmpdirname \
      $atf_tmp_ts_dir \
      $_queue \
      $_save_sdl_log \
      $_save_sdl_core_dump \
      $_test_id_file
    _tmp_workers=$(echo $_tmp_workers" $screen_basename" | xargs)
  done

  log "Workers are running. Waiting for termination..."
  wait_screen_termination_with_progress
}

function TearDown() {
  ts_finish=$(timestamp)
  log "Collecting results..."
  generate_total_report $_tmp_dir

  log "Clearing up..."
  clean_up
}
