// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : layer_ctrl.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Layer sequencing and control FSM.
// -----------------------------------------------------------------------------

module LAYER_CTRL#(
    parameter TOTAL_LAYER_NUMS = 12
)(
    input wire              clk         ,
    input wire              rst_n       ,
    input wire [7:0]        time_step   ,
    output reg [7:0]        did_time_step,
    input wire              cal_start   ,
    output wire             cal_finish  ,
    output wire             fetch_en,
    output reg [7:0]        layer_index ,
    input  wire[3:0]        layer_type  ,
    output wire             processing_en,
    output wire             pooling_calculation_en,
    output wire             fc_cal_enable,
    input  wire             layer_cal_done,
    output wire             ddr_ctrl_enable,
    output wire             weight_r_loaction_init,
    output wire             dummpy_pin,
    output reg [31:0]       counter_s,
    output reg [31:0]       counter_ns
);
    reg neural_processing_doing;
    reg layer_cal_doing;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            neural_processing_doing <= 0;
        end
        else if(cal_finish)begin
            neural_processing_doing <= 0;
        end
        else if(cal_start)begin
            neural_processing_doing <= 1;
        end
    end

    assign weight_r_loaction_init = cal_start;
    assign ddr_ctrl_enable = neural_processing_doing;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            layer_cal_doing <= 0;
        end
        else if(fetch_en)begin
            layer_cal_doing <= 1;
        end
        else if(layer_cal_done)begin
            layer_cal_doing <= 0;
        end
    end

    always@(posedge clk)begin
        if(cal_start)begin
            layer_index <= 0;
        end
        else if(layer_cal_done && did_time_step == time_step - 1)begin
            layer_index <= layer_index + 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            did_time_step <= 0;
        end
        else if(cal_start)begin
            did_time_step <= 0;
        end
        else if(layer_cal_done)begin
            if(did_time_step == time_step - 1)begin
                did_time_step <= 0;
            end
            else begin
                did_time_step <= did_time_step + 1;
            end
        end
    end

    assign fetch_en = neural_processing_doing && ~layer_cal_doing;

    reg fetch_en_ff1, fetch_en_ff2;
    always@(posedge clk)begin
        fetch_en_ff1 <= fetch_en;
        fetch_en_ff2 <= fetch_en_ff1;
    end

    assign processing_en = fetch_en_ff2 & (layer_type == 0 || layer_type == 3);
    assign pooling_calculation_en = fetch_en_ff2 & (layer_type == 1);
    assign fc_cal_enable = fetch_en_ff2 & (layer_type == 2); 

    assign cal_finish = layer_cal_done && (layer_index == TOTAL_LAYER_NUMS - 1) && did_time_step == time_step - 1;

    // (* syn_preserve = "true", keep = "true" *)reg [31:0] counter_s;
	// (* syn_preserve = "true", keep = "true" *)reg [31:0] counter_ns;

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			counter_ns <= 0;
			counter_s <= 0;
		end
		else if(neural_processing_doing)begin
			if(counter_ns == 200000000 - 1)begin
				counter_ns <= 0;
				counter_s <= counter_s + 1;
			end
			else begin
				counter_ns <= counter_ns + 1;
			end
		end
	end

	// ila_0 U_ILA (
	// 	.clk(clk), // input wire clk
	// 	.probe0({counter_s,
	// 			counter_ns}) // input wire [63:0] probe0
	// )/* synthesis preserve = 1 */;

	assign dummpy_pin = (|counter_s) & (|counter_ns);

endmodule