// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : tb/tb_neural_proc.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Unit testbench for NEURAL_PROC.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module TB_NEURAL_PROC();
    reg clk;
    reg rst_n;
    reg processing_en;
    reg pooling_calculation_en;
    reg fc_cal_enable;
    wire fc_cal_finish;
    wire [7:0] fc_cal_res;
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
	wire	[63:0]	RD_FIFO_DATA             ;
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
        // o_ready_from_mp_process = 0;
        #100;
        rst_n = 1'b1;
        #100;
        @(posedge clk);
        processing_en = 1;
        @(posedge clk);
        processing_en = 0;

        // @(posedge clk);
        // pooling_calculation_en = 0;
        // @(posedge clk);
        // pooling_calculation_en = 0;

        // @(posedge clk);
        // fc_cal_enable = 1;
        // @(posedge clk);
        // fc_cal_enable = 0;

        // @(posedge fc_cal_finish);
        // for(i=0;i<3;i=i+1)begin
        //     wait(o_vld_from_weight_top == 1);
        //     @(posedge clk);@(posedge clk);@(posedge clk);
        //     o_ready_from_mp_process = 1;
        //     @(posedge clk);
        //     o_ready_from_mp_process = 0;
        // end

        #2000;
        #1000;
        $finish;
    end

    // second_layer
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 32                      ),
    //     .i_feature_map_len       ( 1024                    ),
    //     .i_channel_mult_time     ( 4                       ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 64                      ),//,
    //     .o_size                  ( 32                      ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );
    // third_conv_layer 128 ---256
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 16                      ),
    //     .i_feature_map_len       ( 256                     ),
    //     .i_channel_mult_time     ( 8                       ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 128                     ),//,
    //     .o_size                  ( 16                      ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );

    // fourth_conv_layer 256 --- 256
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 16                      ),
    //     .i_feature_map_len       ( 256                     ),
    //     .i_channel_mult_time     ( 8                       ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 256                     ),//,
    //     .o_size                  ( 16                      ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );

    // // fifth_conv_layer 256 --- 512 8 --- 8
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 8                       ),
    //     .i_feature_map_len       ( 64                      ),
    //     .i_channel_mult_time     ( 16                      ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 256                     ),//,
    //     .o_size                  ( 8                       ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );

    // sixth_conv_layer 512 --- 512 8 --- 8
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 8                       ),
    //     .i_feature_map_len       ( 64                      ),
    //     .i_channel_mult_time     ( 16                      ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 512                     ),//,
    //     .o_size                  ( 8                       ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );

    // seventh_conv_layer 512 --- 512 4 --- 4
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 4                       ),
    //     .i_feature_map_len       ( 16                      ),
    //     .i_channel_mult_time     ( 16                      ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 1                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 3                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 512                     ),//,
    //     .o_size                  ( 4                       ),
    //     .threshold               ( 16'b0000000000100000    ),
    //     .layer_bias_addr         ( 0                       )
    // );

    // code layer
    NEURAL_PROC u_NEURAL_PROC(
        .clk                     ( clk                     ),
        .rst_n                   ( rst_n                   ),
        .processing_en           ( processing_en           ),
        .i_size                  ( 32                      ),
        .i_feature_map_len       ( 1024                    ),
        .i_channel_mult_time     ( 2                       ),
        .layer_base_addr         ( 0                       ),
        .conv_code_layer_en      ( 1                       ),
        .padding                 ( 1                       ),
        .layer_type              ( 0                       ),
        .shortcut_mode           ( 0                       ),
        .stride                  ( 1                       ),
        .filter_size             ( 3                       ),
        .did_bit_num             ( 0                       ),
        .i_channel               ( 24                      ),//,
        .o_size                  ( 32                      ),
        .threshold               ( 16'b0000100000000000    ),
        .layer_bias_addr         ( 0                       ),
        .next_i_channel_mult_time(4),
        .next_i_channel          (64),
        .next_ddr_base_addr      (0),
        .RD_START                (RD_START),
        .RD_ADRS                 (RD_ADRS),
        .RD_LEN                  (RD_LEN), 
        .RD_SIZE                 (RD_SIZE),

        .RD_READY                (RD_READY),
        .RD_FIFO_WE              (RD_FIFO_WE),
        .RD_FIFO_DATA            (RD_FIFO_DATA),
        .RD_DONE                 (RD_DONE),
        .RD_LAST                 (RD_LAST)
    );

    DDR_Read u_DDR_Read(
        .CLK          ( clk          ),
        .RST_N        ( rst_n          ),
        .RD_START     ( RD_START     ),
        .RD_ADDR      ( RD_ADRS      ),
        .RD_LEN       ( RD_LEN       ),
        .RD_DONE      ( RD_DONE      ),
        .RD_DATA_FIFO ( RD_FIFO_DATA ),
        .RD_FIFO_WE   ( RD_FIFO_WE   )
    );


    // pooling layer
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .i_size                  ( 32                      ),
    //     .i_feature_map_len       ( 1024                    ),
    //     .i_channel_mult_time     ( 2                       ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 0                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 2                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 128                     ),//,
    //     .o_size                  ( 16                      ),
    //     .threshold               ( 16'b0000100000000000    ),
    //     .layer_bias_addr         ( 0                       ),
    //     .pooling_calculation_en  ( pooling_calculation_en  )
    // );

    // pooling layer
    // NEURAL_PROC u_NEURAL_PROC(
    //     .clk                     ( clk                     ),
    //     .rst_n                   ( rst_n                   ),
    //     .processing_en           ( processing_en           ),
    //     .fc_cal_enable           ( fc_cal_enable           ),
    //     .i_size                  ( 4                       ),
    //     .i_feature_map_len       ( 16                      ),
    //     .i_channel_mult_time     ( 2                       ),
    //     .layer_base_addr         ( 0                       ),
    //     .conv_code_layer_en      ( 0                       ),
    //     .padding                 ( 0                       ),
    //     .layer_type              ( 0                       ),
    //     .shortcut_mode           ( 0                       ),
    //     .stride                  ( 1                       ),
    //     .filter_size             ( 2                       ),
    //     .did_bit_num             ( 0                       ),
    //     .i_channel               ( 512                     ),//,
    //     .o_size                  ( 4                       ),
    //     .threshold               ( 16'b0000100000000000    ),
    //     .layer_bias_addr         ( 0                       ),
    //     .pooling_calculation_en  ( pooling_calculation_en  ),
    //     .fc_cal_finish           ( fc_cal_finish           ),
    //     .fc_cal_res              ( fc_cal_res              )
    // );

endmodule