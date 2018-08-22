#!/bin/bash
dirSDL=$1
dirATF=$(pwd)
appName=$2
cd $dirSDL
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:. export LD_LIBRARY_PATH
./$appName > /dev/null &
sdl_pid=$!
echo "SDL pid "$sdl_pid
test -e /proc/$sdl_pid || exit 1
cd $dirATF
echo $sdl_pid > sdl.pid
test -e sdl.pid && test -e /proc/$(cat sdl.pid) && exit 0
exit 1
