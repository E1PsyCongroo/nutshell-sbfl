# NutShell Processor Fault Localization Benchmark（Compact Main Set）

本文件给出一个更适合实验规模控制的处理器错误定位主数据集版本。相比原始 `bugset.md` 的 20 个实例，本版本不再盲目扩展到 32 个，而是采用“**代表性优先 + 可复现优先 + 规模可控**”原则，将 main benchmark 控制在 **24 个 bug 实例**。

其中：

- **18 个实例**来自原始 NutShell bugset 的核心保留项；
- **6 个实例**来自近年处理器验证 / fuzzing 论文中高频出现的真实缺陷模式，并以 patch 形式注入 NutShell；
- 保留原始数据集中的 **3 个 NutShell 真实设计缺陷**；
- 删除或下放若干语义相近、实验价值重复或实现成本较高的 bug。

最终数据集规模为：

| 类型 | 数量 | 说明 |
|------|-----:|------|
| 原始 bugset 保留实例 | 18 | 从原始 20 个实例中筛选，保留覆盖核心模块和系统级行为的代表项 |
| 论文启发式新增实例 | 6 | 来自 DIFUZZRTL、TheHuzz、MorFuzz、Cascade、SimFuzz、ReFuzz 等论文中的高频缺陷模式 |
| 真实 NutShell 缺陷 | 3 | 直接触发，无需 patch |
| patch 注入缺陷 | 21 | 通过修改 NutShell 源码植入 |
| **合计** | **24** | 适合作为主实验 benchmark |

---

## 1. 筛选原则

本版本不追求覆盖所有近期论文中出现过的处理器 bug，而是优先选择满足以下条件的缺陷模式：

1. **在近期处理器验证论文中反复出现**  
   例如非法指令未拦截、CSR 权限检查缺失、异常类型/优先级错误、LR/SC reservation 错误、性能计数器错误等。

2. **能够自然映射到 NutShell**  
   优先选择 NutShell 已支持或容易通过局部 patch 注入的功能。对于 FPU、Vector、AES、Hypervisor、复杂 cache coherence 等依赖特定扩展的 bug，不放入 main benchmark。

3. **适合错误定位实验**  
   触发后应产生明确的 pass/fail 差异，且错误应能映射到具体 RTL 模块或代码片段。纯 deadlock、timeout-only、板级固件相关或硅片特定 bug 不作为主集。

4. **避免功能重复**  
   对同一类错误只保留最有代表性的实例。例如 load 扩展错误保留 `LB/LBU`，不再同时保留 `LWU`；整数比较 signedness 错误下放到扩展集。

---

## 2. Main Benchmark 总览

| 类别 | 数量 | 主要覆盖内容 | 实例 |
|------|-----:|--------------|------|
| A. 基础 ISA 与数据通路语义 | 4 | ALU、跳转、load 扩展、M 扩展 | U1, U6, U7, M1 |
| B. 译码与非法指令处理 | 4 | 普通译码、FENCE/FENCE.I、非法 load/store 编码 | D1, X1, X2, RE1 |
| C. CSR / Trap / 特权状态 | 5 | mepc、mret、mtval、xRET、CSR 权限 | P4, P6, NE1, NE3, X3 |
| D. 异常、异常优先级与副作用抑制 | 5 | precise exception、fault 后写回、store fault 抑制、PMP/PMA、LR/SC | E1, E2, RE2, X4, X5 |
| E. 流水线与微架构协同 | 2 | forwarding、branch flush | C1, C3 |
| F. 页表 / MMU / TLB | 3 | PTE 合法性、superpage、TLB flush | PT4, PT9, PT10 |
| G. 性能计数器与观测状态 | 1 | minstret / retired instruction count | X6 |
| **合计** | **24** | 处理器核心语义、特权状态、异常、流水线、MMU 与观测状态 | |

---

## 3. 实验集详表

