// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : read_mp_bias.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Read membrane potential bias values.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`include "defines.vh"
module READ_MP_BIAS#(
    parameter parallel_metric = 32
)(
    input wire          clk             ,
    input wire          rst_n           ,
    //nn_params
    input wire [15:0]   i_feature_map_len,
    input wire [15:0]   o_feature_map_len,
    input wire [15:0]   spec_i_feature_map_len,
    // input wire [15:0]   spec_o_feature_map_len,
    input wire [15:0]   threshold       ,
    input wire [15:0]   i_channel_mult_time,
    input wire [15:0]   layer_bias_addr ,
    input wire          conv_code_layer_en,

    input wire          enable          ,
    input wire [16*parallel_metric-1:0]  rd_mp           ,
    output wire         rd_mp_en        ,
    output wire [15:0]  rd_mp_addr      ,

    output reg          pre_rd_spike_en  ,
    output wire         spike_wb_en     ,
    input  wire [15:0]  base_addr_from_spike_sim,
    output wire [15:0]  spike_wb_addr   ,
    output wire [1023:0] spike_wb_data  ,
    output wire          conv_cal_done  ,

    // for multiple time step
    output wire          dst_wb_en      ,
    output reg  [15:0]   dst_wb_addr    ,
    output wire [16*parallel_metric-1:0]  dst_wb_mp,
    input wire [ 3:0]           layer_type              ,
    output wire [ 7:0]           send2PC_data           ,
    input wire                  send_triger            
);

    reg [15:0] bias_addr;
    reg [15:0] mp_addr;
    reg [16*parallel_metric-1:0] rd_bias;
    reg [15:0] base_mp_addr;
    reg [15:0]  multi_time;
    reg rd_bias_mp_en;
    reg check_finish;
    reg wb_spike_en;

    assign conv_cal_done = check_finish;

    assign rd_mp_en = rd_bias_mp_en;
    assign rd_mp_addr = mp_addr;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_bias_mp_en <= 0;
        end
        else if(base_mp_addr == o_feature_map_len)begin//check_finish
            rd_bias_mp_en <= 0;
        end
        else if(i_channel_mult_time == 1 && mp_addr == o_feature_map_len - 1)begin
            rd_bias_mp_en <= 0;
        end
        else if(enable)begin
            rd_bias_mp_en <= 1;
        end
    end
    
    // statge 1�? generate bias addr //// rd bias & mp
    reg [15:0] cnt;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            cnt <= 0;
        end
        else if(enable)begin
            cnt <= 0;
        end
        else if(rd_bias_mp_en)begin
            if(cnt == o_feature_map_len - 1)
                cnt <= 0;
            else
                cnt <= cnt + 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            bias_addr <= 0;
        end
        else if(enable)begin
            bias_addr <= layer_bias_addr;
        end
        else if(rd_bias_mp_en)begin
            if(multi_time == i_channel_mult_time - 1)
                bias_addr <= layer_bias_addr;
            else
                bias_addr <= bias_addr + 1;
        end
    end     

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            multi_time <= 0;
        end
        else if(enable)begin
            multi_time <= 0;
        end
        else if(rd_bias_mp_en)begin
            if(multi_time == i_channel_mult_time - 1)
                multi_time <= 0;
            else
                multi_time <= multi_time + 1;
        end
    end

    always@(*)begin
        pre_rd_spike_en = multi_time == 0 && wb_spike_en;
    end
    // always@(posedge clk or negedge rst_n)begin
    //     if(rst_n == 1'b0)begin
    //         pre_rd_spike_en <= 0;
    //     end
    //     else if(enable)begin
    //         pre_rd_spike_en <= 0;
    //     end
    //     else if(rd_bias_mp_en)begin
    //         if(multi_time == 0)begin
    //             pre_rd_spike_en <= 1;
    //         end
    //         else begin
    //             pre_rd_spike_en <= 0;
    //         end
    //     end
    //     else begin
    //         pre_rd_spike_en <= 0;
    //     end
    // end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            base_mp_addr <= 0;
        end
        else if(enable | conv_cal_done)begin
            base_mp_addr <= 0;
        end
        else if(rd_bias_mp_en && multi_time == i_channel_mult_time - 2)begin
            base_mp_addr <= base_mp_addr + 1;
        end
    end
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            mp_addr <= 0;
        end
        else if(enable)begin
            mp_addr <= 0;
        end
        else if(rd_bias_mp_en && i_channel_mult_time != 1)begin
            if(multi_time == i_channel_mult_time - 1)
                mp_addr <= base_mp_addr;
            else
                mp_addr <= mp_addr + o_feature_map_len;
        end
        else if(rd_bias_mp_en && i_channel_mult_time == 1)begin
            mp_addr <= mp_addr + 1;
        end
    end

    // Xilinx Block RAM Generation
    wire [16*parallel_metric-1:0] bias_mem_dout;
    `ifdef VGG11_CIFAR10
        VGG11_CIFAR10_BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `elsif ResNet18_CIFAR10
        ResNet18_CIFAR10_BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `elsif ST4_CIFAR10
        ST4_CIFAR10_BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `elsif ST2_CIFAR100
        ST2_CIFAR100_BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `elsif SEG_NET
        SEG_NET_BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `else
        BIAS_MEM U_BIAS_MEM (
            .clka(clk),    // input wire clka
            .ena(rd_bias_mp_en),      // input wire ena
            .addra(bias_addr),  // input wire [6 : 0] addra
            .douta(bias_mem_dout)  // output wire [511 : 0] douta
            );
    `endif

    always@(*)begin
        rd_bias = bias_mem_dout;
    end

    // reg [511:0] bias_mem [0:85];
    // initial begin
    //     // $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_bias.txt", bias_mem);
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_bias_code_layer.txt", bias_mem);
    //     // $readmemh("c:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_bias_layer_7.txt", bias_mem);
    // end
    // always@(posedge clk)begin
    //     if(rd_bias_mp_en)begin
    //         rd_bias <= bias_mem[bias_addr];
    //     end
    // end

    ///////////////////////MEM AREA////////////////////////////////////////

    // stage 2 & 3: add & check spike
    reg acc_en;
    reg check_spike;
    wire [16*parallel_metric-1:0] res;
    wire [16*parallel_metric-1:0] seg_mp_4compare;
    wire [parallel_metric-1:0] spike;

    always@(posedge clk)begin
        acc_en <= rd_bias_mp_en;
        check_spike <= acc_en;
    end

    genvar i;
    generate
        for(i=0;i<parallel_metric;i=i+1)begin
            MP_BIAS_ACC U_MP_BIAS_ACC(
                .clk         ( clk                      ),
                .rst_n       ( rst_n                    ),
                .conv_code_layer_en (conv_code_layer_en ),
                .acc_en      ( acc_en                   ),   
                .src_mp      ( rd_mp[i*16 +: 16]        ),
                .bias        ( rd_bias[i*16 +: 16]      ),
                .res         ( res[i*16 +: 16]          ),
                .check_spike ( check_spike              ),
                .threshold   ( threshold                ),
                .spike       ( spike[i]                 ),
                .dst_mp      ( dst_wb_mp[i*16 +: 16]    ),
                .seg_mp_4compare (seg_mp_4compare[i*16 +: 16])
            );
        end
    endgenerate

    reg [4096-1:0] seg_label;
    reg compare_res;
    always@(*)begin
        case({seg_mp_4compare[15], seg_mp_4compare[31]})
            2'b00, 2'b11: compare_res = seg_mp_4compare[15:0] >= seg_mp_4compare[31:16] ? 0 : 1;
            2'b01: compare_res = 0;
            2'b10: compare_res = 1;
            // 2'b11: 
            default: compare_res = 0;
        endcase
    end 
    // assign compare_res = seg_mp_4compare[15:0] >= seg_mp_4compare[31:16] ? 0 : 1;
    always@(posedge clk)begin
        if(check_spike && layer_type == 3)begin
            seg_label <= {compare_res, seg_label[4095:1]};
        end
        else if(send_triger == 1'b1)begin
            seg_label <= {8'b0, seg_label[4095:8]};
        end
    end

    assign send2PC_data = seg_label[7:0];

    integer file_wr;
    initial begin
        file_wr = $fopen("C:/Full_Event_Computing/FPL_AE/seg_out.txt");
    end
    
    always@(posedge clk) begin
        if (dst_wb_en && dst_wb_addr == 4095 && layer_type == 3) begin
            // 512bit = 128 hex chars; %0128h preserves leading zeros
            $fdisplay(file_wr, "%01024h", seg_label);
        end
    end

    reg [15:0] addr_ff1, addr_ff2;
    always@(posedge clk)begin
        addr_ff1 <= rd_mp_addr;
        addr_ff2 <= addr_ff1;
        dst_wb_addr <= addr_ff2;
    end

    // stage 4: save spike
    
    always@(posedge clk)begin
        wb_spike_en <= check_spike;
    end

    assign dst_wb_en = wb_spike_en;

    //just for sim
    reg [1023:0] spike_line;
    reg [7:0] w_cnt;
    reg [15:0] wb_real_spike_addr;
    reg        wb_real_spike_en;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_cnt <= 0;
            wb_real_spike_en <= 0;
        end
        else if(enable)begin
            w_cnt <= 0;
            wb_real_spike_en <= 0;
        end
        else if(wb_spike_en)begin
            if(w_cnt == i_channel_mult_time - 1)begin
                wb_real_spike_en <= 1;
                w_cnt <= 0;
            end
            else begin
                wb_real_spike_en <= 0;
                w_cnt <= w_cnt + 1;
            end
        end
        else begin
            wb_real_spike_en <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            wb_real_spike_addr <= 0;
        end
        else if(enable)begin
            wb_real_spike_addr <= base_addr_from_spike_sim;//0;
        end
        else if(wb_real_spike_en)begin
            wb_real_spike_addr <= wb_real_spike_addr + 1;
        end
    end

    generate 
        if(parallel_metric == 16) begin
            always@(posedge clk or negedge rst_n)begin
                if(rst_n == 1'b0)begin
                    spike_line <= 0;
                end
                else if(enable)begin
                    spike_line <= 0;
                end
                else if(wb_spike_en)begin
                    case(w_cnt)
                        0: spike_line[parallel_metric*1-1: parallel_metric*0] <= spike;
                        1: spike_line[parallel_metric*2-1: parallel_metric*1] <= spike;
                        2: spike_line[parallel_metric*3-1: parallel_metric*2] <= spike;
                        3: spike_line[parallel_metric*4-1: parallel_metric*3] <= spike;
                        4: spike_line[parallel_metric*5-1: parallel_metric*4] <= spike;
                        5: spike_line[parallel_metric*6-1: parallel_metric*5] <= spike;
                        6: spike_line[parallel_metric*7-1: parallel_metric*6] <= spike;
                        7: spike_line[parallel_metric*8-1: parallel_metric*7] <= spike;
                        8: spike_line[parallel_metric*9-1: parallel_metric*8] <= spike;
                        9: spike_line[parallel_metric*10-1: parallel_metric*9] <= spike;
                        10: spike_line[parallel_metric*11-1: parallel_metric*10] <= spike;
                        11: spike_line[parallel_metric*12-1: parallel_metric*11] <= spike;
                        12: spike_line[parallel_metric*13-1: parallel_metric*12] <= spike;
                        13: spike_line[parallel_metric*14-1: parallel_metric*13] <= spike;
                        14: spike_line[parallel_metric*15-1: parallel_metric*14] <= spike;
                        15: spike_line[parallel_metric*16-1: parallel_metric*15] <= spike;
                        16: spike_line[parallel_metric*17-1: parallel_metric*16] <= spike;
                        17: spike_line[parallel_metric*18-1: parallel_metric*17] <= spike;
                        18: spike_line[parallel_metric*19-1: parallel_metric*18] <= spike;
                        19: spike_line[parallel_metric*20-1: parallel_metric*19] <= spike;
                        20: spike_line[parallel_metric*21-1: parallel_metric*20] <= spike;
                        21: spike_line[parallel_metric*22-1: parallel_metric*21] <= spike;
                        22: spike_line[parallel_metric*23-1: parallel_metric*22] <= spike;
                        23: spike_line[parallel_metric*24-1: parallel_metric*23] <= spike;
                        24: spike_line[parallel_metric*25-1: parallel_metric*24] <= spike;
                        25: spike_line[parallel_metric*26-1: parallel_metric*25] <= spike;
                        26: spike_line[parallel_metric*27-1: parallel_metric*26] <= spike;
                        27: spike_line[parallel_metric*28-1: parallel_metric*27] <= spike;
                        28: spike_line[parallel_metric*29-1: parallel_metric*28] <= spike;
                        29: spike_line[parallel_metric*30-1: parallel_metric*29] <= spike;
                        30: spike_line[parallel_metric*31-1: parallel_metric*30] <= spike;
                        31: spike_line[parallel_metric*32-1: parallel_metric*31] <= spike;
                        default: spike_line <= spike_line;
                    endcase
                end
            end
        end
        else begin
            always@(posedge clk or negedge rst_n)begin
                if(rst_n == 1'b0)begin
                    spike_line <= 0;
                end
                else if(enable)begin
                    spike_line <= 0;
                end
                else if(wb_spike_en)begin
                    case(w_cnt)
                        0: spike_line[parallel_metric*1-1: parallel_metric*0] <= spike;
                        1: spike_line[parallel_metric*2-1: parallel_metric*1] <= spike;
                        2: spike_line[parallel_metric*3-1: parallel_metric*2] <= spike;
                        3: spike_line[parallel_metric*4-1: parallel_metric*3] <= spike;
                        4: spike_line[parallel_metric*5-1: parallel_metric*4] <= spike;
                        5: spike_line[parallel_metric*6-1: parallel_metric*5] <= spike;
                        6: spike_line[parallel_metric*7-1: parallel_metric*6] <= spike;
                        7: spike_line[parallel_metric*8-1: parallel_metric*7] <= spike;
                        8: spike_line[parallel_metric*9-1: parallel_metric*8] <= spike;
                        9: spike_line[parallel_metric*10-1: parallel_metric*9] <= spike;
                        10: spike_line[parallel_metric*11-1: parallel_metric*10] <= spike;
                        11: spike_line[parallel_metric*12-1: parallel_metric*11] <= spike;
                        12: spike_line[parallel_metric*13-1: parallel_metric*12] <= spike;
                        13: spike_line[parallel_metric*14-1: parallel_metric*13] <= spike;
                        14: spike_line[parallel_metric*15-1: parallel_metric*14] <= spike;
                        15: spike_line[parallel_metric*16-1: parallel_metric*15] <= spike;
                        default: spike_line <= spike_line;
                    endcase
                end
            end
        end
    endgenerate
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            check_finish <= 0;
        end
        else if(wb_real_spike_addr == spec_i_feature_map_len - 1 && wb_real_spike_en && layer_type == 0)begin
            check_finish <= 1;
        end
        else if(wb_real_spike_addr == o_feature_map_len - 1 && wb_real_spike_en && layer_type == 3)begin
            check_finish <= 1;
        end
        else begin
            check_finish <= 0;
        end
    end

    assign spike_wb_en   = wb_real_spike_en;
    assign spike_wb_addr = wb_real_spike_addr;
    assign spike_wb_data = spike_line;

endmodule
