// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : axi_ddr/index2abs_sub.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Index to absolute address conversion submodule.
// -----------------------------------------------------------------------------

module INDEX2ABS_SUB_0#(
    parameter BIAS_LEN = 0
)(
	input wire			clk,
	input wire			rst_n,

	input wire	[127:0]	spike_index,
	input wire			spike_index_valid,

	output reg	[8:0]	absolute_addr,
	output reg			absolute_addr_valid,

	input  wire         generate_next_en

	);

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			absolute_addr <= 0;
			absolute_addr_valid <= 0;
		end
		else if(generate_next_en == 0)begin
			absolute_addr <= absolute_addr;
			absolute_addr_valid <= absolute_addr_valid;
		end
		else if(spike_index_valid)begin
			absolute_addr_valid <= 1;
            case(spike_index)    
                128'h1: absolute_addr <= 0;
                128'h2: absolute_addr <= 1;
                128'h4: absolute_addr <= 2;
                128'h8: absolute_addr <= 3;
                128'h10: absolute_addr <= 4;
                128'h20: absolute_addr <= 5;
                128'h40: absolute_addr <= 6;
                128'h80: absolute_addr <= 7;
                128'h100: absolute_addr <= 8;
                128'h200: absolute_addr <= 9;
                128'h400: absolute_addr <= 10;
                128'h800: absolute_addr <= 11;
                128'h1000: absolute_addr <= 12;
                128'h2000: absolute_addr <= 13;
                128'h4000: absolute_addr <= 14;
                128'h8000: absolute_addr <= 15;
                128'h10000: absolute_addr <= 16;
                128'h20000: absolute_addr <= 17;
                128'h40000: absolute_addr <= 18;
                128'h80000: absolute_addr <= 19;
                128'h100000: absolute_addr <= 20;
                128'h200000: absolute_addr <= 21;
                128'h400000: absolute_addr <= 22;
                128'h800000: absolute_addr <= 23;
                128'h1000000: absolute_addr <= 24;
                128'h2000000: absolute_addr <= 25;
                128'h4000000: absolute_addr <= 26;
                128'h8000000: absolute_addr <= 27;
                128'h10000000: absolute_addr <= 28;
                128'h20000000: absolute_addr <= 29;
                128'h40000000: absolute_addr <= 30;
                128'h80000000: absolute_addr <= 31;
                128'h100000000: absolute_addr <= 32;
                128'h200000000: absolute_addr <= 33;
                128'h400000000: absolute_addr <= 34;
                128'h800000000: absolute_addr <= 35;
                128'h1000000000: absolute_addr <= 36;
                128'h2000000000: absolute_addr <= 37;
                128'h4000000000: absolute_addr <= 38;
                128'h8000000000: absolute_addr <= 39;
                128'h10000000000: absolute_addr <= 40;
                128'h20000000000: absolute_addr <= 41;
                128'h40000000000: absolute_addr <= 42;
                128'h80000000000: absolute_addr <= 43;
                128'h100000000000: absolute_addr <= 44;
                128'h200000000000: absolute_addr <= 45;
                128'h400000000000: absolute_addr <= 46;
                128'h800000000000: absolute_addr <= 47;
                128'h1000000000000: absolute_addr <= 48;
                128'h2000000000000: absolute_addr <= 49;
                128'h4000000000000: absolute_addr <= 50;
                128'h8000000000000: absolute_addr <= 51;
                128'h10000000000000: absolute_addr <= 52;
                128'h20000000000000: absolute_addr <= 53;
                128'h40000000000000: absolute_addr <= 54;
                128'h80000000000000: absolute_addr <= 55;
                128'h100000000000000: absolute_addr <= 56;
                128'h200000000000000: absolute_addr <= 57;
                128'h400000000000000: absolute_addr <= 58;
                128'h800000000000000: absolute_addr <= 59;
                128'h1000000000000000: absolute_addr <= 60;
                128'h2000000000000000: absolute_addr <= 61;
                128'h4000000000000000: absolute_addr <= 62;
                128'h8000000000000000: absolute_addr <= 63;
                128'h10000000000000000: absolute_addr <= 64;
                128'h20000000000000000: absolute_addr <= 65;
                128'h40000000000000000: absolute_addr <= 66;
                128'h80000000000000000: absolute_addr <= 67;
                128'h100000000000000000: absolute_addr <= 68;
                128'h200000000000000000: absolute_addr <= 69;
                128'h400000000000000000: absolute_addr <= 70;
                128'h800000000000000000: absolute_addr <= 71;
                128'h1000000000000000000: absolute_addr <= 72;
                128'h2000000000000000000: absolute_addr <= 73;
                128'h4000000000000000000: absolute_addr <= 74;
                128'h8000000000000000000: absolute_addr <= 75;
                128'h10000000000000000000: absolute_addr <= 76;
                128'h20000000000000000000: absolute_addr <= 77;
                128'h40000000000000000000: absolute_addr <= 78;
                128'h80000000000000000000: absolute_addr <= 79;
                128'h100000000000000000000: absolute_addr <= 80;
                128'h200000000000000000000: absolute_addr <= 81;
                128'h400000000000000000000: absolute_addr <= 82;
                128'h800000000000000000000: absolute_addr <= 83;
                128'h1000000000000000000000: absolute_addr <= 84;
                128'h2000000000000000000000: absolute_addr <= 85;
                128'h4000000000000000000000: absolute_addr <= 86;
                128'h8000000000000000000000: absolute_addr <= 87;
                128'h10000000000000000000000: absolute_addr <= 88;
                128'h20000000000000000000000: absolute_addr <= 89;
                128'h40000000000000000000000: absolute_addr <= 90;
                128'h80000000000000000000000: absolute_addr <= 91;
                128'h100000000000000000000000: absolute_addr <= 92;
                128'h200000000000000000000000: absolute_addr <= 93;
                128'h400000000000000000000000: absolute_addr <= 94;
                128'h800000000000000000000000: absolute_addr <= 95;
                128'h1000000000000000000000000: absolute_addr <= 96;
                128'h2000000000000000000000000: absolute_addr <= 97;
                128'h4000000000000000000000000: absolute_addr <= 98;
                128'h8000000000000000000000000: absolute_addr <= 99;
                128'h10000000000000000000000000: absolute_addr <= 100;
                128'h20000000000000000000000000: absolute_addr <= 101;
                128'h40000000000000000000000000: absolute_addr <= 102;
                128'h80000000000000000000000000: absolute_addr <= 103;
                128'h100000000000000000000000000: absolute_addr <= 104;
                128'h200000000000000000000000000: absolute_addr <= 105;
                128'h400000000000000000000000000: absolute_addr <= 106;
                128'h800000000000000000000000000: absolute_addr <= 107;
                128'h1000000000000000000000000000: absolute_addr <= 108;
                128'h2000000000000000000000000000: absolute_addr <= 109;
                128'h4000000000000000000000000000: absolute_addr <= 110;
                128'h8000000000000000000000000000: absolute_addr <= 111;
                128'h10000000000000000000000000000: absolute_addr <= 112;
                128'h20000000000000000000000000000: absolute_addr <= 113;
                128'h40000000000000000000000000000: absolute_addr <= 114;
                128'h80000000000000000000000000000: absolute_addr <= 115;
                128'h100000000000000000000000000000: absolute_addr <= 116;
                128'h200000000000000000000000000000: absolute_addr <= 117;
                128'h400000000000000000000000000000: absolute_addr <= 118;
                128'h800000000000000000000000000000: absolute_addr <= 119;
                128'h1000000000000000000000000000000: absolute_addr <= 120;
                128'h2000000000000000000000000000000: absolute_addr <= 121;
                128'h4000000000000000000000000000000: absolute_addr <= 122;
                128'h8000000000000000000000000000000: absolute_addr <= 123;
                128'h10000000000000000000000000000000: absolute_addr <= 124;
                128'h20000000000000000000000000000000: absolute_addr <= 125;
                128'h40000000000000000000000000000000: absolute_addr <= 126;
                128'h80000000000000000000000000000000: absolute_addr <= 127;
                default: absolute_addr <= 0;
            endcase
		end
		else begin
			absolute_addr_valid <= 0;
		end
	end