### A. 基础 ISA 与数据通路语义（4 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| U1 | `ADDIW` 符号扩展错误 | 原始 bugset | ALU / writeback | RV64 中 32 位结果零扩展而非符号扩展 | `addiw x2,x1,0`，bit31 为 1 |
| U6 | `JALR` 目标地址最低位未清零 | 原始 bugset | jump unit | `JALR` 没有将跳转目标 bit0 清零 | `li x1,target+1; jalr x0,0(x1)` |
| U7 | `LB/LBU` 符号/零扩展混淆 | 原始 bugset | load unit | 有符号 load 和无符号 load 的扩展方式互换 | 读取 `0x80` 后检查符号扩展 |
| M1 | `DIV/REM` 除零语义错误 | 原始 bugset | divider | 除零时 quotient/remainder 结果错误 | `div x3,x1,x0; rem x4,x1,x0` |

**筛选说明**：这一类保留少量基础 ISA 语义错误，用于检验方法在简单数据通路错误上的基本定位能力。原始 bugset 中的 `U3` 和 `U8` 可下放到扩展集，避免单指令语义错误占比过高。

---

### B. 译码与非法指令处理（4 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| D1 | `SUB/SRA` 译码混淆 | 原始 bugset | decoder | `SUB` 被错误译码为 `ADD` 或相关 ALU 操作 | `sub x3,x1,x2` |
| X1 | `FENCE/FENCE.I` 非法字段检查缺失 | TheHuzz / MorFuzz / ReFuzz 启发 | decoder / control | 对 `FENCE` 或 `FENCE.I` 的保留字段、funct3 或 rs/rd 字段检查不完整，非法编码被当作合法指令执行 | 构造保留字段非零的 `fence.i` 或非法 `fence` 编码 |
| X2 | 非法 `LOAD/STORE` funct3 被执行 | ReFuzz / SimFuzz 启发 | decoder / LSU | 对未定义的 load/store `funct3` 编码未触发 illegal instruction，而是进入 LSU 执行路径 | 构造非法 load/store 编码并检查是否 trap |
| RE1 | 条件分支缺少目标地址对齐检查 | 原始真实缺陷 / ChiRVFormal | IFU / BRU | 条件分支跳转到非对齐地址时未触发 instruction address misaligned | `beq x0,x0, misaligned_target` |

**筛选说明**：近期处理器 fuzzing 论文中，非法编码未被拦截是高频缺陷。该类 bug 对错误定位有较高价值，因为它通常同时涉及译码、异常生成和后端执行路径。

---

### C. CSR / Trap / 特权状态（5 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| P4 | `mepc` 保存错误 | 原始 bugset | trap controller | trap 时 `mepc` 被错误保存为 `pc+4` | `ecall` 后读取 `mepc` |
| P6 | `MRET` 恢复特权级错误 | 原始 bugset | trap return unit | `mret` 后特权级恢复错误，例如始终降为 U-mode | 设置 `mstatus.MPP=M` 后执行 `mret` |
| NE1 | `mtval` 高位不可写 | 原始真实缺陷 / ChiRVFormal | CSR.scala | 异常发生时 `mtval[63:39]` 由符号扩展得到，无法独立写入 | 触发高地址 load/store 异常后检查 `mtval` |
| NE3 | `xRET` 缺少权限检查 | 原始真实缺陷 / ChiRVFormal | CSR.scala | `SRET` 可从 U-mode 执行，不触发 illegal instruction 异常 | 连续执行两次 `sret`，第二次应在 U-mode 触发异常 |
| X3 | 特权 CSR 访问检查缺失 | TheHuzz / MorFuzz / GoldenFuzz 启发 | CSR.scala | U-mode 或 S-mode 对高特权 CSR 的读写未被正确拦截 | U-mode 执行 `csrrw` 访问 M-mode CSR |

**筛选说明**：CSR 与 trap 是处理器错误定位中最值得保留的系统级状态错误。相比普通 ALU bug，这类缺陷更依赖指令序列构造状态，能体现 instruction-sequence-based test case 的必要性。

