#!/bin/bash
shutdown_time=5
read pid < sdl.pid

function shutdown_sdl {
    kill -SIGINT $pid
    for x in `seq $shutdown_time`
    do
        sleep 1
        test -e  /proc/$pid || return 0;
    done
    echo "Unable to stop SDL correctly during "$shutdown_time" seconds"
    return 1
}

# Abort is used for getting core dump
function kill_sdl {
    echo "Kill SDL process : "$pid
    kill -SIGABRT $pid
}

shutdown_sdl || kill_sdl
rm sdl.pid
