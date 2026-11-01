cmake_minimum_required(VERSION 3.20)
project(cfd_mini LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(cfd_core INTERFACE)
target_include_directories(cfd_core INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})

add_library(cfd_spatial STATIC modules/spatial/upwind.cpp)
target_link_libraries(cfd_spatial PUBLIC cfd_core)

add_library(cfd_temporal STATIC modules/temporal/forward_euler.cpp)
target_link_libraries(cfd_temporal PUBLIC cfd_core cfd_spatial)

enable_testing()

add_executable(core_test tests/unit/core_test.cpp)
target_link_libraries(core_test PRIVATE cfd_core)
add_test(NAME core_test COMMAND core_test)
set_tests_properties(core_test PROPERTIES LABELS unit)
