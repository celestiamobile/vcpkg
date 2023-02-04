if (VCPKG_TARGET_IS_LINUX)
    message(WARNING "Building with a gcc version less than 6.1 is not supported.")
    message(WARNING "${PORT} currently requires the following libraries from the system package manager:\n    libx11-dev\n    mesa-common-dev\n    libxi-dev\n    libxext-dev\n\nThese can be installed on Ubuntu systems via apt-get install libx11-dev mesa-common-dev libxi-dev libxext-dev.")
endif()

if (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(ANGLE_CPU_BITNESS ANGLE_IS_32_BIT_CPU)
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(ANGLE_CPU_BITNESS ANGLE_IS_64_BIT_CPU)
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(ANGLE_CPU_BITNESS ANGLE_IS_32_BIT_CPU)
elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(ANGLE_CPU_BITNESS ANGLE_IS_64_BIT_CPU)
else()
    message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

set(ANGLE_USE_D3D11_COMPOSITOR_NATIVE_WINDOW "OFF")
if (VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
  set(ANGLE_BUILDSYSTEM_PORT "Win")
  if (NOT VCPKG_TARGET_IS_MINGW)
    set(ANGLE_USE_D3D11_COMPOSITOR_NATIVE_WINDOW "ON")
  endif()
elseif (VCPKG_TARGET_IS_OSX)
  set(ANGLE_BUILDSYSTEM_PORT "Mac")
elseif (VCPKG_TARGET_IS_LINUX)
  set(ANGLE_BUILDSYSTEM_PORT "Linux")
else()
  # default other platforms to "Linux" config
  set(ANGLE_BUILDSYSTEM_PORT "Linux")
endif()

# chromium/6589
set(ANGLE_COMMIT 7d461b21a4a77c6d48fde1c2e2fc3676b7323642)
set(ANGLE_VERSION 6589)
set(ANGLE_SHA512 ff2c7bbb237292ccbd39e3223023bc600a26de02c76c95a65dc2999a626b0703c61436946a097606e35228643fcda1c1a84ecb6d720628bb387b0c5cd05ba4df)
set(ANGLE_THIRDPARTY_ZLIB_COMMIT 68e57e619c1a59a6ba7e3ad48ad4eee9c0c5b08e)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/angle
    REF ${ANGLE_COMMIT}
    SHA512 ${ANGLE_SHA512}
    # On update check headers against opengl-registry
)

function(checkout_in_path PATH URL REF)
    if(EXISTS "${PATH}")
        file(REMOVE_RECURSE "${PATH}")
    endif()

    vcpkg_from_git(
        OUT_SOURCE_PATH DEP_SOURCE_PATH
        URL "${URL}"
        REF "${REF}"
    )
    file(RENAME "${DEP_SOURCE_PATH}" "${PATH}")
    file(REMOVE_RECURSE "${DEP_SOURCE_PATH}")
endfunction()

checkout_in_path(
    "${SOURCE_PATH}/third_party/zlib"
    "https://chromium.googlesource.com/chromium/src/third_party/zlib"
    "${ANGLE_THIRDPARTY_ZLIB_COMMIT}"
)

# Generate angle_commit.h
set(ANGLE_COMMIT_HASH_SIZE 12)
string(SUBSTRING "${ANGLE_COMMIT}" 0 ${ANGLE_COMMIT_HASH_SIZE} ANGLE_COMMIT_HASH)
set(ANGLE_COMMIT_DATE "invalid-date")
set(ANGLE_REVISION "${ANGLE_VERSION}")
set(ANGLE_PROGRAM_VERSION_HASH_SIZE 16)
string(SUBSTRING "${ANGLE_COMMIT}" 0 ${ANGLE_PROGRAM_VERSION_HASH_SIZE} ANGLE_PROGRAM_VERSION)
configure_file("${CMAKE_CURRENT_LIST_DIR}/angle_commit.h.in" "${SOURCE_PATH}/angle_commit.h" @ONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/angle_commit.h.in" "${SOURCE_PATH}/src/common/angle_commit.h" @ONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/ANGLEShaderProgramVersion.h.in" "${SOURCE_PATH}/ANGLEShaderProgramVersion.h" @ONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/ANGLEShaderProgramVersion.h.in" "${SOURCE_PATH}/src/common/ANGLEShaderProgramVersion.h" @ONLY)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/unofficial-angle-config.cmake" DESTINATION "${SOURCE_PATH}")

set(ANGLE_WEBKIT_BUILDSYSTEM_COMMIT "1da27950f8f1ec9d6cc023e460a1186a08b4e991")

# Download WebKit gni-to-cmake.py conversion script
vcpkg_download_distfile(GNI_TO_CMAKE_PY
    URLS "https://github.com/WebKit/WebKit/raw/${ANGLE_WEBKIT_BUILDSYSTEM_COMMIT}/Source/ThirdParty/ANGLE/gni-to-cmake.py"
    FILENAME "gni-to-cmake.py"
    SHA512 51ca45d4d2384d641b6672cb7cdfac200c58889b4b4cb83f1b04c1a0a2c9ab8b68f1c90d77763983684bcde674b073cfd85cfc160285332c0414d8ec6397601b
)

# Generate CMake files from GN / GNI files
vcpkg_find_acquire_program(PYTHON3)

set(_root_gni_files_to_convert
  "compiler.gni Compiler.cmake"
  "libGLESv2.gni GLESv2.cmake"
)
set(_renderer_gn_files_to_convert
  "libANGLE/renderer/d3d/BUILD.gn D3D.cmake"
  "libANGLE/renderer/gl/BUILD.gn GL.cmake"
  "libANGLE/renderer/metal/BUILD.gn Metal.cmake"
)

x_vcpkg_get_python_packages(PYTHON_EXECUTABLE "${PYTHON3}" PACKAGES ply argparse)

foreach(_root_gni_file IN LISTS _root_gni_files_to_convert)
  separate_arguments(_file_values UNIX_COMMAND "${_root_gni_file}")
  list(GET _file_values 0 _src_gn_file)
  list(GET _file_values 1 _dst_file)
  vcpkg_execute_required_process(
      COMMAND "${PYTHON3}" "${GNI_TO_CMAKE_PY}" "src/${_src_gn_file}" "${_dst_file}"
      WORKING_DIRECTORY "${SOURCE_PATH}"
      LOGNAME "gni-to-cmake-${_dst_file}-${TARGET_TRIPLET}"
  )
endforeach()

foreach(_renderer_gn_file IN LISTS _renderer_gn_files_to_convert)
  separate_arguments(_file_values UNIX_COMMAND "${_renderer_gn_file}")
  list(GET _file_values 0 _src_gn_file)
  list(GET _file_values 1 _dst_file)
  get_filename_component(_src_dir "${_src_gn_file}" DIRECTORY)
  vcpkg_execute_required_process(
      COMMAND "${PYTHON3}" "${GNI_TO_CMAKE_PY}" "src/${_src_gn_file}" "${_dst_file}" --prepend "src/${_src_dir}/"
      WORKING_DIRECTORY "${SOURCE_PATH}"
      LOGNAME "gni-to-cmake-${_dst_file}-${TARGET_TRIPLET}"
  )
endforeach()

# Fetch additional CMake files from WebKit ANGLE buildsystem
vcpkg_download_distfile(WK_ANGLE_INCLUDE_CMAKELISTS
    URLS "https://github.com/WebKit/WebKit/raw/${ANGLE_WEBKIT_BUILDSYSTEM_COMMIT}/Source/ThirdParty/ANGLE/include/CMakeLists.txt"
    FILENAME "include_CMakeLists.txt"
    SHA512 a7ddf3c6df7565e232f87ec651cc4fd84240b8866609e23e3e6e41d22532fd34c70e0f3b06120fd3d6d930ca29c1d0d470d4c8cb7003a66f8c1a840a42f32949
)
configure_file("${WK_ANGLE_INCLUDE_CMAKELISTS}" "${SOURCE_PATH}/include/CMakeLists.txt" COPYONLY)

if(NOT EXISTS "${SOURCE_PATH}/cmake")
    file(MAKE_DIRECTORY "${SOURCE_PATH}/cmake")
endif()

vcpkg_download_distfile(WK_ANGLE_CMAKE_WEBKITCOMPILERFLAGS
    URLS "https://github.com/WebKit/WebKit/raw/${ANGLE_WEBKIT_BUILDSYSTEM_COMMIT}/Source/cmake/WebKitCompilerFlags.cmake"
    FILENAME "WebKitCompilerFlags.cmake"
    SHA512 dd1b826c12051e872bfbcafde6a5c7ad1c805cc3d0d86b13c9ea2705ec732ca8151d765f304965b949fc5d0dee66676e32cef5498881edb5d84fa18715faa0bb
)
file(RENAME "${WK_ANGLE_CMAKE_WEBKITCOMPILERFLAGS}" "${SOURCE_PATH}/cmake/WebKitCompilerFlags.cmake")

vcpkg_download_distfile(WK_ANGLE_CMAKE_WEBKITMACROS
    URLS "https://github.com/WebKit/WebKit/raw/${ANGLE_WEBKIT_BUILDSYSTEM_COMMIT}/Source/cmake/WebKitMacros.cmake"
    FILENAME "WebKitMacros.cmake"
    SHA512 2d6c38ca51f31e86c2bf68c74f8565e7248b7828ffaa94e91b665fe6e168dd202696e63b879372d1ccd7e9b9f143a2424dcbd37e6bd93a3ed6a8051834feddf0
)
file(RENAME "${WK_ANGLE_CMAKE_WEBKITMACROS}" "${SOURCE_PATH}/cmake/WebKitMacros.cmake")

# Copy additional custom CMake buildsystem into appropriate folders
file(GLOB MAIN_BUILDSYSTEM "${CMAKE_CURRENT_LIST_DIR}/cmake-buildsystem/CMakeLists.txt" "${CMAKE_CURRENT_LIST_DIR}/cmake-buildsystem/*.cmake")
file(COPY ${MAIN_BUILDSYSTEM} DESTINATION "${SOURCE_PATH}")
file(GLOB MODULES "${CMAKE_CURRENT_LIST_DIR}/cmake-buildsystem/cmake/*.cmake")
file(COPY ${MODULES} DESTINATION "${SOURCE_PATH}/cmake")

set(WINAPPSDK_DIR "${SOURCE_PATH}/third_party/WindowsAppSDK")

#vcpkg_execute_required_process(
#  COMMAND "${PYTHON3}" "scripts/winappsdk_setup.py" "--version" "1.4.231219000" "--output" "${WINAPPSDK_DIR}"
#  WORKING_DIRECTORY "${SOURCE_PATH}"
#  LOGNAME "download-windowsappsdk-${TARGET_TRIPLET}"
#)

set(WINDOWS_APP_SDK_VERSION 1.5.240627000)

vcpkg_find_acquire_program(NUGET)
vcpkg_execute_required_process(COMMAND ${NUGET} install Microsoft.WindowsAppSDK
        -Version ${WINDOWS_APP_SDK_VERSION}
        -OutputDirectory ${SOURCE_PATH}/WindowsAppSDK
    WORKING_DIRECTORY ${SOURCE_PATH}
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0.18362/Microsoft.Foundation.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0.18362/Microsoft.Graphics.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0.18362/Microsoft.UI.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0/Microsoft.UI.Text.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0/Microsoft.Web.WebView2.Core.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0/Microsoft.Windows.ApplicationModel.Resources.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

vcpkg_execute_required_process(COMMAND winmdidl /nologo /outdir:.
        ../lib/uap10.0/Microsoft.UI.Xaml.winmd
    WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
)

file(GLOB IDL_FILES "${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include/*.idl")
foreach(IDL_FILE ${IDL_FILES})
    get_filename_component(IDL_FILE_NAME "${IDL_FILE}" NAME)
    vcpkg_execute_required_process(COMMAND midlrt ${IDL_FILE_NAME} /metadata_dir C:\\Windows\\System32\\WinMetadata /ns_prefix /nomidl
        WORKING_DIRECTORY ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION}/include
    )
endforeach()

file(RENAME ${SOURCE_PATH}/WindowsAppSDK/Microsoft.WindowsAppSDK.${WINDOWS_APP_SDK_VERSION} ${WINAPPSDK_DIR})

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS_DEBUG -DDISABLE_INSTALL_HEADERS=1
    OPTIONS
        "-D${ANGLE_CPU_BITNESS}=1"
        "-DPORT=${ANGLE_BUILDSYSTEM_PORT}"
        "-DANGLE_USE_D3D11_COMPOSITOR_NATIVE_WINDOW=${ANGLE_USE_D3D11_COMPOSITOR_NATIVE_WINDOW}"
        "-DVCPKG_TARGET_IS_WINDOWS=${VCPKG_TARGET_IS_WINDOWS}"
        "-DWINAPPSDK_DIR=${WINAPPSDK_DIR}"
        "-DWINDOWS_ARCH=${VCPKG_TARGET_ARCHITECTURE}"
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(CONFIG_PATH share/unofficial-angle PACKAGE_NAME unofficial-angle)

vcpkg_copy_pdbs()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
# Remove empty directories inside include directory
file(GLOB directory_children RELATIVE "${CURRENT_PACKAGES_DIR}/include" "${CURRENT_PACKAGES_DIR}/include/*")
foreach(directory_child ${directory_children})
    if(IS_DIRECTORY "${CURRENT_PACKAGES_DIR}/include/${directory_child}")
        file(GLOB_RECURSE subdirectory_children "${CURRENT_PACKAGES_DIR}/include/${directory_child}/*")
        if("${subdirectory_children}" STREQUAL "")
            file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/${directory_child}")
        endif()
    endif()
endforeach()
unset(subdirectory_children)
unset(directory_child)
unset(directory_children)

file(INSTALL "${SOURCE_PATH}/include/angle_windowsstore.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
