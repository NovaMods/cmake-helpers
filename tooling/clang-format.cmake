if(NOT CLANG_FORMAT_COMMAND)
    set(CLANG_FORMAT_COMMAND "clang-format-9" "clang-format-8" "clang-format-7" "clang-format")
endif()

find_program(CLANG_FORMAT_PROGRAM NAMES ${CLANG_FORMAT_COMMAND})

if(CLANG_FORMAT_PROGRAM)
    execute_process(COMMAND "${CLANG_FORMAT_PROGRAM}" "--version"
                    OUTPUT_VARIABLE CLANG_TIDY_VERSION_FULL_STRING)
    string(REGEX MATCH [=[[0-9]\.[0-9]\.[0-9]]=] VERSION "${CLANG_TIDY_VERSION_FULL_STRING}")
    if(VERSION VERSION_LESS "7.0.0")
        message(STATUS "clang-format version ${VERSION} is not greater or equal to 7.0.0")
        set(CLANG_FORMAT_TERMINATE On)
    endif()
else()
    message(STATUS "clang-format not found")
    set(CLANG_FORMAT_TERMINATE On)
endif()

if(CLANG_FORMAT_TERMINATE)
    message(STATUS "Disabling formatting.")
    function(format)
        # no-op
    endfunction()
    return()
endif()

message(STATUS "Found clang-format at ${CLANG_FORMAT_PROGRAM}")

if(NOT TARGET format)
    add_custom_target(format VERBATIM)
    set_target_properties(format PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD True)
endif()
if(NOT TARGET reformat)
    add_custom_target(reformat VERBATIM)
    set_target_properties(reformat PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD True)
endif()

file(GLOB_RECURSE CLANG_FORMAT_PATHS CONFIGURE_DEPENDS "*.clang-format")
foreach(PATH ${CLANG_FORMAT_PATHS})
    message(STATUS "Found .clang-format at ${PATH}")
endforeach()

function(target_format _target)
    list(APPEND TOUCH_PATHS)

    get_property(_target_sources TARGET ${_target} PROPERTY SOURCES)
    get_property(_target_dir TARGET ${_target} PROPERTY SOURCE_DIR)
    list(APPEND _full_sources_list ${_target_sources} ${ARGN})
    list(LENGTH _full_sources_list _sources_count)
    if ("${_sources_count}" GREATER_EQUAL 2)
        list(REMOVE_DUPLICATES _full_sources_list)
    endif()
    foreach(_source_file ${_full_sources_list})
        if(_source_file MATCHES [=[^([A-Z]:)?/.*$]=])
            set(_full_source_paths "${_source_file}")
        else()
            set(_full_source_paths "${_target_dir}/${_source_file}")
        endif()
        file(RELATIVE_PATH _rel_path "${CMAKE_SOURCE_DIR}" "${_full_source_paths}")

        set(_full_touch_path "${CMAKE_BINARY_DIR}/${_rel_path}.format.touch")
        get_filename_component(_touch_dir "${_full_touch_path}" DIRECTORY)
        list(APPEND TOUCH_PATHS "${_full_touch_path}")

        file(MAKE_DIRECTORY "${_touch_dir}")
        add_custom_command(
            OUTPUT "${_full_touch_path}"
            COMMAND "${CLANG_FORMAT_PROGRAM}" -i -style=file "${_source_file}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${_full_touch_path}"
            DEPENDS "${_full_source_paths}" ${CLANG_FORMAT_PATHS}
            COMMENT "${_source_file}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        )
    endforeach()

    add_custom_target(${_target}-format VERBATIM DEPENDS ${TOUCH_PATHS})
    add_custom_target(
        ${_target}-reformat VERBATIM 
        COMMAND "${CMAKE_COMMAND}" -E remove ${TOUCH_PATHS}
        COMMENT "Clearing format dependencies"
    )
    set_target_properties(${_target}-format PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD True FOLDER CMakePredefinedTargets/format)
    set_target_properties(${_target}-reformat PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD True FOLDER CMakePredefinedTargets/reformat)

    add_dependencies(format ${_target}-format)
    add_dependencies(reformat ${_target}-reformat)
endfunction()
