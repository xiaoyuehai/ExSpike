// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : fast_filter.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Fast sparse filtering for spike events.
// -----------------------------------------------------------------------------

module FAST_FILTER(
	input wire          clk                   ,
	input wire          rst_n                 ,

	input wire [511:0]  neuron_spike          ,
	input wire          neuron_spike_valid    ,
    input wire          generate_next_en      ,

	output reg [511:0]  spike_index           ,
	output reg 		    spike_index_valid     ,
	output wire 	    no_valid_spike        
	);
	
	reg 	[511:0] internal_spike;
	wire 	[511:0] sub_1;
	wire    [511:0] and_later;
	wire    [511:0] xor_later;

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			internal_spike <= 'd0;
		end
		else if(neuron_spike_valid)begin
			internal_spike <= neuron_spike;
		end
		else if(generate_next_en)begin
			internal_spike <= internal_spike & ~xor_later;
		end
	end

	//step 1
	// assign sub_1 	 = internal_spike - 1;
	// assign and_later = internal_spike & sub_1;
	// assign xor_later = internal_spike ^ and_later;
	assign xor_later = internal_spike & (~internal_spike + 1'b1);
	//step 2
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			spike_index <= 0;
			spike_index_valid <= 0;
		end
		else if(generate_next_en)begin
			spike_index <= xor_later;
			spike_index_valid <= !no_valid_spike;
		end
	end

	//step 3
	assign no_valid_spike = internal_spike == 0;

endmodule

/*
module FAST_FILTER(
    input  wire         clk,
    input  wire         rst_n,

    input  wire [511:0] neuron_spike,
    input  wire         neuron_spike_valid,
    input  wire         generate_next_en,

    output reg  [511:0] spike_index,
    output reg          spike_index_valid,
    output wire         no_valid_spike
);

    reg  [511:0] internal_spike;

    // === step 1: maintain internal vector (load new spikes, clear lowest output bit each iteration) ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_spike <= '0;
        end else if (neuron_spike_valid) begin
            internal_spike <= neuron_spike;
        end else if (generate_next_en) begin
            // clear lowest set bit with inverted mask -- avoids 512-bit subtractor
            internal_spike <= internal_spike & ~spike_index;
        end
    end

    // === step 2: extract lowest set bit (equivalent to x ^ (x & (x-1)) without subtractor) ===
    wire [511:0] x = internal_spike;
    wire [511:0] lowest_one = x & (~x + 1'b1);

    // === step 3: output on generate_next_en cycle (same 1-cycle latency as original) ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_index       <= '0;
            spike_index_valid <= 1'b0;
        end else if (generate_next_en) begin
            spike_index       <= lowest_one;
            spike_index_valid <= |x;           // equivalent to !no_valid_spike
        end
    end

    assign no_valid_spike = (internal_spike == 512'd0);

endmodule
*/