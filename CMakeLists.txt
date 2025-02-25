#
# Created by Franco P. Moitzi
#

cmake_minimum_required(VERSION 3.18 FATAL_ERROR)

cmake_host_system_information(RESULT Ncpu QUERY NUMBER_OF_PHYSICAL_CORES)
message(STATUS "CMake ${CMAKE_VERSION} with max. ${Ncpu} threads")

project(lsms LANGUAGES Fortran C CXX)

set(CMAKE_EXCLUDE_FROM_ALL ON) 

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Enable compilation for Accelerators
option(USE_ACCELERATOR_CUDA_C "Use the CUDA accelerator" OFF)
option(USE_ACCELERATOR_HIP "Use HIP for accelerator" OFF)
option(INCLUDE_ADDITIONAL_SYNCHRONIZE "Add additional synchronization in accelerator code" OFF)

if (USE_ACCELERATOR_CUDA_C AND USE_ACCELERATOR_HIP)
    message(FATAL_ERROR "Both ACCELERATOR_CUDA_C and ACCELERATOR_HIP defined. Only ONE of these allowed!")
endif ()

if (USE_ACCELERATOR_CUDA_C)
    message(STATUS "ACCELERATOR_CUDA_C was activated")
    enable_language(CUDA)
endif ()

if (USE_ACCELERATOR_HIP)
    message(STATUS "ACCELERATOR_HIP was activated")
endif ()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Default build type is RELEASE
if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RELEASE CACHE BOOL
            "Choose the type of build, options are: Debug Release"
            FORCE)
endif (NOT CMAKE_BUILD_TYPE)

message(STATUS "Build type: " ${CMAKE_BUILD_TYPE})

# Build external libraries
message(STATUS "Build external libraries")

# Build LUA in this project
include(lua)

# Build LibXC in this project
option(USE_LIBXC "Use the libxc library" ON)
if (USE_LIBXC)
    message(STATUS "LIBXC is used")
    include(libxc)
else ()
    message(STATUS "LIBXC is not used")
endif ()

# Build mjson library
include(mjson)

# Build fmt library
include(fmt)

#
# Define library and targets
#

