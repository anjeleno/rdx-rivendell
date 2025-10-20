# RDX GUI Components CMakeLists.txt
# Builds RDX GUI integration for RDAdmin

cmake_minimum_required(VERSION 3.16)

# Find required Qt5 components for GUI
find_package(Qt5 REQUIRED COMPONENTS Core Widgets DBus)

# Add RDX GUI library
set(RDX_GUI_SOURCES
    rdx_jack_dialog.cpp
    rdx_integration.cpp
)

set(RDX_GUI_HEADERS  
    rdx_jack_dialog.h
    rdx_integration.h
)

# Create RDX GUI library
add_library(rdx-gui STATIC ${RDX_GUI_SOURCES} ${RDX_GUI_HEADERS})

# Link Qt5 libraries
target_link_libraries(rdx-gui
    Qt5::Core
    Qt5::Widgets
    Qt5::DBus
)

# Include directories
target_include_directories(rdx-gui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)

# Set properties
set_target_properties(rdx-gui PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED ON
)

# Installation
install(TARGETS rdx-gui
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(FILES ${RDX_GUI_HEADERS}
    DESTINATION include/rdx
)