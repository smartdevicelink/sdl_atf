project(xml)
cmake_minimum_required(VERSION 3.11)

find_package(LibXml2 REQUIRED)
add_library(${PROJECT_NAME} SHARED
             lua_xml.cc)

target_link_libraries(${PROJECT_NAME}
                       ${LIBXML2_LIBRARIES}
	               lua::lua)

target_include_directories(${PROJECT_NAME} PRIVATE
                            ${LIBXML2_INCLUDE_DIR})

install(
  TARGETS ${PROJECT_NAME}
  DESTINATION "${CMAKE_INSTALL_PREFIX}/lib"
  PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
  COMPONENT sdl_atf
)
