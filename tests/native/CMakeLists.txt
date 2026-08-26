cmake_minimum_required(VERSION 3.20)

project(DVSenseNativeConnectionTests LANGUAGES CXX)

set(DVSENSE_FUSION_SDK_ROOT
    ""
    CACHE PATH
    "Official DvsRgbFusionCamera source root containing include/")
set(DVSENSE_FUSION_BUILD_ROOT
    ""
    CACHE PATH
    "Build root containing Release/DvsRgbFusionCamera.lib and bin/Release/")
set(DVSENSE_DRIVER_ROOT
    "C:/Program Files (x86)/DvsenseDriver"
    CACHE PATH
    "Installed DVSenseDriver root")
set(MVS_ROOT
    "C:/Program Files (x86)/MVS"
    CACHE PATH
    "Installed Hikrobot MVS root")
set(OPENCV_ROOT
    "C:/vcpkg-master/vcpkg-master/installed/x64-windows"
    CACHE PATH
    "vcpkg x64-windows root containing include/opencv4/")

if(NOT DVSENSE_FUSION_SDK_ROOT)
    message(FATAL_ERROR
        "Set DVSENSE_FUSION_SDK_ROOT to the official Fusion SDK source root.")
endif()
if(NOT DVSENSE_FUSION_BUILD_ROOT)
    message(FATAL_ERROR
        "Set DVSENSE_FUSION_BUILD_ROOT to the official Fusion SDK build root.")
endif()

set(DVSENSE_FUSION_INCLUDE_DIR "${DVSENSE_FUSION_SDK_ROOT}/include")
set(DVSENSE_FUSION_LIB "${DVSENSE_FUSION_BUILD_ROOT}/Release/DvsRgbFusionCamera.lib")
set(DVSENSE_CALIB_INCLUDE_DIR "${DVSENSE_FUSION_SDK_ROOT}/include")
set(DVSENSE_CALIB_LIB "${DVSENSE_FUSION_BUILD_ROOT}/Release/DvsRgbCalib.lib")
set(DVSENSE_FUSION_BIN_DIR "${DVSENSE_FUSION_BUILD_ROOT}/bin/Release")
set(DVSENSE_DRIVER_INCLUDE_DIR "${DVSENSE_DRIVER_ROOT}/include")
set(DVSENSE_DRIVER_LIB_DIR "${DVSENSE_DRIVER_ROOT}/lib")
set(MVS_INCLUDE_DIR "${MVS_ROOT}/Development/Includes")
set(MVS_LIB "${MVS_ROOT}/Development/Libraries/win64/MvCameraControl.lib")
set(VCPKG_INCLUDE_DIR "${OPENCV_ROOT}/include")
set(OPENCV_INCLUDE_DIR "${OPENCV_ROOT}/include/opencv4")
set(OPENCV_LIB_DIR "${OPENCV_ROOT}/lib")

foreach(required_path IN ITEMS
    DVSENSE_FUSION_INCLUDE_DIR
    DVSENSE_FUSION_LIB
    DVSENSE_CALIB_LIB
    DVSENSE_FUSION_BIN_DIR
    DVSENSE_DRIVER_INCLUDE_DIR
    DVSENSE_DRIVER_LIB_DIR
    MVS_INCLUDE_DIR
    MVS_LIB
    VCPKG_INCLUDE_DIR
    OPENCV_INCLUDE_DIR
    OPENCV_LIB_DIR)
    if(NOT EXISTS "${${required_path}}")
        message(FATAL_ERROR
            "${required_path} does not exist: ${${required_path}}")
    endif()
endforeach()

