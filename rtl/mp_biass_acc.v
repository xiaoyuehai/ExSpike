// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : mp_biass_acc.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Membrane potential bias accumulator.
// -----------------------------------------------------------------------------

module MP_BIAS_ACC(
    input wire clk,
    input wire rst_n,
    input wire conv_code_layer_en,
    input wire acc_en,
    input wire [15:0] src_mp,
    input wire [15:0] bias,

    output reg [15:0] res,
    output wire [15:0] seg_mp_4compare,

    input wire        check_spike,
    input wire [15:0] threshold,
    output reg        spike,
    output reg [15:0] dst_mp
);
    wire [15:0] pre_acc = src_mp + bias;
    wire p_carry = ~src_mp[15] & ~bias[15] & pre_acc[15];
    wire n_carry =  src_mp[15] &  bias[15] & ~pre_acc[15]; 

    always@(posedge clk)begin
        if(acc_en)begin
            if(p_carry)begin
                res <= conv_code_layer_en ? 16'b0111111111000000 : 16'b0100000000000000;
            end
            else if(n_carry)begin
                res <= conv_code_layer_en ? 16'b1001000000000000 : 16'b1100000000000000;
            end
            // if(conv_code_layer_en)begin
            //     if(p_carry)
            //         res <= 16'b0111111111000000;
            //     else if(n_carry)
            //         res <= 16'b1001000000000000;
            //     else begin
            //         res <= pre_acc;
            //     end
            // end
            else begin
                res <= pre_acc;//src_mp + bias;
            end
        end
        else if(check_spike)begin
            res <= 0;
        end
    end

    wire [15:0] div_2_res = {res[15],res[15:1]};
    assign seg_mp_4compare = res;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            spike <= 0;
        end
        else if(check_spike & div_2_res >= threshold)begin
            spike <= div_2_res[15] == 0;
        end
        else begin
            spike <= 0;
        end
    end

    always@(posedge clk)begin
        if(check_spike & div_2_res >= threshold & ~div_2_res[15])begin
            dst_mp <= 0;
        end
        else begin
            dst_mp <= div_2_res;
        end
    end

endmodule