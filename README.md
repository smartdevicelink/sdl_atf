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
Qt5.3 WebSockets       | LGPL 2.1
Qt5.3 Network          | LGPL 2.1
Qt5.3 Core             | LGPL 2.1
Qt5.3 Test             | LGPL 2.1
**Other libs**         |
lpthread               | LGPL
OpenSSL (ssl, crypto)  | OpenSSL License
libxml2                | MIT
ldoc                   | MIT/X11

For ATF usage:
```sudo apt-get install liblua5.2 libxml2 lua-lpeg```

## Get source code:
```
$ git clone https://github.com/smartdevicelink/sdl_atf
$ cd sdl_atf
$ git submodule init
$ git submodule update
```
## Compilation:
**1** Install 3d-parties developers libraries
```
sudo apt-get install liblua5.2-dev libxml2-dev lua-lpeg-dev
sudo apt-get install openssl
```

**2** Install Qt5.3+

[Download Qt5.3+](https://download.qt.io/archive/qt/5.3/5.3.1/)
```
sudo chmod +x some-qt-build.run
./some-qt-build.run
```

**2** Setup QMAKE environment variable to path to qmake
```export QMAKE=${PATH_TO_QMAKE} ```
*You can get path to qmake this way:*
```
$ sudo find / -name qmake
/usr/bin/qmake
/opt/Qt5.3.1/5.3/gcc/bin/qmake
```
/usr/bin/qmake in most cases does not work as it is just soft link to qtchooser

**2**  ```$ make```

 1) If during executing "make" command you have the following problem:
   Project ERROR: Unknown module(s) in QT: websockets

   Solution:
   You have to change location of qmake in Makefile in atf root directory
   Find location of qmake executable on your local PC:
   (It should look like: .../Qt/5.3/gcc_64/bin/qmake)

   and put it into Makefile to the line:
   QMAKE=<your path to qmake>
   Sometimes you will need reinstall QT Creator to get correct qmake executable
   Also you can open QT Creator. Then go to: Tool->Options->Build & Run. Find Qt Versions Tab.
   Here you can find qmake location.

## Run:
``` ./start.sh SDL TEST [OPTION]... ```


- SDL  - path to SDL binaries
- TEST - test target, could be one of the following:
  - test script
  - test set
  - folder with test scripts
- [OPTION] - options supported by ATF:
  - --sdl-interfaces   - path to SDL APIs
  - --report-path      - path to report and logs

In case if folder is specified:
   - only scripts which name starts with number will be taken into account (e.g. 001, 002 etc.)
   - if there are sub-folders scripts will be run recursively

Besides execution of test scripts start.sh also does auxiliary actions:
   - clean up SDL and ATF folders before running of each script
   - backup and restore SDL important files
   - create report with all required logs for each script


## Documentation generation

### Download and install [ldoc](stevedonovan.github.io/ldoc/manual/doc.md.html)
```
sudo apt install luarocks
sudo luarocks install luasec
sudo luarocks install penlight
sudo luarocks install ldoc
sudo luarocks install discount
```

### Generate ATF documentation
```
cd sdl_atf
ldoc -c docs/config.ld .
```

### Open documentation
```chromium-browser docs/html/index.html```

### Useful options:
#### Path to SDL APIs
By default ATF uses APIs from `./data` folder.
But this behavior can be overridden via command line with `--sdl-interfaces` option.
If this option is defined with a particular path, ATF will copy APIs from path defined to `./data` folder during script execution.

**Example :**
```
./start.sh /home/user/development/sdl/build/bin ./test_scripts/test.lua --sdl-interfaces=~/sdl_core/src/components/interfaces
```

#### Path to Reports folder
By default folder for the reports is `./TestingReports`
But this can be overridden via command line with `--report-path` option

**Example :**
```
./start.sh /home/user/development/sdl/build/bin ./test_scripts/test.lua --report-path=~/Reports
```

#### Connect ATF to already started SDL
ATF is able to connect to already started SDL.
Note that you should be sure that:
 - ATF is configured not to start SDL
 - SDL is configured not to start HMI
 - mobile and HMI sockets options match each other in SDL and ATF configs.

**Example :**

*ATF config : modules/config.lua :*
```
config.autorunSDL = false
config.hmiUrl = "ws://localhost"
config.hmiPort = 8087
config.mobileHost = "localhost"
config.mobilePort = 12345
```

*SDL config : smartDeviceLink.ini :*
```
[HMI]
; Open the $LinkToWebHMI in chromium browser
LaunchHMI = false
; WebSocket connection address and port
ServerAddress = 127.0.0.1
ServerPort = 8087
[TransportManager]
; Listening port form incoming TCP mobile connection
TCPAdapterPort = 12345
```

## Run tests
``` make test```
