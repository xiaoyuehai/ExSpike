// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : fetcher_decoder.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Instruction fetcher and decoder for layer control.
// -----------------------------------------------------------------------------

`include "defines.vh"
module FETCHER_DECODER(
    input wire              clk                 ,
    input wire              rst_n               ,
    input wire              fetch_en            ,
    input wire [7:0]        layer_index         ,

    // Neural Parameter
	output reg  			need_rd_ddr			,
	output reg [7:0] 		i_size 				,
	output reg [15:0]       i_feature_map_len	,
	output reg [15:0]       i_channel_mult_time ,
	output reg [15:0]       next_i_channel_mult_time,
	output reg [15:0]       next_i_channel		,
	output reg [31:0]       next_ddr_base_addr	,
	output reg [31:0]       layer_base_addr     ,
	output reg  			conv_code_layer_en  ,
	output reg  			padding 			,
	output reg [3:0]        layer_type			,
	output reg  			shortcut_mode 		,
	output reg [ 1:0]       stride              ,
    output reg [ 3:0]       filter_size         ,
    // output reg  [3:0]       did_bit_num         ,
    output reg [15:0]       i_channel           ,
    output reg [7:0]        o_size              ,
    output reg [15:0]       o_feature_map_len   ,
    output reg [15:0]       threshold           ,
    output reg [15:0]       layer_bias_addr     ,
	output wire [7:0]		time_step 	,
    output reg [5:0]        short_cut_group

);
    reg [218:0] read_neuron_param_memory_data;
	reg generate_parameter, generate_parameter_ff1;
	// r_time_step your_instance_name (
	// .clk(clk),                // input wire clk
	// .probe_out0()  // output wire [7 : 0] probe_out0
	// );
	assign time_step = 4;
    // network_cmpile_mem inst_network_cmpile_mem (
	//   .clka(clk),    // input wire clka
	//   .ena(cal_start),      // input wire ena
	//   .addra(layer_index),  // input wire [2 : 0] addra
	//   .douta(read_neuron_param_memory_data)  // output wire [131 : 0] douta
	// );
	// memory compiler
	// Xilinx Block RAM Generation
	wire [218:0] inst_mem_out;
	`ifdef VGG11_CIFAR10
		VGG11_CIFAR10_INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`elsif ResNet18_CIFAR10
		ResNet18_CIFAR10_INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`elsif ST4_CIFAR10
		ST4_CIFAR10_INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`elsif ST2_CIFAR100
		ST2_CIFAR100_INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`elsif SEG_NET
		SEG_NET_INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`else
		INST_MEM U_INST_MEM (
			.clka(clk),    // input wire clka
			.ena(fetch_en),      // input wire ena
			.addra(layer_index),  // input wire [4 : 0] addra
			.douta(inst_mem_out)  // output wire [218 : 0] douta
		);
	`endif
	always@(*)begin
		read_neuron_param_memory_data = inst_mem_out;
	end
	// 
    // reg [215:0] neural_param_mem [0:31];
    // initial begin
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/network_compile.txt", neural_param_mem);
    // end

    // always@(posedge clk)begin
    //     if(fetch_en == 1'b1)begin
    //         read_neuron_param_memory_data <= neural_param_mem[layer_index];
    //     end 
    // end
	///////////////////////MEM AREA////////////////////////////////////////

	always@(posedge clk)begin
		if(fetch_en == 1'b1)begin
			conv_code_layer_en <= layer_index == 0;
		end
	end

    // logic design
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			i_feature_map_len <= 0;
		end
		else if(generate_parameter_ff1)begin
			case(i_size)
				1: i_feature_map_len <= 1;
				2: i_feature_map_len <= 4;
				4: i_feature_map_len <= 16;
				8: i_feature_map_len <= 64;
				16: i_feature_map_len <= 256;
				32: i_feature_map_len <= 1024;
				64: i_feature_map_len <= 4096;
				default: i_feature_map_len <= 1024;
			endcase
		end
	end

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			o_feature_map_len <= 0;
		end
		else if(generate_parameter_ff1)begin
			case(o_size)
				1: o_feature_map_len <= 1;
				2: o_feature_map_len <= 4;
				4: o_feature_map_len <= 16;
				8: o_feature_map_len <= 64;
				16: o_feature_map_len <= 256;
				32: o_feature_map_len <= 1024;
				64: o_feature_map_len <= 4096;
				default: o_feature_map_len <= 1024;
			endcase
		end
	end

	always@(posedge clk)begin
		generate_parameter <= fetch_en;
		generate_parameter_ff1 <= generate_parameter;
	end

	always@(posedge clk)begin
		if(generate_parameter)begin
			layer_type  				<= read_neuron_param_memory_data[3:0];
			layer_bias_addr 			<= read_neuron_param_memory_data[19:4];
			layer_base_addr 			<= read_neuron_param_memory_data[51:20];
			threshold  	    			<= read_neuron_param_memory_data[67:52];
			stride		    			<= read_neuron_param_memory_data[69:68];
			filter_size	    			<= read_neuron_param_memory_data[73:70];
			padding 	    			<= read_neuron_param_memory_data[74:74];
			i_channel_mult_time 		<= read_neuron_param_memory_data[90:75];
			// o_channel 		    		<= read_neuron_param_memory_data[106:91];
			i_channel 		    		<= read_neuron_param_memory_data[122:107];
			o_size              		<= read_neuron_param_memory_data[130:123];
			i_size              		<= read_neuron_param_memory_data[138:131];
			shortcut_mode       		<= read_neuron_param_memory_data[139:139];
			next_i_channel_mult_time 	<= read_neuron_param_memory_data[155:140];
			next_i_channel 			    <= read_neuron_param_memory_data[171:156];
			next_ddr_base_addr          <= read_neuron_param_memory_data[203:172];
			need_rd_ddr 			    <= read_neuron_param_memory_data[204:204];
			// time_step 					<= read_neuron_param_memory_data[212:205];
			short_cut_group             <= read_neuron_param_memory_data[218:213];
		end
	end

endmodule