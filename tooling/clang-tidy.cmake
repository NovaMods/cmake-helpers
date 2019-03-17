if(MSVC)
    message(STATUS "Windows detected, disabling linting.")
    return()
endif()

set(_clang_tidy_cmake_list_dir ${CMAKE_CURRENT_LIST_DIR})

if(NOT CLANG_TIDY_COMMAND)
    set(CLANG_TIDY_COMMAND
        "clang-tidy-9"
        "clang-tidy-8"
        "clang-tidy-7"
        "clang-tidy-6.0"
        "clang-tidy"
        CACHE STRING "Possible names of clang-tidy")
endif()

if(NOT CLANG_APPLY_REPLACEMENTS_COMMAND)
    set(CLANG_APPLY_REPLACEMENTS_COMMAND 
        "clang-apply-replacements-9"
        "clang-apply-replacements-8"
        "clang-apply-replacements-7"
        "clang-apply-replacements-6.0"
        "clang-apply-replacements"
        CACHE STRING "Possible names of clang-apply-replacements")
endif()

find_program(CLANG_TIDY_PROGRAM NAMES ${CLANG_TIDY_COMMAND})
if(NOT CLANG_TIDY_PROGRAM)
    message(STATUS "clang-tidy not found")
    # function(lint)
    #     # no-op
    # endfunction()
    return()
endif()

message(STATUS "Found clang-tidy at ${CLANG_TIDY_PROGRAM}")
set(CMAKE_EXPORT_COMPILE_COMMANDS On)

find_package(Python3)

find_program(CLANG_APPLY_REPLACEMENTS_PROGRAM NAMES ${CLANG_APPLY_REPLACEMENTS_COMMAND})
if(CLANG_APPLY_REPLACEMENTS_PROGRAM AND CLANG_FORMAT_PROGRAM)
    message(STATUS "Found clang-apply-replacements at ${CLANG_APPLY_REPLACEMENTS_PROGRAM}")
else()
    message(STATUS "clang-apply-replacements not found")
endif()

if(NOT Python3_FOUND)
    message(STATUS "Python3 not found, disabling linting.")
    return()
endif()

# Takes folders to lint in relative to source directory, one per argument
function(enable_linting)
    set(_args ${ARGN})

    if("${ARGC}"" LESS 1)
        message(FATAL_ERROR "Linting must lint at least one folder")
    endif()

    set(_comma_separated "")
    set(_pipe_separated "")
    foreach(folder ${_args})
        set(_comma_separated "${_comma_separated},${folder}")
        set(_pipe_separated "${_pipe_separated}|${folder}")
    endforeach()

    #remove last char
    string(LENGTH "${_comma_separated}" _length)
    math(EXPR _length_wo_one ${_length} - 1)
    string(SUBSTRING "${_comma_separated}" 0 "${_length_wo_one}" _comma_separated)
    string(SUBSTRING "${_pipe_separated}" 0 "${_length_wo_one}" _pipe_separated)

    set(_lint_bash_path "${CMAKE_CURRENT_BINARY_DIR}/tools/lint.bash")

    # configure and copy bash script
    configure_file("${_clang_tidy_cmake_list_dir}/lint.bash.in" "${CMAKE_CURRENT_BINARY_DIR}/tools/unexec/lint.bash" @ONLY NEWLINE_STYLE LF)
    file(COPY "${CMAKE_CURRENT_BINARY_DIR}/tools/unexec/lint.bash"
        DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/tools"
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
        GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    file(REMOVE_RECURSE "${CMAKE_CURRENT_BINARY_DIR}/tools/unexec")

    # status
    message(STATUS "Linting enabled through ${CMAKE_CURRENT_BINARY_DIR}/tools/lint.bash")

    # targets
    add_custom_target(lint "${_lint_bash_path}" "--sort" "file" USES_TERMINAL)
    add_custom_target(lint-by-file "${_lint_bash_path}" "--sort" "file" USES_TERMINAL)
    add_custom_target(lint-by-diagnostic "${_lint_bash_path}" "--sort" "diagnostic"  USES_TERMINAL)

    # autofix
    if(CLANG_APPLY_REPLACEMENTS_PROGRAM AND CLANG_FORMAT_PROGRAM)
        add_custom_target(
            lint-fix 
            COMMAND "${_lint_bash_path}" "--sort" "file" "--fix" "--clang-apply-replacements" "${CLANG_APPLY_REPLACEMENTS_PROGRAM}" 
            COMMAND "${CMAKE_COMMAND}" "--build" "." "--target" "format"
            USES_TERMINAL
        )
    endif()
endfunction()    

if(TARGET all_pch)
    add_dependencies(lint all_pch)
    add_dependencies(lint-by-file all_pch)
    add_dependencies(lint-by-diagnostic all_pch)
    add_dependencies(lint-fix all_pch)
endif()