add_executable(lsms_main_asa)
set_target_properties(lsms_main_asa PROPERTIES OUTPUT_NAME "lsms_asa")
set_target_properties(lsms_main_asa PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_executable(lsms_main)
set_target_properties(lsms_main PROPERTIES OUTPUT_NAME "lsms")
set_target_properties(lsms_main PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_executable(lsms_wl)
set_target_properties(lsms_wl PROPERTIES OUTPUT_NAME "wl-lsms")
set_target_properties(lsms_wl PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

option(LEGACY_MONOPOLE "Use legacy for monopoles" OFF)

if(LEGACY_MONOPOLE)
    target_compile_definitions(lsms_main_asa PUBLIC LEGACY_MONOPOLE)
    target_compile_definitions(lsms_main PUBLIC LEGACY_MONOPOLE)
endif()

# Core `lsms` library
add_library(lsmscore STATIC)
set_target_properties(lsmscore PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
        ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
        Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

target_link_libraries(lsmscore PUBLIC fmt::fmt)
target_link_libraries(lsmscore PUBLIC Threads::Threads)

target_link_libraries(lsms_main_asa PUBLIC lsmscore)
target_link_libraries(lsms_main PUBLIC lsmscore)
target_link_libraries(lsms_wl PUBLIC lsmscore)

#
# Add main source subdirectory
#
add_subdirectory(src)
add_subdirectory(include)

# Find OpenMP library
option(BUILD_WITH_OPENMP "Build with OpenMP" ON)
if (BUILD_WITH_OPENMP)
    find_package(OpenMP REQUIRED)
    target_link_libraries(lsmscore PUBLIC OpenMP::OpenMP_CXX)
endif ()

#
# CUDA
#
if (USE_ACCELERATOR_CUDA_C)
    target_compile_definitions(lsmscore PUBLIC ACCELERATOR_CUDA_C)

    option(CUDA_DEBUG "Debug CUDA routines" OFF)

    if (CUDA_DEBUG)
        target_compile_definitions(lsmscore PUBLIC "CUDA_DEBUG")
    endif ()

    if (BUILD_WITH_OPENMP)
        message(STATUS "OpenMP is also defined for GPU")
        target_compile_options(lsmscore PUBLIC $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler -fopenmp>)
    endif ()

    if (NOT DEFINED CMAKE_CUDA_STANDARD)
        set(CMAKE_CUDA_STANDARD 14)
        set(CMAKE_CUDA_STANDARD_REQUIRED ON)
    endif ()

    if (NOT DEFINED CMAKE_CUDA_SEPARABLE_COMPILATION)
        set(CMAKE_CUDA_SEPARABLE_COMPILATION OFF)
    endif ()

    find_package(CUDAToolkit REQUIRED)

    message(STATUS "CUDA Version: " ${CUDAToolkit_VERSION})
    message(STATUS "CUDA Include dirs: " ${CUDAToolkit_INCLUDE_DIRS})
    message(STATUS "CUDA Library: " ${CUDAToolkit_LIBRARY_DIR})

    target_link_libraries(lsmscore PUBLIC CUDA::toolkit)

    # Check if the necessary libraries have been found
    if (TARGET CUDA::cublas)
        target_link_libraries(lsmscore PUBLIC CUDA::cublas)
    else ()
        message(FATAL_ERROR "CuBLAS was not defined or found")
    endif ()

    if (TARGET CUDA::cusolver)
        target_link_libraries(lsmscore PUBLIC CUDA::cusolver)
    else ()
        message(FATAL_ERROR "Cusolver was not defined or found")
    endif ()

endif ()

if (USE_ACCELERATOR_HIP)
    target_compile_definitions(lsmscore PUBLIC ACCELERATOR_HIP)

    find_package(hip REQUIRED)
    target_link_libraries(lsmscore PUBLIC hip::device)

    find_package(hipblas REQUIRED)
    target_link_libraries(lsmscore PUBLIC roc::hipblas)

    find_package(rocsolver REQUIRED)
    target_link_libraries(lsmscore PUBLIC roc::rocsolver)
endif ()

if (DEFINED MST_LINEAR_SOLVER_DEFAULT)
    message(STATUS "Default linear solver: " ${MST_LINEAR_SOLVER_DEFAULT})
    set(MST_LINEAR_SOLVER_DEFAULT ${MST_LINEAR_SOLVER_DEFAULT} CACHE STRING "Default linear solver")
    target_compile_definitions(lsmscore PUBLIC "MST_LINEAR_SOLVER_DEFAULT=${MST_LINEAR_SOLVER_DEFAULT}")
endif ()

if (DEFINED MST_BUILD_KKR_MATRIX_DEFAULT)
    message(STATUS "Default KKR matrix build: " ${MST_BUILD_KKR_MATRIX_DEFAULT})
    set(MST_BUILD_KKR_MATRIX_DEFAULT ${MST_BUILD_KKR_MATRIX_DEFAULT} CACHE STRING "Default KKR matrix build")
    target_compile_definitions(lsmscore PUBLIC "MST_BUILD_KKR_MATRIX_DEFAULT=${MST_BUILD_KKR_MATRIX_DEFAULT}")
endif ()

option(ARCH_IBM "Is IBM architecture" OFF)

if (ARCH_IBM)
    message(STATUS "Use the IBM architecture")
    target_compile_definitions(lsmscore PUBLIC "ARCH_IBM")
endif ()

# Find MPI library
find_package(MPI REQUIRED COMPONENTS CXX OPTIONAL_COMPONENTS)
target_link_libraries(lsmscore PUBLIC MPI::MPI_CXX)

# Find HDF5
message(STATUS "Find HDF5")
set(HDF5_PREFER_PARALLEL false)
find_package(HDF5 REQUIRED)

message(STATUS "HDF5 C Libraries: " "${HDF5_C_LIBRARIES}")
message(STATUS "HDF5 LIBRARIES: " "${HDF5_LIBRARIES}")
message(STATUS "HDF5 INCLUDE DIRS: " "${HDF5_INCLUDE_DIRS}")
message(STATUS "HDF5 Version: " "${HDF5_VERSION}")

target_link_libraries(lsmscore PUBLIC HDF5::HDF5)

# Linear algebra libraries
option(USE_ESSL "Use IBM ESSL library" OFF)

if (USE_ESSL)
    find_package(ESSL REQUIRED)
    set(ESSL_WORKAROUND True)

    target_link_libraries(lsmscore PUBLIC ESSL)
else ()
    # Lapack
    option(SEARCH_LAPACK "Search for LAPACK" ON)
    if (NOT SEARCH_LAPACK)
        add_library(LAPACK::LAPACK STATIC IMPORTED GLOBAL)
        set_target_properties(LAPACK::LAPACK PROPERTIES IMPORTED_LOCATION ${LAPACK_LIBRARIES})
        if (DEFINED LAPACK_LINKER_FLAGS)
            target_compile_options(LAPACK::LAPACK INTERFACE ${LAPACK_LINKER_FLAGS})
        endif ()
        if (DEFINED LAPACK_INCLUDE_DIR)
            target_include_directories(LAPACK::LAPACK INTERFACE ${LAPACK_INCLUDE_DIR})
        endif ()
    else ()
        if (NOT DEFINED BLA_VENDOR)
            set(BLA_VENDOR "Generic")
        endif ()
        find_package(LAPACK REQUIRED)
    endif ()
    target_link_libraries(lsmscore PUBLIC LAPACK::LAPACK)

    # BLAS
    option(SEARCH_BLAS "Search for BLAS" ON)
    if (NOT SEARCH_BLAS)
        add_library(BLAS::BLAS STATIC IMPORTED GLOBAL)
        set_target_properties(BLAS::BLAS PROPERTIES IMPORTED_LOCATION ${BLAS_LIBRARIES})
        if (DEFINED BLAS_LINKER_FLAGS)
            target_compile_options(BLAS::BLAS INTERFACE ${BLAS_LINKER_FLAGS})
        endif ()
        if (DEFINED BLAS_INCLUDE_DIR)
            target_include_directories(BLAS::BLAS INTERFACE ${BLAS_INCLUDE_DIR})
        endif ()
    else ()
        if (NOT DEFINED BLA_VENDOR)
            set(BLA_VENDOR "Generic")
        endif ()
        find_package(BLAS REQUIRED)
    endif ()
    target_link_libraries(lsmscore PUBLIC BLAS::BLAS)
endif ()

# Link Time optimization
include(CheckIPOSupported)
check_ipo_supported(RESULT supported OUTPUT error)

if( supported )
    message(STATUS "IPO / LTO supported")
else()
    message(STATUS "IPO / LTO not supported: <${error}>")
endif()

# Lua
target_link_libraries(lsmscore PUBLIC Lua::Lua)

# mjson
target_link_libraries(lsmscore PUBLIC mjson)

# LibXC
if (USE_LIBXC)
    target_link_libraries(lsmscore PUBLIC libxc::libxc)
    target_compile_definitions(lsmscore PUBLIC USE_LIBXC)
endif ()

# DL
target_link_libraries(lsmscore PUBLIC ${CMAKE_DL_LIBS})
target_compile_definitions(lsmscore PUBLIC HAS_BACKTRACE)

# Include the common files
target_include_directories(lsmscore PUBLIC ${CMAKE_SOURCE_DIR}/include)

#
# Enable Testing with CTest
#
option(BUILD_TESTING "Build the testing tree." OFF)
if (BUILD_TESTING)
    include(CTest)
    enable_testing()
    message(STATUS "Testing is " ${BUILD_TESTING})
    add_subdirectory(Test)
endif ()

#
# Development Test Codes
#
option(LSMS_DEV_TESTS "Building LSMS development test programs." OFF)
if (LSMS_DEV_TESTS)
    message(STATUS "Building LSMS development test programs.")
endif ()

if(DEFINED ENV{NUGGET_PROCESS_TYPE})
    set(NUGGET_PROCESS_TYPE $ENV{NUGGET_PROCESS_TYPE})

    if(NOT DEFINED ENV{NUGGET_CONFIG_FILE})
        message(FATAL_ERROR "NUGGET_CONFIG_FILE not defined")
    else()
        set(NUGGET_CONFIG_FILE $ENV{NUGGET_CONFIG_FILE})
    endif()

    message(STATUS "Inside NUGGET_PROCESS_TYPE")
    message(STATUS "NUGGET_PROCESS_TYPE: ${NUGGET_PROCESS_TYPE}")
    message(STATUS "NUGGET_CONFIG_FILE: ${NUGGET_CONFIG_FILE}")

    include(${NUGGET_CONFIG_FILE})

    list(APPEND CMAKE_MODULE_PATH "${NUGGET_LIBRARY_PATH}")
    list(APPEND CMAKE_MODULE_PATH "${NUGGET_C_HOOKS_PATH}")
    message(STATUS "CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")
    
    include(Nugget)
    include(hooks)
    llvmir_setup()
    llvmir_set_final_compiler(CXX)

    if(INCLUDE_LIBRARIES_IN_BC)
        get_all_libraries_target(
            TARGET_LIST all_libraries_list
            DEPEND_TARGETS lsms_main_asa lsmscore
        )
        foreach(lib ${all_libraries_list})
            message(STATUS "Library: ${lib}")
            print_target_properties(${lib})
        endforeach()
    endif()

    if("${NUGGET_PROCESS_TYPE}" STREQUAL "lsms-ir-bb-analysis-bc")
        message(STATUS "creating for lsms_ir_bb_analysis_bc")
        if(NOT BB_INFO_OUTPUT_DIR) 
            set(BB_INFO_OUTPUT_DIR ${CMAKE_BINARY_DIR}/bb-info-output)
        endif()
        if(NOT EXISTS ${BB_INFO_OUTPUT_DIR})
            file(MAKE_DIRECTORY ${BB_INFO_OUTPUT_DIR})
            if(NOT EXISTS ${BB_INFO_OUTPUT_DIR})
                message(FATAL_ERROR "Could not create directory ${BB_INFO_OUTPUT_DIR}")
            endif()
        endif()

        nugget_bbv_profiling_bc(
            TARGET ${TARGET_NAME}
            REGION_LENGTH ${REGION_LENGTH}
            BB_INFO_OUTPUT_PATH ${BB_INFO_OUTPUT_DIR}/basic-block-info.txt
            DEPEND_TARGETS ${all_libraries_list} lsms_main lsmscore 
            EXTRA_FLAGS ${EXTRA_FLAGS}
            EXTRA_INCLUDES ${EXTRA_INCLUDES}
            EXTRA_LIB_PATHS ${EXTRA_LIB_PATHS}
            EXTRA_LIBS ${EXTRA_LIBS}
            HOOK_TARGET single-threaded-ir-bb-analysis
        )
    elseif("${NUGGET_PROCESS_TYPE}" STREQUAL "lsms-ir-bb-analysis-exe")
        message(STATUS "creating for lsms_ir_bb_analysis_exe")

        nugget_compile_exe(
            TARGET ${TARGET_NAME}
            DEPEND_TARGETS lsms_main_asa lsmscore ${all_libraries_list}
            BB_FILE_PATH ${BB_FILE_PATH}
            EXTRA_FLAGS ${EXTRA_FLAGS}
            EXTRA_INCLUDES ${EXTRA_INCLUDES}
            EXTRA_LIB_PATHS ${EXTRA_LIB_PATHS}
            EXTRA_LIBS ${EXTRA_LIBS}
            LLC_CMD ${LLC_CMD}
            EXTRACT_FUNCTIONS ${EXTRACT_FUNCTIONS}
            SHRUNK_BC ${SHRUNK_BC}
            FINAL_BB_FILE_PATHS ${FINAL_BB_FILE_PATHS}
        )

    elseif("${NUGGET_PROCESS_TYPE}" STREQUAL "lsms-nugget-bc")
        nugget_nugget_bc(
            TARGET ${TARGET_NAME}
            HOOK_TARGET ${HOOK_TARGET}
            SOURCE_BC_FILE_PATH ${SOURCE_BC_FILE_PATH}
            INPUT_FILE_DIR ${INPUT_FILE_DIR}
            INPUT_FILE_NAME_BASE ${INPUT_FILE_NAME_BASE}
            BB_INFO_INPUT_PATH ${BB_INFO_INPUT_PATH}
            BB_INFO_OUTPUT_DIR ${BB_INFO_OUTPUT_DIR}
            LABEL_TARGET ${LABEL_TARGET}
            LABEL_WARMUP ${LABEL_WARMUP}
            ALL_NUGGET_RIDS ${ALL_NUGGET_RIDS}
            DEPEND_TARGETS lsms_main_asa lsmscore ${all_libraries_list}
            EXTRA_FLAGS ${EXTRA_FLAGS}
            EXTRA_INCLUDES ${EXTRA_INCLUDES}
            EXTRA_LIB_PATHS ${EXTRA_LIB_PATHS}
            EXTRA_LIBS ${EXTRA_LIBS}
        )
    
    elseif("${NUGGET_PROCESS_TYPE}" STREQUAL "lsms-nugget-exe")
        
        if(NOT NUGGET_BC_FILE_DIR OR NOT NUGGET_BC_FILE_BASENAME)
            message(FATAL_ERROR "NUGGET_BC_FILE_DIR or NUGGET_BC_FILE_BASENAME not defined")
        endif()

        set(ALL_TARGETS "")

        foreach(rid ${ALL_NUGGET_RIDS})
            nugget_compile_exe(
                TARGET ${TARGET_NAME}_${rid}
                DEPEND_TARGETS lsms_main_asa lsmscore ${HOOK_TARGET} ${all_libraries_list}
                BB_FILE_PATH ${NUGGET_BC_FILE_DIR}/${NUGGET_BC_FILE_BASENAME}_${rid}/${NUGGET_BC_FILE_BASENAME}_${rid}.bc
                EXTRA_FLAGS ${EXTRA_FLAGS}
                EXTRA_INCLUDES ${EXTRA_INCLUDES}
                EXTRA_LIB_PATHS ${EXTRA_LIB_PATHS}
                EXTRA_LIBS ${EXTRA_LIBS}
                LLC_CMD ${LLC_CMD}
            )
            list(APPEND ALL_TARGETS ${TARGET_NAME}_${rid})
        endforeach()

        add_custom_target(${TARGET_NAME} ALL DEPENDS ${ALL_TARGETS})

    elseif("${NUGGET_PROCESS_TYPE}" STREQUAL "rebuild-deps")
        rebuild_depend_targets_libraries(
            TARGET rebuild_deps 
            DEPEND_TARGETS lsms_main_asa lsmscore
        )
    endif()
endif()

