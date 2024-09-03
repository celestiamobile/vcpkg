set(extra_patches "")
if (VCPKG_TARGET_IS_OSX)
	list(APPEND extra_patches 005-do-not-pass-ld-e-macosx.patch)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO LuaJIT/LuaJIT
    REF eec7a8016c3381b949b5d84583800d05897fa960  #2025-04-10
    SHA512 bb38094e6833b6995e984d0da561f83295e2738386cf790be15f88d91e0fc5a3169137f2dd179f292d7ffa6965e9a44fff7d8f39424c478688e80e914a879712
    HEAD_REF master
    PATCHES
        msvcbuild.patch
        ${extra_patches}
)

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

if(VCPKG_DETECTED_MSVC)
    # Due to lack of better MSVC cross-build support, just always build the host
    # minilua tool with the target toolchain. This will work for native builds and
    # for targeting x86 from x64 hosts. (UWP and ARM64 is unsupported.)
    vcpkg_list(SET options)
    if (VCPKG_LIBRARY_LINKAGE STREQUAL "static")
        list(APPEND options "MSVCBUILD_OPTIONS=static")
    endif()

    vcpkg_install_nmake(SOURCE_PATH "${SOURCE_PATH}"
        PROJECT_NAME "${CMAKE_CURRENT_LIST_DIR}/Makefile.nmake"
        OPTIONS
            ${options}
    )

    if (VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/luajit/luaconf.h" "defined(LUA_BUILD_AS_DLL)" "1")
    endif()

    file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/luajit.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
    if(NOT VCPKG_BUILD_TYPE)
        file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/luajit.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig")
    endif()

    vcpkg_copy_pdbs()
else()
    vcpkg_list(SET options)
    if(VCPKG_CROSSCOMPILING)
        list(APPEND options
            "LJARCH=${VCPKG_TARGET_ARCHITECTURE}"
            "BUILDVM_X=${CURRENT_HOST_INSTALLED_DIR}/manual-tools/${PORT}/buildvm-${VCPKG_TARGET_ARCHITECTURE}${VCPKG_HOST_EXECUTABLE_SUFFIX}"
        )
    endif()

    vcpkg_list(SET make_options "EXECUTABLE_SUFFIX=${VCPKG_TARGET_EXECUTABLE_SUFFIX}")
    set(strip_options "") # cf. src/Makefile
    if(VCPKG_TARGET_IS_OSX)
        vcpkg_list(APPEND make_options "TARGET_SYS=Darwin")
        set(strip_options " -x")
    elseif(VCPKG_TARGET_IS_IOS)
        vcpkg_list(APPEND make_options "TARGET_SYS=iOS")
        set(strip_options " -x")
    elseif(VCPKG_TARGET_IS_LINUX)
        vcpkg_list(APPEND make_options "TARGET_SYS=Linux")
    elseif(VCPKG_TARGET_IS_WINDOWS)
        vcpkg_list(APPEND make_options "TARGET_SYS=Windows")
        set(strip_options " --strip-unneeded")
    endif()

    set(dasm_archs "")
    if("buildvm-32" IN_LIST FEATURES)
        string(APPEND dasm_archs " arm x86")
    endif()
    if("buildvm-64" IN_LIST FEATURES)
        string(APPEND dasm_archs " arm64 x64")
    endif()

    file(COPY "${CMAKE_CURRENT_LIST_DIR}/configure" DESTINATION "${SOURCE_PATH}")
    vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}"
        COPY_SOURCE
        OPTIONS
            "BUILDMODE=${VCPKG_LIBRARY_LINKAGE}"
            ${options}
        OPTIONS_RELEASE
            "DASM_ARCHS=${dasm_archs}"
    )
    vcpkg_install_make(
        MAKEFILE "Makefile.vcpkg"
        OPTIONS
            ${make_options}
            "TARGET_AR=${VCPKG_DETECTED_CMAKE_AR} rcus"
            "TARGET_STRIP=${VCPKG_DETECTED_CMAKE_STRIP}${strip_options}"
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib/lua"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/lua"
    "${CURRENT_PACKAGES_DIR}/share/lua"
    "${CURRENT_PACKAGES_DIR}/share/man"
)

file(GLOB PUBLIC_HEADERS "${CURRENT_PACKAGES_DIR}/include/luajit/*")
file(COPY ${PUBLIC_HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_copy_tools(TOOL_NAMES luajit AUTO_CLEAN)

vcpkg_fixup_pkgconfig()

file(COPY "${SOURCE_PATH}/src/jit/" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/luajit/jit")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYRIGHT")
