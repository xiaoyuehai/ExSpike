# This package is for FPL2026 Artifact Evaluation of ExSpike: A General Full-Event Neuromorphic Architecture for Exploiting Irregular Sparsity with Event Compression 🔥

This repository provides all the artifacts to reproduce the results in the ExSpike report,
including Figure 2, Figure 7, Figure 8, and Figure 9; Table 1 and Table 2.

# 📝 Artifact Checklist

```
**Run-time environment**: Ubuntu 20.04, Python 3.8, and Vivado 2019.1
**Hardware**:
    Desktop: any machine that can run Ubuntu 20.04 and Vivado 2019.1, with a PCIe slot for the FPGA
    FPGA Board: HTG-700 AMD Virtex-7 2000T PCI Express Development Platform
**Source Files**:
    RTL: all the RTL design of ExSpike
    Xilinx IP: required IP for ExSpike implementation (under Vivado 2019.1)
    Netlist: we use Synplify to generate the netlist rather than Vivado, so we provide the required netlist for bitstream generation and power estimation. If you use Vivado to synthesize the RTL code, the results may be different.
    cycle_model: ExSpike's cycle models for fast testing and trace file generation 
**Output**: we provide two ways to generate the output results. One (FAST) uses our provided evaluation logs; the other (FULL) reruns all of the evaluation by yourself. 📊
**Approximate Time For Evaluation**:
    FAST: ~2 mins;
    FULL: ~15 hours. Requires Vivado 2019.1 and a V7-2000T board connected to the PC via PCIe. ⚠️
```

# 🎯 Measurement Methods

```
Evaluation Platform:
    (XDMA + MIG + ExSpike)
Power: in ExSpike, we use the post-synthesis netlist and obtain the SAIF files according to the benchmark, then we use Vivado to estimate the dynamic power consumption.
Area: ExSpike is an AI accelerator, so we report the ExSpike implementation area, excluding the modules used for evaluation, such as the XDMA and MIG IPs.
Latency: we design a run-time counter in RTL that records the computing latency for the benchmark.
```

# 📌 FPGA real-test evaluation (if you have the target FPGA board, please ignore this; it is JUST for FPL2026 AE)

```
If you run the FULL evaluation but do not have the target board, the script will directly use the *_provided.log files to obtain the FPGA execution results, such as latency and accuracy, to complete the figure/table generation.

Specifically, we can provide remote access to evaluate the FPGA run results over SSH. Then you can run run_all_board_tests.sh. If you would like to use the FPGA board, please email me (yuehai.chen@rug.nl 💡), because I need to enumerate the PCIe device for your evaluation.
```

# 📖 Repository Introduction

```
ExSpike 🔥🔥🔥
    --AE_scripts  // automated scripts for artifact generation
    --Artifacts   // output of artifacts
    --cycle_model // cycle-level execution model for ExSpike
    --Evaluation  // FPGA runtime test
    --HW          // FPGA bitstream generation
    --Log         // FPGA runtime test log
    --Power_estimation // including SAIF files and netlists
    --rtl         // RTL for ExSpike ⭐
    --SIM         // simulation required files
    --xsim        // simulation repository
    sourceme      // defines the required paths for evaluation
    README.md     // AE guidelines
```

# 🚀🚀🚀 Evaluation Steps

```
1. Preparation of the Python environment
    install python 3.8.20
    pip install typing_extensions==4.12.2
    pip install torch==2.4.1 torchvision==0.19.1 --index-url https://download.pytorch.org/whl/cpu --no-deps
    pip install -r requirements.txt

2. sourceme file: please change the paths in the sourceme file, especially the Python path and the Vivado path, and **source sourceme**.

3. FAST evaluation
    source sourceme
    ./AE_scripts/run_all_artifact_fast.sh

4. FULL evaluation
    source sourceme
    ./AE_scripts/run_ae_clean.sh --force --deep  # deletes all running logs except the provided logs
    - 💡 If you have a target FPGA board, run:
      ./AE_scripts/run_all_artifact_full.sh
    - 💡 If you do not have a target FPGA board, run:
      ./AE_scripts/run_all_artifact_full.sh --no-fpga
      
📌 The following steps are optional.
5. All figures re-generation
    source sourceme
    ./AE_scripts/run_ae_figures.sh full

6. Power estimation
    source sourceme
    ./AE_scripts/run_ae_power.sh full

7. All tables re-generation
    source sourceme
    ./AE_scripts/run_ae_table1.sh
    ./AE_scripts/run_ae_table2.sh
```

# 💻 Provided evaluation platform for FPL AE

```
Since the FPGA evaluation heavily relies on the PC, the FPGA, and the Vivado version, we provide an environment for the AE for convenience.
1. We provide a user account, named ae, which has the Vivado 2019.1 tool installed and can run the bitstream generation.
2. We provide the target FPGA board, the Virtex-7 2000T.
3. Note:
    (1) please contact yuehai.chen@rug.nl to arrange a timeslot for use
    (2) the full FULL evaluation may take up to 24 hours
    (3) Please install Tailscale on your Linux/Windows machine and log in with your Tailscale account (we suggest registering with a personal email, then send the email address to me so I can share the device with you).
    Then open the shared-device invite link and accept it. After that, run `tailscale status` to find the shared machine `yh-workstation`. You can connect to it using:

    ssh ae@<tailscale-ip>

    where `<tailscale-ip>` is the 100.x.x.x address shown by `tailscale status`.
```

