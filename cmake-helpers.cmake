list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/modules" "${CMAKE_CURRENT_LIST_DIR}/sanitizers")

include("${CMAKE_CURRENT_LIST_DIR}/utilities/os.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/cotire/cotire.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/tooling/clang-format.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/tooling/clang-tidy.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/tooling/coverage.cmake")

find_package(Sanitizers REQUIRED)

include("${CMAKE_CURRENT_LIST_DIR}/utilities/compile-options-if-supported.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/utilities/include-target.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/utilities/remove-permissive.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/utilities/target-includes-system.cmake")

include("${CMAKE_CURRENT_LIST_DIR}/languages/ispc.cmake")
