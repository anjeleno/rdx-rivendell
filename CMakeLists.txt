# RDX Enhanced JACK Management System
# Build configuration for enhanced Rivendell JACK components

cmake_minimum_required(VERSION 3.16)
project(rdx-rivendell VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Qt5 REQUIRED COMPONENTS Core Widgets DBus Network)
find_package(PkgConfig REQUIRED)

# Find JACK
pkg_check_modules(JACK REQUIRED jack)

# Find ALSA (for device discovery)
pkg_check_modules(ALSA REQUIRED alsa)

# Find Rivendell libraries (for reference - RDX works as extension)
find_library(RD_LIB rd PATHS /usr/lib /usr/local/lib)
find_library(RDCONF_LIB rdconf PATHS /usr/lib /usr/local/lib)

if(RD_LIB AND RDCONF_LIB)
    message(STATUS "Found Rivendell libraries: ${RD_LIB}, ${RDCONF_LIB}")
    message(STATUS "RDX will integrate with existing Rivendell ${RIVENDELL_VERSION} installation")
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
    ${Qt5Widgets_INCLUDE_DIRS} 
    ${Qt5DBus_INCLUDE_DIRS}
    ${Qt5Network_INCLUDE_DIRS}
    ${JACK_INCLUDE_DIRS}
    ${ALSA_INCLUDE_DIRS}
    # Note: RDX integrates as extension - no Rivendell headers needed
)

# Compiler flags
add_compile_options(${Qt5Core_CFLAGS} ${Qt5Widgets_CFLAGS} ${Qt5DBus_CFLAGS})
add_compile_options(${JACK_CFLAGS} ${ALSA_CFLAGS})

# Define JACK support
add_definitions(-DJACK)

# RDX JACK Helper Service
add_subdirectory(src/rdx-jack)

# RDX Admin Plugin
add_subdirectory(src/rdx-admin)

# Install configuration files
install(FILES config/rdx-profiles.xml DESTINATION /etc/rdx)
install(FILES config/rdx-jack.conf DESTINATION /etc/rdx)

# Install desktop files
install(FILES config/rdx-jack-config.desktop DESTINATION /usr/share/applications)