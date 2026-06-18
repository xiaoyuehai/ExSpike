// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : event_processor_top.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Top-level event-driven neural network accelerator.
// -----------------------------------------------------------------------------

`include "defines.vh"
module EVENT_PROCESSOR_TOP#( 
    parameter parallel_metric = 32,
    parameter ddr_data_width  = 256,
    `ifdef SEG_NET
        parameter SEG_NET_EN      = 1,
    `else
        parameter SEG_NET_EN      = 0,
    `endif
    parameter TARGET_W_ADDR   = 4095,
    `ifdef ST2_CIFAR100
        parameter CIFAR_100_ENABLE = 1
    `else
        parameter CIFAR_100_ENABLE = 0
    `endif
)(
    input wire          clk                      ,
    input wire          rst_n                    ,
    output wire			uart_tx                  ,
	input wire			uart_rx                  ,
	input wire			Key_Signal               ,
    // DDR controller
	output wire			RD_START                 ,
	output wire	[31:0]	RD_ADRS                  ,
	output wire	[31:0]	RD_LEN                   , 
	output wire	[2 :0]	RD_SIZE                  ,

	input wire			RD_READY                 ,
	input wire			RD_FIFO_WE               ,
	input wire	[ddr_data_width-1:0]	RD_FIFO_DATA             ,
	input wire			RD_DONE                  ,
	input wire			RD_LAST                  ,
    output wire   		dummpy_pin               ,

    input  wire [31:0]  target_addr              ,
`ifndef POWER_ESTIMATION
    input  wire [511:0] target_w_data            ,
    output wire [63:0]  counter_s_ns             ,
`endif
    input  wire         target_w_en              
    
);

wire  			    need_rd_ddr			;
wire [7:0]          uart_time_step      ;
wire [7:0] 		    i_size 				;
wire [15:0]         i_feature_map_len	;
wire [15:0]         i_channel_mult_time ;
wire [15:0]         next_i_channel_mult_time;
wire [15:0]         next_i_channel		;
wire [31:0]         next_ddr_base_addr	;
wire [31:0]         layer_base_addr     ;
wire  			    conv_code_layer_en  ;
wire  			    padding 			;
wire [3:0]          layer_type			;
wire  			    shortcut_mode 		;
wire [ 1:0]         stride              ;
wire [ 3:0]         filter_size         ;
// wire  [3:0]       did_bit_num         ;
wire [15:0]         i_channel           ;
wire [7:0]          o_size              ;
wire [15:0]         threshold           ;
wire [15:0]         layer_bias_addr     ;

wire                fetch_en                ;
wire [7:0]          layer_index             ;
wire                processing_en           ;
wire                pooling_calculation_en  ;
wire                fc_cal_enable           ;
reg                 layer_cal_done_src1          ;
wire                layer_cal_done          ;
wire                weight_vld              ;
wire                conv_cal_done           ;
wire                pooling_cal_done        ;
wire                fc_cal_finish           ;
wire [7:0]          fc_cal_res              ;
wire [7:0]          time_step               ;
wire [7:0]          did_time_step           ;
wire                weight_r_loaction_init  ;
wire                ddr_ctrl_enable         ;
wire	[1023:0]	uart_combine_data       ;
wire				uart_combine_data_valid ;
wire	[15:0]		uart_combine_w_addr     ;
reg                 cal_interrupt_uart      ;
reg     [1:0]       Key_Signal_reg          ;
wire                netwotk_cal_start       ;
wire                cal_start               ;
wire                cal_finish              ;
wire                Tx_done                 ;
wire [5:0]          short_cut_group         ;
wire [15:0]         o_feature_map_len       ;
wire [31:0]         counter_s               ;
wire [31:0]         counter_ns              ;

assign counter_s_ns = {counter_s, counter_ns};

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        Key_Signal_reg <= 2'b11; 
    end
    else begin
        Key_Signal_reg <= {Key_Signal_reg[0],Key_Signal};
    end
end

assign netwotk_cal_start = (Key_Signal_reg[1] & !Key_Signal_reg[0]) | cal_interrupt_uart;
assign cal_start = netwotk_cal_start;

LAYER_CTRL#(
    `ifdef VGG11_CIFAR10
        .TOTAL_LAYER_NUMS       ( 12 )
    `elsif ResNet18_CIFAR10 
        .TOTAL_LAYER_NUMS       ( 21 )
    `elsif ST4_CIFAR10
        .TOTAL_LAYER_NUMS       ( 31 )
    `elsif ST2_CIFAR100
        .TOTAL_LAYER_NUMS       ( 19 )
    `elsif SEG_NET
        .TOTAL_LAYER_NUMS       ( 8 )
    `else
        .TOTAL_LAYER_NUMS       ( 12 )
    `endif
)U_LAYER_CTRL(
    .clk                    ( clk                    ),
    .rst_n                  ( rst_n                  ),
    .cal_start              ( cal_start              ),
    .cal_finish             ( cal_finish             ),
    .fetch_en               ( fetch_en               ),
    .layer_index            ( layer_index            ),
    .layer_type             ( layer_type             ),
    .processing_en          ( processing_en          ),
    .pooling_calculation_en ( pooling_calculation_en ),
    .fc_cal_enable          ( fc_cal_enable          ),
    .layer_cal_done         ( layer_cal_done         ),
    .time_step              ( uart_time_step              ),
    .did_time_step          ( did_time_step          ),
    .weight_r_loaction_init ( weight_r_loaction_init ),
    .ddr_ctrl_enable        ( ddr_ctrl_enable        ),
    .dummpy_pin             ( dummpy_pin             ),
    .counter_s              ( counter_s              ),
    .counter_ns             ( counter_ns             )
);

