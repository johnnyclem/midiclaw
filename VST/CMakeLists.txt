cmake_minimum_required(VERSION 3.14.0)

project(MidiClawVST
    VERSION 1.0.0
    DESCRIPTION "MidiClaw VST3 MIDI Effect Plugin"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- VST3 SDK ---
# Set this to the path where you cloned the VST3 SDK:
#   git clone --recursive https://github.com/steinbergmedia/vst3sdk.git
if(NOT DEFINED VST3_SDK_ROOT)
    set(VST3_SDK_ROOT "${CMAKE_SOURCE_DIR}/vst3sdk" CACHE PATH "Path to VST3 SDK")
endif()

if(NOT EXISTS "${VST3_SDK_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR
        "VST3 SDK not found at: ${VST3_SDK_ROOT}\n"
        "Please clone the VST3 SDK:\n"
        "  cd ${CMAKE_SOURCE_DIR}\n"
        "  git clone --recursive https://github.com/steinbergmedia/vst3sdk.git\n"
        "Or set -DVST3_SDK_ROOT=/path/to/vst3sdk"
    )
endif()

# Add the VST3 SDK
set(SMTG_ADD_VSTGUI OFF CACHE BOOL "" FORCE)  # No VSTGUI needed for MIDI-only plugin
add_subdirectory(${VST3_SDK_ROOT} ${CMAKE_BINARY_DIR}/vst3sdk)

# --- MidiClaw VST3 Plugin ---
set(MIDICLAW_VST_SOURCES
    src/MidiClawCIDs.h
    src/version.h
    src/TokenVocabulary.h
    src/TokenVocabulary.cpp
    src/MidiToken.h
    src/MidiEncoder.h
    src/MidiEncoder.cpp
    src/MidiDecoder.h
    src/MidiDecoder.cpp
    src/MidiClawProcessor.h
    src/MidiClawProcessor.cpp
    src/MidiClawController.h
    src/MidiClawController.cpp
    src/MidiClawFactory.cpp
)

smtg_add_vst3plugin(MidiClawVST ${MIDICLAW_VST_SOURCES})

target_link_libraries(MidiClawVST
    PRIVATE
        sdk
)

target_include_directories(MidiClawVST
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# macOS bundle configuration
if(APPLE)
    set_target_properties(MidiClawVST PROPERTIES
        BUNDLE TRUE
        BUNDLE_EXTENSION "vst3"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.midiclaw.vst3"
        MACOSX_BUNDLE_BUNDLE_NAME "MidiClaw"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/resource/Info.plist.in"
    )
endif()

# Windows resource file
if(WIN32)
    target_sources(MidiClawVST PRIVATE resource/midiclaw.rc)
endif()

smtg_target_configure_version_file(MidiClawVST)

# --- Installation ---
# Install to standard VST3 plugin locations
if(APPLE)
    set(VST3_INSTALL_DIR "$ENV{HOME}/Library/Audio/Plug-Ins/VST3")
elseif(WIN32)
    set(VST3_INSTALL_DIR "$ENV{COMMONPROGRAMFILES}/VST3")
else()
    set(VST3_INSTALL_DIR "$ENV{HOME}/.vst3")
endif()

install(TARGETS MidiClawVST
    LIBRARY DESTINATION "${VST3_INSTALL_DIR}"
    BUNDLE DESTINATION "${VST3_INSTALL_DIR}"
)

message(STATUS "MidiClaw VST3 plugin will be installed to: ${VST3_INSTALL_DIR}")
