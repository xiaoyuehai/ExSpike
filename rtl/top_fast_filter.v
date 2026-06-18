// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : top_fast_filter.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Top-level fast filter for sparse events.
// -----------------------------------------------------------------------------

module TOP_FAST_FILTER(
	input wire clk,
	input wire rst_n,

	input wire [511:0] neuron_spike,
	input wire 		  neuron_spike_valid,
	input wire        generate_next_en,

	output wire 	  no_valid_spike,

	output wire [8:0] absolute_addr,
	output wire 	  absolute_addr_valid,

	output wire 	  idle,
	output wire 		spike_index_valid

	);
	
	wire [511:0] spike_index;
	// wire 		spike_index_valid;

	FAST_FILTER U_FAST_FILTER(
		.clk                (clk),
		.rst_n              (rst_n),
		.neuron_spike       (neuron_spike),
		.neuron_spike_valid (neuron_spike_valid),
		.spike_index        (spike_index),
		.spike_index_valid  (spike_index_valid),
		.no_valid_spike     (no_valid_spike),
		.generate_next_en   (generate_next_en)
	);

	NEW_INDEX2ABS_ADDR U_INDEX2ABS_ADDR(
		.clk                 (clk),
		.rst_n               (rst_n),
		.spike_index         (spike_index),
		.spike_index_valid   (spike_index_valid),
		.absolute_addr       (absolute_addr),
		.absolute_addr_valid (absolute_addr_valid),
		.generate_next_en    (generate_next_en)
	);

	assign idle = no_valid_spike & !spike_index_valid & !absolute_addr_valid;
 
endmodule