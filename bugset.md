# NutShell 处理器错误定位实验 Bug 清单

本文件为 NutShell 处理器 SBFL（基于软件的错误定位）实验的最终 bug 清单，共 **20 个实例**，涵盖：

- **17 个注入 bug**（通过 patch 修改源代码植入，其中 1 个源自 riscv-mini 论文 bug）
- **3 个真实设计缺陷**（NutShell 代码中已存在的 bug，通过 case 直接触发）

覆盖范围：非特权整数指令、M 扩展、译码、CSR/Trap、异常精确提交、流水线协同、页表/MMU。

部分 bug 对应论文 *"Formal Verification of RISC-V Processor Chisel Designs"* (ChiRVFormal) 中通过形式化验证发现的设计缺陷。对 riscv-mini 中发现但 NutShell 不存在的 bug（R:E2），设计了对应的 patch 进行注入。

---

## 总览

| 类别 | 数量 | 主要覆盖内容 | 类型 |
|------|-----:|-------------|------|
| A. 非特权整数指令 | 5 | ALU、比较器、跳转、load 扩展 | 注入 |
| B. M 扩展 | 1 | 除法边界语义 | 注入 |
| C. 译码 | 1 | 译码错误 | 注入 |
| D. CSR / trap | 2 | mepc、mret | 注入 |
| E. 异常与精确提交 | 2 | precise exception、fault 后写回 | 注入 |
| F. 流水线 | 2 | forwarding、flush | 注入 |
| G. 页表 / MMU | 3 | PTE 合法性、superpage、TLB flush | 注入 |
| H. riscv-mini bug 注入 | 1 | store 非对齐异常未抑制写入 | **注入（源自 riscv-mini）** |
| I. 形式化验证发现的真实 bug | 3 | mtval、xRET 权限、分支对齐 | **真实缺陷** |
| **合计** | **20** | 处理器核心语义与系统级行为 | |

---

## 实验集详表

### A. 非特权整数指令 bug（5 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| U1 | `ADDIW` 符号扩展错误 | ALU / writeback | RV64 中 32 位结果零扩展而非符号扩展 | `addiw x2,x1,0`，bit31 为 1 |
| U3 | `SLT/SLTU` signedness 混淆 | comparator | 有符号比较和无符号比较混用 | `li x1,-1; li x2,1; slt x3,x1,x2` |
| U6 | `JALR` 目标地址最低位未清零 | jump unit | `JALR` 没有将跳转目标 bit0 清零 | `li x1,target+1; jalr x0,0(x1)` |
| U7 | `LB/LBU` 符号/零扩展混淆 | load unit | 有符号 load 和无符号 load 扩展方式互换 | 读取 `0x80` 后检查符号扩展 |
| U8 | `LWU` 零扩展错误 | load unit | RV64 中 `LWU` 被错误符号扩展 | `lwu x1,0(x2)` 对 `0xffffffff` |

### B. M 扩展 bug（1 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| M1 | `DIV/REM` 除零语义错误 | divider | 除零时 quotient/remainder 结果错误 | `div x3,x1,x0; rem x4,x1,x0` |

### C. 译码 bug（1 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| D1 | `SUB/SRA` 译码混淆 | decoder | `SUB` 被译码成 `ADD` | `sub x3,x1,x2` |

### D. CSR / trap bug（2 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| P4 | `mepc` 保存错误 | trap controller | trap 时 `mepc` 保存为 `pc+4` | `ecall` 后读取 `mepc` |
| P6 | `MRET` 恢复特权级错误 | trap return unit | mret 后特权级始终降为 U-mode | 设置 `mstatus.MPP=M` 后执行 `mret` |

### E. 异常与精确提交 bug（2 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| E1 | precise exception 错误 | commit / flush | 异常指令之后的 younger instruction 仍然提交 | `ecall; addi x5,x0,1` |
| E2 | load exception 后错误写回 | LSU / writeback | load fault 后目的寄存器仍被写入 | faulting load 后检查 `rd` |

### F. 流水线 bug（2 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 |
|------|---------|---------|---------|-------------|
| C1 | ALU-ALU forwarding 错误 | bypass network | 前一条 ALU 结果没有正确转发 | `add x1,x2,x3; sub x4,x1,x5` |
| C3 | branch flush 后错误写回 | pipeline flush | taken branch 冲刷掉的指令仍然写回 | `beq x0,x0,L; addi x5,x0,1` |

