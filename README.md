# Automated Test Framework (ATF)

## Dependencies:
Library                | License
---------------------- | -------------
**Lua libs**           |
liblua5.2              | MIT
json4lua               | MIT
lua-stdlib             | MIT
lua-lpeg               |
**Qt libs**            |
Qt5.9 WebSockets       | LGPL 2.1
Qt5.9 Network          | LGPL 2.1
Qt5.9 Core             | LGPL 2.1
Qt5.9 Test             | LGPL 2.1
**Other libs**         |
lpthread               | LGPL
OpenSSL (ssl, crypto)  | OpenSSL License
libxml2                | MIT
ldoc                   | MIT/X11
docker-ce              | Apache
screen                 | GNU
rsync                  | GNU

## Get source code
```
$ git clone --recurse-submodules https://github.com/smartdevicelink/sdl_atf.git
$ git clone https://github.com/smartdevicelink/sdl_atf_test_scripts.git
```

## Compilation
**1.** Install 3d-parties developers libraries
- Run the following commands:
```
$ sudo apt-get install lua5.2 liblua5.2-dev libxml2-dev lua-lpeg-dev
$ sudo apt-get install openssl libssl1.0-dev
```

**2.** Install Qt5.9+
- For Ubuntu `18.04`:
    - Run the following command:
```
$ sudo apt-get install libqt5websockets5 libqt5websockets5-dev
```

- For Ubuntu `16.04`:
    - Run the following commands:
```
$ sudo add-apt-repository -y ppa:beineri/opt-qt591-xenial
$ sudo apt-get update
$ sudo apt-get install qt59base qt59websockets
```

**3.** Build ATF

