// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : sparse_processing.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Sparse spike processing pipeline.
// -----------------------------------------------------------------------------

`include "defines.vh"
module SPARSE_PROCESSING#(
    parameter GROUP_NUMBER = `GROUP_NUMBER
)
(
    input  wire                 clk             ,
    input  wire                 rst_n           ,

    // neural network params
    input  wire [15:0]          i_size          ,
    input  wire [15:0]          i_feature_map_len       ,
    input  wire [15:0]          spec_i_feature_map_len,
    input  wire [15:0]          i_channel_mult_time,

    input  wire                 process_enable  ,
    input  wire [15:0]          base_addr_from_spike_sim       ,
    output reg  [15:0]          rd_spike_addr   ,
    output reg                  rd_spike_en     ,
    input  wire [511:0]         rd_spike        , // all in_channel

    output wire                 event_valid     ,
    input wire                  event_fetch_en  ,
    output wire [41:0]          event_info      ,
    output reg                  event_info_vld  ,

    output wire                 event_check_finish

);  
    always@(posedge clk)begin
        event_info_vld <= event_fetch_en;
    end
    //fsm
    localparam IDLE        = 6'b000001;
    localparam RD_SPIKE    = 6'b000010;
    localparam CHECK_SPIKE = 6'b000100;
    localparam FAST_FILTER = 6'b001000;
    localparam TMP_ST      = 6'b010000;
    localparam UPDATE_ROW_COL = 6'b100000;
    reg rd_spike_vld;
    reg [$clog2(GROUP_NUMBER)-1:0] buffered_addr;
    reg [$clog2(GROUP_NUMBER+1):0] check_addr;
    reg [$clog2(GROUP_NUMBER+1):0] check_addr_sub1;
    reg [3:0] rd_times;
    wire [511:0] check_spike_data;
    wire [15:0]  check_row_col;
    reg [5:0] state, next_state;

    // read spike logic
    reg [7:0] self_row, self_col;
    // reg       update_row_col;
    wire      has_spike;
    reg       spike_valid;
    wire      no_valid_spike;
    wire [8:0] absolute_addr;
    wire       absolute_addr_valid;
    wire       idle;
    reg  [15:0] r_i_channel; 
    wire       empty, full;
    reg [7:0]  o_finish_times;
    reg        new_row_col;

    reg [511:0] buffered_spike [0:GROUP_NUMBER - 1];
    reg [15: 0] buffered_rowcol [0:GROUP_NUMBER - 1];
    reg [511:0] overlap_spike;

    assign event_valid = !empty;

    // always@(posedge clk or negedge rst_n)begin
    //     if(rst_n == 1'b0)begin
    //         update_row_col <= 1'b0;
    //     end
    //     else if(next_state == UPDATE_ROW_COL)begin
    //         update_row_col <= 1'b1;
    //     end
    //     else begin
    //         update_row_col <= 1'b0;
    //     end
    // end
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            self_row <= 0;
        end
        else if(process_enable)begin
            self_row <= 0;
        end
        else if(rd_spike_vld == 1'b1)begin
            if(self_col == i_size - 1)begin
                if(self_row == i_size - 1)
                    self_row <= 0;
                else
                    self_row <= self_row + 1;
            end
            else begin
                self_row <= self_row;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            self_col <= 0;
        end
        else if(process_enable)begin
            self_col <= 0;
        end
        else if(rd_spike_vld == 1'b1)begin
            if(self_col == i_size - 1)begin
                self_col <= 0;
            end
            else begin
                self_col <= self_col + 1;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_spike_addr <= 16'b0;
        end
        else if(process_enable)begin
            rd_spike_addr <= base_addr_from_spike_sim;//0;
        end
        else if(rd_spike_en)begin
            if(rd_spike_addr == spec_i_feature_map_len - 1)
                rd_spike_addr <= base_addr_from_spike_sim;//0;
            else
                rd_spike_addr <= rd_spike_addr + 1;//self_row * self_col;
        end
    end 

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            o_finish_times <= 0;
        end
        else if(process_enable)begin
            o_finish_times <= 0;
        end
        else if(rd_spike_en && rd_spike_addr == spec_i_feature_map_len - 1)begin
            o_finish_times <= o_finish_times + 1;
        end
    end

    // always@(posedge clk)begin
    //     if(rd_spike_en)begin
    //         r_i_channel <= rd_spike_addr;
    //     end
    // end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_spike_en <= 1'b0;
        end
        else if(next_state == RD_SPIKE)begin
            rd_spike_en <= 1'b1;
        end
        else begin
            rd_spike_en <= 1'b0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@(posedge clk)begin
        rd_spike_vld <= rd_spike_en;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buffered_addr <= 0;
        end
        else if(rd_spike_vld)begin
            buffered_addr <= buffered_addr + 1;
        end
        else begin
            buffered_addr <= 0;
        end
    end

    always@(posedge clk)begin
        if(rd_spike_vld == 1'b1)begin
            buffered_spike[buffered_addr] <= rd_spike;
            buffered_rowcol[buffered_addr] <= {self_row, self_col};
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            overlap_spike <= 0;
        end
        else if(rd_spike_vld == 1'b1)begin
            overlap_spike <= buffered_addr == 0 ? rd_spike : (overlap_spike & rd_spike); 
        end
    end
    // assign check_addr_sub1 = check_addr-1;
    generate
        if(GROUP_NUMBER == 1)begin
            assign check_spike_data = (check_addr == 0) ? overlap_spike : (buffered_spike[check_addr_sub1] ^ overlap_spike);
            assign check_row_col    = (check_addr == 0) ? buffered_rowcol[0] : buffered_rowcol[check_addr_sub1];
        end
        else begin
            assign check_spike_data = check_addr == 0 ? overlap_spike : buffered_spike[check_addr_sub1] ^ overlap_spike; 
            assign check_row_col = check_addr == 0 ? 0 : buffered_rowcol[check_addr_sub1];
        end
    endgenerate

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            rd_times <= 0;
        end
        else if(rd_spike_en)begin
            if(rd_times == GROUP_NUMBER - 1)begin
                rd_times <= 0;
            end
            else begin
                rd_times <= rd_times + 1;
            end
        end
    end

    assign has_spike = |check_spike_data;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            check_addr <= 0;
            check_addr_sub1 <= 0;
        end
        else if(state == CHECK_SPIKE && ~has_spike & !full)begin
            check_addr <= check_addr + 1;
            if(check_addr != 0)begin
                check_addr_sub1 <= check_addr_sub1 + 1;
            end
        end
        else if(state == FAST_FILTER && next_state == CHECK_SPIKE)begin
            check_addr <= check_addr + 1;
            if(check_addr != 0)begin
                check_addr_sub1 <= check_addr_sub1 + 1;
            end
        end
        else if(state == UPDATE_ROW_COL)begin
            check_addr <= 0;
            check_addr_sub1 <= 0;
        end
    end

    always@(*)begin
        case(state)
            IDLE:begin
                if(process_enable == 1'b1)begin
                    next_state = RD_SPIKE;
                end
                else begin
                    next_state = IDLE;
                end
            end
            RD_SPIKE:begin
                if(rd_times == GROUP_NUMBER - 1)begin
                    next_state = TMP_ST;
                end
                else begin
                    next_state = RD_SPIKE;
                end
            end
            TMP_ST:begin
                next_state = CHECK_SPIKE;
            end
            CHECK_SPIKE:begin
                if(has_spike == 1)begin
                    next_state = FAST_FILTER;
                end
                else if(!full)begin
                    if(check_addr == GROUP_NUMBER || GROUP_NUMBER == 1)begin
                        next_state = UPDATE_ROW_COL;    
                    end
                    else begin
                        next_state = CHECK_SPIKE;
                    end
                end
                else begin
                    next_state = CHECK_SPIKE;
                end
            end
            FAST_FILTER:begin
                if(idle == 1'b1)begin
                    next_state = check_addr == GROUP_NUMBER || GROUP_NUMBER == 1 ? UPDATE_ROW_COL : CHECK_SPIKE;
                end
                else begin
                    next_state = FAST_FILTER;
                end
            end
            UPDATE_ROW_COL:begin
                if(o_finish_times == i_channel_mult_time)begin
                    next_state = IDLE;
                end
                else begin
                    next_state = RD_SPIKE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end 

    reg event_check_finish_i1;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            event_check_finish_i1 <= 0;
        end
        else if(process_enable)begin
            event_check_finish_i1 <= 0;
        end
        else if(state == UPDATE_ROW_COL && next_state == IDLE)begin
            event_check_finish_i1 <= 1;
        end
    end

    reg force_push;

    assign event_check_finish = event_check_finish_i1 & empty & !force_push;

    
    // always@(posedge clk or negedge rst_n)begin
    //     if(rst_n == 1'b0)begin
    //         force_push <= 0;
    //     end
    //     else if(state == UPDATE_ROW_COL && next_state == IDLE)begin
    //         force_push <= 1;
    //     end
    //     else if(full == 1'b0)begin
    //         force_push <= 0;
    //     end
    // end

    always@(*)begin
        if(rst_n == 1'b0)begin
            force_push <= 0;
        end
        else if(state == CHECK_SPIKE && has_spike == 0 && check_addr != 0 && full == 0)begin
            if(overlap_spike == 0)
                force_push <= 0;
            else begin
                force_push <= 1;
            end
        end
        // else if(full == 1'b0 )begin
        else begin
            force_push <= 0;
        end
    end

    always@(*)begin
        spike_valid = state == CHECK_SPIKE && next_state == FAST_FILTER;
    end
    wire spike_index_valid;
    TOP_FAST_FILTER U_TOP_FAST_FILTER(
        .clk                 ( clk                 ),
        .rst_n               ( rst_n               ),
        .neuron_spike        ( check_spike_data            ),
        .neuron_spike_valid  ( spike_valid         ),
        .generate_next_en    ( !full               ),
        .no_valid_spike      ( no_valid_spike      ),
        .absolute_addr       ( absolute_addr       ),
        .absolute_addr_valid ( absolute_addr_valid ),
        .idle                ( idle                ),
        .spike_index_valid   ( spike_index_valid   )
    );

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            new_row_col <= 0;
        end
        else if(state == CHECK_SPIKE && next_state == FAST_FILTER)begin
            new_row_col <= 1;
        end
        else if(absolute_addr_valid & !full)begin
            new_row_col <= 0;
        end
    end

    reg overlap_cal_flag;
    // reg final_event_flag;
    // always@(posedge clk)begin
    //     final_event_flag <= no_valid_spike & spike_index_valid;
    // end
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            overlap_cal_flag <= 0;
        end
        else if(GROUP_NUMBER == 1)begin
            overlap_cal_flag <= 0;
        end
        else if(next_state == FAST_FILTER)begin
            overlap_cal_flag <= (check_addr == 0);
        end 
        else if(next_state == CHECK_SPIKE)begin
            overlap_cal_flag <= 0;
        end       
    end
    reg [15:0] check_row_col_ff1;

    always@(posedge clk)begin
        check_row_col_ff1 <= check_row_col;
    end

    FIFO#(
        .width      ( 42 ), // 16 + 9 + 16
        .depth      ( 16 ),
        .depth_addr ( 4 )
    )U_FIFO(
        .clk        ( clk                            ),
        .rst_n      ( rst_n                          ),
        .push_req_n ( !(!full & (absolute_addr_valid || force_push))          ), //!((absolute_addr_valid & !full) || force_push) 
        .pop_req_n  (   !event_fetch_en         ),
        .data_in    ( force_push ? {1'b1, absolute_addr, check_row_col, {13'b0, 1'b1, 1'b1, 1'b0}} : {new_row_col,absolute_addr, check_row_col, {14'b0, !spike_index_valid,overlap_cal_flag}}    ),//r_i_channel
        .empty      ( empty      ),
        .full       ( full       ),
        .data_out   ( event_info   )
    );

endmodule