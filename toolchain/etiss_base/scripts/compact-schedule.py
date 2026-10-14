#!/usr/bin/env python3

import pathlib
from instrgroups import group_mapping

batch_model_name = "perfModel->vectorBatchHandModel"

group_batch_fun_mapping = {
    "V_vmv_v_i": "getLmul()",
    "V_vmv_regs": "getNfSimm5()",
    "V_vmv_s_x": "one()",
    "V_vmv_x_s": "one()",
    "V_Load": "getLoadStoreEmul()",
    "V_Load_Registers": "getNf()",
    "V_Store": "getLoadStoreEmul()",
    "V_Store_Registers": "getNf()",
    "V_Div_vv": "getLmul()",
    "V_Div_vx": "getLmul()",
    "V_Ext": "getLmul()",
    "V_REDSUM": "getLmul()",
    "V_REDMINMAX": "getLmul()",
    "V_ALU_vv": "getLmul()",
    "V_MUL_vv": "getLmul()",
    "V_ALU_Widening_vv": "getLmul() * 2",
    "V_MUL_Widening_vv": "getLmul() * 2",
    "V_ALU_vx": "getLmul()",
    "V_MUL_vx": "getLmul()",
    "V_ALU_Widening_vx": "getLmul() * 2",
    "V_MUL_Widening_vx": "getLmul() * 2",
    "V_ALU_vi": "getLmul()",
    "V_SLD": "getLmul()",
    "V_ELEM": "getLmul()",
    "V_INDEX": "getLmul()",
    "V_XRESULT": "one()",
}

ETISS_PERFSIM_DIR = pathlib.Path(__file__).parent.parent / "etiss_perfsim"
VARIANTS_DIR = (
    ETISS_PERFSIM_DIR
    / "etiss-perf-sim/etiss_plugins/SoftwareEvalLib/libs/backends/variants"
)
VLENS = [64, 128, 256, 512, 1024]


def zvl(vlen: int) -> str:
    return f"Vicuna_zvl{vlen}b"


def get_header_cpp(vlen: int):
    return f"""
#include <algorithm>
#include <cstdint>
#include "PerformanceModel.h"
#include "{zvl(vlen)}_PerformanceModel.h"

namespace {zvl(vlen)} {{
"""


def get_header_hpp(vlen: int):
    return f"""
#include "PerformanceModel.h"

namespace {zvl(vlen)} {{
"""


def write_cmake(path: pathlib.Path, vlen: int):
    with open(path, "w", encoding="utf-8") as cmake:
        cmake.write(f"""
TARGET_SOURCES(SWEVAL_BACKENDS_LIB PRIVATE
    src/{zvl(vlen)}_Channel.cpp
    src/{zvl(vlen)}_InstructionPrinters.cpp
    src/{zvl(vlen)}_Printer.cpp
    src/{zvl(vlen)}_GroupSchedulingFunction.cpp
    src/{zvl(vlen)}_ResultSchedulingFunction.cpp
    src/{zvl(vlen)}_PerformanceModel.cpp
)

TARGET_INCLUDE_DIRECTORIES(SWEVAL_BACKENDS_LIB PRIVATE
include
)
""")


