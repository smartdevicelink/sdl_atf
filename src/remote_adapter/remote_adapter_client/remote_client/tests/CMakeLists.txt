set(TEST_PROJECT_NAME ${PROJECT_NAME}_test)
set(TEST_SOURCES
    ${RPCLIB_DEPENDENCIES}/src/gmock-gtest-all.cc
    testmain.cc
    remote_client_test.cc)

add_executable(${TEST_PROJECT_NAME} ${TEST_SOURCES})

target_include_directories(${TEST_PROJECT_NAME}
    SYSTEM PRIVATE "${PROJECT_SOURCE_DIR}/tests"
    SYSTEM PRIVATE "${PROJECT_SOURCE_DIR}/remote_client/"
    SYSTEM PRIVATE "${PROJECT_SOURCE_DIR}/../"
    PRIVATE "${RPCLIB_DEPENDENCIES}/include"
    PRIVATE "${rpclib_SOURCE_DIR}/include")

target_link_libraries(${TEST_PROJECT_NAME} ${PROJECT_NAME} Threads::Threads)

# Set less strict warning for tests, since google test is not quite
# warning-clean
if (${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
    get_target_property(ORIGINAL_FLAGS ${TEST_PROJECT_NAME} COMPILE_OPTION)
    target_compile_options(${TEST_PROJECT_NAME} PRIVATE -Wno-sign-conversion -Wno-weak-vtables -Wno-unused-member-function
        -Wno-global-constructors -Wno-used-but-marked-unused -Wno-covered-switch-default
        -Wno-missing-variable-declarations -Wno-deprecated -Wno-unused-macros -Wno-undef
        -Wno-exit-time-destructors -Wno-switch-enum -Wno-format-nonliteral -Wno-unused-parameter -Wno-disabled-macro-expansion)
endif()

add_test (NAME ${TEST_PROJECT_NAME} COMMAND ${TEST_PROJECT_NAME})
