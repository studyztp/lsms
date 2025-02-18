#
# Toolchain for building LSMS on a generic Linux system withour GPU
#

message(STATUS "Use toolchain file generic-cpu")

set(BUILD_TESTING OFF)

set(MST_LINEAR_SOLVER_DEFAULT 0x0005)
set(MST_BUILD_KKR_MATRIX_DEFAULT 0x1000)

set(CMAKE_CXX_COMPILER "mpic++")
set(CMAKE_C_COMPILER "gcc")
set(CMAKE_Fortran_COMPILER "gfortran")

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_CXX_FLAGS "-O3 -mtune=native -mcpu=native")
set(CMAKE_Fortran_FLAGS "-O3 -mtune=native -mcpu=native")
# set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
# set(CMAKE_OPTIMIZE_DEPENDENCIES TRUE)
# set(CMAKE_Fortran_PREPROCESS TRUE)

# from here is what nugget needs

set(NUGGET_PROCESS_TYPE "lsms-ir-bb-analysis")
set(REGION_LENGTH 100000000)
set(TARGET_NAME lsms_ir_bb_analysis_bc)

set(NUGGET_LIBRARY_PATH "${CMAKE_CURRENT_LIST_DIR}/../../nugget-util/cmake")
set(NUGGET_HOOKS_PATH "${CMAKE_CURRENT_LIST_DIR}/../../nugget-util/hook-helper")
set(NUGGET_C_HOOKS_PATH "${NUGGET_HOOKS_PATH}/c-hooks")

set(LLVM_BIN "/home/ztpc/compiler/llvm-dir/bin")

set(MPI_INCLUDES
    -I/usr/lib/x86_64-linux-gnu/openmpi/include
    -I/usr/lib/x86_64-linux-gnu/openmpi/include/openmpi
)

set(MPI_LIB_PATHS
    -L/usr/lib/x86_64-linux-gnu/openmpi/lib
)

set(MPI_LIBS
    -lmpi_cxx
    -lmpi
)

set(Fortran_LIB_PATHS
    -L/scr/studyztp/compiler/llvm-dir/lib
)

set(Fortran_LIBS
    -lgfortran 
    -lFortranRuntime 
    -lFortranDecimal 
    -lFortran_main 
    -lflangFrontend 
)

set(PAPI_LIB "${NUGGET_HOOKS_PATH}/other-tools/papi/x86_64/lib/libpapi.a")

set(EXTRA_FLAGS "-DUSE_NUGGET_LIB")
set(EXTRA_LIBS ${MPI_LIBS} ${Fortran_LIBS} ${PAPI_LIB})
set(EXTRA_LIB_PATHS ${MPI_LIB_PATHS} ${Fortran_LIB_PATHS})
set(EXTRA_INCLUDES ${MPI_INCLUDES})
