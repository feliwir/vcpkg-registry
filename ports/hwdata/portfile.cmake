# hwdata only contains data files — no build step needed.
set(VCPKG_BUILD_TYPE release)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO vcrhonek/hwdata
    REF "v${VERSION}"
    SHA512 9a11e0d8cc6788c6a54c87956afb19853f5214c1d2deb77cc7c6155687a9621b83d54533a8e475decad82aaad84581ee410d16b7db20e666f62a003a76a62618
    HEAD_REF main
)

# Install the data file queried by libdisplay-info
file(INSTALL "${SOURCE_PATH}/pnp.ids"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/hwdata")

# Write a pkg-config file exposing pkgdatadir so that meson's
#   dep_hwdata.get_variable(pkgconfig: 'pkgdatadir')
# call in libdisplay-info's meson.build resolves correctly.
# vcpkg's meson helper injects share/pkgconfig into PKG_CONFIG_PATH,
# so place the file there instead of lib/pkgconfig.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/pkgconfig")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/pkgconfig/hwdata.pc"
"prefix=${CURRENT_PACKAGES_DIR}
pkgdatadir=\${prefix}/share/hwdata

Name: hwdata
Description: Hardware identification and configuration data
Version: ${VERSION}
")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
