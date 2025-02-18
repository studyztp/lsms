set(REGION_LENGTH 100000000)
set(TARGET_NAME lsms_ir_bb_analysis_exe)

set(ANALYSIS_BC_FILE_PATH "${CMAKE_BINARY_DIR}/llvm-bc/lsms_ir_bb_analysis_bc/lsms_ir_bb_analysis_bc.bc")
set(LLC_EXTRATION_FILE_PATH "${CMAKE_CURRENT_LIST_DIR}/../nugget-util/cmake/check-cpu-features/llc-command.txt")
if(NOT EXISTS ${ANALYSIS_BC_FILE_PATH})
    message(FATAL_ERROR "Analysis BC file not found: ${ANALYSIS_BC_FILE_PATH}")
endif()

set(NUGGET_LIBRARY_PATH "${CMAKE_CURRENT_LIST_DIR}/../../nugget-util/cmake")
set(NUGGET_HOOKS_PATH "${CMAKE_CURRENT_LIST_DIR}/../../nugget-util/hook-helper")
set(NUGGET_C_HOOKS_PATH "${NUGGET_HOOKS_PATH}/c-hooks")

set(LLVM_ROOT "/home/ztpc/compiler/llvm-dir")
set(LLVM_BIN "${LLVM_ROOT}/bin")

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
    -L${LLVM_ROOT}/lib
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
