HEADERS = network.h \
          timers.h \
          qtdynamic.h \
          qtlua.h \
          qdatetime.h \
          marshal.h \
          lua_interpreter.h
          
SOURCES = network.cc \
          timers.cc \
          qtdynamic.cc \
          qtlua.cc \
          qdatetime.cc \
          marshal.cc \
          main.cc \
          lua_interpreter.cc
          
TARGET  = interp
QT = core network websockets
CONFIG += c++11 qt debug
# link with libc to meet cross-platform restricts
QMAKE_LFLAGS += -static-libgcc -static-libstdc++
QMAKE_LFLAGS += '-Wl,-rpath,./libs'
QMAKE_RPATHDIR=""
LIBS += -llua5.2
