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

# Find FFmpeg libraries for AAC+ streaming
find_library(AVCODEC_LIBRARY NAMES avcodec libavcodec PATHS /usr/lib/x86_64-linux-gnu)
find_library(AVFORMAT_LIBRARY NAMES avformat libavformat PATHS /usr/lib/x86_64-linux-gnu)
find_library(AVUTIL_LIBRARY NAMES avutil libavutil PATHS /usr/lib/x86_64-linux-gnu)
find_library(SWRESAMPLE_LIBRARY NAMES swresample libswresample PATHS /usr/lib/x86_64-linux-gnu)

if(AVCODEC_LIBRARY AND AVFORMAT_LIBRARY AND AVUTIL_LIBRARY AND SWRESAMPLE_LIBRARY)
    message(STATUS "Found FFmpeg libraries for AAC+ streaming:")
    message(STATUS "  AVCODEC: ${AVCODEC_LIBRARY}")
    message(STATUS "  AVFORMAT: ${AVFORMAT_LIBRARY}")
    message(STATUS "  AVUTIL: ${AVUTIL_LIBRARY}")
    message(STATUS "  SWRESAMPLE: ${SWRESAMPLE_LIBRARY}")
    
    set(FFMPEG_LIBRARIES
        ${AVCODEC_LIBRARY}
        ${AVFORMAT_LIBRARY}
        ${AVUTIL_LIBRARY}
        ${SWRESAMPLE_LIBRARY}
    )
    
    set(BUILD_AAC_STREAMER TRUE)
else()
    message(STATUS "FFmpeg libraries not found - AAC+ streamer will not be built")
    set(BUILD_AAC_STREAMER FALSE)
endif()

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

# Create the rdx-aac-streamer executable if FFmpeg is available
if(BUILD_AAC_STREAMER)
    add_executable(rdx-aac-streamer
        rdx_aac_streamer.cpp
    )
endif()

# Link libraries (RDX extension mode - no Rivendell direct linking)
target_link_libraries(rdx-jack-helper
    ${Qt5Core_LIBRARIES}
    ${Qt5DBus_LIBRARIES}
    ${Qt5Network_LIBRARIES}
    /usr/lib/x86_64-linux-gnu/libjack.so
    asound
    pthread
)

# Link FFmpeg libraries for AAC streamer
if(BUILD_AAC_STREAMER)
    target_link_libraries(rdx-aac-streamer
        ${FFMPEG_LIBRARIES}
        pthread
    )
endif()

# Install the executables
if(BUILD_AAC_STREAMER)
    install(TARGETS rdx-jack-helper rdx-aac-streamer DESTINATION /usr/local/bin)
else()
    install(TARGETS rdx-jack-helper DESTINATION /usr/local/bin)
endif()

# Install AAC+ streaming script
install(FILES rdx-aac-stream.sh
    DESTINATION /usr/local/bin
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# Create symbolic link for easier access
install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink 
    /usr/local/bin/rdx-aac-stream.sh /usr/local/bin/rdx-aac-stream)")

# Install systemd service file
configure_file(rdx-jack-helper.service.in rdx-jack-helper.service @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/rdx-jack-helper.service 
        DESTINATION /etc/systemd/system)