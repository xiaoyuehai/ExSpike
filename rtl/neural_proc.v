// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : neural_proc.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Neural processing subsystem wrapper.
// -----------------------------------------------------------------------------

`include "defines.vh"
module NEURAL_PROC#(
    parameter parallel_metric = 128,
    parameter ddr_data_width  = 256,
    parameter SEG_NET_EN      = 0,
    parameter CIFAR_100_ENABLE = 0
)(
    input  wire                 clk                     ,
    input  wire                 rst_n                   ,
    input  wire  [ 7:0]         time_step               ,
    input  wire  [ 7:0]         did_time_step           ,
    input  wire                 processing_en           ,
    input  wire                 need_rd_ddr             ,
    input  wire                 fc_cal_enable           ,
    input  wire [15:0]          i_size                  ,
    input  wire [15:0]          i_feature_map_len       ,
    input  wire [15:0]          o_feature_map_len       ,
    input  wire [15:0]          i_channel_mult_time     ,
    input  wire [15:0]          next_i_channel_mult_time,
    input  wire [15:0]          next_i_channel          ,
    input  wire [31:0]          next_ddr_base_addr      ,
    input wire  [31:0]          layer_base_addr         ,
    input wire                  conv_code_layer_en      ,
    input wire                  padding                 ,
    input wire [ 3:0]           layer_type              ,
    input wire                  shortcut_mode           ,
    input wire [ 1:0]           stride                  ,
    input wire [ 3:0]           filter_size             ,
    input wire  [3:0]           did_bit_num             ,
    input wire [15:0]           i_channel               ,
    input wire [7:0]            o_size                  ,
    input wire [15:0]           threshold               ,
    input wire [15:0]           layer_bias_addr         ,
    input wire                  pooling_calculation_en  ,
    output  wire                fc_cal_finish           ,
    output  wire [7:0]          fc_cal_res              ,
    output wire                 weight_vld              ,
    output wire                 conv_cal_done           ,
    output wire                 pooling_cal_done        ,
    input  wire                 ddr_ctrl_enable         ,
    input  wire                 weight_r_loaction_init  ,
    //uart config
    input  wire	[1023:0]	    uart_combine_data       ,
	input  wire				    uart_combine_data_valid ,
	input  wire	[15:0]		    uart_combine_w_addr     ,
    input  wire [5:0]           short_cut_group         ,
    output wire [7:0]           send2PC_data            ,
    input  wire                 send_triger             ,

    // DDR controller
	output wire			RD_START                 ,
	output wire	[31:0]	RD_ADRS                  ,
	output wire	[31:0]	RD_LEN                   , 
	output wire	[2 :0]	RD_SIZE                  ,

	input wire			RD_READY                 ,
	input wire			RD_FIFO_WE               ,
	input wire	[255:0]	RD_FIFO_DATA             ,
	input wire			RD_DONE                  ,
	input wire			RD_LAST         
    //sim
    // output wire                 o_vld_from_weight_top   ,
    // output wire                 o_data_from_weight_top  ,
    // input  wire                 o_ready_from_mp_process  
);  

wire                event_valid             ;
wire                event_fetch_en          ;
wire  [15:0]        rd_spike_addr           ;
wire                rd_spike_en             ;
wire [1023:0]       rd_spike                ; // all in_channel
wire [41:0]         event_info              ;
wire                event_check_finish      ;
wire                can_receive_weight_top  ;
wire                event_info_vld_to_w     ;
wire [41:0]         event_info_to_w         ;
wire                o_vld_from_weight_top   ;
wire [1+144+9*16*parallel_metric-1:0]       o_data_from_weight_top  ;
wire                o_ready_from_mp_process ; 
wire [16*parallel_metric-1:0]         rd_mp_to_bias          ;
wire                 rd_mp_en_from_bias     ;
wire [15:0]          rd_mp_addr_from_bias   ;
reg                  enable                 ;
wire                 spike_wb_en            ;
wire [15:0]          spike_wb_addr          ;
wire [1023:0]        spike_wb_data          ;
wire                 fc_rd_en               ;
wire [15:0]          fc_rd_addr             ;
wire [1023:0]        fc_rd_spike            ;
// wire                 weight_vld             ;
wire [19:0]          rd_weight_addr_ddr     ;
wire [19:0]          rd_weight_addr_ddr_reg ;
wire                 rd_weight_en_ddr       ;
wire [9*8*parallel_metric-1:0]        rd_weight_ddr          ;           
wire                 dst_wb_en              ;
wire  [15:0]         dst_wb_addr            ;
wire [16*parallel_metric-1:0]         dst_wb_mp              ;
wire [ 31:0]         weight_r_loaction      ;
wire                 wpe_busy               ;
wire  [7:0]          max_vld_row_sel        ;
wire  [7:0]          max_vld_col_sel        ;
wire                 pre_rd_spike_en        ;
wire [15:0]          base_addr_for_ddr      ;
wire [15:0]          base_addr_from_spike_sim;
/*DDR_READ_CTRL U_DDR_READ_CTRL(
    .clk                       ( clk                       ),
    .rst_n                     ( rst_n                     ),
    .need_rd_ddr               ( need_rd_ddr               ),
    .processing_en             ( processing_en & did_time_step == 0),
    .weight_vld                ( weight_vld                ),
    .next_i_channel_mult_time  ( next_i_channel_mult_time  ),
    .next_i_channel            ( next_i_channel            ),
    .next_ddr_base_addr        ( next_ddr_base_addr        ),
    .rd_weight_addr_ddr        ( rd_weight_addr_ddr        ),
    .rd_weight_en_ddr          ( rd_weight_en_ddr          ),
    .rd_weight_ddr             ( rd_weight_ddr             ),
    .RD_START                  ( RD_START                  ),
    .RD_ADRS                   ( RD_ADRS                   ),
    .RD_LEN                    ( RD_LEN                    ),
    .RD_SIZE                   ( RD_SIZE                   ),
    .RD_READY                  ( RD_READY                  ),
    .RD_FIFO_WE                ( RD_FIFO_WE                ),
    .RD_FIFO_DATA              ( RD_FIFO_DATA              ),
    .RD_DONE                   ( RD_DONE                   ),
    .RD_LAST                   ( RD_LAST                   )
);*/
reg [ddr_data_width-1:0] RD_FIFO_DATA_reg;
reg RD_FIFO_WE_reg;
reg RD_DONE_reg;

always@(posedge clk)begin
    RD_FIFO_DATA_reg <= RD_FIFO_DATA;
    RD_FIFO_WE_reg <= RD_FIFO_WE;
    RD_DONE_reg <= RD_DONE;
end

reg [15:0] spec_i_feature_map_len;
reg [15:0] spec_o_feature_map_len;
always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        spec_i_feature_map_len <= 0;
        spec_o_feature_map_len <= 0;
    end
    else begin
        spec_i_feature_map_len <= i_feature_map_len + base_addr_from_spike_sim;
        spec_o_feature_map_len <= o_feature_map_len + base_addr_from_spike_sim;
    end
end

DDR_READ_CTRL_OPT #(
    .parallel_metric(parallel_metric),
    .ddr_data_width (ddr_data_width)
)
U_DDR_READ_CTRL_OPT(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .i_channel           ( i_channel           ),
    .ddr_ctrl_enable     ( ddr_ctrl_enable     ),
    .weight_r_loaction   ( weight_r_loaction   ),
    .weight_vld          ( weight_vld          ),
    .rd_weight_addr_ddr  ( rd_weight_addr_ddr  ),
    .rd_weight_addr_ddr_reg ( rd_weight_addr_ddr_reg ),
    .rd_weight_en_ddr    ( rd_weight_en_ddr    ),
    .rd_weight_ddr       ( rd_weight_ddr       ),
    .base_addr_for_ddr   ( base_addr_for_ddr   ),
    .RD_START            ( RD_START            ),
    .RD_ADRS             ( RD_ADRS             ),
    .RD_LEN              ( RD_LEN              ),
    .RD_SIZE             ( RD_SIZE             ),
    .RD_READY            ( RD_READY            ),
    .RD_FIFO_WE          ( RD_FIFO_WE_reg          ),
    .RD_FIFO_DATA        ( RD_FIFO_DATA_reg        ),
    .RD_DONE             ( RD_DONE_reg             ),
    .RD_LAST             ( RD_LAST             )
);

// SCHEDULER U_SCHEDULER(
//     .clk                     ( clk                     ),
//     .rst_n                   ( rst_n                   ),
//     .processing_en           ( processing_en           ),
//     .event_valid             ( event_valid             ),
//     .event_fetch_en          ( event_fetch_en          ),
//     .event_info              ( event_info              ),
//     .can_receive_weight_top  ( conv_code_layer_en ? can_receive_weight_top : can_receive_weight_top & weight_vld),
//     .event_check_finish      ( event_check_finish      ),
//     .event_info_vld_to_w     ( event_info_vld_to_w     ),
//     .event_info_to_w         ( event_info_to_w         ),
//     .one_position_finish     ( one_position_finish     )
// );

SPIKE_SIM #(
    .SEG_NET_EN(SEG_NET_EN)
)   
U_SPIKE_SIM(
    .clk            ( clk                 ),
    .rst_n          ( rst_n               ),
    .rd_spike_addr  ( rd_spike_addr       ),
    .rd_spike_en    ( rd_spike_en         ),
    .rd_spike       ( rd_spike            ),
    .spike_wb_en    ( spike_wb_en         ),
    .spike_wb_addr  ( spike_wb_addr       ),
    .spike_wb_data  ( spike_wb_data       ),
    .pooling_calculation_en(pooling_calculation_en),
    .i_size         ( i_size              ),
    .o_size         ( o_size              ),
    .fc_rd_en       ( fc_rd_en            ),
    .fc_rd_addr     ( fc_rd_addr          ),
    .fc_rd_spike    ( fc_rd_spike         ),
    .pooling_cal_done(pooling_cal_done),
    .did_time_step  (did_time_step),
    .uart_combine_data       ( uart_combine_data       ),
    .uart_combine_data_valid ( uart_combine_data_valid ),
    .uart_combine_w_addr     ( uart_combine_w_addr     ),
    .restart        (fc_cal_finish),
    .max_vld_row_sel (max_vld_row_sel),
    .max_vld_col_sel (max_vld_col_sel),
    .short_cut_group (short_cut_group),
    .pre_rd_spike_en (pre_rd_spike_en),
    .base_addr_from_spike_sim (base_addr_from_spike_sim)
);

 SPARSE_PROCESSING U_SPARSE_PROCESSING(
     .clk                 ( clk                 ),
     .rst_n               ( rst_n               ),
     .i_size              ( i_size              ),
     .i_feature_map_len   ( i_feature_map_len   ),
     .spec_i_feature_map_len (spec_i_feature_map_len),
     .i_channel_mult_time ( i_channel_mult_time ),
     .process_enable      ( processing_en       ),
     .rd_spike_addr       ( rd_spike_addr       ),
     .rd_spike_en         ( rd_spike_en         ),
     .rd_spike            ( rd_spike            ),
     .event_valid         ( event_valid         ),
     .event_fetch_en      ( event_fetch_en      ),
     .event_info          ( event_info          ),
     .event_info_vld      ( event_info_vld      ),
     .event_check_finish  ( event_check_finish  ),
     .base_addr_from_spike_sim (base_addr_from_spike_sim)
 );

//sparse_processing_hls u_sparse_processing_hls( 
//    .ap_clk                ( clk                ),
//    .ap_rst                ( rst_n                ),
//    .process_enable_V      ( processing_en      ),
//    .i_feature_map_len_V   ( i_feature_map_len   ),
//    .i_channel_mult_time_V ( i_channel_mult_time ),
//    .i_size_V              ( i_size              ),
//    .r_spike_addr_V        ( rd_spike_addr        ),
//    .r_en_V                ( rd_spike_en                ),
//    .r_spike_V             ( rd_spike             ),
//    .event_fetch_en_V      ( event_fetch_en      ),
//    .event_valid_V         ( event_valid         ),
//    .event_info_V          ( event_info          ),
//    .event_check_finish_V  ( event_check_finish  )
//);


WEIGHT_TOP #(
    .parallel_metric(parallel_metric)
)
U_WEIGHT_TOP(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .processing_en           ( processing_en           ),
    .layer_base_addr         ( layer_base_addr         ),
    .conv_code_layer_en      ( conv_code_layer_en      ),
    .padding                 ( padding                 ),
    .layer_type              ( layer_type              ),
    .shortcut_mode           ( shortcut_mode           ),
    .stride                  ( stride                  ),
    .filter_size             ( filter_size             ),
    .did_bit_num             ( did_bit_num             ),
    .i_channel               ( i_channel               ),
    .i_size                  ( i_size                  ),
    .event_info              ( event_info              ),
    .event_info_vld          ( event_info_vld          ),
    .event_valid             ( event_valid         ),
    .event_fetch_en          ( event_fetch_en      ),
    // .one_position_finish     ( one_position_finish     ),
    .can_receive             ( can_receive_weight_top  ),
    .o_vld_from_weight_top   ( o_vld_from_weight_top   ),
    .o_ready_from_mp_process ( o_ready_from_mp_process ),
    .o_data_from_weight_top  ( o_data_from_weight_top  ),
    .rd_weight_addr_ddr        ( rd_weight_addr_ddr        ),
    .base_addr_for_ddr         ( base_addr_for_ddr         ),
    .rd_weight_addr_ddr_reg   ( rd_weight_addr_ddr_reg   ),
    .rd_weight_en_ddr          ( rd_weight_en_ddr          ),
    .rd_weight_ddr             ( rd_weight_ddr             ),
    .weight_vld              (weight_vld),
    .weight_r_loaction_init  (weight_r_loaction_init),
    .weight_r_loaction       (weight_r_loaction),
    .time_step              ( time_step              ),
    .did_time_step          ( did_time_step          ),
    .conv_cal_done       ( conv_cal_done       ),
    .wpe_busy               (wpe_busy),
    .bias_enable            (enable),
    .max_vld_row_sel (max_vld_row_sel),
    .max_vld_col_sel (max_vld_col_sel)
);

READ_MEMBRANE_P #(
    .parallel_metric(parallel_metric)
)
U_READ_MEMBRANE_P(
    .clk                    ( clk                    ),
    .rst_n                  ( rst_n                  ),
    .time_step              ( time_step              ),
    .did_time_step          ( did_time_step          ),
    .o_size                 ( o_size                 ),
    .processing_en          ( processing_en          ),
    .i_feature_map_len      (i_feature_map_len       ),
    .o_feature_map_len      (o_feature_map_len       ),
    .o_vld_from_weight_top  ( o_vld_from_weight_top  ),
    .o_data_from_weight_top ( o_data_from_weight_top ),
    .o_ready_from_mp_process  ( o_ready_from_mp_process  ),
    .rd_mp_to_bias          ( rd_mp_to_bias          ),
    .rd_mp_en_from_bias     ( rd_mp_en_from_bias     ),
    .rd_mp_addr_from_bias   ( rd_mp_addr_from_bias   ),
    .dst_wb_en              ( dst_wb_en              ),
    .dst_wb_addr            ( dst_wb_addr            ),
    .dst_wb_mp              ( dst_wb_mp              )
);

READ_MP_BIAS #(
    .parallel_metric(parallel_metric)
)
U_READ_MP_BIAS(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .i_feature_map_len   ( i_feature_map_len   ),
    .o_feature_map_len   ( o_feature_map_len   ),
    .spec_i_feature_map_len (spec_o_feature_map_len),//spec_i_feature_map_len
    .threshold           ( threshold           ),
    .i_channel_mult_time ( i_channel_mult_time ),
    .layer_bias_addr     ( layer_bias_addr     ),
    .conv_code_layer_en  ( conv_code_layer_en  ),
    .enable              ( enable              ),
    .rd_mp               ( rd_mp_to_bias               ),
    .rd_mp_en            ( rd_mp_en_from_bias            ),
    .rd_mp_addr          ( rd_mp_addr_from_bias          ),
    .pre_rd_spike_en     ( pre_rd_spike_en     ),
    .spike_wb_en         ( spike_wb_en         ),
    .spike_wb_addr       ( spike_wb_addr       ),
    .spike_wb_data       ( spike_wb_data       ),
    .conv_cal_done       ( conv_cal_done       ),
    .dst_wb_en              ( dst_wb_en              ),
    .dst_wb_addr            ( dst_wb_addr            ),
    .dst_wb_mp              ( dst_wb_mp              ),
    .base_addr_from_spike_sim (base_addr_from_spike_sim),
    .layer_type              ( layer_type              ),
    .send2PC_data            ( send2PC_data            ),
    .send_triger             ( send_triger             )
);
generate
    if(CIFAR_100_ENABLE == 1)begin
        FC_CORE_CIFAR100 U_FC_CORE(
            .clk                ( clk                ),
            .rst_n              ( rst_n              ),
            .time_step          ( time_step          ),
            .did_time_step      ( did_time_step      ),
            .i_feature_map_len  ( i_feature_map_len  ),
            .fc_cal_enable      ( fc_cal_enable      ),
            .fc_rd_en           ( fc_rd_en           ),
            .fc_rd_addr         ( fc_rd_addr         ),
            .fc_rd_spike        ( fc_rd_spike        ),
            .fc_cal_finish      ( fc_cal_finish      ),
            .fc_cal_res         ( fc_cal_res         ),
            .base_addr_from_spike_sim (base_addr_from_spike_sim)
        );
    end
    else begin
        FC_CORE U_FC_CORE(
            .clk                ( clk                ),
            .rst_n              ( rst_n              ),
            // .time_step          ( time_step          ),
            .did_time_step      ( did_time_step      ),
            .i_feature_map_len  ( i_feature_map_len  ),
            .fc_cal_enable      ( fc_cal_enable      ),
            .fc_rd_en           ( fc_rd_en           ),
            .fc_rd_addr         ( fc_rd_addr         ),
            .fc_rd_spike        ( fc_rd_spike        ),
            .fc_cal_finish      ( fc_cal_finish      ),
            .fc_cal_res         ( fc_cal_res         ),
            .base_addr_from_spike_sim (base_addr_from_spike_sim)
        );
    end
endgenerate

//just for sim
// reg o_ready_from_mp_process_ff1;
// always@(posedge clk)begin
//     o_ready_from_mp_process_ff1 <= o_ready_from_mp_process;
// end

// assign enable = ~o_ready_from_mp_process_ff1 & o_ready_from_mp_process & ~o_vld_from_weight_top & can_receive_weight_top & event_check_finish & ~wpe_busy;


reg [2:0] enable_state;
reg event_check_finish_ff1;
wire event_check_finish_pos = event_check_finish & ~event_check_finish_ff1;

always@(posedge clk)begin
    event_check_finish_ff1 <= event_check_finish;
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        enable_state <= 0;
        enable <= 0;
    end
    else begin
        enable <= 0;
        case(enable_state)
            0:begin
                if(event_check_finish_pos == 1)begin
                    enable_state <= 1;
                end
            end
            1:begin
                if(o_ready_from_mp_process && ~o_vld_from_weight_top && can_receive_weight_top && ~wpe_busy)begin
                    enable_state <= 0;
                    enable <= 1;
                end
            end
            default: enable_state <= enable_state;
        endcase
    end
end 

endmodule