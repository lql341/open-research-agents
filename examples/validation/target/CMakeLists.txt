cmake_minimum_required(VERSION 3.20)
project(cfd_validation LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(cfd_core INTERFACE)
target_include_directories(cfd_core INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})

add_library(cfd_spatial STATIC modules/spatial/upwind.cpp)
target_link_libraries(cfd_spatial PUBLIC cfd_core)

enable_testing()

add_executable(core_test tests/unit/core_test.cpp)
target_link_libraries(core_test PRIVATE cfd_core)
add_test(NAME core_test COMMAND core_test)
set_tests_properties(core_test PROPERTIES LABELS unit)

# Numerical verification case (human-owned). It uses only the public API, so it
# stays valid whatever the worker's internal implementation looks like.
add_executable(adv_mms verification/adv_mms.cpp)
target_link_libraries(adv_mms PRIVATE cfd_spatial)
