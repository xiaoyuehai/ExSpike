// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : read_membrane_p.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Read membrane potential from on-chip memory.
// -----------------------------------------------------------------------------

module READ_MEMBRANE_P#(
    parameter parallel_metric = 32
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  processing_en,
    input wire [7:0]            time_step,
    input wire [7:0]            did_time_step,
    input wire [7:0]            o_size,
    input wire [15:0]           i_feature_map_len,
    input wire [15:0]           o_feature_map_len,
    input wire                  o_vld_from_weight_top,
    input wire [1+144+9*16*parallel_metric-1:0]         o_data_from_weight_top,
    output reg                  o_ready_from_mp_process,

    //bias cal
    output reg [16*parallel_metric-1:0]          rd_mp_to_bias           ,
    input  wire                 rd_mp_en_from_bias        ,
    input  wire [15:0]          rd_mp_addr_from_bias      ,

    // for multiple time step
    input wire                  dst_wb_en      ,
    input wire  [15:0]          dst_wb_addr    ,
    input wire [16*parallel_metric-1:0]          dst_wb_mp       
);

    wire                    mp_rw_finish;
    reg [16*9-1:0]          aim_neuron_id_buffer;
    reg [16*parallel_metric-1:0]             weight_sum_buffer [0:8];
    reg                     read_mp_enable;
    reg [3:0]               cnt;
    wire [7:0]              get_row, get_col;
    reg [15:0]              rd_mp_addr;
    reg                     rd_mp_en;
    reg [7:0] buffer_timestep_sub;
    reg [7:0] did_time_step_ff1;

    always@(posedge clk)begin
        buffer_timestep_sub <= time_step - 1;
    end

    always@(posedge clk)begin
        did_time_step_ff1 <= did_time_step;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            o_ready_from_mp_process <= 1'b1;
        end
        else if(mp_rw_finish)begin
            o_ready_from_mp_process <= 1'b1;
        end
        else if(o_vld_from_weight_top && o_ready_from_mp_process)begin
            o_ready_from_mp_process <= 1'b0;
        end
    end

    // flag buffer
    always@(posedge clk)begin
        if(o_vld_from_weight_top && o_ready_from_mp_process)begin
            aim_neuron_id_buffer <= o_data_from_weight_top[1+144+9*16*parallel_metric-2 : 9*16*parallel_metric];
        end
        else if(read_mp_enable)begin
            aim_neuron_id_buffer <= {16'b0, aim_neuron_id_buffer[143:16]};
        end
    end
    genvar i,j;
    generate
        for(i=0;i<9;i=i+1)begin
            for(j=0;j<parallel_metric;j=j+1)begin
                always@(posedge clk)begin
                    if(o_vld_from_weight_top && o_ready_from_mp_process)begin
                        weight_sum_buffer[i][16*j +: 16] <= o_data_from_weight_top[j*144+i*16 +: 16];//[4607:0];
                    end
                end
            end
        end
    endgenerate

    wire mp_r_finish = (cnt == 8);
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            read_mp_enable <= 1'b0;
        end
        else if(o_vld_from_weight_top && o_ready_from_mp_process)begin
            read_mp_enable <= 1'b1;
        end
        else if(mp_r_finish)begin
            read_mp_enable <= 1'b0;
        end
    end
    
    // address 
    assign {get_row, get_col} = aim_neuron_id_buffer[15:0];

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            cnt <= 0;
        end
        else if(o_vld_from_weight_top && o_ready_from_mp_process)begin
            cnt <= 0;
        end
        else if(read_mp_enable)begin
            cnt <= cnt + 1;
        end
    end

    reg [15:0] base_mp_addr;
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            base_mp_addr <= 0;
        end
        else if(processing_en)begin
            base_mp_addr <= 0;
        end
        else if(o_vld_from_weight_top && o_ready_from_mp_process)begin
            if(o_data_from_weight_top[1+144+9*16*parallel_metric-1])begin
                base_mp_addr <= base_mp_addr + o_feature_map_len;
            end
        end
    end
    // disable multiplication
    reg [15:0] get_row_mul_o_size;
    always@(*)begin
        case(o_size)
            8'd64: get_row_mul_o_size = get_row * 64;
            8'd32: get_row_mul_o_size = get_row * 32;
            8'd16: get_row_mul_o_size = get_row * 16;
            8'd8 : get_row_mul_o_size = get_row * 8;
            8'd4 : get_row_mul_o_size = get_row * 4;
            default: get_row_mul_o_size = 0;
        endcase
    end

    always@(posedge clk)begin
        if(read_mp_enable)begin
            if(&get_row || &get_col || get_row >= o_size || get_col >= o_size)begin
                rd_mp_addr <= 16'hFFFF;
            end
            else begin
                rd_mp_addr <= base_mp_addr + get_row_mul_o_size + get_col;
            end
        end
    end 

    //read_mp;
    // !!! add for timing slack
    reg read_mp_enable_ff1;
    reg [15:0] rd_mp_addr_for_timing;
    always@(posedge clk)begin
        read_mp_enable_ff1 <= read_mp_enable;
        rd_mp_addr_for_timing <= rd_mp_addr;
    end
    reg [15:0] rd_mp_addr_ff1;
    reg [16*parallel_metric-1:0] rd_mp;

    always@(posedge clk)begin
        rd_mp_en <= read_mp_enable_ff1;
        rd_mp_addr_ff1 <= rd_mp_addr_for_timing;
    end

    // SIM
    // wire [15:0] sim_mp_0, sim_mp_1, sim_mp_2;
    // wire [15:0] sim_rd_mp;
    // assign sim_rd_mp = rd_mp[15:0];
    // // assign sim_mp_0 = mp_mem[0][15:0]; // 0,0,0
    // // assign sim_mp_1 = mp_mem[495][15:0]; // 0,15,15
    // // assign sim_mp_2 = mp_mem[1023][15:0]; // 0,31, 31
    // assign sim_mp_0 = mp_mem[3072][15:0]; // 0,0,0
    // assign sim_mp_1 = mp_mem[3567][15:0]; // 0,15,15
    // assign sim_mp_2 = mp_mem[4095][15:0]; // 0,31, 31

    //calculation
    reg acc_en;
    reg [3:0] acc_cnt;
    reg [15:0] rd_mp_addr_ff2;

    always@(posedge clk)begin
        acc_en <= rd_mp_en;
        rd_mp_addr_ff2 <= rd_mp_addr_ff1;
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            acc_cnt <= 0;
        end
        else if(acc_en)begin
            acc_cnt <= acc_cnt + 1;
        end
        else if(mp_rw_finish)begin
            acc_cnt <= 0;
        end
    end

    wire [16*parallel_metric-1:0] res;
    generate
        for(i=0;i<parallel_metric;i=i+1)begin
            MP_ACC u_MP_ACC(
                .clk    ( clk    ),
                .acc_en ( acc_en ),
                .src_mp ( rd_mp[i*16 +: 16]  ),
                .weight ( weight_sum_buffer[acc_cnt][i*16 +: 16] ),
                .res    ( res[i*16 +: 16]    )
            );
        end
    endgenerate

    //wb
    reg wb_mp_en;
    // reg [15:0] rd_mp_addr_ff3;
    always@(posedge clk)begin
        wb_mp_en <= acc_en;
        // rd_mp_addr_ff3 <= rd_mp_addr_ff2;
    end

    integer m;

    // Xilinx BRAM
    wire bram_ena;
    wire bram_ena_0;
    wire bram_ena_1;
    wire bram_ena_2;
    reg [15:0] bram_addra;
    reg [16*parallel_metric-1:0] bram_dina;
    wire [16*parallel_metric-1:0] bram_doutb;
    reg rd_mp_en_from_bias_ff1;
    reg [15:0] rd_mp_addr_from_bias_ff1;

    always@(posedge clk)begin
        rd_mp_en_from_bias_ff1 <= rd_mp_en_from_bias;
        rd_mp_addr_from_bias_ff1 <= rd_mp_addr_from_bias;
    end

    assign bram_ena_0 = wb_mp_en && rd_mp_addr_ff2 != 16'hFFFF;
    assign bram_ena_1 = rd_mp_en_from_bias_ff1 && did_time_step_ff1 == buffer_timestep_sub;
    assign bram_ena_2 = dst_wb_en && did_time_step_ff1 != buffer_timestep_sub;
    assign bram_ena = bram_ena_0 | bram_ena_1 | bram_ena_2;

    always@(*)begin
        case({bram_ena_2, bram_ena_1, bram_ena_0})
            3'b001: begin bram_addra = rd_mp_addr_ff2; bram_dina = res; end
            3'b010: begin bram_addra = rd_mp_addr_from_bias_ff1; bram_dina = 'h0; end
            3'b100: begin bram_addra = dst_wb_addr; bram_dina = dst_wb_mp; end
            default: begin bram_addra = rd_mp_addr_ff2; bram_dina = 'h0; end
        endcase
    end

    MP_MEM U_MP_MEM (
    .clka(clk),    // input wire clka
    .ena(bram_ena),      // input wire ena
    .wea(bram_ena),      // input wire [0 : 0] wea
    .addra(bram_addra),  // input wire [11 : 0] addra
    .dina(bram_dina),    // input wire [511 : 0] dina

    .clkb(clk),    // input wire clkb
    .enb(rd_mp_en | rd_mp_en_from_bias),      // input wire enb
    .addrb(rd_mp_en ? rd_mp_addr_for_timing : rd_mp_addr_from_bias),  // input wire [11 : 0] addrb
    .doutb(bram_doutb)  // output wire [511 : 0] doutb
    );

    always@(*)begin
        rd_mp = bram_doutb;
        rd_mp_to_bias = bram_doutb;
    end

    // reg [511:0] mp_mem [0:4095];
    
    // always@(posedge clk)begin
    //     if(rd_mp_en)begin
    //         rd_mp <= mp_mem[rd_mp_addr];
    //     end
    //     else if(rd_mp_en_from_bias)begin
    //         rd_mp_to_bias <= mp_mem[rd_mp_addr_from_bias];
    //     end
    // end

    // always@(posedge clk or negedge rst_n)begin
    //     if(rst_n == 1'b0)begin
    //         for(m=0;m<4096;m=m+1)begin
    //             mp_mem[m] <= 0;
    //         end
    //     end
    //     else if(wb_mp_en && rd_mp_addr_ff2 != 16'hFFFF)begin
    //         mp_mem[rd_mp_addr_ff2] <= res;
    //     end
    //     else if(rd_mp_en_from_bias && did_time_step == time_step - 1)begin
    //         mp_mem[rd_mp_addr_from_bias] <= 0;
    //     end
    //     else if(dst_wb_en && did_time_step != time_step - 1)begin
    //         mp_mem[dst_wb_addr] <= dst_wb_mp;
    //     end
    // end

    // finish;
    assign mp_rw_finish = wb_mp_en & ~acc_en;

endmodule