---

### D. 异常、异常优先级与副作用抑制（5 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| E1 | precise exception 错误 | 原始 bugset | commit / flush | 异常指令之后的 younger instruction 仍然提交 | `ecall; addi x5,x0,1` |
| E2 | load exception 后错误写回 | 原始 bugset | LSU / writeback | load fault 后目的寄存器仍被写入 | faulting load 后检查 `rd` |
| RE2 | store 非对齐异常未抑制写入 | riscv-mini 论文 bug 注入 | UnpipelinedLSU | store 地址非对齐触发异常后，仍向内存发出写入请求 | 非对齐 `sw` 后检查内存是否被修改 |
| X4 | PMP/PMA 异常类型或优先级错误 | MorFuzz / SimFuzz 启发 | LSU / MMU / exception unit | 当一次访问同时涉及权限、地址或属性异常时，异常类型或优先级选择错误 | 构造受保护地址访问，比较 `mcause/mtval` |
| X5 | `LR/SC` reservation 或异常处理错误 | DIFUZZRTL / MorFuzz / GenHuzz 启发 | LSU / atomic unit | faulting LR、misaligned LR 或普通 store 对 reservation 的更新/清除错误 | `lr.w`/`sc.w` 与异常、store、地址冲突组合 |

**筛选说明**：该类是处理器 bug 数据集中最核心的一类，因为它们通常不是单条指令语义错误，而是涉及异常产生、提交控制、写回抑制和状态副作用。对 SBFL 来说，这类 bug 更能区分不同模块和代码区域的可疑度。

---

### E. 流水线与微架构协同（2 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| C1 | ALU-ALU forwarding 错误 | 原始 bugset / TheHuzz 类似模式 | bypass network | 前一条 ALU 结果没有正确转发给后一条相关指令 | `add x1,x2,x3; sub x4,x1,x5` |
| C3 | branch flush 后错误写回 | 原始 bugset | pipeline flush / BRU | taken branch 冲刷掉的指令仍然写回 | `beq x0,x0,L; addi x5,x0,1` |

**筛选说明**：流水线类 bug 保留两个即可。它们分别代表数据相关和控制相关两种典型微架构错误，覆盖 forwarding 与 flush 两条主线。

---

### F. 页表 / MMU / TLB（3 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| PT4 | PTE `R/W` 合法性检查缺失 | 原始 bugset / ChiRVFormal N:E5 模式 | permission check | `R=0,W=1` 的非法 PTE 未触发 page fault | 构造非法权限 PTE |
| PT9 | superpage 对齐掩码错误 | 原始 bugset / ChiRVFormal N:E4 模式 | page table walker | superpage 的 VPN 对齐或物理页号检查错误 | 构造 2MiB superpage |
| PT10 | `SFENCE.VMA` 无效 | 原始 bugset / MorFuzz 类似模式 | TLB flush | 修改 PTE 后 `sfence.vma` 未正确刷新 TLB | 改 PTE 后访问同一 VA |

**筛选说明**：MMU/TLB 类 bug 实现成本相对较高，但非常能体现处理器系统级状态。保留 3 个是合理上限，分别覆盖 PTE 合法性、superpage 和 TLB 刷新。

---

### G. 性能计数器与观测状态（1 个）

| 编号 | Bug 名称 | 来源 | 植入/错误位置 | 错误描述 | 典型触发模式 |
|------|----------|------|---------------|----------|--------------|
| X6 | `minstret` / retired instruction count 错误 | DIFUZZRTL / TheHuzz / ReFuzz / Cascade 启发 | CSR / commit | 某些指令退休时没有增加 `minstret`，或异常/冲刷指令错误增加计数 | 执行 `ebreak`、异常指令或分支冲刷序列后读取 `minstret` |

**筛选说明**：性能计数器错误在多篇处理器 fuzzing 论文中反复出现。它不是传统功能输出错误，但会影响可观测架构状态，适合检验错误定位方法是否能处理“非通用寄存器输出”的 bug。

