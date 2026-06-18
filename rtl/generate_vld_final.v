// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : generate_vld_final.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Generate valid-final signals for spike writeback.
// -----------------------------------------------------------------------------

module GENERATE_VLF_FINAL#(
    parameter MAX = 31,
    parameter SEG_NET_EN = 0
)(
    input wire           clk             ,
    input wire           rst_n           ,
    input wire           restart         ,
    input wire [7:0]     o_size          ,
    input wire           spike_w_vld     ,
    input wire [511:0]   spike           ,
    input wire           spike_wb_basic  ,
    input wire           spike_wb_residual,
    input wire           conv_src_spike   ,
  
    output wire  [7:0]    max_vld_row     ,
    output wire  [7:0]    max_vld_col     

    
);
    reg  [7:0]    basic_max_vld_row     ;
    reg  [7:0]    basic_max_vld_col     ;

    reg  [7:0]    sc_max_vld_row     ;
    reg  [7:0]    sc_max_vld_col     ;

    reg [7:0] row, col;
    reg [511:0] spike_buffer;
    reg spike_buffer_vld;
    reg [7:0] spec_o_size;
    reg spike_wb_basic_ff1;
    reg spike_wb_residual_ff1;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            spike_buffer <= 0;
            spike_buffer_vld <= 0;
            spec_o_size <= 0;
            spike_wb_basic_ff1 <= 0;
            spike_wb_residual_ff1 <= 0;
        end
        else begin
            spike_buffer <= spike;
            spike_buffer_vld <= spike_w_vld;
            spec_o_size <= o_size;
            spike_wb_basic_ff1 <= spike_wb_basic;
            spike_wb_residual_ff1 <= spike_wb_residual;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            row <= 0;
        end
        else if(restart)begin
            row <= 0;
        end
        else if(spike_buffer_vld)begin
            if(col == spec_o_size - 1)begin
                if(row == spec_o_size - 1)begin
                    row <= 0;
                end
                else begin
                    row <= row + 1;
                end
            end
            else begin
                row <= row;
            end
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            col <= 0;
        end
        else if(restart)begin
            col <= 0;
        end
        else if(spike_buffer_vld)begin
            if(col == spec_o_size - 1)begin
                col <= 0;
            end
            else begin
                col <= col + 1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            basic_max_vld_row <= SEG_NET_EN ==  0 ? 31 : 63;//31;
            basic_max_vld_col <= SEG_NET_EN ==  0 ? 31 : 63;//31;
        end
        else if(restart)begin
            basic_max_vld_row <= SEG_NET_EN ==  0 ? 31 : 63;
            basic_max_vld_col <= MAX;
        end
        else if(spike_buffer_vld && (|spike_buffer) && spike_wb_basic_ff1)begin
            basic_max_vld_row <= row;
            basic_max_vld_col <= col;
        end
    end
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            sc_max_vld_row <= SEG_NET_EN ==  0 ? 31 : 63;//31;
            sc_max_vld_col <= SEG_NET_EN ==  0 ? 31 : 63;//31;
        end
        else if(restart)begin
            sc_max_vld_row <= SEG_NET_EN ==  0 ? 31 : 63;
            sc_max_vld_col <= MAX;
        end
        else if(spike_buffer_vld && (|spike_buffer) && spike_wb_residual_ff1)begin
            sc_max_vld_row <= row;
            sc_max_vld_col <= col;
        end
    end

    assign max_vld_row = conv_src_spike == 0 ? basic_max_vld_row : sc_max_vld_row;
    assign max_vld_col = conv_src_spike == 0 ? basic_max_vld_col : sc_max_vld_col;

endmodule