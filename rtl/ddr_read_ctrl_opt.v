// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : ddr_read_ctrl_opt.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Optimized DDR read controller for weight streaming.
// -----------------------------------------------------------------------------

module DDR_READ_CTRL_OPT#(
    parameter parallel_metric = 64,
    parameter ddr_data_width  = 256
)
(
    input  wire         clk                      ,
    input  wire         rst_n                    ,
    input  wire         ddr_ctrl_enable          ,
    input  wire [31:0]  weight_r_loaction        ,
    output wire         weight_vld               ,
    input  wire [15:0]  i_channel                ,

    // read_weight Inference
    input  wire [19:0]  rd_weight_addr_ddr       ,
    input  wire [19:0]  rd_weight_addr_ddr_reg   ,
    input  wire         rd_weight_en_ddr         ,
    output reg  [9*8*parallel_metric-1:0] rd_weight_ddr            ,
    output reg  [15:0] base_addr_for_ddr       ,

    // DDR controller
	output wire			RD_START                 ,
	output reg	[31:0]	RD_ADRS                  ,
	output reg	[31:0]	RD_LEN                   , 
	output wire	[2 :0]	RD_SIZE                  ,

	input wire			RD_READY                 ,
	input wire			RD_FIFO_WE               ,
	input wire	[ddr_data_width-1:0]	RD_FIFO_DATA             ,
	input wire			RD_DONE                  ,
	input wire			RD_LAST         
);
    localparam BUFFER_DEPTH = (parallel_metric == 32 || parallel_metric == 16) ? 512:
                              (parallel_metric == 64) ? 256 :
                              (parallel_metric == 128) ? 128 : 512;
    localparam DUBLE_DEPTH = BUFFER_DEPTH * 2;

    reg [9*8*parallel_metric-1:0]    weight_mem_0 [0:BUFFER_DEPTH-1];
    reg [9*8*parallel_metric-1:0]    weight_mem_1 [0:BUFFER_DEPTH-1];
    reg [31:0]      INTER_LEN;
    reg             reading_busy;
    reg             ddr_in_reading;
    reg [15:0]      loop0;
    reg [15:0]      did_loop0, did_o_channel_multi;
    reg             choose;
    reg             rd_choose;
    reg             reading_busy_ff1;
    wire            reading_busy_pos;
    wire            reading_busy_neg;
    wire            buffer_idle_0;
    wire            buffer_idle_1;
    reg             buffer_vld_0;
    reg             buffer_vld_1;
    reg  [31:0]     current_location_0;
    reg  [31:0]     current_location_1;
    reg  [31:0]     base_location_0;
    reg  [31:0]     base_location_1;
    wire            buffer_idle;
    reg             w_choose;
    reg             ddr_rd_mute;
    wire            re_arrange_enable;
    reg             internal_RD_START;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            ddr_rd_mute <= 0;
        end
        else if(re_arrange_enable)begin // && ddr_in_reading
            ddr_rd_mute <= 1;
        end
        else if(reading_busy_neg)begin
            ddr_rd_mute <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_choose <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0 || re_arrange_enable)begin
            w_choose <= 0;
        end
        else if(reading_busy_neg && ~ddr_rd_mute)begin
            w_choose <= ~w_choose;
        end
    end

    assign          buffer_idle_0 = current_location_0 <= weight_r_loaction;
    assign          buffer_idle_1 = current_location_1 <= weight_r_loaction;
    assign          buffer_idle = buffer_idle_0 | buffer_idle_1;

    wire first_flag;
    reg [3:0] first_cnt;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            first_cnt <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0 || re_arrange_enable == 1'b1)begin
            first_cnt <= 0;
        end
        else if(reading_busy_neg && first_cnt != 2 && ~ddr_rd_mute)begin
            first_cnt <= first_cnt + 1;
        end
    end
    assign first_flag = first_cnt < 2;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            base_location_0 <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0)begin
            base_location_0 <= 0;
        end
        else if(re_arrange_enable == 1'b1)begin
            base_location_0 <= weight_r_loaction;
        end
        else if(reading_busy_neg && w_choose == 1'b0 && ~ddr_rd_mute)begin
            base_location_0 <= first_flag ? base_location_0 : base_location_0 + DUBLE_DEPTH;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            base_location_1 <= BUFFER_DEPTH;
        end
        else if(ddr_ctrl_enable == 1'b0)begin
            base_location_1 <= BUFFER_DEPTH;
        end
        else if(re_arrange_enable == 1'b1)begin
            base_location_1 <= weight_r_loaction + BUFFER_DEPTH;
        end
        else if(reading_busy_neg && w_choose == 1'b1 && ~ddr_rd_mute)begin
            base_location_1 <= first_flag ? base_location_1 : base_location_1 + DUBLE_DEPTH;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            current_location_0 <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0)begin
            current_location_0 <= 0;
        end
        else if(re_arrange_enable)begin
            current_location_0 <= weight_r_loaction;
        end
        else if(reading_busy_neg && w_choose == 1'b0 && ~ddr_rd_mute)begin
            current_location_0 <= first_flag ? current_location_0 + BUFFER_DEPTH : current_location_0 + DUBLE_DEPTH;
            // if(current_location_0 == 0)
            //     current_location_0 <= current_location_0 + 512;
            // else
            //     current_location_0 <= current_location_0 + 1024;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            current_location_1 <= BUFFER_DEPTH;
        end
        else if(ddr_ctrl_enable == 1'b0)begin
            current_location_1 <= BUFFER_DEPTH;
        end
        else if(re_arrange_enable)begin
            current_location_1 <= weight_r_loaction + BUFFER_DEPTH;
        end
        else if(reading_busy_neg && w_choose == 1'b1 && ~ddr_rd_mute)begin
            current_location_1 <= first_flag ? current_location_1 + BUFFER_DEPTH : current_location_1 + DUBLE_DEPTH;
            // if(current_location_1 == 512)
            //     current_location_1 <= current_location_1 + 512;
            // else
            //     current_location_1 <= current_location_1 + 1024;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buffer_vld_0 <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0 || re_arrange_enable)begin
            buffer_vld_0 <= 0;
        end
        else if(reading_busy_neg && w_choose == 1'b0 && ~ddr_rd_mute)begin
            buffer_vld_0 <= 1;
        end
        else if(buffer_idle_0)begin
            buffer_vld_0 <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buffer_vld_1 <= 0;
        end
        else if(ddr_ctrl_enable == 1'b0 || re_arrange_enable)begin
            buffer_vld_1 <= 0;
        end
        else if(reading_busy_neg && w_choose == 1'b1 && ~ddr_rd_mute)begin
            buffer_vld_1 <= 1;
        end
        else if(buffer_idle_1)begin
            buffer_vld_1 <= 0;
        end
    end

    assign weight_vld = parallel_metric == 32 || i_channel != 512 ? (buffer_vld_0 & ~buffer_idle_0) | (buffer_vld_1 & ~buffer_idle_1) : 
                        parallel_metric == 64 ? (buffer_vld_0 & ~buffer_idle_0) & (buffer_vld_1 & ~buffer_idle_1) : (buffer_vld_0 & ~buffer_idle_0) | (buffer_vld_1 & ~buffer_idle_1);

    assign RD_SIZE = ddr_data_width == 256 ? 3'b101 : 3'b100;//3'b011;//3'b010;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            reading_busy <= 0;
        end
        else if(RD_DONE && (did_loop0 == loop0 - 1 || ddr_rd_mute || ddr_ctrl_enable == 1'b0))begin
            reading_busy <= 0;
        end
        else if(re_arrange_enable && ddr_in_reading == 0)begin
            reading_busy <= 0;
        end
        else if(ddr_ctrl_enable && (buffer_vld_0 == 0 || buffer_vld_1 == 0) & ~reading_busy_neg) begin // processing_en && need_rd_ddr
            reading_busy <= 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            ddr_in_reading <= 0;
        end
        else if(RD_START)begin
            ddr_in_reading <= 1;
        end
        else if(RD_DONE)begin
            ddr_in_reading <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            internal_RD_START <= 0;
        end
        else if(reading_busy && ~ddr_in_reading & ~re_arrange_enable)begin
            internal_RD_START <= 1;
        end
        else begin
            internal_RD_START <= 0;
        end
    end

    assign RD_START = internal_RD_START && ~re_arrange_enable;

    generate
        wire [15:0] base_mul;
        if(parallel_metric == 16)begin
            assign base_mul = 144;
        end
        else if(parallel_metric == 32)begin
            assign base_mul = 288;
        end
        else if(parallel_metric == 64)begin
            assign base_mul = 576;
        end
        else if(parallel_metric == 128)begin
            assign base_mul = 1152;
        end
    endgenerate

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            RD_ADRS <= 0;
        end
        // else if(RD_DONE && ~ddr_rd_mute)begin
        //     RD_ADRS <= RD_ADRS + INTER_LEN;
        // end
        else if(re_arrange_enable)begin
            RD_ADRS <= weight_r_loaction * base_mul;
        end
        else if(ddr_ctrl_enable == 1'b0)begin
            RD_ADRS <= 0;
        end
        else if(RD_DONE && ~ddr_rd_mute)begin
            RD_ADRS <= RD_ADRS + INTER_LEN;
        end
        // else if(processing_en)begin
        //     RD_ADRS <= next_ddr_base_addr;
        // end
    end
    reg [15:0] w_cnt_aim;

    always@(posedge clk)begin
        case(parallel_metric)
            16: begin RD_LEN <= 144; INTER_LEN <= 2304; loop0 <= 32; w_cnt_aim <= 8; end
            32: begin RD_LEN <= 144; INTER_LEN <= 4608; loop0 <= 32; w_cnt_aim <= 8; end
            64: begin RD_LEN <= 144; INTER_LEN <= 4608; loop0 <= 32; w_cnt_aim <= 17; end
            128: begin RD_LEN <= 144; INTER_LEN <= 4608; loop0 <= 32; w_cnt_aim <= 35; end
            default:  begin RD_LEN <= 144; INTER_LEN <= 4608; loop0 <= 32; w_cnt_aim <= 8;end
        endcase
    end 

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            did_loop0 <= 0;
        end
        else if(RD_DONE)begin
            if(did_loop0 == loop0 - 1)begin
                did_loop0 <= 0;
            end
            else begin
                did_loop0 <= did_loop0 + 1;
            end
        end
        else if(reading_busy_pos)begin
            did_loop0 <= 0;
        end
    end

    reg [9*8*parallel_metric-1:0] buffer;
    reg [7:0]    w_cnt;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_cnt <= 0;
        end
        else if(RD_FIFO_WE)begin
            if(w_cnt == w_cnt_aim)
                w_cnt <= 0;
            else
                w_cnt <= w_cnt + 1;
        end
        else if(reading_busy_pos)begin
            w_cnt <= 0;
        end
    end
    generate
        if(ddr_data_width == 256) begin
            always@(posedge clk)begin
                if(RD_FIFO_WE) begin
                    buffer <= {RD_FIFO_DATA ,buffer[9*8*parallel_metric-1 : 256]};//{RD_FIFO_DATA ,buffer[2303 -: 2048]};
                end
            end
        end
        else if(ddr_data_width == 128) begin
            always@(posedge clk)begin
                if(RD_FIFO_WE) begin
                    buffer <= {RD_FIFO_DATA ,buffer[9*8*parallel_metric-1 : 128]};//{RD_FIFO_DATA ,buffer[2303 -: 2048]};
                end
            end
        end
    endgenerate

    reg [15:0] w_addr;
    reg        w_en;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_en <= 0;
        end
        else if(RD_FIFO_WE && w_cnt == w_cnt_aim)begin
            w_en <= 1;
        end
        else begin
            w_en <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            w_addr <= 0;
        end
        else if(reading_busy_pos)begin
            w_addr <= 0;
        end
        else if(w_en)begin
            w_addr <= w_addr + 1;
        end
    end

    assign reading_busy_neg = ~reading_busy & reading_busy_ff1;
    assign reading_busy_pos = reading_busy  & ~reading_busy_ff1;

    always@(posedge clk)begin
        reading_busy_ff1 <= reading_busy;
    end

    always@(posedge clk)begin
        if(w_en && w_choose == 0)begin
            weight_mem_0[w_addr] <= buffer;
        end
    end

    always@(posedge clk)begin
        if(w_en && w_choose == 1)begin
            weight_mem_1[w_addr] <= buffer;
        end
    end

    always@(posedge clk)begin
        if(rd_weight_en_ddr)begin
            if(rd_choose == 0)begin
                rd_weight_ddr <= weight_mem_0[rd_weight_addr_ddr_reg];//[rd_weight_addr_ddr-base_location_0];
            end
            else begin
                rd_weight_ddr <= weight_mem_1[rd_weight_addr_ddr_reg];//[rd_weight_addr_ddr-base_location_1];
            end
            // rd_weight_ddr <= rd_choose == 0 ? weight_mem_0[rd_weight_addr_ddr] : weight_mem_1[rd_weight_addr_ddr];
        end
    end
    reg [31:0] weight_r_loaction_ff1;
    always@(posedge clk)begin
        weight_r_loaction_ff1 <= weight_r_loaction;
    end

    // always@(posedge clk or negedge rst_n)begin
    //     if(rst_n == 1'b0)begin
    //         rd_choose <= 0;
    //     end
    //     else if(ddr_ctrl_enable == 0 || re_arrange_enable)begin
    //         rd_choose <= 0;
    //     end
    //     else if(weight_r_loaction_ff1 != weight_r_loaction)begin
    //         if(weight_r_loaction[8:0] == 0 || i_channel == 512)
    //             rd_choose <= ~rd_choose;
    //     end
    // end

    always@(*)begin
        if(rd_weight_addr_ddr >= base_location_0 && rd_weight_addr_ddr < current_location_0)begin
            rd_choose = 0;
        end
        else if(rd_weight_addr_ddr >= base_location_1 && rd_weight_addr_ddr < current_location_1)begin
            rd_choose = 1;
        end
        else begin
            rd_choose = 0;
        end
    end

    always@(posedge clk)begin
        if(weight_r_loaction >= base_location_0 && weight_r_loaction < current_location_0)begin
            base_addr_for_ddr <= weight_r_loaction - base_location_0;
        end
        else if(weight_r_loaction >= base_location_1 && weight_r_loaction < current_location_1)begin
            base_addr_for_ddr <= weight_r_loaction - base_location_1;
        end
    end

    // always@(*)begin
    //     if(weight_r_loaction >= base_location_0 && weight_r_loaction < current_location_0)begin
    //         rd_choose = 0;
    //     end
    //     else if(weight_r_loaction >= base_location_1 && weight_r_loaction < current_location_1)begin
    //         rd_choose = 1;
    //     end
    //     else begin
    //         rd_choose = 0;
    //     end
    // end

    reg [15:0] i_channel_ff1;
    always@(posedge clk)begin
        i_channel_ff1 <= i_channel;
    end
    wire for_multi_time_step;
    reg [31:0] ms_base_loc_0, ms_base_loc_1;

    always@(*)begin
        if(reading_busy & !w_choose & !first_flag)begin
            ms_base_loc_0 = base_location_0 + DUBLE_DEPTH;
        end
        else begin
            ms_base_loc_0 = base_location_0;
        end
    end

    always@(*)begin
        if(reading_busy & w_choose & !first_flag)begin
            ms_base_loc_1 = base_location_1 + DUBLE_DEPTH;
        end
        else begin
            ms_base_loc_1 = base_location_1;
        end
    end

    assign for_multi_time_step = (weight_r_loaction < ms_base_loc_0) && (weight_r_loaction < ms_base_loc_1);
    assign re_arrange_enable = (i_channel != i_channel_ff1 && (i_channel == 512) )  || for_multi_time_step;

endmodule


////////////////////////****

