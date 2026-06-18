// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : axi_ddr/SCNN_TOP_PCIE.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: PCIe wrapper top for SCNN deployment.
// -----------------------------------------------------------------------------

module SCNN_TOP_PCIE(
    // DDR3 memory port (same as ddr3a_controller connection)
	inout	[63:0]	ddr3_dq,
	inout	[7:0]	ddr3_dqs_n,
	inout	[7:0]	ddr3_dqs_p,
	output	[14:0]	ddr3_addr,
	output	[2:0]	ddr3_ba,
	output			ddr3_ras_n,
	output			ddr3_cas_n,
	output			ddr3_we_n,
	output			ddr3_reset_n,
	output	[1:0]	ddr3_ck_p,
	output	[1:0]	ddr3_ck_n,
	output	[1:0]	ddr3_cke,
	output	[1:0]	ddr3_cs_n,
	output	[7:0]	ddr3_dm,
	output	[1:0]	ddr3_odt,

	input			sys_clk_p,
	input			sys_clk_n,
    input			diff_clock_rtl_0_clk_n,
    input			diff_clock_rtl_0_clk_p,
	input			sys_rst,	// low active

	// PCIe serial (x8 lane)
	input	[7:0]	pcie_7x_mgt_rtl_0_rxn,
	input	[7:0]	pcie_7x_mgt_rtl_0_rxp,
	output	[7:0]	pcie_7x_mgt_rtl_0_txn,
	output	[7:0]	pcie_7x_mgt_rtl_0_txp,

	output   		uart_tx,
	input 			uart_rx,
	input           Key_Signal,
	output  		dummpy_pin
);

	parameter WIDTH = 256;
	parameter PARALLEL = 32;

	// User Interface Channel: READ
	wire         RD_START;
	wire [31:0]  RD_ADRS;
	wire [31:0]  RD_LEN;
	wire         RD_READY;
	wire         RD_FIFO_WE;
	wire [WIDTH-1:0]  RD_FIFO_DATA;
	wire         RD_DONE;
	wire [2:0]   RD_SIZE;
	wire         RD_LAST;

	// User Interface Channel: WRITE
	reg          WR_START;
	wire [31:0]  WR_ADRS;
	wire [31:0]  WR_LEN;
	wire         WR_READY;
	wire         WR_FIFO_RE;
	wire         WR_FIFO_EMPTY;
	wire         WR_FIFO_AEMPTY;
	wire [WIDTH-1:0]  WR_FIFO_DATA;
	wire         WR_DONE;
	wire [2:0]   WR_SIZE;
	wire [31:0]  WR_STRB;

	wire         ui_clk;
	wire         clk;
	wire [7:0]   rx_data;
	wire         po_flag;
	wire         one_time_is_ok;
	wire         Tx_done;
	wire [31:0]target_addr;
    wire [511:0]target_w_data;
    wire 		target_w_en;
    wire [63:0]  counter_s_ns;
	assign clk = ui_clk;

	reg [31:0] cnt;
	// always @(posedge clk or negedge sys_rst) begin
	// 	if (!sys_rst)
	// 		cnt <= 0;
	// 	else if(choose_pos)
	// 		cnt <= cnt + 1;
	// end

	// wire choose;
	// vio_0 your_instance_name (
	// 	.clk       (clk),
	// 	.probe_out0(choose)
	// );

	wire uart_tx_spike;
	wire uart_rx_spike;
	wire uart_tx_weight;
	wire uart_rx_weight;

	// assign uart_tx = choose == 0 ? uart_tx_weight : uart_tx_spike;
	// assign uart_rx_spike = choose == 1 ? uart_rx : 1'b1;
	// assign uart_rx_weight = choose == 0 ? uart_rx : 1'b1;
    assign uart_tx = uart_tx_spike;
	assign uart_rx_spike = uart_rx;
	assign uart_rx_weight = uart_rx;
    // jsut test
    /*reg choose_reg;
    wire choose_pos, choose_neg;
    always@(posedge clk)begin
        choose_reg <= choose;
    end
    assign choose_pos = choose_reg == 0 && choose == 1;
    assign choose_neg = choose_reg == 1 && choose == 0;

    // assign WR_START = choose_neg;
    // assign WR_ADRS = cnt;
    // assign WR_LEN = 32'h4;
    // assign WR_FIFO_DATA = 16'h1234;
    // assign WR_STRB = 32'b1111;
    // assign WR_SIZE = 3'b101;
    // assign WR_FIFO_EMPTY = choose_neg;
    // assign WR_FIFO_AEMPTY = choose_neg;

    assign RD_START = choose_pos;
    assign RD_ADRS = cnt;
    assign RD_LEN = 32'h4;
    assign RD_SIZE = 3'b101;

    assign dummpy_pin = (RD_FIFO_DATA != 0 & RD_DONE & RD_LAST & RD_READY & RD_FIFO_WE) ||
                        (WR_READY & WR_FIFO_RE & WR_DONE);*/

	EVENT_PROCESSOR_TOP #(
		.parallel_metric(PARALLEL),
		.ddr_data_width (WIDTH)
	) U_EVENT_PROCESSOR_TOP (
		.clk        (clk),
		.rst_n      (sys_rst),
		.uart_tx    (uart_tx_spike),
		.uart_rx    (uart_rx_spike),
		.Key_Signal (Key_Signal),
		.RD_START   (RD_START),
		.RD_ADRS    (RD_ADRS),
		.RD_LEN     (RD_LEN),
		.RD_SIZE    (RD_SIZE),
		.RD_READY   (RD_READY),
		.RD_FIFO_WE (RD_FIFO_WE),
		.RD_FIFO_DATA(RD_FIFO_DATA),
		.RD_DONE    (RD_DONE),
		.RD_LAST    (RD_LAST),
		.dummpy_pin (dummpy_pin),
		.target_addr       (target_addr),
		.target_w_data     (target_w_data),
		.target_w_en       (target_w_en),
		.counter_s_ns      (counter_s_ns)
	);

	input_uart_r inst_input_uart_r (
		.sclk   (clk),
		.s_rst_n(sys_rst),
		.rx     (uart_rx_weight),
		.rx_data(rx_data),
		.po_flag(po_flag)
	);

	reco_uart_send inst_reco_uart_send (
		.Clk     (clk),
		.Reset_n (sys_rst),
		.Data    (8'h55),
		.Send_Go (one_time_is_ok),
		.Baud_set(3'b100),
		.uart_tx (uart_tx_weight),
		.Tx_done (Tx_done)
	);

	// uart_ddr_w #(
	// 	.ddr_data_width(WIDTH)
	// ) inst_uart_ddr_w (
	// 	.clk                (clk),
	// 	.rst_n              (sys_rst),
	// 	.uart_rece_data     (rx_data),
	// 	.uart_rece_data_valid(po_flag),
	// 	.one_time_is_ok     (one_time_is_ok),
	// 	.WR_START           (WR_START),
	// 	.WR_ADRS            (WR_ADRS),
	// 	.WR_LEN             (WR_LEN),
	// 	.WR_READY           (WR_READY),
	// 	.WR_FIFO_RE         (WR_FIFO_RE),
	// 	.WR_FIFO_DATA       (WR_FIFO_DATA),
	// 	.WR_DONE            (WR_DONE),
	// 	.WR_SIZE            (WR_SIZE),
	// 	.WR_STRB            (WR_STRB)
	// );

	always@(posedge clk or negedge sys_rst)begin
		if(sys_rst == 1'b0)begin
			WR_START <= 0;
		end
		else if(target_addr == 0 && target_w_en && (&target_w_data))begin
			WR_START <= 1;
		end
		else begin
			WR_START <= 0;
		end
	end

	assign WR_ADRS 		= 32'h40000000;
	assign WR_FIFO_DATA = counter_s_ns;
	assign WR_LEN       = 1;
	assign WR_SIZE      = 3'b101;
	assign WR_STRB 		= {32{1'b1}};

	// PCIE_Controller_wrapper: BRAM unconnected; DDR3 connected like ddr3a_controller
	design_1_wrapper U_PCIE_Controller_wrapper (
		// BRAM ports left unconnected
		// .BRAM_PORTA_0_addr (),
		// .BRAM_PORTA_0_clk  (),
		// .BRAM_PORTA_0_din  (),
		// .BRAM_PORTA_0_dout (),
		// .BRAM_PORTA_0_en   (),
		// .BRAM_PORTA_0_rst  (),
		// .BRAM_PORTA_0_we   (),

		.CLK_IN_D_clk_n    (diff_clock_rtl_0_clk_n),
		.CLK_IN_D_clk_p    (diff_clock_rtl_0_clk_p),

		// DDR3 interface (same as ddr3a_controller -> top ports)
		.DDR3_addr         (ddr3_addr),
		.DDR3_ba           (ddr3_ba),
		.DDR3_cas_n        (ddr3_cas_n),
		.DDR3_ck_n         (ddr3_ck_n),
		.DDR3_ck_p         (ddr3_ck_p),
		.DDR3_cke          (ddr3_cke),
		.DDR3_cs_n         (ddr3_cs_n),
		.DDR3_dm           (ddr3_dm),
		.DDR3_dq           (ddr3_dq),
		.DDR3_dqs_n        (ddr3_dqs_n),
		.DDR3_dqs_p        (ddr3_dqs_p),
		.DDR3_odt          (ddr3_odt),
		.DDR3_ras_n        (ddr3_ras_n),
		.DDR3_reset_n      (ddr3_reset_n),
		.DDR3_we_n         (ddr3_we_n),

		// User read interface
		.RD_ADRS           (RD_ADRS),
		.RD_DONE           (RD_DONE),
		.RD_FIFO_DATA      (RD_FIFO_DATA),
		.RD_FIFO_WE        (RD_FIFO_WE),
		.RD_LAST           (RD_LAST),
		.RD_LEN            (RD_LEN),
		.RD_READY          (RD_READY),
		.RD_SIZE           (RD_SIZE),
		.RD_START          (RD_START),

		// System clock (reference to ddr3 sys_clk)
		.SYS_CLK_0_clk_n   (sys_clk_n),
		.SYS_CLK_0_clk_p   (sys_clk_p),

		// User write interface
		.WR_ADRS           (WR_ADRS),
		.WR_DONE           (WR_DONE),
		.WR_FIFO_AEMPTY    (WR_FIFO_AEMPTY),
		.WR_FIFO_DATA      (WR_FIFO_DATA),
		.WR_FIFO_EMPTY     (WR_FIFO_EMPTY),
		.WR_FIFO_RE        (WR_FIFO_RE),
		.WR_LEN            (WR_LEN),
		.WR_READY          (WR_READY),
		.WR_SIZE           (WR_SIZE),
		.WR_START          (WR_START),
		.WR_STRB           (WR_STRB),

		// PCIe serial
		.pcie_7x_mgt_rtl_0_rxn(pcie_7x_mgt_rtl_0_rxn),
		.pcie_7x_mgt_rtl_0_rxp(pcie_7x_mgt_rtl_0_rxp),
		.pcie_7x_mgt_rtl_0_txn(pcie_7x_mgt_rtl_0_txn),
		.pcie_7x_mgt_rtl_0_txp(pcie_7x_mgt_rtl_0_txp),

		.sys_rst_n_0         (sys_rst),	// wrapper expects rst_n, sys_rst is low active
		.ui_clk            (ui_clk),

		.target_addr       (target_addr),
		.target_w_data     (target_w_data),
		.target_w_en       (target_w_en)
	);

	// ddr3a_controller commented out: PCIE_Controller already includes DDR3 controller
	/*
	ddr3a_controller u_ddr3a_controller (
		.ddr3_addr          (ddr3_addr),
		.ddr3_ba            (ddr3_ba),
		.ddr3_cas_n         (ddr3_cas_n),
		.ddr3_ck_n          (ddr3_ck_n),
		.ddr3_ck_p          (ddr3_ck_p),
		.ddr3_cke           (ddr3_cke),
		.ddr3_ras_n         (ddr3_ras_n),
		.ddr3_reset_n       (ddr3_reset_n),
		.ddr3_we_n          (ddr3_we_n),
		.ddr3_dq            (ddr3_dq),
		.ddr3_dqs_n         (ddr3_dqs_n),
		.ddr3_dqs_p         (ddr3_dqs_p),
		.ddr3_cs_n          (ddr3_cs_n),
		.ddr3_dm            (ddr3_dm),
		.ddr3_odt           (ddr3_odt),
		.ui_clk             (ui_clk),
		.sys_clk_p          (sys_clk_p),
		.sys_clk_n          (sys_clk_n),
		.sys_rst            (sys_rst)
	);
	*/

endmodule