CMake 3.15 or newer is required to generate the build files and can be downloaded from [here](https://cmake.org/download/).
- Create a build folder outside of the `sdl_atf` folder
- cd into your build folder and run commands:
```
$ cmake ../sdl_atf
$ make
$ make install
```

**4.** Create symlinks to folders in scripts repository
```
$ ln -s ../sdl_atf_test_scripts/files
$ ln -s ../sdl_atf_test_scripts/test_sets
$ ln -s ../sdl_atf_test_scripts/test_scripts
$ ln -s ../sdl_atf_test_scripts/user_modules
```

**5.** Install dependencies for local parallel mode

Steps below are required only in case if local parallel mode is going to be used.
- Install Docker, e.g. [how-to](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04)
- Install additional tools:
```
$ sudo apt-get install screen rsync
```
- Create docker image
```
$ cd atf_parallels/docker
$ ./build.sh <ubuntu_version>
```
<b>Note:</b> accepted values are `16` and `18` (will be processed as `16.04` and `18.04` correspondingly).
If version is not specified `18` will be used by default.

## Settings

### Defaults

By default ATF reads the following parameters from `Default` configuration (`./modules/configuration/`).

Config File           | Config Parameter                | Cmd Argument | Description
----------------------|---------------------------------|--------------|-----------------------------------------
base_config.lua       | config.SDL                      |              | SDL binary name
base_config.lua       | config.reportPath               | --report     | Path to reports and logs
base_config.lua       | config.pathToSDL                | --sdl-core   | Path to SDL binaries
base_config.lua       | config.pathToSDLInterfaces      | --sdl-api    | Path to SDL APIs
connection_config.lua | config.remoteConnection.enabled |              | Defines if remote connection is enabled

### Priorities

1. Command line argument
2. Specific config
3. Base config

Where 1 is max and 3 is min priority.

This means if some particular option is defined in all 3 places ATF will use the one from highest priority place.

E.g. if path to SDL binaries is defined through `--sdl-core` command line argument (1), in specific config (2) and also in base config (3), ATF will use the value from command line argument.

## Run

```
./start.sh TEST [OPTIONS]...
```

- TEST - test target, is one of the following:
  - test script
  - test set
  - folder with test scripts
- [OPTION] - is one or more of available options:
  - --sdl-core &lt;path&gt;  - path to SDL binaries
  - --config &lt;folder&gt;  - name of the folder with configuration
  - --sdl-api &lt;path&gt;   - path to SDL APIs
  - --report &lt;path&gt;    - path to report and logs
  - --sdl-log [ACTION]       - how to collect SDL logs:
    'yes' - (default) always save, 'no' - do not save, 'fail' - save if script failed or aborted
  - --sdl-core-dump [ACTION] - how to collect SDL core dumps:
    'yes' - (default) always save, 'no' - do not save, 'fail' - save if script failed or aborted
  - --parallels              - force to use local parallel mode
    - -j|--jobs &lt;n&gt;        - number of simultaneous jobs to start
    - --third-party &lt;path&gt; - path to SDL third party
    - --tmp &lt;path&gt;         - path to temporary folder
    - --copy-atf-ts              - force copying of ATF test scripts instead of creating symlinks

In case if folder is specified:
   - only scripts which name starts with number will be taken into account (e.g. 001, 002 etc.)
   - if there are sub-folders scripts will be run recursively

Besides execution of .lua scripts ATF also does auxiliary actions:
  - clean up SDL and ATF folders before running of each script
  - backup and restore SDL important files
  - create report with all required logs for each script including SDL core dumps (in local parallel mode)

### Modes

#### Local consecutive

Test scripts will be run locally one by one.

*Example 1* - Single script:
```
./start.sh ./test_scripts/Smoke/Policies/001_PTU_all_flows.lua
```

*Example 2* - Multiple scripts from some folder:
```
./start.sh ./test_scripts/Smoke/Policies
```

*Example 3* - Test set:
```
./start.sh ./test_sets/smoke_tests.txt
```

#### Local parallel

Test scripts will be run locally in isolated environments and, if required, in several threads.

Test targets described in examples 1 - 3 can be executed in parallel mode by adding --parallels option.

In addition number of parallel jobs can be defined by setting `-j` (or `--jobs`) option.

*Example 4* - Single script in parallel mode:
```
./start.sh ./test_scripts/Smoke/Policies/001_PTU_all_flows.lua --parallels
```

*Example 5* - Multiple scripts from some folder in parallel mode split into 4 threads:
```
./start.sh ./test_scripts/Smoke/Policies -j 4
```

*Example 6* - Test set in parallel mode split into 2 threads:
```
./start.sh ./test_sets/smoke_tests.txt -j 2
```

In case if number of jobs is more than one `--parallels` option can be omitted.

#### Remote consecutive

Test scripts will be run using remote connection.
In this mode `RemoteTestingAdapterServer` should be run on the same host as SDL

Test targets described in examples 1 - 3 can be executed in remote mode.

Appropriate parameters needs to be defined in configuration files:

Config Parameter                | Description
------------------------------- | -----------------------------------
config.pathToSDL                | Path to SDL on a remote host
config.remoteConnection.enabled | Set to `true` for remote connection
config.remoteConnection.url     | SDL host URL
config.mobileHost               | Mobile host URL
config.sdl_logs_host            | SDL host URL to receive log

The best approach is to use predefined configuration (e.g. `remote_linux`) as base and update some parameters in it.

*Example 7* - Test set in remote connection mode:
```
./start.sh ./test_sets/smoke_tests.txt --config remote_linux
```

### Advanced options

1. For a big tests sets (>1000 scripts) Report and Logs can be very huge (>10Gb). Most of the space is occupied by SDL logs. In order to turn them off `--sdl-log` or `--sdl-core-dump` options with `no` or `fail` value can be specified.
2. Some scripts (old policy ones) create the same temporary files inside `files`, `test_scripts` or `user_modules` folders. In case of parallel mode the same temporary file can be used by different scripts at the same time. This leads to incorrect results or even aborts. In order to mitigate this issue `--copy-atf-ts` option can be specified. It tells ATF to copy mentioned folders for each job instead of creating symlinks.

## Documentation generation

### Download and install [ldoc](stevedonovan.github.io/ldoc/manual/doc.md.html)
```
$ sudo apt install luarocks
$ sudo luarocks install luasec
$ sudo luarocks install penlight
$ sudo luarocks install ldoc
$ sudo luarocks install discount
```

### Generate ATF documentation
```
$ cd sdl_atf
$ ldoc -c docs/config.ld .
```

### Open documentation
```
$ chromium-browser docs/html/index.html
```

## Run Unit Tests
```
$ make test
```
