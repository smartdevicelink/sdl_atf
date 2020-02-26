project(ATF)
cmake_minimum_required(VERSION 3.11)

# Enable PIC as static libraries may be linked to shared objects
set (CMAKE_POSITION_INDEPENDENT_CODE TRUE)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_INCLUDE_CURRENT_DIR ON)
set (CMAKE_AUTOMOC ON)
# Append directories in the linker search path and outside the project
set (CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set (CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/bin" CACHE PATH "default install path" FORCE )
endif()

#
# Options
#
option(BUILD_TESTS
    "Build unit BUILD_TESTS."
    OFF)
option(BUILD_WITH_SERVER_LOGGING
    "ALlow logging in the library for debug purposes."
    ON)
option(BUILD_WITH_CLIENT_LOGGING
    "ALlow logging in the library for debug purposes."
    OFF)

if(BUILD_TESTS)
    enable_testing()
endif()

find_package(Qt5 5.9 COMPONENTS Core Network WebSockets REQUIRED)
find_package(Lua 5.2 EXACT REQUIRED)

list(GET LUA_LIBRARIES 0 LUA_LIB)
list(GET LUA_LIBRARIES 1 LIBM_LIB)

message(STATUS "lualib : ${LUA_LIB}")
message(STATUS "libmlib : ${LIBM_LIB}")

add_library(lua::lua UNKNOWN IMPORTED GLOBAL)
set_target_properties(lua::lua PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${LUA_INCLUDE_DIR}"
    IMPORTED_LOCATION ${LUA_LIB}
    IMPORTED_LINK_DEPENDENT_LIBRARIES ${LIBM_LIB})

execute_process(COMMAND git submodule init WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
execute_process(COMMAND git submodule update WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(${PROJECT_NAME}
    src/network.cc
    src/timers.cc
    src/qtdynamic.cc
    src/qtlua.cc
    src/qdatetime.cc
    src/marshal.cc
    src/main.cc
    src/lua_interpreter.cc)

target_link_libraries(${PROJECT_NAME}
    Qt5::Core
    Qt5::Network
    Qt5::WebSockets
    lua::lua)

include("BSON.cmake")

install(TARGETS ${PROJECT_NAME}
    DESTINATION "${CMAKE_INSTALL_PREFIX}"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)

install(DIRECTORY "${CMAKE_SOURCE_DIR}/modules"
    "${CMAKE_SOURCE_DIR}/data"
    DESTINATION "${CMAKE_INSTALL_PREFIX}"
    FILE_PERMISSIONS OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)

install(DIRECTORY "${CMAKE_SOURCE_DIR}/tools"
    DESTINATION "${CMAKE_INSTALL_PREFIX}"
    FILE_PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)

install(FILES "${CMAKE_SOURCE_DIR}/start.sh"
    DESTINATION "${CMAKE_INSTALL_PREFIX}"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)

install(CODE "execute_process( \
    COMMAND ${CMAKE_COMMAND} -E create_symlink \
    ./libluabson.so \
    ${CMAKE_INSTALL_PREFIX}/lib/libbson4lua.so \
    )")

add_subdirectory(src/luaxml)
add_subdirectory(src/luaopenssl)
add_subdirectory(src/remote_adapter)
