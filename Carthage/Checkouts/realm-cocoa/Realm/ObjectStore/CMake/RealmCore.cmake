#
# Copyright 2016 Realm Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
###########################################################################

include(ExternalProject)
include(ProcessorCount)

find_package(Threads)

# Load dependency info from dependencies.list into REALM_FOO_VERSION variables.
set(DEPENDENCIES_FILE "dependencies.list" CACHE STRING "path to dependencies list")
file(STRINGS ${DEPENDENCIES_FILE} DEPENDENCIES)
message("Dependencies: ${DEPENDENCIES}")
foreach(DEPENDENCY IN LISTS DEPENDENCIES)
    string(REGEX MATCHALL "([^=]+)" COMPONENT_AND_VERSION ${DEPENDENCY})
    list(GET COMPONENT_AND_VERSION 0 COMPONENT)
    list(GET COMPONENT_AND_VERSION 1 VERSION)
    set(${COMPONENT} ${VERSION})
endforeach()


if(APPLE)
    find_library(FOUNDATION_FRAMEWORK Foundation)
    find_library(SECURITY_FRAMEWORK Security)

    set(CRYPTO_LIBRARIES "")
    set(SSL_LIBRARIES ${FOUNDATION_FRAMEWORK} ${SECURITY_FRAMEWORK})
elseif(CMAKE_SYSTEM_NAME MATCHES "^Windows")
    # Windows doesn't do crypto right now, but that is subject to change
    set(CRYPTO_LIBRARIES "")
    set(SSL_LIBRARIES "")
else()
    if(NOT EXISTS ${CMAKE_BINARY_DIR}/openssl/lib/cmake/OpenSSL/OpenSSLConfig.cmake)
        set(OPENSSL_URL "http://static.realm.io/downloads/openssl/${OPENSSL_VERSION}/Linux/x86_64/openssl.tgz")
        if(REALM_PLATFORM STREQUAL "Android")
            set(OPENSSL_URL "http://static.realm.io/downloads/openssl/${OPENSSL_VERSION}/Android/${ANDROID_ABI}/openssl.tgz")
        endif()
    
        message(STATUS "Downloading OpenSSL...")
        file(DOWNLOAD "${OPENSSL_URL}" "${CMAKE_BINARY_DIR}/openssl/openssl.tgz" STATUS download_status)
    
        list(GET download_status 0 status_code)
        if (NOT "${status_code}" STREQUAL "0")
            message(FATAL_ERROR "Downloading ${OPENSSL_URL}... Failed. Status: ${download_status}")
        endif()
    
        message(STATUS "Uncompressing OpenSSL...")
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xfz "openssl.tgz"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/openssl"
        )
        message(STATUS "Importing OpenSSL...")
    endif()
    set(OpenSSL_DIR "${CMAKE_BINARY_DIR}/openssl/lib/cmake/OpenSSL")
    find_package(OpenSSL REQUIRED CONFIG)

    set(CRYPTO_LIBRARIES OpenSSL::Crypto)
    set(SSL_LIBRARIES OpenSSL::SSL)
endif()

if (${CMAKE_VERSION} VERSION_GREATER "3.4.0")
    set(USES_TERMINAL_BUILD USES_TERMINAL_BUILD 1)
endif()

function(use_realm_core enable_sync core_prefix sync_prefix)
    if(core_prefix)
        build_existing_realm_core(${core_prefix})
        if(sync_prefix)
            build_existing_realm_sync(${sync_prefix})
        endif()
    elseif(enable_sync)
        # FIXME: Support building against prebuilt sync binaries.
        clone_and_build_realm_core("v${REALM_CORE_VERSION}")
        clone_and_build_realm_sync("v${REALM_SYNC_VERSION}")
    else()
        if(APPLE OR REALM_PLATFORM STREQUAL "Android" OR CMAKE_SYSTEM_NAME MATCHES "^Windows")
            download_realm_core(${REALM_CORE_VERSION})
        else()
            clone_and_build_realm_core("v${REALM_CORE_VERSION}")
        endif()
    endif()
endfunction()

