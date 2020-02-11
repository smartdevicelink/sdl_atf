## How to build
- Install all [dependencies](#dependencies)
- Clone repository
- Create build directory and get into created directory
- Run the following command : `cmake <path to sources>`
- Run `make`

## Dependencies:
 - [CMake](https://cmake.org/download/) : Download and install any release version > 3.11
 - **GNU Make & C++ compiler** : Install with command `sudo apt-get install build-essential`
 - [rpclib](https://github.com/rpclib/rpclib) : Library for TCP communication.
   *Note* : Installed automatically while running CMake.

 - **Lua library** : Install with command `sudo apt-get install liblua5.2-dev`
 - **Doxygen** : Install with command `sudo apt-get install doxygen`

## Remote Testing Adapter server (RemoteTestingAdapterServer) usage
 - Accepts rpclib connections
 - Executes client requests using plugins

libRemoteUtilsManager.so:
 - `app_start` - start application on remote host
 - `app_stop` - shutdown application on remote host
 - `app_check_status` - check application status on remote host
 - `file_backup` - backup file on remote host
 - `file_restore` - restore backuped file on remote host
 - `file_update` - update file content on remote host
 - `file_exists` - check whether file exists on remote host
 - `file_content` - get content of file on remote host
 - `file_delete` - delete file on remote host
 - `folder_exists` - check whether folder exists on remote host
 - `folder_create` - create folder on remote host
 - `folder_delete` - delete folder on remote host
 - `command_execute` - execute bash command on remote host

libRemoteMessageBroker.so
 - `open` - open WS connection
 - `close` - close WS connection
 - `send` - send text message via WS connection
 - `receive` - receive text message via WS connection

## Remote client library for Lua (libremote.so) usage
Provides RemoteClient class with next methods for Lua:
 - `connected` - check connection
 - `call` - call function on remote host which returns string value as result
 - `file_call` - call function on remote host which returns path to local file as result

Provides RemoteTestAdapter class with next methods for Lua:
 - `connect` - connect to SDL on remote host as HMI
 - `write` - send text message to SDL

And callbacks for `connected`, `disconnected` and `received` events.