FETCHER_DECODER U_FETCHER_DECODER(
    .clk                      ( clk                      ),
    .rst_n                    ( rst_n                    ),
    .fetch_en                 ( fetch_en                 ),
    .layer_index              ( layer_index              ),
    .need_rd_ddr              ( need_rd_ddr              ),
    .i_size                   ( i_size                   ),
    .i_feature_map_len        ( i_feature_map_len        ),
    .o_feature_map_len        ( o_feature_map_len        ),
    .i_channel_mult_time      ( i_channel_mult_time      ),
    .next_i_channel_mult_time ( next_i_channel_mult_time ),
    .next_i_channel           ( next_i_channel           ),
    .next_ddr_base_addr       ( next_ddr_base_addr       ),
    .layer_base_addr          ( layer_base_addr          ),
    .conv_code_layer_en       ( conv_code_layer_en       ),
    .padding                  ( padding                  ),
    .layer_type               ( layer_type               ),
    .shortcut_mode            ( shortcut_mode            ),
    .stride                   ( stride                   ),
    .filter_size              ( filter_size              ),
    .i_channel                ( i_channel                ),
    .o_size                   ( o_size                   ),
    .threshold                ( threshold                ),
    .layer_bias_addr          ( layer_bias_addr          ),
    .time_step                ( time_step                ),
    .short_cut_group          ( short_cut_group          )
);

UART_COMBINE_CONTROLLER U_UART_COMBINE_CONTROLLER(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .uart_rx                 ( uart_rx                 ),
    .one_nn_cal_success      ( cal_finish              ),
    .uart_combine_data       ( uart_combine_data       ),
    .uart_combine_data_valid ( uart_combine_data_valid ),
    .uart_combine_w_addr     ( uart_combine_w_addr     ),
    .cal_interrupt_uart      (),//( cal_interrupt_uart      ),
    .uart_time_step          ( uart_time_step          )
);

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        cal_interrupt_uart <= 0;
    end
    else if(target_addr == TARGET_W_ADDR && target_w_en)begin
        cal_interrupt_uart <= 1;
    end
    else begin
        cal_interrupt_uart <= 0;
    end
end

reg send2PC_enable;
reg [15:0] send2PC_counter;
wire send_triger;
wire [7:0] send2PC_data;

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        send2PC_enable <= 0;
    end
    else if(cal_finish && SEG_NET_EN)begin
        send2PC_enable <= 1;
    end
    else if(Tx_done && send2PC_counter == 511)begin
        send2PC_enable <= 0;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        send2PC_counter <= 0; 
    end
    else if(send2PC_enable && Tx_done)begin
        send2PC_counter <= send2PC_counter + 1;
    end
    else if(send2PC_enable)begin
        send2PC_counter <= send2PC_counter;
    end
    else begin
        send2PC_counter <= 0;
    end
end

assign send_triger = (cal_finish | (Tx_done && send2PC_counter < 511)) && SEG_NET_EN;