### G. 页表 / MMU bug（3 个，注入）

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 典型触发模式 | 论文对应 |
|------|---------|---------|---------|-------------|---------|
| PT4 | PTE `R/W` 合法性检查缺失 | permission check | `R=0,W=1` 的非法 PTE 未触发 page fault | 构造非法权限 PTE | N:E5 |
| PT9 | superpage 对齐掩码错误 | page table walker | superpage 的 VPN 掩码始终使用叶级 | 构造 2MiB superpage | N:E4 |
| PT10 | `SFENCE.VMA` 无效 | TLB flush | 修改 PTE 后 `sfence.vma` 不刷新 TLB | 改 PTE 后访问同一 VA | — |

### H. riscv-mini bug 注入（1 个，注入）

以下 bug 来自 ChiRVFormal 论文中 riscv-mini 的设计缺陷。该 bug 在 riscv-mini 中存在但在 NutShell 中**不存在**（NutShell 已正确处理）。为覆盖此类 bug 模式，通过 patch 将其注入 NutShell。

| 编号 | Bug 名称 | 植入位置 | 错误描述 | 论文编号 | 典型触发模式 |
|------|---------|---------|---------|---------|-------------|
| RE2 | store 非对齐异常未抑制写入 | UnpipelinedLSU | store 地址非对齐触发异常后，dmem 请求未被正确抑制，仍向内存发出写入 | R:E2 | `sw` 到奇数地址后检查内存是否被改写 |

**Patch 设计说明**：NutShell 在 `UnpipelinedLSU.scala:379` 通过 `dmem.req.valid := ... && !io.storeAddrMisaligned` 抑制非对齐 store 的内存写入。Patch 移除 `!io.storeAddrMisaligned` 条件，使非对齐 store 仍发出内存请求，复现 riscv-mini R:E2 的行为。

### I. 形式化验证发现的真实设计缺陷（3 个，无 patch）

以下 bug 来自 ChiRVFormal 论文对 NutShell 的形式化验证结果，为 NutShell 源码中**真实存在**的设计缺陷。这些 bug 不需要 patch 注入——测试用例直接触发代码中的现有错误。

| 编号 | Bug 名称 | 错误位置 | 错误描述 | 论文编号 | 典型触发模式 |
|------|---------|---------|---------|---------|-------------|
| NE1 | `mtval` 高位不可写 | CSR.scala | 异常发生时 `mtval[63:39]` 通过 SignExt 从 39 位扩展，无法独立写入 | N:E1 | 触发 load 地址非对齐异常后检查 mtval 值 |
| NE3 | `xRET` 缺少权限检查 | CSR.scala | SRET 可从 U-mode 执行，不触发 illegal instruction 异常 | N:E3 | 连续执行两次 SRET，第二次应在 U-mode 触发异常 |
| RE1 | 条件分支缺少对齐检查 | IFU/BRU | 条件分支跳转到非对齐地址时不触发指令地址非对齐异常 | R:E1 | `beq x0,x0, misaligned_target` |

---

## Bug 与源文件对应关系

### 注入 bug（有 patch）

| 编号 | Case 文件 | Patch 文件 | 修改的源文件 |
|------|----------|-----------|-------------|
| U1 | `case/U1_addiw_signext.S` | `patch/U1_addiw_signext.patch` | `ALU.scala` |
| U3 | `case/U3_slt_sltu_swap.S` | `patch/U3_slt_sltu_swap.patch` | `ALU.scala` |
| U6 | `case/U6_jalr_bit0_not_cleared.S` | `patch/U6_jalr_bit0_not_cleared.patch` | `ALU.scala` |
| U7 | `case/U7_lb_lbu_ext_swap.S` | `patch/U7_lb_lbu_ext_swap.patch` | `LSU.scala` |
| U8 | `case/U8_lwu_signext.S` | `patch/U8_lwu_signext.patch` | `LSU.scala` |
| M1 | `case/M1_div_by_zero.S` | `patch/M1_div_by_zero.patch` | `MDU.scala` |
| D1 | `case/D1_sub_sra_decode.S` | `patch/D1_sub_sra_decode.patch` | `IDU.scala` |
| P4 | `case/P4_mepc_save_error.S` | `patch/P4_mepc_save_error.patch` | `CSR.scala` |
| P6 | `case/P6_mret_privilege_mode.S` | `patch/P6_mret_privilege_mode.patch` | `CSR.scala` |
| E1 | `case/E1_precise_exception_writeback.S` | `patch/E1_precise_exception_writeback.patch` | `EXU.scala` |
| E2 | `case/E2_load_exception_writeback.S` | `patch/E2_load_exception_writeback.patch` | `EXU.scala` |
| C1 | `case/C1_alu_forwarding_disabled.S` | `patch/C1_alu_forwarding_disabled.patch` | `ISU.scala` |
| C3 | `case/C3_branch_no_redirect.S` | `patch/C3_branch_no_redirect.patch` | `BRU.scala` |
| PT4 | `case/PT4_pte_rw_legality_check.S` | `patch/PT4_pte_rw_legality_check.patch` | `EmbeddedTLB.scala` |
| PT9 | `case/PT9_superpage_mask_error.S` | `patch/PT9_superpage_mask_error.patch` | `EmbeddedTLB.scala` |
| PT10 | `case/PT10_sfence_vma_flush_disabled.S` | `patch/PT10_sfence_vma_flush_disabled.patch` | `EmbeddedTLB.scala` |
| RE2 | `case/RE2_store_misaligned_flush.S` | `patch/RE2_store_misaligned_flush.patch` | `UnpipelinedLSU.scala` |

