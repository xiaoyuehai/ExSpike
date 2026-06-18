// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : aim_range_generate.v
// Create : 2025-06-08 14:42:24
// Revise : 2025-06-08 14:42:24
// Editor : vscode, tab size (4)
// Description: This module is used to generate the aim range for the aim_neuron_id.
// -----------------------------------------------------------------------------

module AIM_RANGE_GENENRATE(
    input wire                  clk             ,
    input wire                  rst_n           ,

    input wire                  act_spike_valid ,
    input wire [15:0]           act_spike_index ,
    input wire [ 3:0]           layer_type      ,
    input wire                  shortcut_mode   ,
    input wire [ 1:0]           stride          ,
    input wire [ 3:0]           filter_size     ,

    output reg                  aim_neuron_vld  ,
    output reg [16*9-1:0]       aim_neuron_id   ,
    output reg                  FIFO_write

);
    wire  conv_cal_mode;
    wire  pooling_mode;

    assign conv_cal_mode = layer_type == 0 || layer_type == 3;//(layer_type == 3 && shortcut_mode);
    assign pooling_mode = layer_type == 1;

    // pipelined stage 1
    wire [7:0]  act_spike_row_index, act_spike_col_index;
    reg  [7:0]  center_row_index, center_col_index;
    // reg  [2:0]  one_hot;
    reg center_index_vld;
    reg [15:0]  act_spike_index_buffer;
    reg [15:0]  aim_index[0:8];

    assign act_spike_row_index = act_spike_index[15:8];
	assign act_spike_col_index = act_spike_index[7:0]; 

    always@(posedge clk)begin
        center_index_vld <= act_spike_valid;
    end

    always@(posedge clk)begin
        act_spike_index_buffer <= act_spike_index;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            center_row_index <= 0;
        end
        else if(act_spike_valid)begin
            if(conv_cal_mode && stride == 1)begin
                if(filter_size == 1)begin
                    center_row_index <= act_spike_row_index;
                end
                else 
                    center_row_index <= act_spike_row_index - 1;
            end
            else if((conv_cal_mode && stride == 2) || pooling_mode)begin
                // if(act_spike_row_index[0] && act_spike_col_index[0])begin
                //     center_row_index <= act_spike_row_index >> 1;
                // end
                // else if(act_spike_row_index[0] || act_spike_col_index[0])begin
                //     center_row_index <= act_spike_row_index >> 1;
                // end
                // else if(!act_spike_row_index[0] && !act_spike_col_index[0])begin
                    center_row_index <= act_spike_row_index >> 1;
                // end
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            center_col_index <= 0;
        end
        else if(act_spike_valid)begin
            if(conv_cal_mode && stride == 1)begin
                if(filter_size == 1)begin
                    center_col_index <= act_spike_col_index;
                end
                else
                    center_col_index <= act_spike_col_index - 1;
            end
            else if((conv_cal_mode && stride == 2) || pooling_mode)begin
                // if(filter_size == 1 && !act_spike_row_index[0] && !act_spike_col_index[0])begin
                //     center_col_index <= act_spike_col_index >> 1;
                // end
                // else begin
                    center_col_index <= act_spike_col_index >> 1;
                // end
                // if(act_spike_row_index[0] && act_spike_col_index[0])begin
                //     center_col_index <= act_spike_col_index >> 1;
                // end
                // else if(act_spike_row_index[0] || act_spike_col_index[0])begin
                //     center_col_index <= act_spike_col_index >> 1;
                // end
                // else if(!act_spike_row_index[0] && !act_spike_col_index[0])begin
                //     center_col_index <= act_spike_col_index >> 1;
                // end
                // else begin
                //     center_col_index <= act_spike_col_index >> 1;
                // end
            end
        end
    end

    // pipelined stage 2
    // left up;
    wire [7:0] act_spike_row_index_stage2,act_spike_col_index_stage2;
    assign act_spike_row_index_stage2 = act_spike_index_buffer[15:8];
	assign act_spike_col_index_stage2 = act_spike_index_buffer[7:0]; 

    always@(posedge clk)begin
        if(center_index_vld)begin
            if(conv_cal_mode && stride == 1)begin
                if(filter_size == 1)begin
                    aim_index[0][15:8] <= center_row_index;
                    aim_index[0][7:0] <=  center_col_index;
                end else begin
                    aim_index[0][15:8] <= center_row_index + 1;
                    aim_index[0][7:0]  <= center_col_index + 1;
                end
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[0][15:8] <= center_row_index;
                    aim_index[0][7:0] <=  center_col_index;
                end
                else begin
                    aim_index[0][15:8] <= 8'hFF;
                    aim_index[0][7:0] <=  8'hFF;
                end
            end
            else if(pooling_mode)begin
                aim_index[0][15:8] <= center_row_index;
                aim_index[0][7:0] <=  center_col_index;
            end
            else begin
            aim_index[0][15:8] <= 8'hFF;
            aim_index[0][7:0] <=  8'hFF;
        end
        end
        else begin
            aim_index[0][15:8] <= 8'hFF;
            aim_index[0][7:0] <=  8'hFF;
        end
    end

    // up 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[1][15:8] <= center_row_index + 1;
                aim_index[1][7:0] <= center_col_index;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && act_spike_col_index_stage2[0])begin
                    aim_index[1][15:8] <= center_row_index;
                    aim_index[1][7:0] <= center_col_index;
                end
                else begin
                    aim_index[1][15:8] <= 8'hFF;
                    aim_index[1][7:0] <= 8'hFF;
                end
            end
            else begin
                aim_index[1][15:8] <= 8'hFF;
                aim_index[1][7:0] <= 8'hFF;
            end
        end
        else begin
            aim_index[1][15:8] <= 8'hFF;
            aim_index[1][7:0] <= 8'hFF;
        end
    end
    //right up
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[2][15:8] <= center_row_index + 1;
                aim_index[2][7:0] <= center_col_index - 1;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[2][15:8] <= center_row_index;
                    aim_index[2][7:0] <= center_col_index - 1;
                end
                else begin
                    aim_index[2][15:8] <= 8'hFF;
                    aim_index[2][7:0] <= 8'hFF;
                end
            end
            else begin
                aim_index[2][15:8] <= 8'hFF;
                aim_index[2][7:0] <= 8'hFF;
            end
        end
        else begin
            aim_index[2][15:8] <= 8'hFF;
            aim_index[2][7:0] <= 8'hFF;
        end
    end
    //left 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[3][15:8] <= center_row_index;
                aim_index[3][7:0]  <= center_col_index + 1;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[3][15:8] <= center_row_index;
                    aim_index[3][7:0] <= center_col_index;
                end
                else begin
                    aim_index[3][15:8] <= 8'hFF;
                    aim_index[3][7:0]  <= 8'hFF;
                end
            end
            else begin
                aim_index[3][15:8] <= 8'hFF;
                aim_index[3][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[3][15:8] <= 8'hFF;
            aim_index[3][7:0]  <= 8'hFF;
        end
    end
    //center 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[4][15:8] <= center_row_index;
                aim_index[4][7:0]  <= center_col_index;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(act_spike_row_index_stage2[0] && act_spike_col_index_stage2[0])begin
                    aim_index[4][15:8] <= center_row_index;
                    aim_index[4][7:0]  <= center_col_index;
                end
                else begin
                    aim_index[4][15:8] <= 8'hFF;
                    aim_index[4][7:0]  <= 8'hFF;
                end
            end
            else begin
                    aim_index[4][15:8] <= 8'hFF;
                    aim_index[4][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[4][15:8] <= 8'hFF;
            aim_index[4][7:0]  <= 8'hFF;
        end
    end
    //right 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[5][15:8] <= center_row_index;
                aim_index[5][7:0]  <= center_col_index - 1;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[5][15:8] <= center_row_index;
                    aim_index[5][7:0]  <= center_col_index - 1;
                end
                else begin
                    aim_index[5][15:8] <= 8'hFF;
                    aim_index[5][7:0]  <= 8'hFF;
                end
            end
            else begin
                aim_index[5][15:8] <= 8'hFF;
                aim_index[5][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[5][15:8] <= 8'hFF;
            aim_index[5][7:0]  <= 8'hFF;
        end
    end
    //left bottom 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[6][15:8] <= center_row_index - 1;
                aim_index[6][7:0]  <= center_col_index + 1;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[6][15:8] <= center_row_index - 1;
                    aim_index[6][7:0]  <= center_col_index;
                end
                else begin
                    aim_index[6][15:8] <= 8'hFF;
                    aim_index[6][7:0]  <= 8'hFF;
                end
            end
            else begin
                aim_index[6][15:8] <= 8'hFF;
                aim_index[6][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[6][15:8] <= 8'hFF;
            aim_index[6][7:0]  <= 8'hFF;
        end
    end
    //bottom 
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[7][15:8] <= center_row_index - 1;
                aim_index[7][7:0]  <= center_col_index;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && act_spike_col_index_stage2[0])begin
                    aim_index[7][15:8] <= center_row_index - 1;
                    aim_index[7][7:0]  <= center_col_index;
                end
                else begin
                    aim_index[7][15:8] <= 8'hFF;
                    aim_index[7][7:0]  <= 8'hFF;
                end
            end
            else begin
                aim_index[7][15:8] <= 8'hFF;
                aim_index[7][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[7][15:8] <= 8'hFF;
            aim_index[7][7:0]  <= 8'hFF;
        end
    end
    //bottom  right
    always@(posedge clk)begin
        if(center_index_vld && filter_size != 1)begin
            if(conv_cal_mode && stride == 1)begin
                aim_index[8][15:8] <= center_row_index - 1;
                aim_index[8][7:0]  <= center_col_index - 1;
            end
            else if(conv_cal_mode && stride == 2)begin
                if(!act_spike_row_index_stage2[0] && !act_spike_col_index_stage2[0])begin
                    aim_index[8][15:8] <= center_row_index - 1;
                    aim_index[8][7:0]  <= center_col_index - 1;
                end
                else begin
                    aim_index[8][15:8] <= 8'hFF;
                    aim_index[8][7:0]  <= 8'hFF;
                end
            end
            else begin
                aim_index[8][15:8] <= 8'hFF;
                aim_index[8][7:0]  <= 8'hFF;
            end
        end
        else begin
            aim_index[8][15:8] <= 8'hFF;
            aim_index[8][7:0]  <= 8'hFF;
        end
    end

    // stage 3
    reg FIFO_check_in;
    always@(posedge clk)begin
        FIFO_check_in <= center_index_vld;
    end

    generate 
        genvar i;
        for(i=0;i<9;i=i+1)begin
            always@(posedge clk)begin
                if(FIFO_check_in)
                    aim_neuron_id[15+16*i:16*i] <= aim_index[i];
            end
        end
    endgenerate

    // assign aim_neuron_vld = FIFO_check_in;
    always@(posedge clk)begin
        aim_neuron_vld <= FIFO_check_in;
    end

    // stage 4
    //reg FIFO_write;
    always@(posedge clk)begin
        FIFO_write <= FIFO_check_in;
    end


endmodule