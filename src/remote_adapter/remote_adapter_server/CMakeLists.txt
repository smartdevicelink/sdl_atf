project(RemoteTestingAdapterServer)
SET_PROPERTY(GLOBAL PROPERTY GLOBAL_NAME ${PROJECT_NAME})
cmake_minimum_required(VERSION 3.11)
set (CMAKE_CXX_STANDARD 11)
include(FetchContent)

# Enable PIC as static libraries may be linked to shared objects
set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)

if(QNXNTO)
    set(CMAKE_CXX_FLAGS "-stdlib=libstdc++")
endif()

FetchContent_Declare(rpclib
    GIT_REPOSITORY https://github.com/smartdevicelink/rpclib.git
    GIT_TAG v2.2.2)

find_package(Threads REQUIRED)
FetchContent_GetProperties(rpclib)
if(NOT rpclib_POPULATED)
    FetchContent_Populate(rpclib)
    add_subdirectory("${rpclib_SOURCE_DIR}" "${rpclib_BINARY_DIR}")
    add_library(rpc::rpclib ALIAS rpc)
endif()

set(RPCLIB_DEPENDENCIES "${rpclib_SOURCE_DIR}/dependencies")
file(GLOB_RECURSE DEP_HEADERS
    ${RPCLIB_DEPENDENCIES}/include/*.h)
set(DEP_SOURCES
    ${RPCLIB_DEPENDENCIES}/src/format.cc
    ${RPCLIB_DEPENDENCIES}/src/posix.cc)

add_executable(${PROJECT_NAME}
    main.cc
    remote_adapter_plugin_manager.cc
    ${DEP_SOURCES})

include("BOOST.cmake")

target_link_libraries(${PROJECT_NAME}
    rpc::rpclib
    Threads::Threads
    $<$<BOOL:${AGL}>:rt>
    $<$<BOOL:${LINUX}>:rt>
    $<$<BOOL:${QNXNTO}>:socket>
    $<$<BOOL:${QNXNTO}>:backtrace.a>
    $<$<BOOL:${QNXNTO}>:stdc++>
    ${BOOST_LIBRARIES}
	-ldl)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    PRIVATE ${RPCLIB_DEPENDENCIES}/include)

target_compile_definitions(${PROJECT_NAME}
    PRIVATE
        "ASIO_STANDALONE"
        "RPCLIB_ASIO=clmdep_asio"
        "RPCLIB_FMT=clmdep_fmt"
    PUBLIC
        "RPCLIB_MSGPACK=clmdep_msgpack")

if(BUILD_WITH_SERVER_LOGGING)
    target_compile_definitions(${PROJECT_NAME} PRIVATE "RPCLIB_ENABLE_LOGGING")
endif()

install(
    TARGETS ${PROJECT_NAME}
    DESTINATION "${CMAKE_INSTALL_PREFIX}/${PROJECT_NAME}"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)

add_subdirectory(plugins/transport)
add_subdirectory(plugins/utils)