endmodule

module NEW_INDEX2ABS_ADDR(
    input wire			clk,
	input wire			rst_n,

	input wire	[511:0]	spike_index,
	input wire			spike_index_valid,

	output reg	[8:0]	absolute_addr,
	output wire			absolute_addr_valid,

	input  wire         generate_next_en
);
    wire [8:0] a_addr_sub [0:3];
    reg  [3:0] sel_bit;
    wire [3:0] a_vld_sub;

    // INDEX2ABS_SUB_0 U_INDEX2ABS_SUB_0(
    //     .clk                 ( clk                 ),
    //     .rst_n               ( rst_n               ),
    //     .spike_index         ( spike_index[128*0 +: 128]         ),
    //     .spike_index_valid   ( spike_index_valid   ),
    //     .absolute_addr       ( a_addr_sub[0]       ),
    //     .absolute_addr_valid ( a_vld_sub[0] ),
    //     .generate_next_en    ( generate_next_en    )
    // );

    // INDEX2ABS_SUB_1 U_INDEX2ABS_SUB_1(
    //     .clk                 ( clk                 ),
    //     .rst_n               ( rst_n               ),
    //     .spike_index         ( spike_index[128*1 +: 128]         ),
    //     .spike_index_valid   ( spike_index_valid   ),
    //     .absolute_addr       ( a_addr_sub[1]       ),
    //     .absolute_addr_valid ( a_vld_sub[1] ),
    //     .generate_next_en    ( generate_next_en    )
    // );

    // INDEX2ABS_SUB_2 U_INDEX2ABS_SUB_2(
    //     .clk                 ( clk                 ),
    //     .rst_n               ( rst_n               ),
    //     .spike_index         ( spike_index[128*2 +: 128]         ),
    //     .spike_index_valid   ( spike_index_valid   ),
    //     .absolute_addr       ( a_addr_sub[2]       ),
    //     .absolute_addr_valid ( a_vld_sub[2] ),
    //     .generate_next_en    ( generate_next_en    )
    // );

    // INDEX2ABS_SUB_3 U_INDEX2ABS_SUB_3(
    //     .clk                 ( clk                 ),
    //     .rst_n               ( rst_n               ),
    //     .spike_index         ( spike_index[128*3 +: 128]         ),
    //     .spike_index_valid   ( spike_index_valid   ),
    //     .absolute_addr       ( a_addr_sub[3]       ),
    //     .absolute_addr_valid ( a_vld_sub[3] ),
    //     .generate_next_en    ( generate_next_en    )
    // );

    genvar i;
    generate
        for(i=0;i<4;i=i+1)begin
            INDEX2ABS_SUB_0 U_INDEX2ABS_SUB(
                .clk                 ( clk                 ),
                .rst_n               ( rst_n               ),
                .spike_index         ( spike_index[128*i +: 128]         ),
                .spike_index_valid   ( spike_index_valid   ),
                .absolute_addr       ( a_addr_sub[i]       ),
                .absolute_addr_valid ( a_vld_sub[i] ),
                .generate_next_en    ( generate_next_en    )
            );

            always@(posedge clk)begin
                if(generate_next_en == 1'b0)
                    sel_bit[i] <= sel_bit[i];
                else if(spike_index_valid)
                    sel_bit[i] <= |spike_index[128*i +: 128];
            end
        end
    endgenerate

    always@(*)begin
        case(sel_bit)
            4'b0001: absolute_addr = a_addr_sub[0];
            4'b0010: absolute_addr = a_addr_sub[1] + 128;
            4'b0100: absolute_addr = a_addr_sub[2] + 256;
            4'b1000: absolute_addr = a_addr_sub[3] + 384;
            default: absolute_addr = a_addr_sub[0];
        endcase
    end 

    assign absolute_addr_valid = |a_vld_sub;

endmodule 