def main():

    extraction_mapping: dict = {
        igroup: insns[0] for igroup, insns in group_mapping.items()
    }

    for vlen in VLENS:
        variant_dir = VARIANTS_DIR / zvl(vlen)
        src_dir = variant_dir / "src"
        orig_sched_cpp = src_dir / f"{zvl(vlen)}_SchedulingFunction.cpp"
        result_sched_cpp = src_dir / f"{zvl(vlen)}_ResultSchedulingFunction.cpp"
        group_sched_cpp = src_dir / f"{zvl(vlen)}_GroupSchedulingFunction.cpp"
        group_sched_hpp = src_dir / f"{zvl(vlen)}_GroupSchedulingFunction.hpp"
        cmake_path = variant_dir / "CMakeLists.txt"

        with open(orig_sched_cpp, "r", encoding="utf-8") as orig_cpp, open(
            group_sched_cpp, "w", encoding="utf-8"
        ) as group_cpp, open(
            result_sched_cpp, "w", encoding="utf-8"
        ) as result_cpp, open(
            group_sched_hpp, "w", encoding="utf-8"
        ) as group_hpp:
            group_cpp.write(get_header_cpp(vlen))
            group_hpp.write(get_header_hpp(vlen))

            active = False
            printout = False
            in_batch = False
            batch_var_stack = []
            batch_calc_stack = []
            scalar_copy = True
            inline = False
            vector_copy = False
            vlevel = 0
            level = 0
            current_grp = ""
            for i, line in enumerate(orig_cpp):

                if inline:
                    result_cpp.write(line)
                    continue

                if "namespace" in line and "//" not in line:
                    result_cpp.write(
                        f'#include "{zvl(vlen)}_GroupSchedulingFunction.hpp"\n\n'
                    )

                # Greedily update vector instruction
                for grp, grp_insns in group_mapping.items():
                    for insn in grp_insns:
                        if f'"{insn}"' in line:
                            current_grp = grp

                # Scalar & vector copying
                if "static SchedulingFunction *schedulingFunction_vle32_v" in line:
                    scalar_copy = False
                if "static SchedulingFunction *schedulingFunction__def" in line:
                    inline = True
                    scalar_copy = True

                if (
                    f"{zvl(vlen)}_PerformanceModel *perfModel" in line
                    or f"{zvl(vlen)}_PerformanceModel* perfModel" in line
                ):
                    # Insert call in vector scheduling function
                    result_cpp.write(f"\t{current_grp}(perfModel_);\n")
                    vector_copy = False
                    scalar_copy = False
                    vlevel = 1

                vlevel += line.count("(")
                vlevel -= line.count(")")

                if vlevel <= 0:
                    if (
                        not scalar_copy
                        and not vector_copy
                        and not "}" in line
                        and line.strip()
                    ):
                        result_cpp.write("}")
                    vector_copy = True
                    scalar_copy = True

                if scalar_copy:
                    result_cpp.write(line)
                elif vector_copy:
                    result_cpp.write(line)

                # Vector extracting
                if not active:
                    for group, single in extraction_mapping.items():
                        if f'"{single}"' in line:
                            group_cpp.write(
                                f"void {group}(PerformanceModel *perfModel_) {{\n{zvl(vlen)}_PerformanceModel *perfModel = static_cast<{zvl(vlen)}_PerformanceModel *>(perfModel_);\n"
                            )
                            group_hpp.write(
                                f"void {group}(PerformanceModel *perfModel_);\n\n"
                            )
                            active = True
                else:
                    if not printout:
                        if "// Enter" in line:
                            level = 1
                            printout = True
                    else:
                        level += line.count("{")
                        level -= line.count("}")
                        if level <= 0:
                            # print(f"Done Line {i}")
                            active = False
                            printout = False
                            group_cpp.write("}\n\n")
                            continue

                        if in_batch:
                            line = line.replace("getVs1()", "getVs1(batch_i)")
                            line = line.replace("getVs2()", "getVs2(batch_i)")
                            line = line.replace("getVs3()", "getVs3(batch_i)")
                            line = line.replace("setVd(", "setVd(batch_i,")
                            line = line.replace(
                                "perfModel->V1_Subpipe,",
                                "(batch_i == 0) * (perfModel->V1_Subpipe + 1),",
                            )
                            line = line.replace(
                                "perfModel->V2_Subpipe,",
                                "(batch_i == 0) * (perfModel->V2_Subpipe + 1),",
                            )
                            if "uint64_t" in line and "=" not in line:
                                # Variable
                                batch_var_stack.append(line)
                            else:
                                # Calc
                                batch_calc_stack.append(line)
                        else:
                            group_cpp.write(line)

                        if "// V1_Unpack" in line or "// V2_Unpack" in line:
                            in_batch = True
                        if (
                            "perfModel->V2_Pack_stg = n_V2_Pack_stg;" in line
                            or "perfModel->V1_Pack_stg = n_V1_Pack_stg;" in line
                        ):
                            in_batch = False
                            group_cpp.write("// Batched Pipeline Variables\n")
                            for var_line in batch_var_stack:
                                group_cpp.write(var_line)
                            first_var = batch_var_stack[0].strip().split(" ")[1][:-1]
                            batch_var_stack = []
                            group_cpp.write("// Batched Pipeline Calculation Loop\n")
                            group_cpp.write(
                                f"for (size_t batch_i = 0; batch_i < {batch_model_name}.{group_batch_fun_mapping[current_grp]}; batch_i++) {{\n"
                            )
                            delay_fun = ""
                            for calc_line in batch_calc_stack:
                                pipe = "V1" if "V1" in calc_line else "V2"
                                if f"{first_var} =" in calc_line:
                                    delay_fun = calc_line[
                                        calc_line.find("+") + 1 :
                                    ].strip()[:-1]
                                    calc_line = f"{first_var} = (batch_i == 0 ? n_V_DISP_stg : n_{pipe}_Unpack_stg);\n"
                                group_cpp.write(calc_line)

                            batch_calc_stack = []
                            group_cpp.write("}\n")
                            group_cpp.write("// End Batch Loop")

            group_cpp.write("} // Namespace")
            group_hpp.write("} // Namespace")
            write_cmake(cmake_path, vlen)


if __name__ == "__main__":
    main()
