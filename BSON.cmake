set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}")
set(CMAKE_SOURCE_PREFIX ${CMAKE_SOURCE_PREFIX} "${CMAKE_INSTALL_PREFIX}")

find_package (BSON)

if (${BSON_LIB} MATCHES "BSON_LIB-NOTFOUND")
    message (STATUS "Building bson required")
    set(BSON_LIB_SOURCE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bson_c_lib CACHE INTERNAL "Sources of bson library" FORCE)
    set(BSON_LIBS_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib CACHE INTERNAL "Installation path of bson libraries" FORCE)
    set(BSON_INCLUDE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/include CACHE INTERNAL "Installation path of bson headers" FORCE)
    set(EMHASHMAP_LIBS_DIRECTORY ${CMAKE_INSTALL_PREFIX}/lib CACHE INTERNAL "Installation path of emashmap libraries" FORCE)
    set(EMHASHMAP_INCLUDE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/include CACHE INTERNAL "Installation path of emashmap headers" FORCE)

    set(BSON_INSTALL_COMMAND make install)
    if (${CMAKE_INSTALL_PREFIX} MATCHES "/usr/local")
        set(BSON_INSTALL_COMMAND sudo make install)
    endif()
    set(BSON_CONFIGURE_FLAGS
        "--with-lua-wrapper=yes"
        "CPPFLAGS=-I${BSON_LIB_SOURCE_DIRECTORY}/src")
    include(ExternalProject)
    ExternalProject_Add(libbson
        GIT_REPOSITORY "http://github.com/smartdevicelink/bson_c_lib.git"
        GIT_TAG "master"
        BINARY_DIR ${BSON_LIB_SOURCE_DIRECTORY}
        INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
        DOWNLOAD_DIR ${BSON_LIB_SOURCE_DIRECTORY}
        SOURCE_DIR ${BSON_LIB_SOURCE_DIRECTORY}
        CONFIGURE_COMMAND touch aclocal.m4 configure.ac Makefile.am Makefile.in configure config.h.in && ./configure ${BSON_CONFIGURE_FLAGS} --prefix=${CMAKE_INSTALL_PREFIX}
        BUILD_COMMAND make
        INSTALL_COMMAND ${BSON_INSTALL_COMMAND})
else()
    get_filename_component(BSON_LIBS_DIRECTORY ${BSON_LIB} DIRECTORY)
    get_filename_component(EMHASHMAP_LIBS_DIRECTORY ${EMHASHMAP_LIB} DIRECTORY)
    message (STATUS "bson installed in: " ${BSON_LIBS_DIRECTORY} " , " ${BSON_INCLUDE_DIRECTORY})
    message (STATUS "emhashmap installed in: " ${EMHASHMAP_LIBS_DIRECTORY} " , " ${EMHASHMAP_INCLUDE_DIRECTORY})
    set(BSON_LIBS_DIRECTORY ${BSON_LIBS_DIRECTORY} CACHE INTERNAL "Installation path of bson libraries" FORCE)
    set(EMHASHMAP_LIBS_DIRECTORY ${BSON_LIBS_DIRECTORY} CACHE INTERNAL "Installation path of emashmap libraries" FORCE)
    add_custom_target(libbson
        DEPENDS ${BSON_LIBS_DIRECTORY}
        DEPENDS ${EMHASHMAP_LIBS_DIRECTORY})
endif()
