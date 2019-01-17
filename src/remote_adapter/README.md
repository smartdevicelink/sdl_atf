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
