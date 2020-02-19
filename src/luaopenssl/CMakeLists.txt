project(luaopenssl)
cmake_minimum_required(VERSION 3.11)

find_package(OpenSSL REQUIRED)

add_library(${PROJECT_NAME} SHARED
    lua_openssl.cc)

target_link_libraries(${PROJECT_NAME}
    ${OPENSSL_LIBRARIES})

target_include_directories(${PROJECT_NAME} PRIVATE
    ${OPENSSL_INCLUDE_DIRS})

install(TARGETS ${PROJECT_NAME}
    DESTINATION "${CMAKE_INSTALL_PREFIX}/lib"
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    COMPONENT sdl_atf)
