#create_pblock pblock_inst_accelerator_top
#add_cells_to_pblock [get_pblocks pblock_inst_accelerator_top] [get_cells -quiet [list inst_accelerator_top]]
#resize_pblock [get_pblocks pblock_inst_accelerator_top] -add {SLICE_X252Y0:SLICE_X457Y149}
#resize_pblock [get_pblocks pblock_inst_accelerator_top] -add {DSP48_X5Y0:DSP48_X7Y59}
#resize_pblock [get_pblocks pblock_inst_accelerator_top] -add {RAMB18_X5Y0:RAMB18_X8Y59}
#resize_pblock [get_pblocks pblock_inst_accelerator_top] -add {RAMB36_X5Y0:RAMB36_X8Y29}
set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]

set_property PACKAGE_PIN A15 [get_ports Key_Signal]
set_property PACKAGE_PIN AW37 [get_ports uart_rx]
set_property PACKAGE_PIN AV39 [get_ports uart_tx]
set_property PACKAGE_PIN G41 [get_ports dummpy_pin]
#set_property PACKAGE_PIN K42 [get_ports uart_rx_ddr]
#set_property PACKAGE_PIN J42 [get_ports uart_tx_ddr]
#set_property PACKAGE_PIN B19 [get_ports sys_rst]

set_property IOSTANDARD LVCMOS18 [get_ports Key_Signal]
set_property IOSTANDARD LVCMOS18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS18 [get_ports uart_tx]
# set_property IOSTANDARD LVCMOS15 [get_ports sys_rst]
set_property IOSTANDARD LVCMOS18 [get_ports dummpy_pin]
#create_clock -period 5 -name sysCLK [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst]
set_property PULLTYPE PULLUP [get_ports sys_rst]
set_property PACKAGE_PIN AN39 [get_ports sys_rst]

# For PCIe
#set_property LOC GTXE2_CHANNEL_X0Y19 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN Y3 [get_ports {pcie_7x_mgt_rtl_0_rxn[0]}]
set_property PACKAGE_PIN Y4 [get_ports {pcie_7x_mgt_rtl_0_rxp[0]}]
set_property PACKAGE_PIN W1 [get_ports {pcie_7x_mgt_rtl_0_txn[0]}]
set_property PACKAGE_PIN W2 [get_ports {pcie_7x_mgt_rtl_0_txp[0]}]
#set_property LOC GTXE2_CHANNEL_X0Y18 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AA5 [get_ports {pcie_7x_mgt_rtl_0_rxn[1]}]
set_property PACKAGE_PIN AA6 [get_ports {pcie_7x_mgt_rtl_0_rxp[1]}]
set_property PACKAGE_PIN AA1 [get_ports {pcie_7x_mgt_rtl_0_txn[1]}]
set_property PACKAGE_PIN AA2 [get_ports {pcie_7x_mgt_rtl_0_txp[1]}]
#set_property LOC GTXE2_CHANNEL_X0Y17 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AB3 [get_ports {pcie_7x_mgt_rtl_0_rxn[2]}]
set_property PACKAGE_PIN AB4 [get_ports {pcie_7x_mgt_rtl_0_rxp[2]}]
set_property PACKAGE_PIN AC1 [get_ports {pcie_7x_mgt_rtl_0_txn[2]}]
set_property PACKAGE_PIN AC2 [get_ports {pcie_7x_mgt_rtl_0_txp[2]}]
#set_property LOC GTXE2_CHANNEL_X0Y16 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AC5 [get_ports {pcie_7x_mgt_rtl_0_rxn[3]}]
set_property PACKAGE_PIN AC6 [get_ports {pcie_7x_mgt_rtl_0_rxp[3]}]
set_property PACKAGE_PIN AE1 [get_ports {pcie_7x_mgt_rtl_0_txn[3]}]
set_property PACKAGE_PIN AE2 [get_ports {pcie_7x_mgt_rtl_0_txp[3]}]
#set_property LOC GTXE2_CHANNEL_X0Y15 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[4].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AD3 [get_ports {pcie_7x_mgt_rtl_0_rxn[4]}]
set_property PACKAGE_PIN AD4 [get_ports {pcie_7x_mgt_rtl_0_rxp[4]}]
set_property PACKAGE_PIN AG1 [get_ports {pcie_7x_mgt_rtl_0_txn[4]}]
set_property PACKAGE_PIN AG2 [get_ports {pcie_7x_mgt_rtl_0_txp[4]}]
#set_property LOC GTXE2_CHANNEL_X0Y14 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[5].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AE5 [get_ports {pcie_7x_mgt_rtl_0_rxn[5]}]
set_property PACKAGE_PIN AE6 [get_ports {pcie_7x_mgt_rtl_0_rxp[5]}]
set_property PACKAGE_PIN AH3 [get_ports {pcie_7x_mgt_rtl_0_txn[5]}]
set_property PACKAGE_PIN AH4 [get_ports {pcie_7x_mgt_rtl_0_txp[5]}]
#set_property LOC GTXE2_CHANNEL_X0Y13 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[6].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AF3 [get_ports {pcie_7x_mgt_rtl_0_rxn[6]}]
set_property PACKAGE_PIN AF4 [get_ports {pcie_7x_mgt_rtl_0_rxp[6]}]
set_property PACKAGE_PIN AJ1 [get_ports {pcie_7x_mgt_rtl_0_txn[6]}]
set_property PACKAGE_PIN AJ2 [get_ports {pcie_7x_mgt_rtl_0_txp[6]}]
#set_property LOC GTXE2_CHANNEL_X0Y12 [get_cells {U_PCIE_Controller_wrapper/design_1_i/xdma_0/inst/design_1_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[7].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property PACKAGE_PIN AG5 [get_ports {pcie_7x_mgt_rtl_0_rxn[7]}]
set_property PACKAGE_PIN AG6 [get_ports {pcie_7x_mgt_rtl_0_rxp[7]}]
set_property PACKAGE_PIN AK3 [get_ports {pcie_7x_mgt_rtl_0_txn[7]}]
set_property PACKAGE_PIN AK4 [get_ports {pcie_7x_mgt_rtl_0_txp[7]}]

set_property PACKAGE_PIN Y8 [get_ports diff_clock_rtl_0_clk_p]
set_property PACKAGE_PIN Y7 [get_ports diff_clock_rtl_0_clk_n]







