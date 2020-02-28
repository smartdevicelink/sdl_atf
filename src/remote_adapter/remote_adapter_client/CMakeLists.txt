project(remote)
cmake_minimum_required(VERSION 3.11)
include(FetchContent)

#
# Options
#
option(BUILD_WITH_CLIENT_LOGGING
    "ALlow logging in the library for debug purposes."
    OFF)

# Enable PIC as static libraries may be linked to shared objects
set (CMAKE_POSITION_INDEPENDENT_CODE TRUE)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_INCLUDE_CURRENT_DIR ON)
set (CMAKE_AUTOMOC ON)

FetchContent_Declare(rpclib
    GIT_REPOSITORY https://github.com/smartdevicelink/rpclib.git
    GIT_TAG v2.2.2)

FetchContent_GetProperties(rpclib)
if(NOT rpclib_POPULATED)
    FetchContent_Populate(rpclib)
    add_subdirectory("${rpclib_SOURCE_DIR}" "${rpclib_BINARY_DIR}")
    find_package(Threads REQUIRED)
    add_library(rpc::rpclib ALIAS rpc)
endif()

find_package(Qt5 COMPONENTS Core REQUIRED)
find_package(Threads REQUIRED)
find_package(Lua 5.2 EXACT REQUIRED)

list(GET LUA_LIBRARIES 0 LUA_LIB)
list(GET LUA_LIBRARIES 1 LIBM_LIB)
message(STATUS "lualib : ${LUA_LIB}")
message(STATUS "libmlib : ${LIBM_LIB}")

if (NOT TARGET lua::lua)
    add_library(lua::lua UNKNOWN IMPORTED GLOBAL)

    set_target_properties(lua::lua PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${LUA_INCLUDE_DIR}"
        IMPORTED_LOCATION ${LUA_LIB}
        IMPORTED_LINK_DEPENDENT_LIBRARIES ${LIBM_LIB})
endif()

set(RPCLIB_DEPENDENCIES "${rpclib_SOURCE_DIR}/dependencies")
file(GLOB_RECURSE DEP_HEADERS
    ${RPCLIB_DEPENDENCIES}/include/*.h)
set(DEP_SOURCES
    ${RPCLIB_DEPENDENCIES}/src/format.cc
    ${RPCLIB_DEPENDENCIES}/src/posix.cc)

add_library(${PROJECT_NAME} SHARED
    remote_client/remote_client.cc
    remote_client/rpc_connection_impl.cc
    hmi_adapter/hmi_adapter_client.cc
    remote_client/lua_lib/remote_client_lua_wrapper.cc
    hmi_adapter/lua_lib/hmi_adapter_client_lua_wrapper.cc
    lua_remote_library.cc
    ${DEP_SOURCES})

target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE ${RPCLIB_DEPENDENCIES}/include
    ${LUA_INCLUDE_DIR})

target_link_libraries(${PROJECT_NAME}
    Qt5::Core
    lua::lua
    rpc::rpclib
    Threads::Threads
    $<$<BOOL:${QNXNTO}>:socket>)

target_compile_definitions(${PROJECT_NAME}
    PRIVATE
        "ASIO_STANDALONE"
        "RPCLIB_ASIO=clmdep_asio"
        "RPCLIB_FMT=clmdep_fmt"
    PUBLIC
        "RPCLIB_MSGPACK=clmdep_msgpack")

if(BUILD_WITH_CLIENT_LOGGING)
    target_compile_definitions(${PROJECT_NAME} PRIVATE "RPCLIB_ENABLE_LOGGING")
endif()

#
# Unit tests
#
if(BUILD_TESTS)
    add_subdirectory(remote_client/tests)
endif()

install(
    TARGETS ${PROJECT_NAME}
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)
