// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : defines.vh
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: RTL compile-time macro definitions for benchmarks and simulation paths.
// -----------------------------------------------------------------------------

`ifndef RTL_DEFINES_VH
`define RTL_DEFINES_VH

// Benchmark and GROUP_NUMBER are selected at compile time via +define, e.g.:
//   +define+ST4_CIFAR10 +define+GROUP_NUMBER=2
// Path roots (SIM_ROOT, CYCLE_MODEL) come from sourceme / run_xsim.sh.

// `define POWER_ESTIMATION

// `define VGG11_CIFAR10
// `define ResNet18_CIFAR10
// `define ST4_CIFAR10
// `define ST2_CIFAR100
// `define SEG_NET

`define LATENCY_REPORT
// xsim/run_xsim.sh symlinks ./simdata and ./reports into each run directory.
`ifndef SEG_NET
    `ifdef LATENCY_REPORT
        `define LATENCY_REPORT_DIR reports
    `endif // LATENCY_REPORT
`endif // SEG_NET

`endif