function(download_realm_tarball url target libraries)
    get_filename_component(tarball_name "${url}" NAME)

    set(tarball_parent_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}")
    set(tarball_path "${tarball_parent_directory}/${tarball_name}")
    set(temp_tarball_path "/tmp/${tarball_name}")

    if (NOT EXISTS ${tarball_path})
        if (NOT EXISTS ${temp_tarball_path})
            message("Downloading ${url}.")
            file(DOWNLOAD ${url} ${temp_tarball_path}.tmp SHOW_PROGRESS)
            file(RENAME ${temp_tarball_path}.tmp ${temp_tarball_path})
        endif()
        file(COPY ${temp_tarball_path} DESTINATION ${tarball_parent_directory})
    endif()

    if(APPLE)
        add_custom_command(
            COMMENT "Extracting ${tarball_name}"
            OUTPUT ${libraries}
            COMMAND ${CMAKE_COMMAND} -E tar xf ${tarball_path}
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${target}
            COMMAND ${CMAKE_COMMAND} -E rename core ${target}
            COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${libraries})
    elseif(REALM_PLATFORM STREQUAL "Android" OR CMAKE_SYSTEM_NAME MATCHES "^Windows")
        add_custom_command(
            COMMENT "Extracting ${tarball_name}"
            OUTPUT ${libraries}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${target}"
            COMMAND "${CMAKE_COMMAND}" -E chdir "${target}" "${CMAKE_COMMAND}" -E tar xf "${tarball_path}"
            COMMAND "${CMAKE_COMMAND}" -E touch_nocreate ${libraries})
    endif()
endfunction()

function(download_realm_core core_version)
    if(CMAKE_SYSTEM_NAME MATCHES "Windows")
        set(compression "tar.gz")
        set(library_directory "lib")

        if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]$")
            set(architecture "ARM")
        elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$" OR CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(architecture "x64")
        else()
            set(architecture "Win32")
        endif()

        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(platform "Windows")
        elseif(CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
            set(platform "UWP")
        endif()

        set(tarball_name_debug "realm-core-Debug-v${core_version}-${platform}-${architecture}-devel.tar.gz")
        set(tarball_name_release "realm-core-Release-v${core_version}-${platform}-${architecture}-devel.tar.gz")

        set(url_debug "https://static.realm.io/downloads/core/${tarball_name_debug}")
        set(url_release "https://static.realm.io/downloads/core/${tarball_name_release}")

        set(core_directory_parent "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}")
        set(core_directory_debug "${core_directory_parent}/realm-core-${core_version}-debug")
        set(core_directory_release "${core_directory_parent}/realm-core-${core_version}-release")
        set(core_directory "${core_directory_debug}")

        set(core_library_debug "${core_directory_debug}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}realm-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
        set(core_library_release "${core_directory_release}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}realm${CMAKE_STATIC_LIBRARY_SUFFIX}")
        set(core_parser_library_debug "${core_directory_debug}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
        set(core_parser_library_release "${core_directory_release}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser${CMAKE_STATIC_LIBRARY_SUFFIX}")
        set(core_libraries ${core_library_debug} ${core_library_release} ${core_parser_library_debug} ${core_parser_library_release})

        download_realm_tarball(${url_debug} ${core_directory_debug} ${core_library_debug} ${core_parser_library_debug})
        download_realm_tarball(${url_release} ${core_directory_release} ${core_library_release} ${core_parser_library_release})
    else()
        if(APPLE)
            set(basename "realm-core-cocoa")
            set(compression "tar.xz")
            set(platform "-macosx")
        elseif(REALM_PLATFORM STREQUAL "Android")
            set(basename "realm-core-android")
            set(compression "tar.gz")
            set(platform "-android-${ANDROID_ABI}")
        endif()

        set(tarball_name "${basename}-v${core_version}.${compression}")
        set(url "https://static.realm.io/downloads/core/${tarball_name}")
        set(core_directory_parent "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}")
        set(core_directory "${core_directory_parent}/realm-core-${core_version}")

        set(core_library_debug ${core_directory}/${library_directory}/${CMAKE_STATIC_LIBRARY_PREFIX}realm${platform}-dbg${CMAKE_STATIC_LIBRARY_SUFFIX})
        set(core_library_release ${core_directory}/${library_directory}/${CMAKE_STATIC_LIBRARY_PREFIX}realm${platform}${CMAKE_STATIC_LIBRARY_SUFFIX})
        set(core_parser_library_debug ${core_directory}/${library_directory}/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser${platform}-dbg${CMAKE_STATIC_LIBRARY_SUFFIX})
        set(core_parser_library_release ${core_directory}/${library_directory}/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser${platform}${CMAKE_STATIC_LIBRARY_SUFFIX})
        set(core_libraries ${core_library_debug} ${core_library_release} ${core_parser_library_debug} ${core_parser_library_release})

        download_realm_tarball(${url} ${core_directory} "${core_libraries}")
    endif()

    add_custom_target(realm-core DEPENDS ${core_libraries})

    add_library(realm STATIC IMPORTED)
    add_dependencies(realm realm-core)
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_DEBUG ${core_library_debug})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_COVERAGE ${core_library_debug})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_RELEASE ${core_library_release})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION ${core_library_release})

    set_property(TARGET realm PROPERTY INTERFACE_LINK_LIBRARIES Threads::Threads ${CRYPTO_LIBRARIES})

    # Create directories that are included in INTERFACE_INCLUDE_DIRECTORIES, as CMake requires they exist at
    # configure time, when they'd otherwise not be created until we download and extract core.
    file(MAKE_DIRECTORY ${core_directory}/include)
    set_property(TARGET realm PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${core_directory}/include)

    add_library(realm-parser STATIC IMPORTED)
    add_dependencies(realm-parser realm-core)
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_DEBUG ${core_parser_library_debug})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_COVERAGE ${core_parser_library_debug})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_RELEASE ${core_parser_library_release})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION ${core_parser_library_release})
endfunction()

