project(RemoteUtilsManager)
GET_PROPERTY(ROOT_PROJECT_NAME GLOBAL PROPERTY GLOBAL_NAME)

# Enable PIC as static libraries may be linked to shared objects
# Enable PIC as static libraries may be linked to shared objects
set (CMAKE_POSITION_INDEPENDENT_CODE TRUE)
set (CMAKE_CXX_STANDARD 11)
set (CMAKE_INCLUDE_CURRENT_DIR ON)
set (CMAKE_AUTOMOC ON)

set(RPCLIB_DEPENDENCIES "${rpclib_SOURCE_DIR}/dependencies")
file(GLOB_RECURSE DEP_HEADERS
    ${RPCLIB_DEPENDENCIES}/include/*.h)
set(DEP_SOURCES
    ${RPCLIB_DEPENDENCIES}/src/format.cc
    ${RPCLIB_DEPENDENCIES}/src/posix.cc)

add_library(${PROJECT_NAME} SHARED utils_manager.cc ${DEP_SOURCES})

target_link_libraries(${PROJECT_NAME}
    rpc::rpclib
    Threads::Threads
    $<$<BOOL:${AGL}>:rt>
    $<$<BOOL:${LINUX}>:rt>
    $<$<BOOL:${QNXNTO}>:socket>
    $<$<BOOL:${QNXNTO}>:backtrace.a>
    $<$<BOOL:${QNXNTO}>:stdc++>)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../common
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

#
# Unit tests
#
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()

install(TARGETS ${PROJECT_NAME}
    DESTINATION "${CMAKE_INSTALL_PREFIX}/${ROOT_PROJECT_NAME}"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)