add_executable(fusion_connection_smoke fusion_connection_smoke.cpp)
target_compile_features(fusion_connection_smoke PRIVATE cxx_std_17)
target_compile_definitions(fusion_connection_smoke PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(fusion_connection_smoke PRIVATE
    "${DVSENSE_FUSION_INCLUDE_DIR}"
    "${VCPKG_INCLUDE_DIR}"
    "${OPENCV_INCLUDE_DIR}"
    "${DVSENSE_DRIVER_INCLUDE_DIR}"
    "${MVS_INCLUDE_DIR}")
target_link_directories(fusion_connection_smoke PRIVATE
    "${DVSENSE_DRIVER_LIB_DIR}"
    "${OPENCV_LIB_DIR}")
target_link_libraries(fusion_connection_smoke PRIVATE
    "${DVSENSE_FUSION_LIB}"
    DvsenseDriver
    DvsenseHal
    DvsenseBase
    avcodec
    avformat
    avutil
    swscale
    opencv_core4
    "${MVS_LIB}")

set_target_properties(fusion_connection_smoke PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

add_custom_command(TARGET fusion_connection_smoke POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${DVSENSE_FUSION_BIN_DIR}/DvsRgbFusionCamera.dll"
        "$<TARGET_FILE_DIR:fusion_connection_smoke>")

add_executable(dvs_connection_smoke dvs_connection_smoke.cpp)
target_compile_features(dvs_connection_smoke PRIVATE cxx_std_17)
target_compile_definitions(dvs_connection_smoke PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(dvs_connection_smoke PRIVATE
    "${DVSENSE_DRIVER_INCLUDE_DIR}")
target_link_directories(dvs_connection_smoke PRIVATE
    "${DVSENSE_DRIVER_LIB_DIR}")
target_link_libraries(dvs_connection_smoke PRIVATE
    DvsenseDriver
    DvsenseHal
    DvsenseBase)
set_target_properties(dvs_connection_smoke PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

add_executable(hik_connection_smoke hik_connection_smoke.cpp)
target_compile_features(hik_connection_smoke PRIVATE cxx_std_17)
target_compile_definitions(hik_connection_smoke PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(hik_connection_smoke PRIVATE
    "${MVS_INCLUDE_DIR}")
target_link_libraries(hik_connection_smoke PRIVATE
    "${MVS_LIB}")
set(MVS_RUNTIME_DIR
    "C:/Program Files (x86)/Common Files/MVS/Runtime/Win64_x64"
    CACHE PATH
    "MVS native Win64 runtime directory")
set_target_properties(hik_connection_smoke PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")
add_custom_command(TARGET hik_connection_smoke POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${MVS_RUNTIME_DIR}/MvCameraControl.dll"
        "$<TARGET_FILE_DIR:hik_connection_smoke>")

add_executable(dual_camera_connection_smoke dual_camera_connection_smoke.cpp)
target_compile_features(dual_camera_connection_smoke PRIVATE cxx_std_17)
target_compile_definitions(dual_camera_connection_smoke PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(dual_camera_connection_smoke PRIVATE
    "${DVSENSE_DRIVER_INCLUDE_DIR}"
    "${MVS_INCLUDE_DIR}")
target_link_directories(dual_camera_connection_smoke PRIVATE
    "${DVSENSE_DRIVER_LIB_DIR}")
target_link_libraries(dual_camera_connection_smoke PRIVATE
    DvsenseDriver
    DvsenseHal
    DvsenseBase
    "${MVS_LIB}")
set_target_properties(dual_camera_connection_smoke PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

add_executable(three_view_layout_test
    three_view_layout_test.cpp
    three_view_layout.cpp)
target_compile_features(three_view_layout_test PRIVATE cxx_std_17)
target_compile_definitions(three_view_layout_test PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(three_view_layout_test PRIVATE
    "${VCPKG_INCLUDE_DIR}"
    "${OPENCV_INCLUDE_DIR}")
target_link_directories(three_view_layout_test PRIVATE
    "${OPENCV_LIB_DIR}")
target_link_libraries(three_view_layout_test PRIVATE
    opencv_core4
    opencv_imgproc4)
set_target_properties(three_view_layout_test PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

add_executable(event_window_test
    event_window_test.cpp
    three_view_event_window.cpp)
target_compile_features(event_window_test PRIVATE cxx_std_17)
target_compile_definitions(event_window_test PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(event_window_test PRIVATE
    "${VCPKG_INCLUDE_DIR}"
    "${OPENCV_INCLUDE_DIR}")
target_link_directories(event_window_test PRIVATE
    "${OPENCV_LIB_DIR}")
target_link_libraries(event_window_test PRIVATE
    opencv_core4)
set_target_properties(event_window_test PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")

add_executable(three_view_fusion_preview
    three_view_fusion_preview.cpp
    three_view_event_window.cpp
    three_view_layout.cpp)
target_compile_features(three_view_fusion_preview PRIVATE cxx_std_17)
target_compile_definitions(three_view_fusion_preview PRIVATE
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX)
target_include_directories(three_view_fusion_preview PRIVATE
    "${DVSENSE_FUSION_INCLUDE_DIR}"
    "${DVSENSE_DRIVER_INCLUDE_DIR}"
    "${MVS_INCLUDE_DIR}"
    "${VCPKG_INCLUDE_DIR}"
    "${OPENCV_INCLUDE_DIR}")
target_link_directories(three_view_fusion_preview PRIVATE
    "${DVSENSE_DRIVER_LIB_DIR}"
    "${OPENCV_LIB_DIR}")
target_link_libraries(three_view_fusion_preview PRIVATE
    "${DVSENSE_FUSION_LIB}"
    "${DVSENSE_CALIB_LIB}"
    DvsenseDriver
    DvsenseHal
    DvsenseBase
    avcodec
    avformat
    avutil
    swscale
    opencv_core4
    opencv_imgproc4
    opencv_highgui4
    "${MVS_LIB}")
set_target_properties(three_view_fusion_preview PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/$<CONFIG>")
add_custom_command(TARGET three_view_fusion_preview POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${DVSENSE_FUSION_BIN_DIR}/DvsRgbFusionCamera.dll"
        "$<TARGET_FILE_DIR:three_view_fusion_preview>"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${DVSENSE_FUSION_BUILD_ROOT}/bin/Release/DvsRgbCalib.dll"
        "$<TARGET_FILE_DIR:three_view_fusion_preview>"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${DVSENSE_FUSION_SDK_ROOT}/calibration_result.json"
        "$<TARGET_FILE_DIR:three_view_fusion_preview>")
