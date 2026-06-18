// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : tb/tb_weight_top.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Unit testbench for WEIGHT_TOP.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module TB_WEIGHT_TOP();
    reg clk;
    reg rst_n;
    reg process_enable;

    wire  [15:0]          addr   ;
    reg   [41:0]          event_info ;
    reg                   event_info_vld;
    wire can_receive;
    reg  o_ready_from_mp_process;
    wire o_vld_from_weight_top;
    wire [4751:0]     o_data_from_weight_top;
    reg one_position_finish;
    reg [41:0] src [0:100];
    initial begin
        clk = 0;
        forever begin
            #2.5 clk = ~clk;
        end
    end
    integer i;

    initial begin
        rst_n = 0;
        event_info = 0;
        event_info_vld = 0;
        #100;
        rst_n = 1;
        #100;
        @(posedge clk);
        wait(can_receive);
        for(i=0;i<22;i=i+1)begin
            @(posedge clk);
            event_info_vld = 1;
            event_info = src[i];
            // @(posedge clk);
            // event_info_vld = 0;
            // @(posedge clk)
            // wait(can_receive);
        end
        @(posedge clk);
        event_info_vld = 0;
        one_position_finish = 1;
        @(posedge clk);
        one_position_finish = 0;
        
        #1000;
        $finish;
    end

    initial begin
        $readmemh("C:/Full_Event_Computing/RTL/tb/for_tb_weight.txt",src);
    end

    WEIGHT_TOP U_WEIGHT_TOP(
        .clk                     ( clk                     ),
        .rst_n                   ( rst_n                   ),
        .layer_base_addr         ( 0         ),
        .conv_code_layer_en      ( 0      ),
        .padding                 ( 1                 ),
        .layer_type              ( 0              ),
        .shortcut_mode           ( 0           ),
        .stride                  ( 1                  ),
        .filter_size             ( 3             ),
        .did_bit_num             (0),
        .event_info              ( event_info              ),
        .event_info_vld          ( event_info_vld          ),
        .one_position_finish     ( one_position_finish     ),
        .can_receive             ( can_receive             ),
        .o_vld_from_weight_top   ( o_vld_from_weight_top   ),
        .o_ready_from_mp_process ( o_ready_from_mp_process ),
        .o_data_from_weight_top  ( o_data_from_weight_top  )
    );


    // initial begin
    //     event_fetch_en = 0;
    //     forever begin
    //         wait(event_valid == 1);
    //         @(posedge clk);
    //         @(posedge clk);
    //         @(posedge clk);
    //         @(posedge clk);

    //         @(posedge clk);
    //         event_fetch_en = 1;
    //         @(posedge clk);
    //         event_fetch_en = 0;
    //     end
    // end


endmodule