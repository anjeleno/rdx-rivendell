# RDX Enhanced JACK Management System
# Build configuration for enhanced Rivendell JACK components

cmake_minimum_required(VERSION 3.16)
project(rdx-rivendell VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build options
option(GUI_SUPPORT "Build GUI components" ON)
option(JACK_SUPPORT "Build JACK components" ON)
option(RIVENDELL_API_SUPPORT "Build with Rivendell Web API support" ON)

# Find required packages
find_package(Qt5 REQUIRED COMPONENTS Core DBus Network)
find_package(PkgConfig REQUIRED)

# Find JACK
if(JACK_SUPPORT)
    pkg_check_modules(JACK REQUIRED jack)
endif()

# Find ALSA (for device discovery)
pkg_check_modules(ALSA REQUIRED alsa)

# Find Qt5 Widgets for GUI
if(GUI_SUPPORT)
    find_package(Qt5 REQUIRED COMPONENTS Widgets)
    message(STATUS "GUI support enabled - Qt5 Widgets found")
endif()

# Find Rivendell Web API for professional integration
if(RIVENDELL_API_SUPPORT)
    find_path(RIVENDELL_API_INCLUDE_DIR
        NAMES rivwebcapi/rd_common.h
        PATHS /usr/include /usr/local/include
    )
    
    if(RIVENDELL_API_INCLUDE_DIR)
        message(STATUS "Found Rivendell Web API headers at: ${RIVENDELL_API_INCLUDE_DIR}")
        set(RIVENDELL_API_FOUND TRUE)
        add_definitions(-DRIVENDELL_API_SUPPORT)
        include_directories(${RIVENDELL_API_INCLUDE_DIR})
    else()
        message(STATUS "Rivendell Web API not found - install rivendell-dev package")
        set(RIVENDELL_API_FOUND FALSE)
    endif()
endif()

# Find Rivendell headers for GUI integration (fallback to local source)
if(GUI_SUPPORT AND RIVENDELL_INCLUDE_DIR)
    if(EXISTS "${RIVENDELL_INCLUDE_DIR}/rdstation.h")
        message(STATUS "Found Rivendell headers at: ${RIVENDELL_INCLUDE_DIR}")
        set(RIVENDELL_HEADERS_FOUND TRUE)
        add_definitions(-DRIVENDELL_INTEGRATION)
        include_directories(${RIVENDELL_INCLUDE_DIR})
    else()
        message(WARNING "Rivendell headers not found - GUI will be built without RDAdmin integration")
        set(RIVENDELL_HEADERS_FOUND FALSE)
    endif()
elseif(GUI_SUPPORT)
    # Try local source headers
    if(EXISTS "${CMAKE_SOURCE_DIR}/rivendell-v4/lib/rdstation.h")
        message(STATUS "Using local Rivendell headers from source tree")
        set(RIVENDELL_HEADERS_FOUND TRUE)
        add_definitions(-DRIVENDELL_INTEGRATION)
        include_directories("${CMAKE_SOURCE_DIR}/rivendell-v4/lib")
    else()
        message(STATUS "GUI support disabled - no Rivendell headers available")
        set(RIVENDELL_HEADERS_FOUND FALSE)
        set(GUI_SUPPORT OFF)
    endif()
else()
    message(STATUS "GUI support disabled or Rivendell headers not specified")
    set(RIVENDELL_HEADERS_FOUND FALSE)
endif()

# Find Rivendell libraries (for reference - RDX works as extension)
find_library(RD_LIB rd PATHS /usr/lib /usr/local/lib)
find_library(RDCONF_LIB rdconf PATHS /usr/lib /usr/local/lib)

if(RD_LIB AND RDCONF_LIB)
    message(STATUS "Found Rivendell libraries: ${RD_LIB}, ${RDCONF_LIB}")
    message(STATUS "RDX will integrate with existing Rivendell installation")
else()
    message(STATUS "Rivendell libraries not found - RDX will work as standalone extension")
    set(RD_LIB "")
    set(RDCONF_LIB "")
endif()

# RDX works as extension package - no direct Rivendell linking required
add_definitions(-DRDX_EXTENSION_MODE)

# Include directories  
include_directories(
    ${CMAKE_SOURCE_DIR}/include
    ${Qt5Core_INCLUDE_DIRS}
    ${Qt5DBus_INCLUDE_DIRS}
    ${Qt5Network_INCLUDE_DIRS}
    ${ALSA_INCLUDE_DIRS}
)

if(JACK_SUPPORT)
    include_directories(${JACK_INCLUDE_DIRS})
endif()

if(GUI_SUPPORT)
    include_directories(${Qt5Widgets_INCLUDE_DIRS})
endif()

# Compiler flags
add_compile_options(${Qt5Core_CFLAGS} ${Qt5DBus_CFLAGS} ${ALSA_CFLAGS})

if(JACK_SUPPORT)
    add_compile_options(${JACK_CFLAGS})
endif()

if(GUI_SUPPORT)
    add_compile_options(${Qt5Widgets_CFLAGS})
endif()

# Define JACK support
add_definitions(-DJACK)

# RDX JACK Helper Service (always build if JACK support enabled)
if(JACK_SUPPORT)
    add_subdirectory(src/rdx-jack)
endif()

# RDX GUI Components (build only if GUI support enabled)
if(GUI_SUPPORT)
    add_subdirectory(src/rdx-gui)
endif()

# Install configuration files
install(FILES config/rdx-profiles.xml DESTINATION /etc/rdx)
install(FILES config/rdx-jack.conf DESTINATION /etc/rdx)

# Install desktop files
install(FILES config/rdx-jack-config.desktop DESTINATION /usr/share/applications)