---

## 4. 从原始 bugset 删除或下放的实例

| 编号 | 处理方式 | 原因 |
|------|----------|------|
| U3 | 下放到扩展集 | `SLT/SLTU` signedness 混淆属于基础 ALU 单指令语义错误，与 U1/M1 同属基础数据通路错误，主集中不宜过多保留 |
| U8 | 下放到扩展集 | `LWU` 零扩展错误与 U7 的 load 扩展错误高度相近，保留 U7 即可覆盖 load sign/zero-extension 类型 |

---

## 5. 未纳入 main benchmark 的论文缺陷模式

| 缺陷模式 | 不纳入原因 |
|----------|------------|
| FPU rounding mode / FPU flag 错误 | NutShell 是否支持完整 F/D 扩展取决于配置；实现和 oracle 成本较高 |
| AES / vector 指令字段错误 | 依赖特定扩展，不适合作为 NutShell 通用主集 |
| GhostWrite / 真实硅片非标准扩展漏洞 | 与特定商用 CPU 和非标准扩展强相关，难以映射到 NutShell |
| cache coherence protocol bug | NutShell 配置与实验环境可能不包含复杂 coherence 场景，定位粒度也不同 |
| 纯 deadlock / timeout-only bug | pass/fail oracle 不够稳定，容易引入实验噪声 |
| Yosys 综合器 bug | 属于工具链综合错误，不是处理器 RTL 本身的定位目标 |
| Hypervisor / debug mode 复杂状态 bug | 实验成本较高，可作为后续扩展而非主集 |

---

## 6. 推荐实验分层

为了让论文实验更清晰，可以把 24 个 bug 分成三个难度层级。

### Level 1：基础语义与单指令触发 bug（7 个）

用于验证方法是否能处理基本 ISA 语义错误和简单译码错误。

```text
U1, U6, U7, M1, D1, RE1, X2
```

### Level 2：特权状态、CSR 与异常控制 bug（9 个）

用于验证方法是否能处理 trap、CSR、权限和异常副作用。

```text
P4, P6, NE1, NE3, X3, E1, E2, RE2, X4
```

### Level 3：多指令状态构造与微架构协同 bug（8 个）

用于验证 instruction sequence 作为测试用例的必要性。

```text
C1, C3, PT4, PT9, PT10, X1, X5, X6
```

---

## 7. 论文写作中的推荐表述

可以在论文中这样描述 benchmark 的设计：

> We construct a compact processor fault-localization benchmark on NutShell, consisting of 24 bug instances. The benchmark includes 18 representative bugs from our original NutShell bugset and 6 additional bug patterns inspired by recent processor verification and fuzzing studies. The selected bugs cover basic ISA semantics, instruction decoding, CSR and privilege handling, precise exceptions, pipeline interactions, MMU/TLB behaviors, atomic operations, and performance counters. To keep the benchmark manageable and reproducible, we exclude extension-specific bugs such as FPU, vector, AES, and hypervisor bugs, as well as timeout-only deadlocks and toolchain-induced synthesis bugs. Among the 24 instances, 3 are real design defects already present in NutShell, while the remaining 21 are injected by source-code patches.

---

## 8. 推荐结论

相比 32 个实例版本，本版本更适合作为论文主实验集：

1. **规模更可控**：24 个实例比 32 个更适合完成完整 patch、测试生成、覆盖收集和定位评估。
2. **覆盖更均衡**：减少基础单指令语义 bug 的比例，增加近期论文高频出现的 CSR、非法指令、PMP/PMA、LR/SC 和性能计数器错误。
3. **更贴近真实处理器 bug**：新增实例来自多篇近期处理器验证论文中的真实缺陷模式。
4. **更适合 SBFL**：多数 bug 能通过指令序列触发，并产生明确的 pass/fail 差异，便于构造谱信息和计算 suspiciousness。

