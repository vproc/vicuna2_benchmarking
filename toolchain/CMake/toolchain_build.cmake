# Macros for checking and building the submodules present in the toolchain directory.
macro(build_gcc_multilib)
    if(NOT EXISTS "${TOOLCHAIN_TOP}/GCC/multilib")
        message("GCC Multilib not found. Building")
        # Make sure required dependencies are installed for GCC
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev libncurses-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(STATUS "Downloading Fedora Dependencies")
            execute_process(COMMAND sudo yum install autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel libslirp-devel ncurses-devel
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR GCC")
        endif()

        #riscv-gnu-toolchain submodule is not downloaded with --recursive flag.  Need to checkout if not done already
        if(NOT EXISTS "${TOOLCHAIN_TOP}/riscv-gnu-toolchain/gcc")
            execute_process(COMMAND git submodule update --checkout riscv-gnu-toolchain/
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        endif()
        execute_process(COMMAND make clean
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)
        execute_process(COMMAND ./configure --prefix=${TOOLCHAIN_TOP}/GCC/multilib --with-arch=rv32im_zve32x --with-abi=ilp32 --enable-multilib   #Multilib build should include all valid configs for ANY benchmark for --with-arch
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)
        execute_process(COMMAND make -j8 #Build crashes with -j${nproc}?
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)

    else()
        message(STATUS "GCC Multilib Build found in ${TOOLCHAIN_TOP}/GCC/multilib")
    endif()
endmacro()

macro(build_gcc_header_only ARCH)

     if(NOT EXISTS "${TOOLCHAIN_TOP}/GCC/${ARCH}")
        message("GCC Headers for ${ARCH} not found. Building")
        # Make sure required dependencies are installed for GCC
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev libncurses-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(STATUS "Downloading Fedora Dependencies")
            execute_process(COMMAND sudo yum install autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel libslirp-devel ncurses-devel
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR GCC")
        endif()

        #riscv-gnu-toolchain submodule is not downloaded with --recursive flag.  Need to checkout if not done already
        if(NOT EXISTS "${TOOLCHAIN_TOP}/riscv-gnu-toolchain/gcc")
            execute_process(COMMAND git submodule update --checkout riscv-gnu-toolchain/
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        endif()
        execute_process(COMMAND make clean
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)
        execute_process(COMMAND ./configure --prefix=${TOOLCHAIN_TOP}/GCC/${ARCH} --with-arch=${ARCH} --with-abi=ilp32 --disable-multilib   #LLVM needs headers (non-multilib) for each specific architecture
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)
        execute_process(COMMAND make -j30 #Build crashes with -j${nproc}?
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-gnu-toolchain/)

    else()
        message(STATUS "GCC Header Build found in ${TOOLCHAIN_TOP}/GCC/${ARCH}")
    endif()

endmacro()

macro(build_llvm)
    build_gcc_header_only(rv32im_zve32x)
    if(NOT EXISTS "${TOOLCHAIN_TOP}/llvm/llvm_22_1_8")

        if(DIST STREQUAL "Ubuntu") #TODO: Find these dependencies
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install 
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(STATUS "Downloading Fedora Dependencies")
            execute_process(COMMAND sudo yum install 
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR LLVM")
        endif()

        if(NOT EXISTS "${TOOLCHAIN_TOP}/llvm-project/clang")
            execute_process(COMMAND git submodule update --checkout llvm-project/
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        endif()

        message(FATAL_ERROR "#####################################################################################################################\n ERROR : LLVM NOT BUILT \n Run the following two commands in the ${TOOLCHAIN_TOP}/llvm-project/ folder \n\n cmake -S llvm -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${TOOLCHAIN_TOP}/llvm/llvm_22_1_8 -DCMAKE_C_COMPILER=clang  -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=\"RISCV\" -DLLVM_ENABLE_PROJECTS=\"clang;lld\"  -DLLVM_DEFAULT_TARGET_TRIPLE=\"riscv32-unknown-linux-gnu\" -DLLVM_INSTALL_TOOLCHAIN_ONLY=On \n\n ninja -C build install \n\n#####################################################################################################################\n")
        # CANNOT CALL cmake project from within cmake project  TODO: resolve this
        # execute_process(COMMAND  cmake -S llvm -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${TOOLCHAIN_TOP}/llvm/llvm_22_1_8 -DCMAKE_C_COMPILER=clang  -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="RISCV" -DLLVM_ENABLE_PROJECTS="clang;lld"  -DLLVM_DEFAULT_TARGET_TRIPLE="riscv32-unknown-linux-gnu" -DLLVM_INSTALL_TOOLCHAIN_ONLY=On
        #                 WORKING_DIRECTORY ${TOOLCHAIN_TOP}/llvm-project/)
        # execute_process(COMMAND  ninja -C build install
        #                 WORKING_DIRECTORY ${TOOLCHAIN_TOP}/llvm-project/)



    else()
        message(STATUS "LLVM found in ${TOOLCHAIN_TOP}/llvm")
    endif()

endmacro()

macro(build_spike)
    if(NOT EXISTS "${TOOLCHAIN_TOP}/spike/bin/spike")
        message("Spike Executable not present, building")

        # Make sure required dependencies are installed for Spike
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install device-tree-compiler libboost-regex-dev libboost-system-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(STATUS "Downloading Fedora Dependencies")
            execute_process(COMMAND sudo yum install device-tree-compiler libboost-regex-dev libboost-system-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR SPIKE")
        endif()

        execute_process(COMMAND mkdir build 
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-isa-sim)
        execute_process(COMMAND ../configure --prefix=${TOOLCHAIN_TOP}/spike
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-isa-sim/build)
        execute_process(COMMAND make -j8
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-isa-sim/build)
        execute_process(COMMAND make install
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/riscv-isa-sim/build)
    endif()
endmacro()

macro(build_verilator)

    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../toolchain/verilator/bin/verilator_bin")
        message("Verilator binary not found in '/toolchain/verilator', building from Verilator submodule")

        # Make sure required dependencies are installed for Verilator
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install help2man perl python3 make autoconf flex bison
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(STATUS "Downloading Fedora Dependencies")
            execute_process(COMMAND sudo yum install help2man perl python3 make autoconf flex bison
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR VERILATOR")
        endif()

        execute_process(COMMAND autoconf
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/verilator/)
        execute_process(COMMAND ./configure --prefix ${TOOLCHAIN_TOP}/verilator/
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/verilator/)
        execute_process(COMMAND make -j${nproc}
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/verilator/)

    endif()

endmacro()

macro(build_gem5) #TODO: Move gem5 submodule to toolchain directory

    if(NOT EXISTS "${GEM5_MODEL_DIR}/gem5/build/ALL/gem5.opt"  OR (REBUILD_GEM5 AND NOT REBUILT))
        message("gem5 executable not present!  Building it now.")
        set(REBUILT ON)

        # Make sure required dependencies are installed for gem5
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt-get install build-essential scons python3-dev git pre-commit zlib1g zlib1g-dev libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev libboost-all-dev  libhdf5-serial-dev python3-pydot python3-venv python3-tk mypy m4 libcapstone-dev libpng-dev libelf-dev pkg-config wget cmake doxygen clang-format
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(WARNING "Downloading Fedora Dependencies - WARNING THIS IS UNTESTED")
            execute_process(COMMAND sudo yum install build-essential scons python3-dev git pre-commit zlib1g zlib1g-dev libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev libboost-all-dev  libhdf5-serial-dev python3-pydot python3-venv python3-tk mypy m4 libcapstone-dev libpng-dev libelf-dev pkg-config wget cmake doxygen clang-format
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR gem5")
        endif()

        # Make sure verilator C files have been built
        if(NOT EXISTS "${VERILATOR_MODEL_DIR}/build/CMakeFiles/verilated_model.dir/Vvproc_top.dir/")
            message(FATAL_ERROR "Verilator Model C Files not present!  Build the verilator model and try again.")
        endif()
        #${nproc} not parsing correctly?
        #In case of error "error while loading shared libraries libpython3.13.so.1.0: no such file or directory", add path to python install /lib folder to $LD_LIBRARY_PATH environment variable
        execute_process(COMMAND scons EXTRAS=${GEM5_MODEL_DIR}/vicuna2_simobject -j32 build/ALL/gem5.opt 
                            WORKING_DIRECTORY ${GEM5_MODEL_DIR}/gem5/)
    endif()

endmacro()

macro(build_etiss)
    # TODO
    if(NOT EXISTS "${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build/installed/bin/bare_etiss_processor")
        message("ETISS Executable not present!  Building it now.")
        # Make sure required dependencies are installed for ETISS
        if(DIST STREQUAL "Ubuntu")
            message(STATUS "Downloading Ubuntu Dependencies")
            execute_process(COMMAND sudo apt install build-essential libboost-all-dev libtinfo-dev zlib1g-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        elseif(DIST STREQUAL "Fedora")
            message(WARNING "Downloading Fedora Dependencies - WARNING THIS IS UNTESTED")
            execute_process(COMMAND sudo yum install cmake build-essential libboost-all-dev libtinfo-dev zlib1g-dev
                            WORKING_DIRECTORY ${TOOLCHAIN_TOP})
        else()
            message(WARNING "MIGHT NEED TO DOWNLOAD DEPENDENCIES FOR YOUR DISTRIBUTION FOR ETISS")
        endif()


        message(WARNING "ETISS build is not fully automated yet.  This might fail. Ensure that the bare_etiss_processor binary is built and present in ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build/installed/bin/bare_etiss_processor")
        execute_process(COMMAND mkdir -p build
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/)
        execute_process(COMMAND cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./installed ..
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build)
        execute_process(COMMAND make -j32 -s install
                        WORKING_DIRECTORY ${TOOLCHAIN_TOP}/etiss_base/etiss_rvv/build)
    endif()
endmacro()

macro(build_iree_compiler)
    if(NOT IREE_HOST_BIN_DIR)
        set(IREE_HOST_BIN_DIR "${TOOLCHAIN_TOP}/iree_compiler/install/bin" CACHE PATH "Path to IREE compiler binaries" FORCE)
    endif()

    if(NOT EXISTS "${IREE_HOST_BIN_DIR}/iree-compile")
        message(STATUS "IREE Compiler not found at ${IREE_HOST_BIN_DIR}, building natively from submodule")
        
        # Configure the IREE host compiler
        execute_process(COMMAND cmake -G Ninja -B ${TOOLCHAIN_TOP}/iree_compiler/build -S ${TOOLCHAIN_TOP}/../benchmark_sources/generic_iree/iree/iree-source -DCMAKE_BUILD_TYPE=Release -DIREE_BUILD_TESTS=OFF -DIREE_BUILD_SAMPLES=OFF -DIREE_HAL_DRIVER_LOCAL_TASK=OFF -DCMAKE_INSTALL_PREFIX=${TOOLCHAIN_TOP}/iree_compiler/install)
                        
        # Build and install the IREE host compiler
        # Using parallel build automatically with Ninja
        execute_process(COMMAND cmake --build ${TOOLCHAIN_TOP}/iree_compiler/build --target install)
        
        if(NOT EXISTS "${IREE_HOST_BIN_DIR}/iree-compile")
            message(FATAL_ERROR "Failed to build IREE compiler natively. Check the CMake logs.")
        endif()
    else()
        message(STATUS "IREE Compiler found in ${IREE_HOST_BIN_DIR}")
    endif()
endmacro()
