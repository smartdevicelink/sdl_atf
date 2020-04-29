## How to build
- Install all [dependencies](#dependencies)
- Clone repository
- Create build directory and get into created directory
- Run the following command : `cmake <path to sources>`
- Run `make`

## Dependencies:
 - [CMake](https://cmake.org/download/) : Download and install any release version > 3.11
 - **GNU Make & C++ compiler** : Install with command `sudo apt-get install build-essential`
 - [rpclib](https://github.com/smartdevicelink/rpclib) : Library for TCP communication.
   *Note* : Installed automatically while running CMake.

 - **Lua library** : Install with command `sudo apt-get install liblua5.2-dev`
 - **Doxygen** : Install with command `sudo apt-get install doxygen`

## Remote Testing Adapter server (RemoteTestingAdapterServer) usage
 - Accepts rpclib connections
 - Executes client requests using plug-ins

libRemoteUtilsManager.so:
- `app_start` : start application on remote host
```
Request:
 1. String app_path - full path to the application folder
 2. String app_name - the file name of the application to be started
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `app_stop` : shutdown application on remote host
```
Request:
 1. String app_name - application name to be shutdown
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `app_check_status` : check application status on remote host
```
Request:
 1. String app_name - application name to be checked
```
```
Response:
 1. String result       - string representation of the result code
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `file_backup` : backup file on remote host
```
Request:
 1. String file_path - full path to the file folder
 2. String file_name - the file name to be backup-ed
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `file_restore` : restore backup-ed file on remote host
```
Request:
 1. String file_path - full path to the file folder
 2. String file_name - the file name to be restored
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `file_update` : update file content on remote host
```
Request:
 1. String file_path - full path to the file folder
 2. String file_name - the file name to be updated
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `file_exists` : check whether file exists on remote host
```
Request:
 1. String file_path - full path to the file folder
 2. String file_name - the file name to be checked
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `file_content` : get content of file on remote host
```
Request:
 1. String file_path         - full path to the file folder
 2. String file_name         - the file name to be got content
 3. Integer offset           - number of bytes from beginning of file,
                               this parameter is modified during function call
                               it contains file offset for next function call
                               if the end of the file is not reached
                               or result code SUCCESS if it is reached
 4. Integer max_size_content - maximum size in bytes to be read at one time
```
```
Response:
 1. String result       - contains read content
 2. Integer result_code - offset or a predefined result code after performing the operation
 ```
- `file_delete` : delete file on remote host
```
Request:
 1. String file_path - full path to the file folder
 2. String file_name - the file name to be deleted
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `folder_exists` : check whether folder exists on remote host
```
Request:
 1. String folder_path - full path to the folder to be checked
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `folder_create` : create folder on remote host
```
Request:
 1. String folder_path - full path to the folder to be created
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `folder_delete` : delete folder on remote host
```
Request:
 1. String folder_path - full path to the folder to be deleted
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `command_execute` : execute bash command on remote host
```
Request:
 1. String bash_command - bash command to be executed
```
```
Response:
 1. String result       - output for the bash command
 2. Integer result_code - a predefined result code after performing the operation
 ```

libRemoteMessageBroker.so
- `open` : open WS connection
```
Request:
 1. String address  - IPv4 address in dotted decimal form, or from an
                      IPv6 address in hexadecimal notation
 2. Integer port    - the port number
 3. Integer threads - the requested number of threads for the I/O service run,default value 2
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `close` : close WS connection
```
Request:
 1. String address  - IPv4 address in dotted decimal form, or from an
                      IPv6 address in hexadecimal notation
 2. Integer port    - the port number
```
```
Response:
 1. String result       - string representation of the error code or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `send` : send text message via WS connection
```
Request:
 1. String address  - IPv4 address in dotted decimal form, or from an
                      IPv6 address in hexadecimal notation
 2. Integer port    - the port number
 3. String  data    - data to be sent
```
```
Response:
 1. String result       - contains pending messages or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```
- `receive` : receive text message via WS connection
```
Request:
 1. String address  - IPv4 address in dotted decimal form, or from an
                      IPv6 address in hexadecimal notation
 2. Integer port    - the port number
```
```
Response:
 1. String result       - contains received message or empty value
 2. Integer result_code - a predefined result code after performing the operation
 ```

## Remote client library for Lua (libremote.so) usage
Provides RemoteClient class with next methods for Lua:
- `connected` : check connection
- `call` : call function on remote host which returns string value as result
- `file_call` : call function on remote host which returns path to local file as result

Provides RemoteTestAdapter class with next methods for Lua:
- `connect` : connect to SDL on remote host as HMI
- `write` : send text message to SDL

And callbacks for `connected`, `disconnected` and `received` events.