reco_uart_send inst_reco_uart_send(
	    .Clk(clk),
	    .Reset_n(rst_n),
	    .Data(SEG_NET_EN == 0 ? fc_cal_res : send2PC_data),
	    .Send_Go(SEG_NET_EN == 0 ? cal_finish : send_triger),
	    .Baud_set(3'b100),
	    .uart_tx(uart_tx),
	    .Tx_done(Tx_done)
    );

NEURAL_PROC #(
    .parallel_metric(parallel_metric),
    .ddr_data_width (ddr_data_width),
    .SEG_NET_EN     (SEG_NET_EN),
    .CIFAR_100_ENABLE (CIFAR_100_ENABLE)
)
U_NEURAL_PROC(
    .clk                      ( clk                      ),
    .rst_n                    ( rst_n                    ),
    .time_step                ( uart_time_step                ),
    .did_time_step            ( did_time_step            ),
    .need_rd_ddr              ( need_rd_ddr              ),
    .processing_en            ( processing_en            ),
    .fc_cal_enable            ( fc_cal_enable            ),
    .i_size                   ( {8'b0, i_size[7:0]}              ),
    .i_feature_map_len        ( i_feature_map_len        ),
    .o_feature_map_len        ( o_feature_map_len        ),
    .i_channel_mult_time      ( i_channel_mult_time      ),
    .next_i_channel_mult_time ( next_i_channel_mult_time ),
    .next_i_channel           ( next_i_channel           ),
    .next_ddr_base_addr       ( next_ddr_base_addr       ),
    .layer_base_addr          ( layer_base_addr          ),
    .conv_code_layer_en       ( conv_code_layer_en       ),
    .padding                  ( padding                  ),
    .layer_type               ( layer_type               ),
    .shortcut_mode            ( shortcut_mode            ),
    .stride                   ( stride                   ),
    .filter_size              ( filter_size              ),
    .did_bit_num              (     0                    ),
    .i_channel                ( i_channel                ),
    .o_size                   ( o_size                   ),
    .threshold                ( threshold                ),
    .layer_bias_addr          ( layer_bias_addr          ),
    .pooling_calculation_en   ( pooling_calculation_en   ),
    .fc_cal_finish            ( fc_cal_finish            ),
    .fc_cal_res               ( fc_cal_res               ),
    .weight_vld               ( weight_vld               ),
    .conv_cal_done            ( conv_cal_done            ),
    .pooling_cal_done         ( pooling_cal_done         ),
    .RD_START                 ( RD_START                 ),
    .RD_ADRS                  ( RD_ADRS                  ),
    .RD_LEN                   ( RD_LEN                   ),
    .RD_SIZE                  ( RD_SIZE                  ),
    .RD_READY                 ( RD_READY                 ),
    .RD_FIFO_WE               ( RD_FIFO_WE               ),
    .RD_FIFO_DATA             ( RD_FIFO_DATA             ),
    .RD_DONE                  ( RD_DONE                  ),
    .RD_LAST                  ( RD_LAST                  ),
    .weight_r_loaction_init   ( weight_r_loaction_init   ),
    .ddr_ctrl_enable          ( ddr_ctrl_enable          ),
    `ifndef POWER_ESTIMATION
    .uart_combine_data        (target_w_data),//( uart_combine_data        ),
    `else
    .uart_combine_data        (uart_combine_data        ),
    `endif
    .uart_combine_data_valid  (target_w_en),//( uart_combine_data_valid  ),
    .uart_combine_w_addr      (target_addr),//( uart_combine_w_addr      ),
    .short_cut_group          ( short_cut_group          ),
    .send2PC_data             ( send2PC_data             ),
    .send_triger              ( send_triger              )
);

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        layer_cal_done_src1 <= 0;
    end
    else if(processing_en | pooling_calculation_en | fc_cal_enable)begin
        layer_cal_done_src1 <= 0;
    end
    else if(layer_cal_done)begin
        layer_cal_done_src1 <= 0;
    end
    else if(conv_cal_done | pooling_cal_done | fc_cal_finish)begin
        layer_cal_done_src1 <= 1;
    end
end

// assign layer_cal_done = need_rd_ddr && did_time_step == time_step-1 ? layer_cal_done_src1 & weight_vld : layer_cal_done_src1;
assign layer_cal_done = layer_cal_done_src1;

endmodule