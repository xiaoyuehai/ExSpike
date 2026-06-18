// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : tb/tb_spike_processing.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Unit testbench for spike processing.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module TB_SPIKE_PROCESSING();
    reg clk;
    reg rst_n;
    reg process_enable;

    wire  [15:0]          rd_spike_addr   ;
    wire                  rd_spike_en     ;
    reg   [1023:0]               rd_spike ;
    wire event_valid;
    reg  event_fetch_en;
    initial begin
        clk = 0;
        forever begin
            #2.5 clk = ~clk;
        end
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;
        @(posedge clk)begin
            process_enable = 1;
        end
        @(posedge clk)begin
            process_enable = 0;
        end

        #1000;
        $finish;
    end

    reg [1023:0] spike_mem [0:1023];
    initial begin
        $readmemb("C:/Full_Event_Computing/input_map.txt",spike_mem);
    end

    always@(posedge clk)begin
        if(rd_spike_en)begin
            rd_spike <= spike_mem[rd_spike_addr];
        end
    end

    SPARSE_PROCESSING u_SPARSE_PROCESSING(
        .clk             ( clk             ),
        .rst_n           ( rst_n           ),
        .i_size          ( 32              ),
        .i_feature_map_len (1024),
        .i_channel_mult_time (4),
        .process_enable  ( process_enable  ),
        .rd_spike_addr   ( rd_spike_addr   ),
        .rd_spike_en     ( rd_spike_en     ),
        .rd_spike        ( rd_spike        ),
        .event_valid     (event_valid      ),
        .event_fetch_en  (event_fetch_en   )
    );

    initial begin
        event_fetch_en = 0;
        forever begin
            wait(event_valid == 1);
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);

            @(posedge clk);
            event_fetch_en = 1;
            @(posedge clk);
            event_fetch_en = 0;
        end
    end


endmodule