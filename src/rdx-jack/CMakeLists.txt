# RDX JACK Enhancement CMakeLists.txt

set(RDX_JACK_SOURCES
    rdx_jack_manager.cpp
    rdx_jack_service.cpp
    main.cpp
)

set(RDX_JACK_HEADERS
    ${CMAKE_SOURCE_DIR}/include/rdx/rdx_jack_manager.h
    rdx_jack_service.h
)

# Qt5 MOC processing
qt5_wrap_cpp(RDX_JACK_MOC_SOURCES 
    ${CMAKE_SOURCE_DIR}/include/rdx/rdx_jack_manager.h
    rdx_jack_service.h
)

# Create the rdx-jack-helper executable
add_executable(rdx-jack-helper
    ${RDX_JACK_SOURCES}
    ${RDX_JACK_MOC_SOURCES}
)

# Link libraries (RDX extension mode - no Rivendell direct linking)
target_link_libraries(rdx-jack-helper
    ${Qt5Core_LIBRARIES}
    ${Qt5DBus_LIBRARIES}
    ${Qt5Network_LIBRARIES}
    /usr/lib/x86_64-linux-gnu/libjack.so
    asound
    pthread
)

# Install the executable
install(TARGETS rdx-jack-helper DESTINATION /usr/local/bin)

# Install systemd service file
configure_file(rdx-jack-helper.service.in rdx-jack-helper.service @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/rdx-jack-helper.service 
        DESTINATION /etc/systemd/system)