### 真实缺陷（无 patch，仅有 case）

| 编号 | Case 文件 | Bug 所在源文件 | 说明 |
|------|----------|--------------|------|
| NE1 | `case/NE1_mtval_high_bits.S` | `CSR.scala:588,597` | `mtval` 通过 `SignExt(addr(VAddrBits-1,0), XLEN)` 写入，VAddrBits=39 |
| NE3 | `case/NE3_xret_privilege_check.S` | `CSR.scala:695-706` | SRET 执行无当前特权级检查 |
| RE1 | `case/RE1_branch_misaligned.S` | `IFU.scala` / `BRU.scala` | 无分支指令目标地址对齐检查 |

---

## 论文 bug 对应关系

ChiRVFormal 论文共在 NutShell 中发现 5 个真实设计缺陷（N:E1–N:E5），在 riscv-mini 中发现 2 个（R:E1–R:E2）。与本文实验集的对应关系如下：

| 论文编号 | 论文描述 | 在 NutShell 中 | 本实验集 | 类型 |
|---------|---------|---------------|---------|------|
| N:E1 | mtval 高位不可写 | 存在 | **NE1**（直接触发） | 真实缺陷 |
| N:E2 | Sv39 物理地址仅 32 位 | 存在（设计选择） | — | 难以通过仿真测试 |
| N:E3 | xRET 缺少权限检查 | 存在 | **NE3**（直接触发） | 真实缺陷 |
| N:E4 | superpage 对齐检查缺失 | 不存在 | **PT9**（patch 注入） | 注入 bug |
| N:E5 | PTE X/W/R/V 角标缺失 | 不存在 | **PT4**（patch 注入） | 注入 bug |
| R:E1 | 分支指令缺少对齐异常 | 存在 | **RE1**（直接触发） | 真实缺陷 |
| R:E2 | store 非对齐异常未抑制写入 | **不存在** | **RE2**（patch 注入） | **注入 bug** |

---

## 实验分层

### Level 1：单指令语义 bug（9 个）

验证方法能否定位基础 ISA 语义错误。

```
U1, U3, U6, U7, U8, M1, D1, NE1, RE1
```

### Level 2：特权、CSR 与异常 bug（4 个）

验证方法能否处理系统级状态错误。

```
P4, P6, E1, E2
```

### Level 3：多指令协同与系统级 bug（7 个）

验证 instruction sequence 在处理器错误定位中的必要性。

```
C1, C3, PT4, PT9, PT10, RE2, NE3
```

---

## 说明

1. **注入 bug vs 真实缺陷**：标记为"注入"的 bug 通过 git patch 修改 NutShell 源码植入，用于评估 SBFL 工具的定位能力；标记为"真实缺陷"的 bug 是 NutShell 源码中已存在的设计问题，直接通过测试用例触发。

2. **riscv-mini bug 注入（RE2）**：论文在 riscv-mini 中发现 R:E2（store 非对齐异常后未正确抑制后续内存写入），该 bug 在 NutShell 中不存在。为覆盖此类 bug 模式，设计 patch 移除 `UnpipelinedLSU.scala` 中对 `storeAddrMisaligned` 的内存请求门控，使非对齐 store 仍发出内存写入请求。

3. **数据集精简原则**：从原始 34 个 bug 中选取 20 个代表性实例，覆盖处理器主要功能模块（ALU、LSU、MDU、译码器、CSR、流水线控制、MMU/TLB），同时加入经形式化验证确认的真实缺陷和跨处理器注入 bug，增强实验的可信度。

4. **PT4 与 PT9**：这两个注入 bug 的模式分别对应论文中 N:E5（PTE 权限角标缺失）和 N:E4（superpage 对齐检查缺失），验证了论文发现的缺陷类型。

5. **NE2 未纳入**：论文发现的 N:E2（Sv39 物理地址仅 32 位）是 NutShell 的架构级设计选择（`PAddrBits = 32`），难以通过仿真测试触发，因此未纳入实验集。
