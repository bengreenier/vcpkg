# Common Ambient Variables:
#   CURRENT_BUILDTREES_DIR    = ${VCPKG_ROOT_DIR}\buildtrees\${PORT}
#   CURRENT_PACKAGES_DIR      = ${VCPKG_ROOT_DIR}\packages\${PORT}_${TARGET_TRIPLET}
#   CURRENT_PORT_DIR          = ${VCPKG_ROOT_DIR}\ports\${PORT}
#   PORT                      = current port name (zlib, etc)
#   TARGET_TRIPLET            = current triplet (x86-windows, x64-windows-static, etc)
#   VCPKG_CRT_LINKAGE         = C runtime linkage type (static, dynamic)
#   VCPKG_LIBRARY_LINKAGE     = target library linkage type (static, dynamic)
#   VCPKG_ROOT_DIR            = <C:\path\to\current\vcpkg>
#   VCPKG_TARGET_ARCHITECTURE = target architecture (x64, x86, arm)
#

include(vcpkg_common_functions)

#TODO(bengreenier): remove this and generate libs for autolinking dlls
SET(VCPKG_POLICY_DLLS_WITHOUT_LIBS enabled)

# get sources
set(REL_VERSION 1.6.1)
set(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src/socket.io-client-cpp-${REL_VERSION})

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/socketio/socket.io-client-cpp/archive/${REL_VERSION}.tar.gz"
    FILENAME "socket-io-rel"
    SHA512 01c9c172e58a16b25af07c6bde593507792726aca28a9b202ed9531d51cd7e77c7e7d536102e50265d66de96e9708616075902dfdcfc72983758755381bad707
)
vcpkg_extract_source_archive(${ARCHIVE})

# patch underlying source to support vcpkg build options
vcpkg_apply_patches(SOURCE_PATH ${SOURCE_PATH} PATCHES
    ${CMAKE_CURRENT_LIST_DIR}/0001-patch-cmake-for-vcpkg.patch
    ${CMAKE_CURRENT_LIST_DIR}/0001-patch-lib-dllexport.patch
    ${CMAKE_CURRENT_LIST_DIR}/0001-define-sio_api.patch)

# determine build type
set(BUILD_SL 0)
set(BUILD_OUTDIR "lib")
if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    set(BUILD_SL 1)
    set(BUILD_OUTDIR "bin")
endif()

# configure cmake for the underlying source
# note: our patch adds support for some of these options
vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
    # don't use boost statically
    # TODO(bengreenier): but should we when ${Build_SL}
    -DBoost_USE_STATIC_LIBS=0
    # conditionally build the project as a shared lib
    -DBUILD_SHARED_LIBS=${BUILD_SL}
    # set the include output directory
    -DINC_OUTDIR=${CURRENT_PACKAGES_DIR}/include/socket-io
    # conditionally export a dll-compatible interface (only has impact on windows [when WIN32 is defined])
    -DEXPORT_SIO=${BUILD_SL}
    OPTIONS_RELEASE
    # in release, we change the lib outdir
    -DLIB_OUTDIR=${CURRENT_PACKAGES_DIR}/${BUILD_OUTDIR}
    OPTIONS_DEBUG
    # in debug, we change the lib outdir
    -DLIB_OUTDIR=${CURRENT_PACKAGES_DIR}/debug/${BUILD_OUTDIR}
)

# run the build (and install targets as well)
vcpkg_install_cmake()

# copy pdbs
vcpkg_copy_pdbs()

# handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/socket-io RENAME copyright)

# warn about dll
if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    message(STATUS "Warning: socket-io requires manual deployment of the correct dll files.")
else()
    message(STATUS "Warning: socket-io requires manual linkage of the correct lib files.")
endif()

# TODO(bengreenier): we still need to patch some stuff:
# <------------------------------->
# add_definitions(-DEXPORT_SIO=${EXPORT_SIO})
# add_definitions(-DSIO_DLL=${SIO_DLL})
# <------------------------------->
# #ifdef SIO_DLL
# 	#ifdef WIN32
# 		#ifdef EXPORT_SIO
# 			#define SIO_API __declspec(dllexport)
# 		#else
# 			#define SIO_API __declspec(dllimport)
# 		#endif
# 	#else
# 		#define SIO_API extern
# 	#endif
# #else
# 	#define SIO_API
# #endif