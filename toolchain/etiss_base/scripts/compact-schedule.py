#!/usr/bin/env python3

import pathlib

batch_model_name = "perfModel->vectorBatchHandModel"

group_batch_fun_mapping = {
    "V_vmv_v_i": "getLmul()",
    "V_vmv_regs": "getNfSimm5()",
    "V_vmv_x_s": "one()",
    "V_vmv_s_x": "one()",
    "V_Load": "getLoadStoreEmul()",
    "V_Load_Registers": "getNf()",
    "V_Store": "getLoadStoreEmul()",
    "V_Store_Registers": "getNf()",
    "V_Div_vv": "getLmul()",
    "V_Div_vx": "getLmul()",
    "V_Ext": "getLmul()",
    "V_RED_vv": "getLmul()",
    "V_ALU_vv": "getLmul()",
    "V_MUL_vv": "getLmul()",
    "V_ALU_Widening_vv": "getLmul() * 2",
    "V_MUL_Widening_vv": "getLmul() * 2",
    "V_ALU_vx": "getLmul()",
    "V_MUL_vx": "getLmul()",
    "V_ALU_Widening_vx": "getLmul() * 2",
    "V_MUL_Widening_vx": "getLmul() * 2",
    "V_ALU_vi": "getLmul()",
}

group_mapping = {
    "V_vmv_v_i": ["vmv_v_i"],
    "V_vmv_regs": ["vmvr_v"],
    "V_vmv_x_s": ["vmv_x_s"],
    "V_vmv_s_x": ["vmv_s_x"],
    "V_Load": ["vle32_v", "vle16_v", "vle8_v"],
    "V_Load_Registers": ["vl8r_v", "vl16r_v", "l32r_v"],
    "V_Store": ["vse32_u", "vse16_u", "vse8_u"],
    "V_Store_Registers": ["vsr_v"],
    "V_Div_vv": ["vdiv_vv", "vdivu_vv", "vremu_vv", "vrem_vv"],
    "V_Div_vx": ["vdiv_vx", "vdivu_vx", "vremu_vx", "vrem_vx"],
    "V_Ext": [
        "vzext_vf2",
        "vsext_vf2",
        "vzext_vf4",
        "vsext_vf4",
        "vzext_vf8",
        "vsext_vf8",
    ],
    "V_RED_vv": [
        "vcompress_vm",
        "vredsum_vs",
        "vredmaxu_vs",
        "vredmax_vs",
        "vredminu_vs",
        "vredmin_vs",
        "vredand_vs",
        "vredor_vs",
        "vredxor_v",
    ],
    "V_ALU_vv": [
        "vadd_vv",
        "vsub_vv",
        "vadc_vvm",
        "vmadc_vv",
        "vsbc_vvm",
        "vmsbc_vv",
        "vand_vv",
        "vor_vv",
        "vxor_vv",
        "vsll_vv",
        "vsrl_vv",
        "vsra_vv",
        "vmseq_vv",
        "vmsne_vv",
        "vmsltu_vv",
        "vmslt_vv",
        "vmsleu_vv",
        "vmsle_vv",
        "vminu_vv",
        "vmin_vv",
        "vmaxu_vv",
        "vmax_vv",
        "vmerge_vvm",
        "vsaddu_vv",
        "vsadd_vv",
        "vssubu_vv",
        "vssub_vv",
        "vaaddu_vv",
        "vaadd_vv",
        "vasubu_vv",
        "vasub_vv",
        "vsmul_vv",
        "vssrl_vv",
        "vssra_vv",
    ],
    "V_MUL_vv": [
        "vmul_vv",
        "vmulh_vv",
        "vmulhu_vv",
        "vmulhsu_vv",
        "vmacc_vv",
        "vnmsac_vv",
        "vmadd_vv",
        "vnmsub_vv",
    ],
    "V_ALU_Widening_vv": [
        "vwaddu_vv",
        "vwsubu_vv",
        "vwadd_vv",
        "vwsub_vv",
        "vwaddu_w_vv",
        "vwsubu_w_vv",
        "vwadd_w_vv",
        "vwsub_w_vv",
    ],
    "V_MUL_Widening_vv": [
        "vwmul_vv",
        "vwmulu_vv",
        "vwmulsu_vv",
        "vwmaccu_vv",
        "vwmacc_vv",
        "vwmaccsu_vv",
    ],
    "V_ALU_vx": [
        "vadd_vx",
        "vsub_vx",
        "vrsub_vx",
        "vadc_vxm",
        "vmadc_vx",
        "vsbc_vxm",
        "vmsbc_vx",
        "vand_vx",
        "vor_vx",
        "vxor_vx",
        "vsll_vx",
        "vsrl_vx",
        "vsra_vx",
        "vmseq_vx",
        "vmsne_vx",
        "vmsltu_vx",
        "vmslt_vx",
        "vmsleu_vx",
        "vmsle_vx",
        "vmsgtu_vx",
        "vmsgt_vx",
        "vminu_vx",
        "vmin_vx",
        "vmaxu_vx",
        "vmax_vx",
        "vmerge_vxm",
        "vsaddu_vx",
        "vsadd_vx",
        "vssubu_vx",
        "vssub_vx",
        "vaaddu_vx",
        "vaadd_vx",
        "vasubu_vx",
        "vasub_vx",
        "vsmul_vx",
        "vssrl_vx",
        "vssra_vx",
        "vslideup_vx",
        "vslidedown_vx",
        "vslide1up_vx",
        "vslide1down_vx",
    ],
    "V_MUL_vx": [
        "vmul_vx",
        "vmulh_vx",
        "vmulhu_vx",
        "vmulhsu_vx",
        "vmacc_vx",
        "vnmsac_vx",
        "vmadd_vx",
        "vnmsub_vx",
    ],
    "V_ALU_Widening_vx": [
        "vwaddu_vx",
        "vwsubu_vx",
        "vwadd_vx",
        "vwsub_vx",
        "vwaddu_w_vx",
        "vwsubu_w_vx",
        "vwadd_w_vx",
        "vwsub_w_vx",
    ],
    "V_MUL_Widening_vx": [
        "vwmul_vx",
        "vwmulu_vx",
        "vwmulsu_vx",
        "vwmaccu_vx",
        "vwmacc_vx",
        "vwmaccsu_vx",
        "vwmaccus_vx",
    ],
    "V_ALU_vi": [
        "vadd_vi",
        "vrsub_vi",
        "vadc_vim",
        "vmadc_vi",
        "vand_vi",
        "vor_vi",
        "vxor_vi",
        "vsll_vi",
        "vsrl_vi",
        "vsra_vi",
        "vmseq_vi",
        "vmsne_vi",
        "vmsleu_vi",
        "vmsle_vi",
        "vmsgtu_vi",
        "vmsgt_vi",
        "vmerge_vim",
        "vsaddu_vi",
        "vsadd_vi",
        "vssrl_vi",
        "vssra_vi",
        "vslideup_vi",
        "vslidedown_vi",
    ],
    "V_vsetivli": ["vsetivli"],
    "V_vsetvli": ["vsetvli"],
    "V_vsetvl": ["vsetvl"],
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
            vlevel = 0
            level = 0
            current_grp = ""
            for i, line in enumerate(orig_cpp):
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
                    scalar_copy = True

                if (
                    f"{zvl(vlen)}_PerformanceModel *perfModel" in line
                    or f"{zvl(vlen)}_PerformanceModel* perfModel" in line
                ):
                    # Insert call in vector scheduling function
                    if not scalar_copy:
                        # vector_cpp.write(f"\t{current_grp}(perfModel_);\n")
                        result_cpp.write(f"\t{current_grp}(perfModel_);\n")
                    vector_copy = False
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
                        # vector_cpp.write("}")
                        result_cpp.write("}")
                    vector_copy = True

                if scalar_copy:
                    result_cpp.write(line)
                elif vector_copy:
                    # vector_cpp.write(line)
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
                            # print(f"Found Line {i}")
                else:
                    if not printout:
                        if "// Enter" in line:
                            # print(f"Print Line {i}")
                            # group_cpp.write(f'std::printf("{current_grp}\\n");')
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
                                if f"n_V1_Unpack_1 =" in calc_line:
                                    calc_line = calc_line.replace("n_V_DISP_stg", f"(batch_i == 0 ? n_V_DISP_stg : n_V1_Unpack_1_stg)")
                                elif f"{first_var} =" in calc_line:
                                    delay_fun = calc_line[calc_line.find("+") + 1:].strip()[:-1]
                                    # print(delay_fun)
                                    calc_line = f"{first_var} = (batch_i == 0 ? n_V_DISP_stg : n_{pipe}_Unpack_1_stg);\n"
                                group_cpp.write(calc_line)

                                if f"n_{pipe}_Unpack_1_stg =" in calc_line:
                                    group_cpp.write(f"n_{pipe}_Unpack_1_stg += {delay_fun} - 1;\n")

                            batch_calc_stack = []
                            group_cpp.write("}\n")
                            group_cpp.write("// End Batch Loop")

            group_cpp.write("} // Namespace")
            group_hpp.write("} // Namespace")
            write_cmake(cmake_path, vlen)


if __name__ == "__main__":
    main()
