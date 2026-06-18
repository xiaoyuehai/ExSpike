// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : reco_compare.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Recognition result comparison logic.
// -----------------------------------------------------------------------------

module RECO_COMPARE
	#(
		parameter DATA_WIDTH = 20
	)
	(
	input wire						CLK,
	input wire						RST_N,
	input wire						comapre_start,
	input wire	[DATA_WIDTH-1:0]	data_in0,
	input wire	[DATA_WIDTH-1:0]	data_in1,
	input wire	[DATA_WIDTH-1:0]	data_in2, 
	input wire	[DATA_WIDTH-1:0]	data_in3,
	input wire	[DATA_WIDTH-1:0]	data_in4,
	input wire	[DATA_WIDTH-1:0]	data_in5,
	input wire	[DATA_WIDTH-1:0]	data_in6,
	input wire	[DATA_WIDTH-1:0]	data_in7,
	input wire	[DATA_WIDTH-1:0]	data_in8,
	input wire	[DATA_WIDTH-1:0]	data_in9,


	output reg	[7:0]				max_index,
	output reg	[DATA_WIDTH-1:0]	max_data,
	output reg						compare_success
);
	

	reg [7:0] state;
	reg [7:0] max0,max1,max2,max3,max4;
	reg [DATA_WIDTH-1:0] max_data0,max_data1,max_data2,max_data3,max_data4;

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			state <= 0;
			max0 <= 0;
			max_index <= 0;
			max_data <= 0;
		end
		else begin
			compare_success <= 0;

			case(state)
				
				0:begin
					case({data_in0[DATA_WIDTH-1],data_in1[DATA_WIDTH-1]})
					2'b00,2'b11:begin
						if(data_in0 >= data_in1)begin
							max0 <= 0;
							max_data0 <= data_in0;					
						end
						else begin
							max0 <= 1;
							max_data0 <= data_in1;
						end
					end

					2'b10:begin
						max0 <= 1;
						max_data0 <= data_in1;
					end

					2'b01:begin
						max0 <= 0;
						max_data0 <= data_in0;	
					end

					endcase

					///////////////////////
					case({data_in2[DATA_WIDTH-1],data_in3[DATA_WIDTH-1]})
					2'b00,2'b11:begin
						if(data_in2 >= data_in3)begin
							max1 <= 2;
							max_data1 <= data_in2;					
						end
						else begin
							max1 <= 3;
							max_data1 <= data_in3;
						end
					end

					2'b10:begin
						max1 <= 3;
						max_data1 <= data_in3;
					end

					2'b01:begin
						max1 <= 2;
						max_data1 <= data_in2;		
					end

					endcase
					///////////////////////////

					case({data_in4[DATA_WIDTH-1],data_in5[DATA_WIDTH-1]})
					2'b00,2'b11:begin
						if(data_in4 >= data_in5)begin
							max2 <= 4;
							max_data2 <= data_in4;					
						end
						else begin
							max2 <= 5;
							max_data2 <= data_in5;
						end
					end

					2'b10:begin
						max2 <= 5;
						max_data2 <= data_in5;
					end

					2'b01:begin
						max2 <= 4;
						max_data2 <= data_in4;			
					end

					endcase
					///////////////////////////
					case({data_in6[DATA_WIDTH-1],data_in7[DATA_WIDTH-1]})
					2'b00,2'b11:begin
						if(data_in6 >= data_in7)begin
							max3 <= 6;
							max_data3 <= data_in6;					
						end
						else begin
							max3 <= 7;
							max_data3 <= data_in7;
						end
					end

					2'b10:begin
						max3 <= 7;
						max_data3 <= data_in7;
					end

					2'b01:begin
						max3 <= 6;
						max_data3 <= data_in6;			
					end

					endcase
					///////////////////////////
					case({data_in8[DATA_WIDTH-1],data_in9[DATA_WIDTH-1]})
					2'b00,2'b11:begin
						if(data_in8 >= data_in9)begin
							max4 <= 8;
							max_data4 <= data_in8;					
						end
						else begin
							max4 <= 9;
							max_data4 <= data_in9;
						end
					end

					2'b10:begin
						max4 <= 9;
						max_data4 <= data_in9;
					end

					2'b01:begin
						max4 <= 8;
						max_data4 <= data_in8;				
					end

					endcase
					///////////////////////////
				
					
					if(comapre_start)
						state <= 1;
				end

				1:begin
					case({max_data0[DATA_WIDTH-1],max_data1[DATA_WIDTH-1]})
						2'b00,2'b11:begin
							if(max_data0 >= max_data1)begin
								max0 <= max0;
								max_data0 <= max_data0;					
							end
							else begin
								max0 <= max1;
								max_data0 <= max_data1;
							end
						end

						2'b10:begin
							max0 <= max1;
							max_data0 <= max_data1;
						end

						2'b01:begin
							max0 <= max0;
							max_data0 <= max_data0;		
						end

					endcase
					/////////
					case({max_data2[DATA_WIDTH-1],max_data3[DATA_WIDTH-1]})
						2'b00,2'b11:begin
							if(max_data2 >= max_data3)begin
								max1 <= max2;
								max_data1 <= max_data2;					
							end
							else begin
								max1 <= max3;
								max_data1 <= max_data3;
							end
						end

						2'b10:begin
							max1 <= max3;
							max_data1 <= max_data3;
						end

						2'b01:begin
							max1 <= max2;
							max_data1 <= max_data2;		
						end

					endcase


					max2 <= max4;
					max_data2 <= max_data4;

					state <= 2;
				end
	
				2:begin

					case({max_data0[DATA_WIDTH-1],max_data1[DATA_WIDTH-1]})
						2'b00,2'b11:begin
							if(max_data0 >= max_data1)begin
								max0 <= max0;
								max_data0 <= max_data0;					
							end
							else begin
								max0 <= max1;
								max_data0 <= max_data1;
							end
						end

						2'b10:begin
							max0 <= max1;
							max_data0 <= max_data1;
						end

						2'b01:begin
							max0 <= max0;
							max_data0 <= max_data0;		
						end

					endcase

					max1 <= max2;
					max_data1 <= max_data2;
					state <= 3;

				end

				3:begin

					case({max_data0[DATA_WIDTH-1],max_data1[DATA_WIDTH-1]})
						2'b00,2'b11:begin
							if(max_data0 >= max_data1)begin
								max0 <= max0;
								max_index <= max0;
								max_data0 <= max_data0;	
								max_data <= max_data0;				
							end
							else begin
								max0 <= max1;
								max_data0 <= max_data1;
								max_index <= max1;
								max_data <= max_data1;	
							end
						end

						2'b10:begin
							max0 <= max1;
							max_index <= max1;
							max_data <= max_data1;
							max_data0 <= max_data1;

						end

						2'b01:begin
							max0 <= max0;
							max_index <= max0;
							max_data <= max_data0;
							max_data0 <= max_data0;		
						end

					endcase

					state <= 0;
					compare_success <= 1;
				end

				default:;
	
			endcase
		end
	end


endmodule
 