// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : elastic_fifo.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Elastic FIFO buffer between producer and consumer.
// -----------------------------------------------------------------------------

module ELASTIC_FIFO#(
	parameter DATA_WIDTH = 32
	)(
	input wire 							clk 	,
	input wire 							rst_n 	,

 
	// input hand shake
	output wire  						i_ready ,
	input  wire 						i_vld   ,
	/// data
	input  wire [DATA_WIDTH - 1 : 0] 	i_data  ,

	// output hand shake
	output wire 						o_vld 	,
	input  wire  						o_ready ,
	/// data
	output wire [DATA_WIDTH - 1 : 0]    o_data   

	);

	reg [2*DATA_WIDTH - 1 : 0] 	fifo    	;
	reg [1:0] 					cnt			;

	wire     					wr_en 		;
	wire  						rd_en       ;

	assign wr_en = i_ready & i_vld			;
	assign rd_en = o_vld   & o_ready        ;

	always@(posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0)begin
			cnt <= 2'b00;
		end
		else begin
			case({wr_en,rd_en})
				2'b00, 2'b11: cnt <= cnt 	;
				2'b10		: cnt <= cnt + 1;
				2'b01		: cnt <= cnt - 1;
				default     : cnt <= cnt   	;
			endcase
		end
	end

	assign i_ready = (cnt != 2'b10);
	assign o_vld   = (cnt != 2'b00);
	assign o_data  = fifo[DATA_WIDTH-1:0];

	// FIFO operation
	always@(posedge clk)begin
		// if(wr_en == 1'b1 && rd_en == 1'b1)begin
		// 	fifo <= {i_data,fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH]}
		// end
		// else if(wr_en == 1'b1)begin
		// 	fifo <= {i_data,fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH]};
		// end
		// else if(rd_en == 1'b1)begin
		// 	fifo <= {i_data,fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH]};
		// end
		if ((wr_en == 1'b1 && rd_en == 1'b1))begin
			if(cnt == 1)begin
				fifo <= {fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH],i_data};
			end
			else begin
				fifo <= {i_data,fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH]};
			end
		end
		else if (rd_en == 1'b1)begin
			fifo <= {i_data,fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH]};
		end
		else if(wr_en == 1'b1)begin
			case(cnt)
				0: fifo[DATA_WIDTH - 1:0] <= i_data;
				1: fifo[2*DATA_WIDTH - 1 -: DATA_WIDTH] <= i_data;
				default:;
			endcase
		end

	end

endmodule

// module ELASTIC_FIFO #(
//     parameter DATA_WIDTH = 32,
//     parameter DEPTH      = 8          // FIFO depth, configurable (power-of-two recommended)
// )(
//     input  wire                      clk,
//     input  wire                      rst_n,

//     // Input handshake
//     output wire                      i_ready,
//     input  wire                      i_vld,
//     input  wire [DATA_WIDTH-1:0]     i_data,

//     // Output handshake
//     output wire                      o_vld,
//     input  wire                      o_ready,
//     output wire [DATA_WIDTH-1:0]     o_data
// );

//     // ------------------ parameter calculation ------------------
//     localparam ADDR_WIDTH = $clog2(DEPTH);   // address width

//     // ------------------ internal signals ------------------
//     reg [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];   // RAM-style storage

//     reg [ADDR_WIDTH-1:0] wptr;   // write pointer
//     reg [ADDR_WIDTH-1:0] rptr;   // read pointer
//     reg [ADDR_WIDTH:0]   cnt;    // data counter (range 0~DEPTH)

//     wire wr_en = i_ready & i_vld;
//     wire rd_en = o_vld   & o_ready;

//     // ------------------ handshake signals ------------------
//     assign i_ready = (cnt != DEPTH);           // writable when not full
//     assign o_vld   = (cnt != 0);               // readable when not empty
//     assign o_data  = fifo_mem[rptr];           // read data directly from RAM

//     // ------------------ pointer and counter update ------------------
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             wptr <= 0;
//             rptr <= 0;
//             cnt  <= 0;
//         end
//         else begin
//             case ({wr_en, rd_en})
//                 2'b00: begin /* no operation */ end
//                 2'b01: begin // read only
//                     rptr <= (rptr == DEPTH-1) ? 0 : rptr + 1;
//                     cnt  <= cnt - 1;
//                 end
//                 2'b10: begin // write only
//                     wptr <= (wptr == DEPTH-1) ? 0 : wptr + 1;
//                     cnt  <= cnt + 1;
//                 end
//                 2'b11: begin // read and write simultaneously (pointers move together)
//                     wptr <= (wptr == DEPTH-1) ? 0 : wptr + 1;
//                     rptr <= (rptr == DEPTH-1) ? 0 : rptr + 1;
//                     // cnt unchanged
//                 end
//             endcase
//         end
//     end

//     // ------------------ RAM write operation ------------------
//     always @(posedge clk) begin
//         if (wr_en) begin
//             fifo_mem[wptr] <= i_data;
//         end
//     end

// endmodule