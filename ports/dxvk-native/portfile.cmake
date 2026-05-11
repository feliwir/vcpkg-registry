set(DXVK_PATCHES "")
if(VCPKG_TARGET_IS_APPLE)
    list(APPEND DXVK_PATCHES "${CMAKE_CURRENT_LIST_DIR}/dxvk-native-macos.patch")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO doitsujin/dxvk
    REF "v${VERSION}"
    SHA512 4d8c580d6e7a4e1a3438ec60fa323c5af002a3ea2f6dc4f049832ee6cbae34177623c373ab3d3f720be3149ce3cffb5b91da5892c1bdfe22c1e86bb9dde071ca
    HEAD_REF master
    PATCHES ${DXVK_PATCHES}
)

# The release archive omits the include/native/directx submodule content.
# Pull it in explicitly so d3d9/d3d11 headers are available.
vcpkg_from_github(
    OUT_SOURCE_PATH DIRECTX_HEADERS_SOURCE_PATH
    REPO Joshua-Ashton/mingw-directx-headers
    REF 9df86f2341616ef1888ae59919feaa6d4fad693d
    SHA512 5563b842d2c6f97c2a1abfd2d5066c15f1e4f310324310a61f98ed62731f90a0fd16d419858bb1ef8351a1d911e3de3d8ff861af0e69dac373f25b2f3d76a179
    HEAD_REF main
)
file(COPY "${DIRECTX_HEADERS_SOURCE_PATH}/"
     DESTINATION "${SOURCE_PATH}/include/native/directx")

# --- libdisplay-info subproject --------------------------------------------
# DXVK ships an empty subprojects/libdisplay-info/ placeholder but no wrap
# file, so meson cannot fetch the source itself (especially with vcpkg's
# --wrap-mode=nodownload).  We fetch it here and place it in the expected
# subproject directory so meson finds it via the fallback mechanism.
vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.freedesktop.org
    OUT_SOURCE_PATH DISPLAYINFO_SOURCE_PATH
    REPO emersion/libdisplay-info
    REF 0.1.1
    SHA512 8b11c35315f3f16f6853b2ba5daa39c622f2326cfa01d54574beb577efd38d25b8260f7d74c63924473a0487bffdbff727ddc05b12d36e2106b78aadc7d4ff42
    HEAD_REF main
)
file(COPY "${DISPLAYINFO_SOURCE_PATH}/"
     DESTINATION "${SOURCE_PATH}/subprojects/libdisplay-info")

# Meson disables pkg-config for this cross build setup, so libdisplay-info
# cannot discover hwdata.pc and falls back to /usr/share/hwdata/pnp.ids.
# Stage host hwdata's pnp.ids into the subproject and repoint fallback there.
set(HWDATA_PNP_IDS "${CURRENT_HOST_INSTALLED_DIR}/share/hwdata/pnp.ids")
if(EXISTS "${HWDATA_PNP_IDS}")
    file(COPY "${HWDATA_PNP_IDS}"
         DESTINATION "${SOURCE_PATH}/subprojects/libdisplay-info")
endif()

set(DISPLAYINFO_MESON_BUILD "${SOURCE_PATH}/subprojects/libdisplay-info/meson.build")
file(READ "${DISPLAYINFO_MESON_BUILD}" DISPLAYINFO_MESON_CONTENT)
string(REPLACE
    "/usr/share/hwdata/pnp.ids"
    "pnp.ids"
    DISPLAYINFO_MESON_CONTENT
    "${DISPLAYINFO_MESON_CONTENT}")
file(WRITE "${DISPLAYINFO_MESON_BUILD}" "${DISPLAYINFO_MESON_CONTENT}")

# ---------------------------------------------------------------------------

# --- WSI feature options ---------------------------------------------------
# At least one WSI backend must be enabled (SDL3, SDL2, or GLFW).
# Disabled backends are explicitly turned off so meson doesn't pick up
# system libraries the user hasn't requested.

set(FEATURE_OPTIONS "")

if("sdl3" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS "-Dnative_sdl3=enabled")
else()
    list(APPEND FEATURE_OPTIONS "-Dnative_sdl3=disabled")
endif()

if("sdl2" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS "-Dnative_sdl2=enabled")
else()
    list(APPEND FEATURE_OPTIONS "-Dnative_sdl2=disabled")
endif()

if("glfw" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS "-Dnative_glfw=enabled")
else()
    list(APPEND FEATURE_OPTIONS "-Dnative_glfw=disabled")
endif()

# ---------------------------------------------------------------------------

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        # Force meson to use the subproject we populated above rather than
        # looking for libdisplay-info via pkg-config.
        --force-fallback-for=libdisplay-info

        -Dbuild_id=false
        -Denable_dxgi=true
        -Denable_d3d8=true
        -Denable_d3d9=true
        -Denable_d3d10=true
        -Denable_d3d11=true
        ${FEATURE_OPTIONS}
)

vcpkg_install_meson()
vcpkg_fixup_pkgconfig()

# Extract version for CMake config
string(REGEX MATCH "^([0-9]+)\\.([0-9]+)" VERSION_MATCH "${VERSION}")
set(MAJOR_VERSION "${CMAKE_MATCH_1}")
set(MINOR_VERSION "${CMAKE_MATCH_2}")

# Install CMake config file for find_package(DXVK) support
set(DXVK_CMAKE_DIR "${CURRENT_PACKAGES_DIR}/share/cmake/DXVK")
file(MAKE_DIRECTORY "${DXVK_CMAKE_DIR}")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/DXVKConfig.cmake.in"
     DESTINATION "${DXVK_CMAKE_DIR}")
file(RENAME "${DXVK_CMAKE_DIR}/DXVKConfig.cmake.in"
            "${DXVK_CMAKE_DIR}/DXVKConfig.cmake")

# Configure the CMake file with version info
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/DXVKConfig.cmake.in"
    "${DXVK_CMAKE_DIR}/DXVKConfig.cmake"
    @ONLY
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

# Remove artefacts that don't belong in an installed vcpkg package
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
