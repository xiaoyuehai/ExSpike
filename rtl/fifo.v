// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : fifo.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Synchronous FIFO buffer.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/07 11:19:55
// Design Name: 
// Module Name: fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FIFO #(
    parameter width      = 8,
    parameter depth      = 256,
    parameter depth_addr = 8
)(
    input wire                      clk,
    input wire                      rst_n,
    input wire                      push_req_n,
    input wire                      pop_req_n,
    input wire  [width-1: 0]        data_in,
    output reg                      empty,
    output wire                     full,
    output reg  [width-1: 0]        data_out
);
  
    reg [width-1:0] mem [0:depth-1]; 

    reg [depth_addr-1:0] write_ptr;
    reg [depth_addr-1:0] read_ptr;
    reg [depth_addr-1:0] fill_cnt;

    // assign in_fc_fifo_cnt = fill_cnt;

    genvar i;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            write_ptr <= 2'b0;
        else if (!push_req_n)
            write_ptr <= write_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            write_ptr <= write_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            read_ptr <= 2'b0;
        else if (!pop_req_n)
            read_ptr <= read_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            read_ptr <= read_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            fill_cnt <= 2'b0;
        else if (!push_req_n && pop_req_n && !empty)
            fill_cnt <= fill_cnt + {{(depth_addr-1){1'b0}},1'b1};
        else if (!push_req_n && !pop_req_n)
            fill_cnt <= fill_cnt;
        else if (!pop_req_n && |fill_cnt)
            fill_cnt <= fill_cnt - {{(depth_addr-1){1'b0}},1'b1};
        else
            fill_cnt <= fill_cnt;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            empty <= 1'b1;
        else if (!push_req_n)
            empty <= 1'b0;
        else if (!pop_req_n)
            empty <= ~|fill_cnt; 
    end

    assign full  =  &fill_cnt;

    //generate    
    always @(posedge clk) begin
        if (!push_req_n)
            mem[write_ptr] <= data_in;
    end

    // assign data_out = mem[read_ptr];
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out <= 0; 
        end 
        else if(!pop_req_n)begin
            data_out <= mem[read_ptr]; 
        end
    end

endmodule 