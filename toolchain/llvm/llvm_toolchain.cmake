set(RISCV_CMODEL "medany" CACHE STRING "mcmodel argument to the compiler")
set(RISCV_GCC_PREFIX "${TOOLCHAIN_TOP}/GCC/rv32im_zve32x")
set(RISCV_GCC_BASENAME "riscv32-unknown-elf")

set(RISCV_LLVM_PREFIX "${TOOLCHAIN_TOP}/llvm/llvm_22_1_8/bin" CACHE PATH "Install location of LLVM RISC-V toolchain.")

set(CMAKE_C_COMPILER ${RISCV_LLVM_PREFIX}/clang)
set(CMAKE_CXX_COMPILER ${RISCV_LLVM_PREFIX}/clang++)
set(CMAKE_ASM_COMPILER ${RISCV_LLVM_PREFIX}/clang)
set(CMAKE_OBJCOPY ${RISCV_LLVM_PREFIX}/llvm-objcopy)
set(CMAKE_OBJDUMP ${RISCV_LLVM_PREFIX}/llvm-objdump)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --target=riscv32 -march=${RISCV_ARCH_COMP_STRING}_zicsr -mabi=${RISCV_ABI} -mcmodel=${RISCV_CMODEL}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --gcc-toolchain=${RISCV_GCC_PREFIX} --sysroot=${RISCV_GCC_PREFIX}/${RISCV_GCC_BASENAME}")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --target=riscv32 -march=${RISCV_ARCH_COMP_STRING}_zicsr -mabi=${RISCV_ABI} -mcmodel=${RISCV_CMODEL}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --gcc-toolchain=${RISCV_GCC_PREFIX} --sysroot=${RISCV_GCC_PREFIX}/${RISCV_GCC_BASENAME}")
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} --target=riscv32 -march=${RISCV_ARCH_COMP_STRING}_zicsr -mabi=${RISCV_ABI} -mcmodel=${RISCV_CMODEL}")
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} --gcc-toolchain=${RISCV_GCC_PREFIX} --sysroot=${RISCV_GCC_PREFIX}/${RISCV_GCC_BASENAME}")

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -march=${RISCV_ARCH_COMP_STRING}_zicsr -mabi=${RISCV_ABI} -fuse-ld=lld -mcmodel=${RISCV_CMODEL} --gcc-toolchain=${RISCV_GCC_PREFIX}")
