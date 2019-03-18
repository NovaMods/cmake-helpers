if(WIN32)
    set(OS_WINDOWS 1)
elseif (APPLE)
    set(OS_OSX 1)
elseif(UNIX AND NOT APPLE)
    set(OS_LINUX 1)
else()
    message(FATAL_ERROR "Unsupported Platform")
endif()

if (CMAKE_SIZEOF_VOID_P STREQUAL "8")
	set(OS_64bit)
else()
	set(OS_32bit)
endif()