#!/bin/bash

_sdl_prepared=$1; shift
_tmpdirname=$1; shift
_atf_ts_dir=$1; shift
_queue=$1; shift
_save_sdl_log=$1; shift
_save_sdl_core_dump=$1; shift
_test_id_file=$1; shift

_lockfile=.lock

_image_name=atf_worker
_container_name=$(basename $_tmpdirname)

####################################################################
#   The following code has to be run in several different processes
#       i.e. `screen -d -m 'script_to_run.sh'`
####################################################################

function docker_run {
    docker run --rm \
        --name $_container_name \
        --cap-add NET_ADMIN \
        --privileged \
        -e LOCAL_USER_ID=`id -u $USER` \
        -v $_atf_ts_dir:/home/developer/atf_ts \
        -v $_tmpdirname:/home/developer/sdl \
        -v $_sdl_prepared:/home/developer/sdl_ext \
        $_image_name "$@"
}

function docker_stop {
    docker stop $(docker ps -q -f "name=$_container_name")
    for id in $container_ids;
    do
        docker stop $id
    done
}

function pop {
    local FILE=$1
    local RES=1
    if (set -o noclobber; echo "$$" > "$_lockfile") 2> /dev/null; then
        trap 'rm -f "$_lockfile"; exit $?' TERM EXIT

        local LINE=$(head -n 1 $FILE | awk '{print $1}')
        if [ -n "$LINE" ]; then
            sed -i '1d' $FILE
            RES=0
            if [ -z $_test_id_file ]; then echo 0 > $_test_id_file; fi
            local CURRENT_ID=$(cat $_test_id_file)
            let CURRENT_ID=CURRENT_ID+1
            echo $CURRENT_ID > $_test_id_file
            echo $CURRENT_ID $LINE
        else
            RES=2
        fi
        rm -f "$_lockfile"
        trap - TERM EXIT
    fi
    return $RES
}

function int_handler() {
    echo "Stopping docker containers"

    # Stop handling sigint
    trap - INT

    rm -f $_lockfile
    docker_stop

    exit 0
}

function main {
    trap 'int_handler' INT

    while true; do
        row=$(pop $_queue)
        local res=$?

        if [ $res == 1 ]; then
            sleep 0.2;
            continue;
        elif [ $res == 2 ]; then
            break;
        fi

        local script_num=$(echo $row | awk '{print $1}')
        local script_name=$(echo $row | awk '{print $2}')

        docker_run $script_name \
          $([ "$_save_sdl_log" = false ] && echo "--no-sdl-log") \
          $([ "$_save_sdl_core_dump" = false ] && echo "--no-sdl-core-dump") \
          --test-id $script_num

        sleep 0.1
    done
}

main
