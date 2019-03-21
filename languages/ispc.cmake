# windows: https://cwfitz.com/s/19079-081337-ispc.exe
# darwin: https://cwfitz.com/s/19079-081248-ispc
# linux: https://cwfitz.com/s/19079-081319-ispc

cmake_minimum_required(VERSION 3.12)

find_program(ISPC_PATH ispc)

if(ISPC_PATH)
	message(STATUS "Found ISPC at ${ISPC_PATH}")
else()
	message(STATUS "Couldn't find ISPC.")
	function(add_ispc_object_library)
		message(FATAL_ERROR "ISPC not found and is required.")
	endfunction()
	return()
endif()
	

function(add_ispc_object_library target)
	set(options 64BIT_ADDRESSING INSTRUMENT NOSTDLIB NOCPP PIC)
	set(one_value_args HEADER_PATH)
	set(multi_value_args FLAGS INCLUDE_DIRS TARGETS)
	cmake_parse_arguments(OPTION "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN} )

	# Object file extension
	if(OS_WINDOWS)
		set(obj_ext "obj")
	else()
		set(obj_ext "o")
	endif()

	# For readability
	set(sources ${OPTION_UNPARSED_ARGUMENTS})

	set(arguments)

	# Targets
	set(targets 
		"sse2"      "sse2-x2" 
		"sse4"      "sse4-x2" 
		"avx1"      "avx1-x2" 
		"avx1.1"    "avx1.1x-2" 
		"avx2"      "avx2-x2" 
		"avx512knl"
		"avx512skx"
	)

	set(target_list)
	set(target_comma_list)
	set(target_filenames)

	# Sanity check targets
	list(LENGTH OPTION_TARGETS target_count)
	if(target_count EQUAL 0)
		message(FATAL_ERROR "Must specifiy ISPC targets!")
	endif()

	foreach(target ${OPTION_TARGETS})
		# Must be one of the known targets, we must transform it in multiple ways.
		if(NOT (target IN_LIST targets))
			message(FATAL_ERROR "Unknown ISPC target ${target}")
		endif()

		# The actual filename does not have the `-x2` or the `.` (in `avx1.1`).
		# This is annoying, but fixable.
		string(REPLACE "." "" target_filename "${target}")
		string(REPLACE "-x2" "" target_filename "${target_filename}")

		# The `avx1` target's suffix is `avx`.
		if(target MATCHES "avx1(-x2)?$")
			set(target_filename "avx")
		endif()

		# avx512 doesn't have short aliases, add full target name
		if(target MATCHES "avx512")
			set(target ${target}-i32x16)
		endif()

		list(APPEND target_list ${target})
		list(APPEND target_filenames ${target_filename})
		set(target_comma_list "${target_comma_list},${target}")
	endforeach()
	# Remove the first comma
	string(SUBSTRING "${target_comma_list}" 1 -1 target_comma_list)

	# Set targets
	set(arguments "${arguments}" "--target=${target_comma_list}")

	# Include Dirs
	foreach(dir ${OPTION_INCLUDE_DIRS})
		set(arguments "${arguments}" "-I" "${dir}")
	endforeach()

	# 64bit Addressing
	if(OPTION_64BIT_ADDRESSING)
		set(arguments "${arguments}" "--addressing=64")
	endif()

	# Instrumentation
	if(OPTION_INSTRUMENT)
		set(arguments "${arguments}" "--instrument")
	endif()

	# No Standard Library
	if(OPTION_NOSTDLIB)
		set(arguments "${arguments}" "--nostdlib")
	endif()

	# No Preprocessor
	if(OPTION_NOCPP)
		set(arguments "${arguments}" "--nocpp")
	endif()

	# Position Independent Code
	if(OPTION_PIC AND (NOT OS_WINDOWS))
		set(arguments "${arguments}" "--pic")
	endif()

	# OS arch
	if(OS_64bit)
		set(arguments "${arguments}" "--arch=x86-64")
	elseif(OS_32bit)
		set(arguments "${arguments}" "--arch=x86")
	else()
		message(FATAL_ERROR "Unknown build bitness.")
	endif()

	# Debug symbols
	if(CMAKE_CONFIGURATION_TYPES)
		set(arguments "${arguments}" $<IF:$<OR:$<STREQUAL:$<CONFIG>,Debug>,$<STREQUAL:$<CONFIG>,RelWithDebInfo>>,-g,>)
	elseif(CMAKE_BUILD_TYPE MATCHES "Debug|RelWithDebInfo")
		set(arguments "${arguments}" "-g")
	endif()


	# Optimization
	if(CMAKE_CONFIGURATION_TYPES)
		set(arguments "${arguments}" "$<IF:$<STREQUAL:$<CONFIG>,Debug>,-O0,-O3>")
		set(arguments "${arguments}" "$<IF:$<STREQUAL:$<CONFIG>,Debug>,-wno-perf,>")
	elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
		set(arguments "${arguments}" "-O0" "-wno-perf")
	elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
		set(arguments "${arguments}" "-O2")
	else()
		set(arguments "${arguments}" "-O3")
	endif()

	# Folders
	set(header_include_path "${CMAKE_CURRENT_BINARY_DIR}/ispc/include/")
	set(header_output_path "${header_include_path}/${OPTION_HEADER_PATH}")
	file(MAKE_DIRECTORY "${header_output_path}")

	# Actually call ispc
	set(ispc_objects)
	foreach(file ${sources})
		if(NOT (EXISTS "${file}"))
			message(FATAL_ERROR "File ${file} not found.")
		endif()

		# Various versions of the file path
		get_filename_component(basename "${file}" NAME)
		get_filename_component(noextant "${file}" NAME_WE)
		get_filename_component(dir "${file}" DIRECTORY)
		file(RELATIVE_PATH reldir "${CMAKE_CURRENT_SOURCE_DIR}" "${dir}")

		if(basename MATCHES ".*\\.ispc")
			# Mark source file as a header so cmake doesn't try to build it, but we can
			# keep it in the target so it shows up in IDEs
			set_source_files_properties("${file}" PROPERTIES HEADER_FILE_ONLY TRUE)

			# ISPC does many things with exact header/obj file names. These are some templates.
			set(output_header_template "${CMAKE_CURRENT_BINARY_DIR}/ispc/include/${OPTION_HEADER_PATH}/${noextant}")
			set(output_obj_folder "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target}.dir/${reldir}")
			set(output_obj_template "${output_obj_folder}/${noextant}")

			file(MAKE_DIRECTORY "${output_obj_folder}")

			# Ensure that the non-suffixed file is added.
			set(output_headers "${output_header_template}.h")
			set(output_objects "${output_obj_template}.${obj_ext}")
			# Add all suffixed files (only generated if targeting more than one target)
			if(target_count GREATER_EQUAL 2)
				foreach(name ${target_filenames})
					list(APPEND output_headers "${output_header_template}_${name}.h")
					list(APPEND output_objects "${output_obj_template}_${name}.${obj_ext}")
				endforeach()
			endif()

			file(RELATIVE_PATH obj_display "${CMAKE_CURRENT_SOURCE_DIR}" "${output_obj_template}.${obj_ext}")

			# Call ISPC
			add_custom_command(
				OUTPUT ${output_headers} ${output_objects}
				COMMAND ${ISPC_PATH} ${arguments} -o "${output_obj_template}.${obj_ext}" -h "${output_header_template}.h" "${file}"
				DEPENDS "${file}"
				COMMENT "Building ISPC object ${obj_display}"
				VERBATIM
			)

			list(APPEND ispc_objects ${output_objects})
		endif()
	endforeach()

	# Pass objects to add_library to create a dependency on them
	add_library(${target} OBJECT ${sources} ${ispc_objects})
	# Include path to generated includes
	target_include_directories(${target} PUBLIC "${header_include_path}")
	# Link against objects to make sure the symbols show up. Something funky happens with object libraries and actual objects :thinking:
	target_link_libraries(${target} PUBLIC ${ispc_objects})
	# For safety
	set_target_properties(${target} PROPERTIES LINKER_LANGUAGE C)
endfunction()
