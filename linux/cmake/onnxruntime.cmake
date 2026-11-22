# Prepare the download fallback before the plugin checks its runtime directory.
set(onnxruntime_package_version "1.32.0")
if(ONNXRUNTIME_VERSION AND NOT ONNXRUNTIME_VERSION STREQUAL onnxruntime_package_version)
  return()
endif()

if(NOT DEFINED USE_SYSTEM_ONNXRUNTIME OR USE_SYSTEM_ONNXRUNTIME)
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND)
    pkg_check_modules(ONNXRUNTIME_PC QUIET onnxruntime)
    if(ONNXRUNTIME_PC_FOUND)
      return()
    endif()
  endif()
  find_library(ONNXRUNTIME_LIBRARY NAMES onnxruntime PATHS "${ONNXRUNTIME_ROOT_DIR}/lib")
  find_path(ONNXRUNTIME_INCLUDE_DIR NAMES onnxruntime_cxx_api.h PATHS "${ONNXRUNTIME_ROOT_DIR}/include")
  if(ONNXRUNTIME_LIBRARY AND ONNXRUNTIME_INCLUDE_DIR)
    return()
  endif()
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
  set(onnxruntime_plugin_arch "x64")
  set(onnxruntime_nuget_arch "x64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
  set(onnxruntime_plugin_arch "aarch64")
  set(onnxruntime_nuget_arch "arm64")
else()
  message(FATAL_ERROR "Unsupported ONNX Runtime architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

# Microsoft's NuGet package contains matching Linux binaries and C++ headers.
set(ONNXRUNTIME_VERSION "${onnxruntime_package_version}")
set(onnxruntime_cache "${CMAKE_CURRENT_BINARY_DIR}/onnxruntime")
set(onnxruntime_dir "${onnxruntime_cache}/onnxruntime-linux-${onnxruntime_plugin_arch}-${ONNXRUNTIME_VERSION}")
set(onnxruntime_lib_dir "${onnxruntime_dir}/lib")
file(MAKE_DIRECTORY "${onnxruntime_cache}")
file(LOCK "${onnxruntime_cache}/prepare.lock" GUARD FILE TIMEOUT 180)

if(NOT EXISTS "${onnxruntime_dir}/include/onnxruntime_cxx_api.h" OR
   NOT EXISTS "${onnxruntime_lib_dir}/libonnxruntime.so.1" OR
   NOT EXISTS "${onnxruntime_lib_dir}/libonnxruntime_providers_shared.so")
  set(onnxruntime_staging "${onnxruntime_cache}/nuget-${ONNXRUNTIME_VERSION}")
  set(onnxruntime_archive "${onnxruntime_staging}/onnxruntime.nupkg")
  set(onnxruntime_extract "${onnxruntime_staging}/extract")
  set(onnxruntime_ready "${onnxruntime_staging}/runtime")
  file(REMOVE_RECURSE "${onnxruntime_extract}" "${onnxruntime_ready}")
  file(MAKE_DIRECTORY "${onnxruntime_extract}" "${onnxruntime_ready}")
  message(STATUS "Fetching ONNX Runtime ${ONNXRUNTIME_VERSION} from NuGet")
  file(DOWNLOAD
    "https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/${ONNXRUNTIME_VERSION}/microsoft.ml.onnxruntime.${ONNXRUNTIME_VERSION}.nupkg"
    "${onnxruntime_archive}"
    TLS_VERIFY ON
    TIMEOUT 180
    INACTIVITY_TIMEOUT 45
    EXPECTED_HASH SHA256=a9150bc2992cbbb6722070da9910e1ffa989a8bfc67bdd5bb8e745ca755641db
  )

  set(onnxruntime_native "runtimes/linux-${onnxruntime_nuget_arch}/native")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xf "${onnxruntime_archive}" --
            build/native/include "${onnxruntime_native}"
    WORKING_DIRECTORY "${onnxruntime_extract}"
    RESULT_VARIABLE onnxruntime_extraction_result
  )
  if(NOT onnxruntime_extraction_result STREQUAL "0")
    message(FATAL_ERROR "Failed to extract ONNX Runtime ${ONNXRUNTIME_VERSION} for ${onnxruntime_nuget_arch}")
  endif()
  file(RENAME "${onnxruntime_extract}/build/native/include" "${onnxruntime_ready}/include")
  file(RENAME "${onnxruntime_extract}/${onnxruntime_native}" "${onnxruntime_ready}/lib")

  # The ELF loader requests the SONAME even though the package file is unversioned.
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E create_symlink libonnxruntime.so "${onnxruntime_ready}/lib/libonnxruntime.so.1"
    RESULT_VARIABLE onnxruntime_symlink_result
  )
  if(NOT onnxruntime_symlink_result STREQUAL "0")
    message(FATAL_ERROR "Failed to create the ONNX Runtime SONAME link")
  endif()
  file(REMOVE_RECURSE "${onnxruntime_dir}")
  file(RENAME "${onnxruntime_ready}" "${onnxruntime_dir}")
  file(REMOVE_RECURSE "${onnxruntime_staging}")
endif()

set(ONNXRUNTIME_COMPANION_LIBRARIES
    "${onnxruntime_lib_dir}/libonnxruntime.so.1"
    "${onnxruntime_lib_dir}/libonnxruntime_providers_shared.so"
    PARENT_SCOPE)
