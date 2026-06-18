// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : weight_top.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Weight fetch and buffering top module.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`include "defines.vh"
module WEIGHT_TOP#(
    parameter parallel_metric = 32,
    parameter GROUP_NUMBER = `GROUP_NUMBER == 1 ? 2 : `GROUP_NUMBER
)(
    input wire                              clk             ,
    input wire                              rst_n           ,
    //neural params
    // input wire                              weight_vld      ,
    input wire                              processing_en   ,
    input wire  [31:0]                      layer_base_addr ,
    input wire                              conv_code_layer_en,
    input wire                              padding         ,
    input wire [ 3:0]                       layer_type      ,
    input wire                              shortcut_mode   ,
    input wire [ 1:0]                       stride          ,
    input wire [ 3:0]                       filter_size     ,
    input wire  [3:0]                       did_bit_num     ,
    input wire [15:0]                       i_channel       ,
    input wire [15:0]                       i_size          ,
    input wire [ 7:0]                       time_step       ,
    input wire [ 7:0]                       did_time_step   ,
    input wire                              conv_cal_done   ,
    input wire  [41:0]                      event_info      ,
    input wire                              event_info_vld  ,
    input wire                              event_valid     ,
    output wire                             event_fetch_en  ,

    // input wire                              one_position_finish,
    output wire                             can_receive,
    input wire                              weight_vld,
    input wire                              bias_enable,
    input wire   [7:0]                      max_vld_row_sel,
    input wire   [7:0]                      max_vld_col_sel,

    output wire [19:0]                      rd_weight_addr_ddr,
    input  wire [15:0]                      base_addr_for_ddr,
    output reg  [19:0]                      rd_weight_addr_ddr_reg,
    output wire                             rd_weight_en_ddr,
    input  wire [9*8*parallel_metric-1:0]   rd_weight_ddr   ,
    input  wire                             weight_r_loaction_init,
    output reg  [31:0]                      weight_r_loaction,
    output wire                             wpe_busy,

    //to MP process
    output wire                             o_vld_from_weight_top,
    input  wire                             o_ready_from_mp_process,
    output wire [1+144+9*16*parallel_metric-1:0]  o_data_from_weight_top
);
    // how to use can_receive and weight_vld

    reg event_fetch_en_reg, event_fetch_en_reg_ff1;
    reg system_stall;
    wire full_overlap = event_info[2] && event_info_vld;
    wire final_event = event_fetch_en_reg_ff1 ? event_info[1] : 0;
    wire one_position_finish = final_event;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            event_fetch_en_reg <= 0;
        end
        else if(event_info_vld && (full_overlap || final_event))begin
            event_fetch_en_reg <= 0;
        end
        else if(event_valid == 1'b1 && system_stall == 1'b0)begin
            if(conv_code_layer_en)
                event_fetch_en_reg <= 1;
            else begin
                event_fetch_en_reg <= weight_vld;
            end
        end
        else begin
            event_fetch_en_reg <= 0;
        end
    end

    always@(posedge clk)begin
        if(final_event == 1)
            event_fetch_en_reg_ff1 <= 0;
        else
            event_fetch_en_reg_ff1 <= event_fetch_en_reg;
    end

    assign event_fetch_en = event_fetch_en_reg & ~final_event & event_valid & !system_stall;

    wire                                new_row_col;
    reg [31:0]                          base_w_addr;
    reg                                 mp_base_addr_change_flag;
    wire [8:0]                          processing_i_channel;
    wire [7:0]                          self_row;
    wire [7:0]                          self_col;
    reg  [7:0]                          self_row_ff1;
    reg  [7:0]                          self_col_ff1;   
    wire [9*8*parallel_metric-1:0]      rd_weight;
    reg                                 rd_weight_en;
    reg  [9*16*parallel_metric-1:0]     rd_code_weight;
    wire                                i_ready;
    reg                                 aim_neuron_done;
    reg                                 one_position_finish_ff1, one_position_finish_ff2;
    reg                                 w_acc_finish;
    reg [31:0]                          rd_weight_addr;
    reg [15:0]                          act_spike_index;
    reg                                 act_spike_valid;
    wire                                FIFO_write;
    wire                                aim_neuron_vld  ;
    wire [16*9-1:0]                     aim_neuron_id  ;
    reg                                 can_receive_ff1;
    wire                                can_receive_pos;
    reg                                 vld_flag;
    wire                                overlap_cal_flag;
    reg [3:0]                           can_receive_pos_cnt;
    
    wire                                overlap_clear_w /* synthesis syn_keep=1 */;
    // always@(posedge clk)begin
    //     if(rst_n == 1'b0)begin
    //         overlap_clear_w <= 0;
    //     end
    //     else if(can_receive_pos & vld_flag & (can_receive_pos_cnt == GROUP_NUMBER - 1))begin
    //         overlap_clear_w <= 1;
    //     end
    //     else begin
    //         overlap_clear_w <= 0;
    //     end
    // end
    assign overlap_clear_w = can_receive_pos & vld_flag & (can_receive_pos_cnt == GROUP_NUMBER - 1);
    assign wpe_busy             = vld_flag;
    assign new_row_col          = event_info[41];
    assign processing_i_channel = event_info[40:32];
    assign self_row             = event_info[31:24];
    assign self_col             = event_info[23:16];
    assign overlap_cal_flag     = event_info[0];

    reg overlap_cal_flag_reg;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            overlap_cal_flag_reg <= 0;
        end
        else if(event_info_vld && new_row_col)begin
            overlap_cal_flag_reg <= overlap_cal_flag;
        end
    end
    reg need_clr_overlap;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            need_clr_overlap <= 0;
        end
        else if(overlap_clear_w)begin
            need_clr_overlap <= 0;
        end
        else if(event_info_vld && new_row_col & overlap_cal_flag)begin
            need_clr_overlap <= 1;
        end
    end

    //read weight
    // reg [2303:0] weight_mem [0:8192];

    // Xilinx Block RAM Generation
    generate
        if(parallel_metric == 16 || parallel_metric == 32)begin
            wire [9*16*parallel_metric-1:0] coder_weight_mem_dout;
            `ifdef VGG11_CIFAR10
                VGG11_CIFAR10_CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `elsif ResNet18_CIFAR10
                ResNet18_CIFAR10_CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `elsif ST4_CIFAR10
                ST4_CIFAR10_CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `elsif ST2_CIFAR100
                ST2_CIFAR100_CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `elsif SEG_NET
                SEG_NET_CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `else
                CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                    .clka(clk),    // input wire clka
                    .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                    .addra(rd_weight_addr),  // input wire [5 : 0] addra
                    .douta(coder_weight_mem_dout)  // output wire [4607 : 0] douta
                );
            `endif
            always@(*)begin
                rd_code_weight = coder_weight_mem_dout;
            end
        end
        else if(parallel_metric == 64)begin
            // wire [9*16*parallel_metric-1:0] coder_weight_mem_dout;
            wire [9*16*32-1:0] w0,w1;
            CODE_WEIGHT_1_MEM U_CODER_WEIGHT_MEM_1 (
                .clka(clk),    // input wire clka
                .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                .addra(rd_weight_addr),  // input wire [5 : 0] addra
                .douta(w1)  // output wire [4607 : 0] douta
            );
            CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                .clka(clk),    // input wire clka
                .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                .addra(rd_weight_addr),  // input wire [5 : 0] addra
                .douta(w0)  // output wire [4607 : 0] douta
            );
            always@(*)begin
                rd_code_weight = {w1,w0};
            end
        end
        else if(parallel_metric == 128) begin
            wire [9*16*32-1:0] w0,w1;
            CODE_WEIGHT_1_MEM U_CODER_WEIGHT_MEM_1 (
                .clka(clk),    // input wire clka
                .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                .addra(rd_weight_addr),  // input wire [5 : 0] addra
                .douta(w1)  // output wire [4607 : 0] douta
            );
            CODER_WEIGHT_MEM U_CODER_WEIGHT_MEM (
                .clka(clk),    // input wire clka
                .ena(rd_weight_en & conv_code_layer_en),      // input wire ena
                .addra(rd_weight_addr),  // input wire [5 : 0] addra
                .douta(w0)  // output wire [4607 : 0] douta
            );
            always@(*)begin
                rd_code_weight = {9216'b0,w1,w0};
            end
        end
    endgenerate

    // reg [4607:0] code_weight_mem [0:47];
    // initial begin
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_weight_conv_layer.txt", code_weight_mem);
    //     // $readmemh("c:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_weight_layer_7.txt",weight_mem);
    // end
    
    // always@(posedge clk)begin
    //     if(rd_weight_en & conv_code_layer_en)begin
    //         rd_code_weight <= code_weight_mem[rd_weight_addr];
    //     end
    // end
    //MEM AREA//

    //weight address generate
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            self_row_ff1 <= 0;
            self_col_ff1 <= 0;
        end
        else if(processing_en)begin
            self_row_ff1 <= 0;
            self_col_ff1 <= 0;
        end
        else if(event_info_vld)begin
            self_row_ff1 <= self_row;
            self_col_ff1 <= self_col;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            base_w_addr <= 0;
        end
        else if(processing_en)begin
            base_w_addr <= layer_base_addr;
        end
        // else if(next_multiplex)begin
        else if(can_receive_pos && self_row_ff1 == max_vld_row_sel && self_col_ff1 == max_vld_col_sel)begin
            base_w_addr <= base_w_addr + i_channel;
        end
    end

    // reg w_acc_finish_ff1;
    wire w_acc_finish_pos;
    assign w_acc_finish_pos = one_position_finish_ff1 & !one_position_finish_ff2;
    // always@(posedge clk)begin
    //     w_acc_finish_ff1 <= w_acc_finish;
    // end
    reg [31:0] weight_r_loaction_layer_base;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            weight_r_loaction <= 0;
        end
        else if(weight_r_loaction_init == 1'b1)begin
            weight_r_loaction <= 0;
        end
        else if(conv_cal_done == 1'b1 && did_time_step != time_step - 1)begin
            weight_r_loaction <= weight_r_loaction_layer_base;
        end
        // else if(~conv_code_layer_en && next_multiplex)begin
        else if(~conv_code_layer_en && w_acc_finish_pos && self_row_ff1 == max_vld_row_sel && self_col_ff1 == max_vld_col_sel)begin
            weight_r_loaction <= weight_r_loaction + i_channel;
        end
    end

    always@(posedge clk)begin
        if(processing_en && did_time_step == 0)begin
            weight_r_loaction_layer_base <= weight_r_loaction;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            mp_base_addr_change_flag <= 0;
        end
        // else if(next_multiplex)begin
        else if(can_receive_pos && self_row_ff1 == max_vld_row_sel && self_col_ff1 == max_vld_col_sel)begin
            mp_base_addr_change_flag <= 1;
        end
        else if(can_receive_pos || processing_en)begin
            mp_base_addr_change_flag <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_weight_addr <= 0;
        end
        else if(event_info_vld)begin
            if(conv_code_layer_en)
                rd_weight_addr <= base_w_addr + processing_i_channel;
            // rd_weight_addr <= base_w_addr + processing_i_channel;
            else begin
                rd_weight_addr <= weight_r_loaction + processing_i_channel;
                rd_weight_addr_ddr_reg <= base_addr_for_ddr +processing_i_channel;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            act_spike_index <= 0;
            act_spike_valid <= 0;
        end
        else if(event_info_vld & new_row_col & overlap_cal_flag == 0)begin
            // act_spike_index[15:8] <= padding ? self_row + 1 : self_row;
            // act_spike_index[7:0]  <= padding ? self_col + 1 : self_col;
            // act_spike_valid <= 1'b1;
            if(layer_type == 0) begin
                act_spike_index[15:8] <= padding ? self_row + 1 : self_row;
                act_spike_index[7:0]  <= padding ? self_col + 1 : self_col;
            	act_spike_valid <= 1'b1;
            end
            else if(layer_type == 3)begin
                act_spike_index[15:8] <= padding ? {self_row[6:0], 1'b0} + 1 : {self_row[6:0], 1'b0};
                act_spike_index[7:0]  <= padding ? {self_col[6:0], 1'b0} + 1 : {self_col[6:0], 1'b0};
		        act_spike_valid <= 1'b1;
            end
        end
        else begin
            act_spike_valid <= 0;
        end
    end

    AIM_RANGE_GENENRATE U_AIM_RANGE_GENENRATE(
        .clk              ( clk              ),
        .rst_n            ( rst_n            ),
        .act_spike_valid  ( act_spike_valid  ),
        .act_spike_index  ( act_spike_index  ),
        .layer_type       ( layer_type       ),
        .shortcut_mode    ( shortcut_mode    ),
        .stride           ( stride           ),
        .filter_size      ( filter_size      ),
        .aim_neuron_vld   ( aim_neuron_vld   ),
        .aim_neuron_id    ( aim_neuron_id    )//,
        //.FIFO_write       ( FIFO_write       )
    );

    // weight get
    reg overlap_cal_flag_ff1, overlap_cal_flag_ff2;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_weight_en <= 1'b0;
        end
        else begin
            rd_weight_en <= event_info_vld && full_overlap == 0;
        end
    end

    always@(posedge clk)begin
        overlap_cal_flag_ff1 <= overlap_cal_flag;
        overlap_cal_flag_ff2 <= overlap_cal_flag_ff1;
    end

    //weight accumulation
    reg w_accumulation_en;
    wire [143:0] weight_acc_res [0:parallel_metric-1];
    wire [9*16*parallel_metric-1:0] flat_data;

    always@(posedge clk)begin
        w_accumulation_en <= rd_weight_en;
    end

    genvar o_channle_parallel, inter_parallel;


    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            can_receive_pos_cnt <= 0;
        end
        else if(can_receive_pos && vld_flag && need_clr_overlap)begin
            if(can_receive_pos_cnt == GROUP_NUMBER - 1)
                can_receive_pos_cnt <= 0;
            else 
                can_receive_pos_cnt <= can_receive_pos_cnt + 1; 
        end
    end
    
    generate
        for(o_channle_parallel=0;o_channle_parallel<parallel_metric;o_channle_parallel=o_channle_parallel+1)begin
            for(inter_parallel = 0; inter_parallel < 9; inter_parallel = inter_parallel + 1)begin
                WEIGHT_ACC U_WEIGHT_ACC(
                    .clk                 ( clk                 ),
                    .rst_n               ( rst_n               ),
                    .synapse_weight      ( conv_code_layer_en ? rd_code_weight[(o_channle_parallel*144+inter_parallel*16) +: 16] : {{8{rd_weight[(o_channle_parallel*72+inter_parallel*8) + 7]}}, rd_weight[(o_channle_parallel*72+inter_parallel*8) +: 8]}      ),
                    .w_accumulation_en   ( w_accumulation_en   ),
                    .overlap_cal_en      ( overlap_cal_flag_ff2 ),
                    .overlap_clear       ( overlap_clear_w ),
                    .new_row_col         ( new_row_col         ),//can_receive_pos
                    .event_valid         ( event_info_vld         ),
                    .conv_code_layer_en  ( conv_code_layer_en  ),
                    .did_bit_num         ( did_bit_num         ),
                    .weight_acc_res      ( weight_acc_res[o_channle_parallel][inter_parallel*16 +: 16]   )
                );
            end
            assign flat_data[144 * o_channle_parallel +: 144] = weight_acc_res[o_channle_parallel];
        end
    endgenerate

    ELASTIC_FIFO#(
        .DATA_WIDTH ( 1+144+9*16*parallel_metric )
    )u_ELASTIC_FIFO(
        .clk      ( clk      ),
        .rst_n    ( rst_n    ),
        .i_ready  ( i_ready  ),
        .i_vld    ( can_receive_pos & vld_flag),//can_receive_pos
        .i_data   ( {mp_base_addr_change_flag, aim_neuron_id, flat_data}   ),
        .o_vld    ( o_vld_from_weight_top    ),
        .o_ready  ( o_ready_from_mp_process  ),
        .o_data   ( o_data_from_weight_top   )
    );

    // integer file_wr;
    // reg [4753:0] trace_data;
    // reg     debug_wb_err;
    // initial begin
    //     file_wr = $fopen("C:/Full_Event_Computing/RTL/tb/EFIFO_trace.txt", "r");
    // end

    // always @(posedge clk)
    // begin 
    //     #1;
    //     if(can_receive_pos & vld_flag & i_ready)
    //     begin
    //         $fscanf(file_wr, "%h", trace_data);
    //     end
    // end
    // integer i;
    // always @(posedge clk)
    // begin
    //     #2;
    //     if(!rst_n)
    //     begin
    //         debug_wb_err <= 1'b0;
    //     end
    //     else if(can_receive_pos & vld_flag & i_ready)
    //     begin
    //         if({mp_base_addr_change_flag, final_id, flat_data} !== trace_data)  begin
    //             $display("--------------------------ERROR----------------------------");
    //             $finish;
    //         end 
    //     end
    // end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            one_position_finish_ff1 <= 0;
            one_position_finish_ff2 <= 0;
        end
        else begin
            one_position_finish_ff1 <= one_position_finish;
            one_position_finish_ff2 <= one_position_finish_ff1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_acc_finish <= 1;
        end
        else if(event_info_vld && new_row_col && full_overlap == 0)begin
            w_acc_finish <= 0;
        end
        else if(one_position_finish_ff2)begin
            w_acc_finish <= 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            vld_flag <= 0;
        end
        else if(event_info_vld && new_row_col && overlap_cal_flag == 0)begin
            vld_flag <= 1;
        end
        else if(can_receive_pos)begin
            vld_flag <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            aim_neuron_done <= 1;
        end
        else if(event_info_vld && new_row_col && overlap_cal_flag == 0)begin
            aim_neuron_done <= 0;
        end
        else if(aim_neuron_vld)begin
            aim_neuron_done <= 1;
        end
    end

    assign can_receive = i_ready & aim_neuron_done & w_acc_finish;

    always@(posedge clk)begin
        can_receive_ff1 <= can_receive;
    end
    
    assign can_receive_pos = (can_receive & !can_receive_ff1) & overlap_cal_flag_reg == 0 & vld_flag; 

    assign rd_weight = rd_weight_ddr;
    assign rd_weight_addr_ddr = rd_weight_addr;
    assign rd_weight_en_ddr = rd_weight_en & ~conv_code_layer_en;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 0)begin
            system_stall <= 0;
        end
        else if(conv_code_layer_en == 1)begin
            if(final_event == 1)begin
                if(full_overlap == 1)begin
                    system_stall <= 1;
                end
                else if((i_ready && aim_neuron_done && w_acc_finish) && new_row_col == 0)begin
                    system_stall <= 0;
                end
                else begin
                    system_stall <= 1;
                end
            end
            else if(i_ready && aim_neuron_done && w_acc_finish)begin
                system_stall <= 0;
            end
        end
        else if(conv_code_layer_en == 0)begin
            if(weight_vld == 0)begin
                system_stall <= 0;
            end
            else if(final_event == 1)begin
                if(full_overlap == 1)begin
                    system_stall <= 1;
                end
                else if(i_ready && aim_neuron_done && w_acc_finish && new_row_col == 0)begin
                    system_stall <= 0;
                end
                else begin
                    system_stall <= 1;
                end
            end
            else if(i_ready && aim_neuron_done && w_acc_finish)begin
                system_stall <= 0;
            end
        end
    end

    // summary
    reg [63:0] rd_weight_cnt, buffer_cnt, calculaiton_cnt;
    always@(posedge clk)begin
        if(rst_n == 1'b0)begin
            rd_weight_cnt <= 0;
            buffer_cnt <= 0;
        end
        else if(weight_vld == 0 && conv_code_layer_en == 0)begin
            rd_weight_cnt <= rd_weight_cnt + 1;
        end
        else if(system_stall == 1)begin
            buffer_cnt <= buffer_cnt + 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            calculaiton_cnt <= 0;
        end
        else if(w_accumulation_en == 1)begin
            calculaiton_cnt <= calculaiton_cnt + 1;
        end
    end


endmodule