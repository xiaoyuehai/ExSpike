// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : spike_sim.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Spike simulation and input map handling.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`include "defines.vh"
module SPIKE_SIM#( 
    parameter TIME_STEP = 4,
    parameter SEG_NET_EN = 0
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  restart,
    input wire  [ 7:0]          did_time_step ,
    input wire                  pooling_calculation_en,
    input wire  [ 7:0]          i_size                ,
    input wire  [ 7:0]          o_size,        
    input wire  [15:0]          rd_spike_addr   ,
    input wire                  rd_spike_en     ,
    output wire  [1023:0]        rd_spike        , // all in_channel

    input  wire                 spike_wb_en     ,
    input  wire [15:0]          spike_wb_addr   ,
    input  wire [1023:0]        spike_wb_data   ,

    //fc calculation
    input  wire                 fc_rd_en        ,
    input  wire [15:0]          fc_rd_addr      ,
    output wire [1023:0]        fc_rd_spike     ,
    output wire                 pooling_cal_done,

    //uart config
    input  wire	[1023:0]	    uart_combine_data,
	input  wire				    uart_combine_data_valid,
	input  wire	[15:0]		    uart_combine_w_addr,

    output reg  [7:0]           max_vld_row_sel,
    output reg  [7:0]           max_vld_col_sel,

    input wire  [5:0]           short_cut_group,
    input wire                  pre_rd_spike_en,
    output wire [15:0]          base_addr_from_spike_sim
);

    // reg [1023:0]    spike_mem [0:1023]          ;
    // reg [1023:0]    spike_mem_t1 [0:1023]       ;
    // next layer is pooling
    reg             pooling_busy            ;
    reg  [1:0]      pooling_window_cnt      ;
    reg             update_row_col          ;
    reg  [7:0]      row, col                ;
    reg  [7:0]      src_row, src_col        ;
    wire [7:0]      double_row, double_col  ;
    reg             generate_raddr_en       ;
    reg  [15:0]     generate_raddr          ;
    reg             pooling_rd_en           ;
    reg             pooling_start           ;
    reg  [1:0]      p_cnt                   ;
    reg  [1023:0]   pooling_buffer          ;
    reg             pooling_wb_en           ;
    reg  [15:0]     pooling_wb_addr         ;
    wire            q_flag                  ;
    wire            v_flag                  ;
    wire            conv_src_spike;
    wire            spike_wb_basic;
    wire            spike_wb_residual;
    wire            and_spike_enable;
    // wire            process_t0;
    // wire            process_t1;
    // wire            process_t2;
    // wire            process_t3;
    assign q_flag               = short_cut_group[5];
    assign v_flag               = short_cut_group[4];
    assign conv_src_spike       = short_cut_group[3];
    assign spike_wb_basic       = short_cut_group[2];
    assign spike_wb_residual    = short_cut_group[1];
    assign and_spike_enable     = short_cut_group[0];

    assign fc_rd_spike = rd_spike;
    // assign process_t0 = did_time_step == 0;
    // assign process_t1 = did_time_step == 1;
    // assign process_t2 = did_time_step == 2;
    // assign process_t3 = did_time_step == 3;

    reg [15:0] base_addr;
    assign base_addr_from_spike_sim = base_addr;
    always@(posedge clk)begin
        case(did_time_step)
            0: base_addr <= 0;
            1: base_addr <= 1024;
            2: base_addr <= 2048;
            3: base_addr <= 3072;
            4: base_addr <= 4096;
            5: base_addr <= 5120;
            6: base_addr <= 6144;
            7: base_addr <= 7168;
            default: base_addr <= 0;
        endcase
    end 
    
    // Xilinx Block RAM
    wire rd_bram_en;
    reg [15:0] rd_bram_addr;
    wire [511:0] bram_dout_t0, bram_dout_residual;//, bram_dout_t1, bram_dout_t2, bram_dout_t3;

    always@(*)begin
        case({pre_rd_spike_en, fc_rd_en, pooling_rd_en, rd_spike_en})
            4'b0001: begin rd_bram_addr = rd_spike_addr; end
            4'b0010: begin rd_bram_addr = generate_raddr; end
            4'b0100: begin rd_bram_addr = fc_rd_addr; end
            4'b1000: begin rd_bram_addr = spike_wb_addr; end
            default:begin rd_bram_addr = rd_spike_addr; end
        endcase
    end

    // just for timing optimization
    /*reg [9:0] real_rd_bram_addr;
    reg       real_rd_bram_en;

    always@(posedge clk)begin
        real_rd_bram_en <= rd_bram_en | pre_rd_spike_en;
        if(rd_bram_en | pre_rd_spike_en)begin
            real_rd_bram_addr <= rd_bram_addr;
        end
    end*/
    // just for timing optimization
    assign rd_bram_en = rd_spike_en | pooling_rd_en | fc_rd_en;
    reg spike_wb_en_ff1;
    reg [15:0] spike_wb_addr_ff1;
    reg [511:0] real_wb_data, k_rd_out_data_ff1;
    reg [511:0] kv_cache [0:TIME_STEP-1];
    wire [511:0] kv_status;

    assign kv_status = kv_cache[did_time_step];

    always@(posedge clk)begin
        spike_wb_en_ff1 <= spike_wb_en;
        spike_wb_addr_ff1 <= spike_wb_addr;
        k_rd_out_data_ff1 <= bram_dout_t0;
        // real_wb_data <= and_spike_enable ? spike_wb_data | bram_dout_residual : spike_wb_data;
    end

    always@(posedge clk)begin
        if(and_spike_enable)begin
            real_wb_data <= spike_wb_data | bram_dout_residual; // | or and
        end
        else if(q_flag)begin
            real_wb_data <= spike_wb_data & kv_status;
        end
        else begin
            real_wb_data <= spike_wb_data;
        end
    end

    // Attention Implementation
    genvar i;
    reg v_flag_ff1;
    wire v_flag_pos = v_flag & !v_flag_ff1;
    always@(posedge clk)begin
        v_flag_ff1 <= v_flag;
    end

    generate
        for(i=0;i<TIME_STEP;i=i+1)begin
            always@(posedge clk or negedge rst_n)begin
                if(rst_n == 1'b0)begin
                    kv_cache[i] <= 512'b0;
                end
                else if(spike_wb_en_ff1 & v_flag & did_time_step == i)begin
                    kv_cache[i] <= kv_cache[i] | (k_rd_out_data_ff1 & real_wb_data);
                end
                else if(v_flag_pos)begin
                    kv_cache[i] <= 512'b0;
                end
            end
        end
    endgenerate
`ifdef VGG11_CIFAR10
    VGG11_CIFAR10_INPUT_MAP U_INPUT_MAP_T0 (
`elsif ResNet18_CIFAR10
    ResNet18_CIFAR10_INPUT_MAP U_INPUT_MAP_T0 (
`elsif ST4_CIFAR10
    ST4_CIFAR10_INPUT_MAP U_INPUT_MAP_T0 (
`elsif ST2_CIFAR100
    ST2_CIFAR100_INPUT_MAP U_INPUT_MAP_T0 (
`elsif SEG_NET
    SEG_NET_INPUT_MAP U_INPUT_MAP_T0 (
`else
    INPUT_MAP U_INPUT_MAP_T0 (
`endif
    .clka(clk),    // input wire clka
    .ena(((spike_wb_en_ff1 | pooling_wb_en) & spike_wb_basic) || uart_combine_data_valid),      // input wire ena
    .wea((spike_wb_en_ff1 | pooling_wb_en) || uart_combine_data_valid),      // input wire [0 : 0] wea
    .addra(uart_combine_data_valid ? uart_combine_w_addr : (spike_wb_en_ff1 ? spike_wb_addr_ff1: pooling_wb_addr)),  // input wire [9 : 0] addra
    .dina(uart_combine_data_valid ? uart_combine_data : (spike_wb_en_ff1 ? real_wb_data : pooling_buffer)),    // input wire [1023 : 0] dina

    .clkb(clk),    // input wire clkb
    .enb(rd_bram_en | pre_rd_spike_en),      // input wire enb
    .addrb(rd_bram_addr),  // input wire [9 : 0] addrb
    .doutb(bram_dout_t0)  // output wire [1023 : 0] doutb
    );

`ifdef VGG11_CIFAR10
    VGG11_CIFAR10_INPUT_MAP RESIDUAL_MAP (
`elsif ResNet18_CIFAR10
    ResNet18_CIFAR10_INPUT_MAP RESIDUAL_MAP (
`elsif ST4_CIFAR10
    ST4_CIFAR10_INPUT_MAP RESIDUAL_MAP (
`elsif ST2_CIFAR100
    ST2_CIFAR100_INPUT_MAP RESIDUAL_MAP (
`elsif SEG_NET
    SEG_NET_INPUT_MAP RESIDUAL_MAP (
`else
    INPUT_MAP RESIDUAL_MAP (
`endif
    // INPUT_MAP RESIDUAL_MAP (
    .clka(clk),    // input wire clka
    .ena(((spike_wb_en_ff1 | pooling_wb_en) & spike_wb_residual) || uart_combine_data_valid),      // input wire ena
    .wea((spike_wb_en_ff1 | pooling_wb_en) || uart_combine_data_valid),      // input wire [0 : 0] wea
    .addra(uart_combine_data_valid ? uart_combine_w_addr : (spike_wb_en_ff1 ? spike_wb_addr_ff1: pooling_wb_addr)),  // input wire [9 : 0] addra
    .dina(uart_combine_data_valid ? 0 : (spike_wb_en_ff1 ? real_wb_data : pooling_buffer)),    // input wire [1023 : 0] dina

    .clkb(clk),    // input wire clkb
    .enb(pre_rd_spike_en | rd_spike_en),      // input wire enb
    .addrb(rd_bram_addr),  // input wire [9 : 0] addrb
    .doutb(bram_dout_residual)  // output wire [1023 : 0] doutb
    );

    assign rd_spike = conv_src_spike == 0 ? bram_dout_t0 : bram_dout_residual;

    wire [7:0] u_w_t;
    generate
        if(SEG_NET_EN == 0)begin
            assign u_w_t[0] = uart_combine_w_addr < 1024 && uart_combine_w_addr >= 0;
            assign u_w_t[1] = uart_combine_w_addr < 2048 && uart_combine_w_addr >= 1024;
            assign u_w_t[2] = uart_combine_w_addr < 3072 && uart_combine_w_addr >= 2048;
            assign u_w_t[3] = uart_combine_w_addr < 4096 && uart_combine_w_addr >= 3072;
            assign u_w_t[4] = uart_combine_w_addr < 5120 && uart_combine_w_addr >= 4096;
            assign u_w_t[5] = uart_combine_w_addr < 6144 && uart_combine_w_addr >= 5120;
            assign u_w_t[6] = uart_combine_w_addr < 7168 && uart_combine_w_addr >= 6144;
            assign u_w_t[7] = uart_combine_w_addr < 8192 && uart_combine_w_addr >= 7168;
        end
        else begin
            assign u_w_t[0] = uart_combine_w_addr < 4096 && uart_combine_w_addr >= 0;
            assign u_w_t[1] = 0;
            assign u_w_t[2] = 0;
            assign u_w_t[3] = 0;
            assign u_w_t[4] = 0;
            assign u_w_t[5] = 0;
            assign u_w_t[6] = 0;
            assign u_w_t[7] = 0;
        end
    endgenerate
    

    wire [7:0] max_vld_row [0:TIME_STEP-1];
    wire [7:0] max_vld_col [0:TIME_STEP-1];
    generate
        // genvar i;
        for(i=0;i<TIME_STEP;i=i+1)
            GENERATE_VLF_FINAL#(
                .MAX(i==0?28:30),
                .SEG_NET_EN(SEG_NET_EN)
            ) u_GENERATE_VLF_FINAL(
                .clk          ( clk          ),
                .rst_n        ( rst_n        ),
                .restart      ( restart      ),
                .spike_wb_basic (spike_wb_basic || uart_combine_data_valid),
                .spike_wb_residual (spike_wb_residual || uart_combine_data_valid),
                .conv_src_spike (conv_src_spike),
                .o_size       ( uart_combine_data_valid ? (SEG_NET_EN == 0 ? 8'd32 : 8'd64) : o_size       ),
                .spike_w_vld  ( ((spike_wb_en_ff1 | pooling_wb_en) && did_time_step == i) | (uart_combine_data_valid && u_w_t[i]) ),
                .spike        ( uart_combine_data_valid ? uart_combine_data : (spike_wb_en_ff1 ? real_wb_data : pooling_buffer) ),
                .max_vld_row  ( max_vld_row[i]  ),
                .max_vld_col  ( max_vld_col[i]  )
            );
    endgenerate

    always@(*)begin
        case(did_time_step)
            0: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[0], max_vld_col[0]};
            1: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[1], max_vld_col[1]};
            2: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[2], max_vld_col[2]};
            3: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[3], max_vld_col[3]};
            4: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[4], max_vld_col[4]};
            5: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[5], max_vld_col[5]};
            6: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[6], max_vld_col[6]};
            7: {max_vld_row_sel, max_vld_col_sel} = {max_vld_row[7], max_vld_col[7]};
            default:{max_vld_row_sel, max_vld_col_sel} = {max_vld_row[0], max_vld_col[0]};
        endcase
    end 

    //

    // initial begin
    //     // $readmemb("C:/Full_Event_Computing/input_map.txt",spike_mem);
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_code_map.txt",spike_mem);
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_code_map.txt",spike_mem_t1);
    //     // $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_map.txt",spike_mem);
    //     // $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_map_fc_layer.txt",spike_mem);
    //     // $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_map_pooling_layer.txt", spike_mem);
    //     // $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/Config_files/input_map_layer_6.txt", spike_mem);
    // end

    // always@(posedge clk)begin
    //     if(rd_spike_en)begin
    //         rd_spike <= process_t0 ? spike_mem[rd_spike_addr] : spike_mem_t1[rd_spike_addr];
    //     end
    //     else if(pooling_rd_en)begin
    //         rd_spike <= process_t0 ? spike_mem[generate_raddr] : spike_mem_t1[generate_raddr];
    //     end
    //     else if(fc_rd_en)begin
    //         rd_spike <= process_t0 ? spike_mem[fc_rd_addr] : spike_mem_t1[fc_rd_addr];
    //     end
    // end

    // always@(posedge clk)begin
    //     if(spike_wb_en & process_t0)begin
    //         spike_mem[spike_wb_addr] <= spike_wb_data;
    //     end
    //     else if(pooling_wb_en & process_t0)begin
    //         spike_mem[pooling_wb_addr] <= pooling_buffer;
    //     end
    // end

    // always@(posedge clk)begin
    //     if(spike_wb_en & process_t1)begin
    //         spike_mem_t1[spike_wb_addr] <= spike_wb_data;
    //     end
    //     else if(pooling_wb_en & process_t1)begin
    //         spike_mem_t1[pooling_wb_addr] <= pooling_buffer;
    //     end
    // end

    // trace
     integer trace_ref;
     reg [511:0] trace_data;
     reg     debug_wb_err;
     wire [511:0] compare_data = spike_wb_en_ff1 ? real_wb_data[511:0] : pooling_buffer[511:0]; //spike_wb_data

     initial begin
            trace_ref = $fopen("simdata/trace_spike_1.txt", "r");
     end

     always @(posedge clk)
     begin 
         #1;
         if(spike_wb_en_ff1 || pooling_wb_en)
         begin
             $fscanf(trace_ref, "%h", trace_data);
         end
     end

     always @(posedge clk)
     begin
         #2;
         if(!rst_n)
         begin
             debug_wb_err <= 1'b0;
         end
         else if(spike_wb_en_ff1 || pooling_wb_en)
         begin
             if(compare_data[511:0] != trace_data)  begin
                 $display("--------------------------ERROR----------------------------");
                 $finish;
             end 
         end
     end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pooling_busy <= 0;
            // pooling_cal_done <= 0;
        end
        else if(pooling_window_cnt == 3 && row == o_size - 1 && col == o_size - 1)begin
            pooling_busy <= 0;
            // pooling_cal_done <= 1;
        end
        else if(pooling_calculation_en)begin
            pooling_busy <= 1;
            // pooling_cal_done <= 0;
        end
        else begin
            // pooling_cal_done <= 0;
        end
    end

    assign pooling_cal_done = pooling_wb_en & !pooling_start;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pooling_window_cnt <= 0;
        end
        else if(pooling_busy == 1'b1)begin
            pooling_window_cnt <= pooling_window_cnt + 1;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            update_row_col <= 0;
        end
        else if(pooling_window_cnt == 2)begin
            update_row_col <= 1;
        end
        else begin
            update_row_col <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            row <= 0;
        end
        else if(update_row_col)begin
            if(col == o_size - 1)begin
                row <= row == o_size - 1 ? 0 : row + 1;
            end
            else begin
                row <= row;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 0)begin
            col <= 0;
        end
        else if(update_row_col)begin
            if(col == o_size - 1)begin
                col <= 0;
            end
            else begin
                col <= col + 1;
            end
        end
    end

    assign double_row = row << 1;
    assign double_col = col << 1;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            src_row <= 0;
            src_col <= 0;
        end
        else if(pooling_busy)begin
            case(pooling_window_cnt)
                2'd0: begin
                    src_row <= double_row;
                    src_col <= double_col;
                end
                2'd1:begin
                    src_row <= double_row;
                    src_col <= double_col + 1;
                end
                2'd2:begin
                    src_row <= double_row + 1;
                    src_col <= double_col;
                end
                2'd3:begin
                    src_row <= double_row + 1;
                    src_col <= double_col + 1;
                end
                default:begin
                    src_row <= src_row;
                    src_col <= src_col;
                end
            endcase
        end     
    end

    // generate addr
    always@(posedge clk)begin
        generate_raddr_en <= pooling_busy;
    end
    // src_row * 64/32/16/8/4/2/1

    always@(posedge clk)begin
        case(i_size)
            8'd64: generate_raddr <= {2'b0, src_row, 6'b0} + src_col + base_addr;
            8'd32: generate_raddr <= {3'b0, src_row, 5'b0} + src_col + base_addr;
            8'd16: generate_raddr <= {4'b0, src_row, 4'b0} + src_col + base_addr;
            8'd8 : generate_raddr <= {5'b0, src_row, 3'b0} + src_col + base_addr;
            default: generate_raddr <= 0;
        endcase
        // generate_raddr <= src_row * i_size + src_col + base_addr;
    end

    // read spike memory
    
    always@(posedge clk)begin
        pooling_rd_en <= generate_raddr_en;
    end

    // pooling calculation
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            p_cnt <= 0;
        end
        else if(pooling_start)begin
            p_cnt <= p_cnt + 1;
        end
    end

    always@(posedge clk)begin
        pooling_start <= pooling_rd_en;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pooling_wb_en <= 0;
        end
        else if(p_cnt == 3)begin
            pooling_wb_en <= 1;
        end
        else begin
            pooling_wb_en <= 0;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pooling_buffer <= 0;
        end
        else if(pooling_calculation_en)begin
            pooling_buffer <= 0;
        end
        else if(pooling_start)begin
            if(pooling_wb_en)begin
                pooling_buffer <= rd_spike;
            end
            else begin
                pooling_buffer <= pooling_buffer | rd_spike;
            end
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            pooling_wb_addr <= 0;
        end
        else if(pooling_calculation_en)begin
            pooling_wb_addr <= base_addr;
        end
        else if(pooling_wb_en)begin
            pooling_wb_addr <= pooling_wb_addr + 1;
        end
    end

endmodule