macro(build_realm_core)
    set(core_prefix_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/realm-core")

    ExternalProject_Add(realm-core
        PREFIX ${core_prefix_directory}
        BUILD_IN_SOURCE 1
        UPDATE_DISCONNECTED 1
        INSTALL_COMMAND ""
        CONFIGURE_COMMAND cmake -B build.debug -DOpenSSL_DIR="${CMAKE_BINARY_DIR}/openssl/lib/cmake/OpenSSL" -D CMAKE_BUILD_TYPE=Debug ${CORE_SANITIZER_FLAGS} -G Ninja
                       && cmake -B build.release -DOpenSSL_DIR="${CMAKE_BINARY_DIR}/openssl/lib/cmake/OpenSSL" -D CMAKE_BUILD_TYPE=RelWithDebInfo ${CORE_SANITIZER_FLAGS} -G Ninja
                       
        BUILD_COMMAND cmake --build build.debug --target Storage --target QueryParser
                   && cmake --build build.release --target Storage --target QueryParser

        ${USES_TERMINAL_BUILD}
        ${ARGN}
        )
    ExternalProject_Get_Property(realm-core SOURCE_DIR)

    set(core_debug_binary_dir "${SOURCE_DIR}/build.debug")
    set(core_release_binary_dir "${SOURCE_DIR}/build.release")
    set(core_library_debug "${core_debug_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(core_library_release "${core_release_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(core_parser_library_debug "${core_debug_binary_dir}/src/realm/parser/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(core_parser_library_release "${core_release_binary_dir}/src/realm/parser/${CMAKE_STATIC_LIBRARY_PREFIX}realm-parser${CMAKE_STATIC_LIBRARY_SUFFIX}")

    ExternalProject_Add_Step(realm-core ensure-libraries
        DEPENDEES build
        BYPRODUCTS ${core_library_debug} ${core_library_release}
                   ${core_parser_library_debug} ${core_parser_library_release}
        )

    set(core_generated_headers_dir_debug "${core_debug_binary_dir}/src")
    set(core_generated_headers_dir_release "${core_release_binary_dir}/src")

    add_library(realm STATIC IMPORTED)
    add_dependencies(realm realm-core)
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_DEBUG ${core_library_debug})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_COVERAGE ${core_library_debug})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION_RELEASE ${core_library_release})
    set_property(TARGET realm PROPERTY IMPORTED_LOCATION ${core_library_release})

    set_property(TARGET realm PROPERTY INTERFACE_LINK_LIBRARIES ${CRYPTO_LIBRARIES} Threads::Threads)

    # Create directories that are included in INTERFACE_INCLUDE_DIRECTORIES, as CMake requires they exist at
    # configure time, when they'd otherwise not be created until we download and build core.
    file(MAKE_DIRECTORY "${core_generated_headers_dir_debug}" "${core_generated_headers_dir_release}" "${SOURCE_DIR}/src")

    set_property(TARGET realm PROPERTY INTERFACE_INCLUDE_DIRECTORIES
        ${SOURCE_DIR}/src
        $<$<CONFIG:Debug>:${core_generated_headers_dir_debug}>
        $<$<NOT:$<CONFIG:Debug>>:${core_generated_headers_dir_release}>
    )

    add_library(realm-parser STATIC IMPORTED)
    add_dependencies(realm realm-core)
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_DEBUG ${core_parser_library_debug})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_COVERAGE ${core_parser_library_debug})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION_RELEASE ${core_parser_library_release})
    set_property(TARGET realm-parser PROPERTY IMPORTED_LOCATION ${core_parser_library_release})
endmacro()

function(clone_and_build_realm_core branch)
    build_realm_core(GIT_REPOSITORY "https://github.com/realm/realm-core.git"
                     GIT_TAG ${branch}
                     )
endfunction()

function(build_existing_realm_core core_directory)
    get_filename_component(core_directory ${core_directory} ABSOLUTE)

    build_realm_core(SOURCE_DIR ${core_directory}
                     URL ""
                     BUILD_ALWAYS 1
                     )
endfunction()

