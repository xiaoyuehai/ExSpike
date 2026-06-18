// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : tb/tb_event_processor_top.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Unit testbench for EVENT_PROCESSOR_TOP.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module TB_EVENT_PROCESSOR_TOP();
    reg clk;
    reg rst_n;
    reg processing_en;
    reg pooling_calculation_en;
    reg fc_cal_enable;
    wire fc_cal_finish;
    wire [7:0] fc_cal_res;
    reg  cal_start;
    wire cal_finish;
    // wire o_vld_from_weight_top;
    // wire [4751:0] o_data_from_weight_top;
    // reg o_ready_from_mp_process;
    // DDR controller
	wire			RD_START                 ;
	wire	[31:0]	RD_ADRS                  ;
	wire	[31:0]	RD_LEN                   ; 
	wire	[2 :0]	RD_SIZE                  ;

	wire			RD_READY                 ;
	wire			RD_FIFO_WE               ;
	wire	[255:0]	RD_FIFO_DATA             ;
	wire			RD_DONE                  ;
	wire			RD_LAST                  ;
    initial begin
        clk = 0;
        forever begin
            #2.5 clk = ~clk;
        end
    end

    integer i;

    initial begin
        rst_n = 1'b0;
        processing_en = 0;
        pooling_calculation_en = 0;
        fc_cal_enable = 0;
        cal_start = 0;
        // o_ready_from_mp_process = 0;
        #100;
        rst_n = 1'b1;
        #100;
        @(posedge clk);
        cal_start = 1;
        @(posedge clk);
        cal_start = 0;

        #2000;
        #1000;
        $finish;
    end

    // code layer
    EVENT_PROCESSOR_TOP U_EVENT_PROCESSOR_TOP(
        .clk           ( clk           ),
        .rst_n         ( rst_n         ),
        .cal_start     ( cal_start     ),
        .cal_finish    ( cal_finish    ),
        .RD_START      ( RD_START      ),
        .RD_ADRS       ( RD_ADRS       ),
        .RD_LEN        ( RD_LEN        ),
        .RD_SIZE       ( RD_SIZE       ),
        .RD_READY      ( RD_READY      ),
        .RD_FIFO_WE    ( RD_FIFO_WE    ),
        .RD_FIFO_DATA  ( RD_FIFO_DATA  ),
        .RD_DONE       ( RD_DONE       ),
        .RD_LAST       ( RD_LAST       )
    );

    DDR_Read_256bit U_DDR_Read_256bit(
        .CLK          ( clk          ),
        .RST_N        ( rst_n          ),
        .RD_START     ( RD_START     ),
        .RD_ADDR      ( RD_ADRS      ),
        .RD_LEN       ( RD_LEN       ),
        .RD_DONE      ( RD_DONE      ),
        .RD_DATA_FIFO ( RD_FIFO_DATA ),
        .RD_FIFO_WE   ( RD_FIFO_WE   )
    );

endmodule