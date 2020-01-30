include(ExternalProject)

if (UNIX)
    if (QNXNTO)
        set(LINUX FALSE)
    else(QNXNTO)
        if(CMAKE_TOOLCHAIN_FILE)
            set(AGL TRUE)
            set(LINUX FALSE)
        else(CMAKE_TOOLCHAIN_FILE)
            set(LINUX TRUE)
            set(AGL FALSE)
        endif(CMAKE_TOOLCHAIN_FILE)
    endif(QNXNTO)
endif()

set(Boost_NO_SYSTEM_PATHS TRUE)
set(BOOST_ROOT ${CMAKE_CURRENT_BINARY_DIR}/third_party/boost)
set(BOOST_INSTALL ${BOOST_ROOT})
set(BOOST_INCLUDE_DIRS ${BOOST_INSTALL}/include)
set(BOOST_LIBRARY_DIRS ${BOOST_INSTALL}/lib)

if(QNXNTO)
    set(CMAKE_FIND_ROOT_PATH "${CMAKE_FIND_ROOT_PATH}" "${BOOST_ROOT}")
endif()

find_package(Boost 1.68.0 COMPONENTS system filesystem)

if (NOT ${Boost_FOUND})
    message(STATUS "Did not find boost. Downloading and installing boost 1.68")
    if(NOT QNXNTO)
        set(BOOST_GCC_JAM "")
        set(BOOST_FILESYSTEM_OPERATION "")
        if(${LINUX})
            set(BOOST_PROJECT_CONFIG_JAM "")
            set(BOOTSTRAP ./bootstrap.sh --with-libraries=system,filesystem --prefix=${BOOST_INSTALL})
            set(BOOST_BUILD_COMMAND ./b2 cxxflags="-fpic" --prefix=${BOOST_INSTALL})
        else()
            set(BOOST_PROJECT_CONFIG_JAM
                "using gcc : agl : x86_64-agl-linux-gcc  -march=corei7 -mtune=corei7 -mfpmath=sse -msse4.2 --sysroot=/opt/agl-sdk/6.0.2-corei7-64/sysroots/corei7-64-agl-linux" $<SEMICOLON>)
            set(BOOTSTRAP env CC=\"\" ./bootstrap.sh --with-toolset=gcc --with-libraries=system,filesystem --prefix=${BOOST_INSTALL})
            string(STRIP "$ENV{CXXFLAGS} -fpic" FLAGS)
            set(BOOST_BUILD_COMMAND ./b2 toolset=gcc-agl cxxflags=${FLAGS})
        endif()
    else()
        if(${CMAKE_SYSTEM_PROCESSOR} MATCHES ".*aarch64")
            set(ADDRESS_MODEL "64")
        else()
            set(ADDRESS_MODEL "32_64")
        endif()
        set(BOOST_PROJECT_CONFIG_JAM
            "using gcc : nto${CMAKE_SYSTEM_PROCESSOR} : ${QNX_HOST}/usr/bin/nto${CMAKE_SYSTEM_PROCESSOR}-g++${HOST_EXECUTABLE_SUFFIX} : -L${QNX_HOST}/usr/lib -I${QNX_HOST}/usr/include" $<SEMICOLON>)
        set(BOOST_GCC_JAM sed -Ei "s/ : rt/ /g" ./tools/build/src/tools/gcc.jam)
        set(BOOST_FILESYSTEM_OPERATION sed -Ei "s/__SUNPRO_CC/__QNX__/g" ./libs/filesystem/src/operations.cpp)
        set(BOOTSTRAP
            ./bootstrap.sh --with-toolset=gcc --with-libraries=system,filesystem --prefix=${BOOST_INSTALL})
        set(BOOST_BUILD_COMMAND
            ./b2 address-model=${ADDRESS_MODEL} cxxflags="-stdlib=libstdc++ -fpic" linkflags="-stdlib=libstdc++" target-os=qnxnto toolset=gcc-nto${CMAKE_SYSTEM_PROCESSOR} --prefix=${BOOST_INSTALL})
    endif()
    set(BOOST_INSTALL_COMMAND ${BOOST_BUILD_COMMAND} install)
    ExternalProject_Add(Boost
        URL https://dl.bintray.com/boostorg/release/1.68.0/source/boost_1_68_0.tar.gz
        DOWNLOAD_DIR ${BOOST_LIB_SOURCE_DIRECTORY}
        SOURCE_DIR ${BOOST_LIB_SOURCE_DIRECTORY}
        CONFIGURE_COMMAND  ${BOOST_GCC_JAM} COMMAND ${BOOST_FILESYSTEM_OPERATION} COMMAND ${BOOTSTRAP}
        BUILD_COMMAND echo ${BOOST_PROJECT_CONFIG_JAM} >> ./project-config.jam COMMAND ${BOOST_BUILD_COMMAND}
        INSTALL_COMMAND ${BOOST_INSTALL_COMMAND}
        INSTALL_DIR ${BOOST_INSTALL}
        BUILD_IN_SOURCE true)
endif()

set(BOOST_LIBRARIES
    "${BOOST_LIBRARY_DIRS}/libboost_system.a"
    "${BOOST_LIBRARY_DIRS}/libboost_filesystem.a")

include_directories("${BOOST_INCLUDE_DIRS}")

if (NOT ${Boost_FOUND})
    add_dependencies(${PROJECT_NAME} Boost)
endif()