macro(build_realm_sync)
    set(sync_prefix_directory "${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/realm-sync")

    ExternalProject_Get_Property(realm-core SOURCE_DIR)
    set(core_directory ${SOURCE_DIR})

    separate_arguments(sync_cfg_args UNIX_COMMAND "-DREALM_BUILD_DOGLESS=OFF ${CORE_SANITIZER_FLAGS} -G Ninja")
    ExternalProject_Add(realm-sync-lib
        DEPENDS realm-core
        PREFIX ${sync_prefix_directory}
        BUILD_IN_SOURCE 1
        UPDATE_DISCONNECTED 1
        INSTALL_COMMAND ""
        CONFIGURE_COMMAND cmake -B build.debug -DCMAKE_BUILD_TYPE=Debug -DRealmCore_DIR=${core_directory}/build.debug ${sync_cfg_args}
                       && cmake -B build.release -DCMAKE_BUILD_TYPE=RelWithDebInfo -DRealmCore_DIR=${core_directory}/build.release ${sync_cfg_args}
        BUILD_COMMAND cmake --build build.debug --target Sync --target SyncServer
                   && cmake --build build.release --target Sync --target SyncServer
             ${USES_TERMINAL_BUILD}
        ${ARGN}
        )

    ExternalProject_Get_Property(realm-sync-lib SOURCE_DIR)

    set(sync_debug_binary_dir "${SOURCE_DIR}/build.debug")
    set(sync_release_binary_dir "${SOURCE_DIR}/build.release")
    set(sync_library_debug "${sync_debug_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm-sync-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(sync_library_release "${sync_release_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm-sync${CMAKE_STATIC_LIBRARY_SUFFIX}")

    ExternalProject_Add_Step(realm-sync-lib ensure-libraries
        BYPRODUCTS ${sync_library_debug} ${sync_library_release}
        DEPENDEES build
        )

    add_library(realm-sync STATIC IMPORTED)
    add_dependencies(realm-sync realm-sync-lib)

    set_property(TARGET realm-sync PROPERTY IMPORTED_LOCATION_DEBUG ${sync_library_debug})
    set_property(TARGET realm-sync PROPERTY IMPORTED_LOCATION_COVERAGE ${sync_library_debug})
    set_property(TARGET realm-sync PROPERTY IMPORTED_LOCATION_RELEASE ${sync_library_release})
    set_property(TARGET realm-sync PROPERTY IMPORTED_LOCATION ${sync_library_release})

    set_property(TARGET realm-sync PROPERTY INTERFACE_LINK_LIBRARIES ${SSL_LIBRARIES})

    # Create directories that are included in INTERFACE_INCLUDE_DIRECTORIES, as CMake requires they exist at
    # configure time, when they'd otherwise not be created until we download and build sync.
    file(MAKE_DIRECTORY ${SOURCE_DIR}/src)
    set_property(TARGET realm-sync PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${SOURCE_DIR}/src)

    # Sync server library is built as part of the sync library build
    set(sync_server_library_debug "${sync_debug_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm-server-dbg${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set(sync_server_library_release "${sync_release_binary_dir}/src/realm/${CMAKE_STATIC_LIBRARY_PREFIX}realm-server${CMAKE_STATIC_LIBRARY_SUFFIX}")

    ExternalProject_Add_Step(realm-sync-lib ensure-server-libraries
        BYPRODUCTS ${sync_server_library_debug} ${sync_server_library_release}
        DEPENDEES build
        )

    add_library(realm-sync-server STATIC IMPORTED)
    add_dependencies(realm-sync-server realm-sync-lib)

    set_property(TARGET realm-sync-server PROPERTY IMPORTED_LOCATION_DEBUG ${sync_server_library_debug})
    set_property(TARGET realm-sync-server PROPERTY IMPORTED_LOCATION_COVERAGE ${sync_server_library_debug})
    set_property(TARGET realm-sync-server PROPERTY IMPORTED_LOCATION_RELEASE ${sync_server_library_release})
    set_property(TARGET realm-sync-server PROPERTY IMPORTED_LOCATION ${sync_server_library_release})

    find_package(PkgConfig)
    pkg_check_modules(YAML QUIET yaml-cpp)
    set_property(TARGET realm-sync-server PROPERTY INTERFACE_LINK_LIBRARIES ${SSL_LIBRARIES} ${YAML_LDFLAGS})
endmacro()

function(build_existing_realm_sync sync_directory)
    get_filename_component(sync_directory ${sync_directory} ABSOLUTE)
    build_realm_sync(URL ""
                     SOURCE_DIR ${sync_directory}
                     BUILD_ALWAYS 1
                     )

endfunction()

function(clone_and_build_realm_sync branch)
    set(cmake_files ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY})

    build_realm_sync(GIT_REPOSITORY "git@github.com:realm/realm-sync.git"
                     GIT_TAG ${branch}
                     CONFIGURE_COMMAND ${config_cmd}
                     )

endfunction()
