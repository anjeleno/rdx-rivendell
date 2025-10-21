# RDX GUI Components CMakeLists.txt
# Builds RDX GUI integration for RDAdmin

cmake_minimum_required(VERSION 3.16)

# Find required Qt5 components for GUI
find_package(Qt5 REQUIRED COMPONENTS Core Widgets DBus Sql)

# Find Rivendell libraries for proper linking
find_library(RD_LIBRARY NAMES rd librd PATHS /usr/lib /usr/local/lib)
find_library(RDCONF_LIBRARY NAMES rdconf librdconf PATHS /usr/lib /usr/local/lib)

if(RD_LIBRARY)
    message(STATUS "Found Rivendell library: ${RD_LIBRARY}")
    set(RIVENDELL_LIBRARIES ${RD_LIBRARY})
    if(RDCONF_LIBRARY)
        list(APPEND RIVENDELL_LIBRARIES ${RDCONF_LIBRARY})
        message(STATUS "Found Rivendell config library: ${RDCONF_LIBRARY}")
    endif()
    
    # Find all multimedia dependencies that Rivendell needs
    find_library(CURL_LIBRARY curl)
    find_library(VORBIS_LIBRARY vorbis)
    find_library(VORBISENC_LIBRARY vorbisenc)
    find_library(VORBISFILE_LIBRARY vorbisfile)
    find_library(OGG_LIBRARY ogg)
    find_library(FLAC_LIBRARY FLAC)
    find_library(FLACPP_LIBRARY FLAC++)
    find_library(SNDFILE_LIBRARY sndfile)
    find_library(TAG_LIBRARY tag)
    find_library(MUSICBRAINZ5_LIBRARY musicbrainz5)
    find_library(SSL_LIBRARY ssl)
    find_library(CRYPTO_LIBRARY crypto)
    find_library(PAM_LIBRARY pam)
    find_library(SRC_LIBRARY samplerate)
    find_library(SOUNDTOUCH_LIBRARY SoundTouch)
    find_library(MAGICKPP_LIBRARY Magick++)
    find_library(DISCID_LIBRARY discid)
    find_library(ID3_LIBRARY id3)
    find_library(COVERARTARCHIVE_LIBRARY coverartarchive)
    
    # Find FFmpeg libraries for AAC+ streaming support
    find_library(AVCODEC_LIBRARY avcodec)
    find_library(AVFORMAT_LIBRARY avformat)
    find_library(AVUTIL_LIBRARY avutil)
    find_library(SWRESAMPLE_LIBRARY swresample)
    find_library(SWSCALE_LIBRARY swscale)
    find_library(X264_LIBRARY x264)
    
    # Create list of multimedia libraries (filtering out empty ones)
    set(MULTIMEDIA_LIBRARIES)
    foreach(lib ${CURL_LIBRARY} ${VORBIS_LIBRARY} ${VORBISENC_LIBRARY} ${VORBISFILE_LIBRARY} 
                ${OGG_LIBRARY} ${FLAC_LIBRARY} ${FLACPP_LIBRARY} ${SNDFILE_LIBRARY} 
                ${TAG_LIBRARY} ${MUSICBRAINZ5_LIBRARY} ${SSL_LIBRARY} ${CRYPTO_LIBRARY} 
                ${PAM_LIBRARY} ${SRC_LIBRARY} ${SOUNDTOUCH_LIBRARY} ${MAGICKPP_LIBRARY} 
                ${DISCID_LIBRARY} ${ID3_LIBRARY} ${COVERARTARCHIVE_LIBRARY}
                ${AVCODEC_LIBRARY} ${AVFORMAT_LIBRARY} ${AVUTIL_LIBRARY} 
                ${SWRESAMPLE_LIBRARY} ${SWSCALE_LIBRARY} ${X264_LIBRARY})
        if(lib)
            list(APPEND MULTIMEDIA_LIBRARIES ${lib})
            message(STATUS "Found multimedia library: ${lib}")
        endif()
    endforeach()
else()
    message(STATUS "Rivendell libraries not found - building standalone GUI")
    set(RIVENDELL_LIBRARIES "")
    set(MULTIMEDIA_LIBRARIES "")
endif()

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

# Link Qt5 and Rivendell libraries
target_link_libraries(rdx-gui
    Qt5::Core
    Qt5::Widgets
    Qt5::DBus
    Qt5::Sql
    ${RIVENDELL_LIBRARIES}
    ${MULTIMEDIA_LIBRARIES}
)

# Include directories
target_include_directories(rdx-gui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)

# Create standalone GUI executable
add_executable(rdx-gui-app main.cpp)
target_link_libraries(rdx-gui-app 
    rdx-gui 
    Qt5::Core 
    Qt5::Widgets 
    Qt5::DBus 
    Qt5::Sql
    Qt5::Network
    ${RIVENDELL_LIBRARIES}
    ${MULTIMEDIA_LIBRARIES}
)

# Set properties
set_target_properties(rdx-gui PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED ON
)

set_target_properties(rdx-gui-app PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED ON
    OUTPUT_NAME rdx-gui
)

# Installation
install(TARGETS rdx-gui rdx-gui-app
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES ${RDX_GUI_HEADERS}
    DESTINATION include/rdx
)