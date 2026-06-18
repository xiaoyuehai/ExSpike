// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : fc_core.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Fully-connected layer compute core.
// -----------------------------------------------------------------------------

`include "defines.vh"
module FC_CORE_CIFAR100#(
    parameter CIFAR_10 = 1,
    parameter CIFAR_100_ENABLE = 0
)(
    input   wire          clk                   ,
    input   wire          rst_n                 , 
    input   wire [ 7:0]   did_time_step         ,
    input   wire [ 7:0]   time_step             ,       
    input   wire [15:0]   i_feature_map_len     ,
    input   wire          fc_cal_enable         , 
    output  reg           fc_rd_en              ,
    input   wire [15:0]   base_addr_from_spike_sim,
    output  reg  [15:0]   fc_rd_addr            ,
    input   wire [1023:0] fc_rd_spike           ,

    output  wire          fc_cal_finish         ,
    output  wire [7:0]    fc_cal_res        

);
    localparam  IDLE             = 4'b0001;
    localparam  CHECK_POSITION   = 4'b0010;
    localparam  CHECK_SPIKE      = 4'b0100;
    localparam  COMPARE          = 4'b1000;
    
    localparam loop_number = 10;
    reg        fc_internal_enable;
    reg        fc_mp_rd_enable;
    reg        fc_mp_set_enable;
    reg        fc_mp_wb_enable;
    reg        fc_cmp_busy;
    reg [15:0] fc_mp_rd_addr;
    reg [15:0] fc_mp_wb_addr;
    reg [15:0] fc_weight_base_addr;

    reg [3:0] success_loop_number;
    reg [7:0] saved_max_index;
    reg [15:0] saved_max_data;
    reg [15:0] base_index_bias;
    reg [159:0] fc_mp_sram [0:9];
    wire [159:0] fc_mp_sram_out;
    wire [159:0] fc_wb_data;

    reg [3 :0]  state, next_state;
    reg [15:0]  position;
    reg         neuron_spike_valid;
    wire        no_valid_spike;
    wire [8:0]  absolute_addr;
    wire        absolute_addr_valid;
    wire        idle;
    wire        compare_success_cifar10;
    reg [7:0]  max_index_cifar10;
    reg [175:0] fc_weight;

    // assign fc_cal_finish = compare_success_cifar10;
    // assign fc_cal_res    = max_index_cifar10;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@(*)begin
        case(state)
            IDLE:begin
                if(fc_internal_enable)begin
                    next_state = CHECK_POSITION;
                end
                else begin
                    next_state = IDLE;
                end
            end

            CHECK_POSITION:begin
                if(position == i_feature_map_len)begin
                    next_state = COMPARE;
                end
                else begin
                    next_state = CHECK_SPIKE;
                end
            end

            CHECK_SPIKE:begin
                if(idle & ~neuron_spike_valid & ~fc_rd_en)begin
                    next_state = CHECK_POSITION;
                end
                else begin
                    next_state = CHECK_SPIKE;
                end
            end

            COMPARE:begin
                if(compare_success_cifar10)begin
                    next_state = IDLE;
                end
                else begin
                    next_state = COMPARE;
                end
            end

            default:begin
                next_state = IDLE;
            end
        endcase
    end 

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            position <= 0;
        end
        else if(fc_internal_enable)begin
            position <= 0;
        end
        else if(state == CHECK_POSITION)begin
            position <= position + 1;
        end
    end

    // assign fc_rd_addr = position;
    // assign fc_rd_en = (state == CHECK_POSITION) && (position != i_feature_map_len);

    always@(posedge clk)begin
        fc_rd_addr <= position + base_addr_from_spike_sim;
        fc_rd_en <= (state == CHECK_POSITION) && (position != i_feature_map_len);
    end

    always@(posedge clk)begin
        neuron_spike_valid <= fc_rd_en;
    end

    TOP_FAST_FILTER U_TOP_FAST_FILTER(
        .clk                 ( clk                 ),
        .rst_n               ( rst_n               ),
        .neuron_spike        ( fc_rd_spike[511:0]  ),
        .neuron_spike_valid  ( neuron_spike_valid  ),
        .generate_next_en    ( 1'b1                ),
        .no_valid_spike      ( no_valid_spike      ),
        .absolute_addr       ( absolute_addr       ),
        .absolute_addr_valid ( absolute_addr_valid ),
        .idle                ( idle                )
    );

    // full-connected neuron state update
    // Xilinx Block RAM Generation
    wire [175:0] fc_weight_mem_dout;
    ST2_CIFAR100_FC_WEIGHT_MEM U_FC_WEIGHT_MEM (
        .clka(clk),    // input wire clka
        .ena(absolute_addr_valid),      // input wire ena
        .addra(absolute_addr+fc_weight_base_addr),  // input wire [8 : 0] addra
        .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
    );
    always@(*)begin
        fc_weight = fc_weight_mem_dout;
    end
    // reg [159:0] fc_weight_mem [0:511];

    // initial begin
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_fc_weight.txt", fc_weight_mem);
    // end

    // // read fc_weight
    // 

    // always@(posedge clk)begin
    //     if(absolute_addr_valid)begin
    //         fc_weight <= fc_weight_mem[absolute_addr];
    //     end
    // end
    ////////////MEM AREA///////////////
    
    // calculate 
    reg add_en, mp_eb_en;
    always@(posedge clk)begin
        add_en <= absolute_addr_valid;
    end

    wire [15:0] sim_neuron [0:10];
    wire [159:0] fc_bias;
    wire fc_bias_add;
    reg compare_start_before, compare_start;

    assign fc_bias_add = compare_start_before;//state == CHECK_POSITION && next_state == COMPARE;
    assign fc_bias = 160'b0;//160'hfea2ffc200040095ff68ffab011e000dfe82ffc4;

    generate
        genvar i;
        for(i = 0; i < 10; i = i + 1)begin
            FC_NEURON_CIFAR100 U_FC_NEURON(
                .clk           ( clk                            ),
                .rst_n         ( rst_n                          ),
                .shift_en      ( 1'b0                           ),
                .set_mem_p_en  ( fc_mp_set_enable               ),
                .set_mem_p     ( fc_mp_sram_out[15+16*i:16*i]),
                .synaptic_w    ( add_en ? fc_weight[15+16*i:16*i] : fc_bias[15+16*i:16*i]        ),
                .add_en        ( add_en | fc_bias_add            ),
                .out_mem_p     ( sim_neuron[i]        )
            );

            // assign sim_neuron[i] = out_mem_p[15+16*i:16*i];
        end
    endgenerate

    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            compare_start_before <= 1'b0;
        end
        else if(state == CHECK_POSITION && next_state == COMPARE)begin
            compare_start_before <= 1'b1;
        end
        else begin
            compare_start_before <= 0;
        end
    end
    always@(posedge clk)begin
        compare_start <= compare_start_before;
    end

    wire  [7:0] max_index_low;
    wire [15:0] max_data_low;

    RECO_COMPARE #(
        .DATA_WIDTH(16)
    ) 
    U_RECO_COMPARE (
            .CLK             (clk),
            .RST_N           (rst_n),
            .comapre_start   (compare_start),
            .data_in0        (sim_neuron[0]),
            .data_in1        (sim_neuron[1]),
            .data_in2        (sim_neuron[2]),
            .data_in3        (sim_neuron[3]),
            .data_in4        (sim_neuron[4]),
            .data_in5        (sim_neuron[5]),
            .data_in6        (sim_neuron[6]),
            .data_in7        (sim_neuron[7]),
            .data_in8        (sim_neuron[8]),
            .data_in9        (sim_neuron[9]),
            .max_index       (max_index_low),
            .max_data        (max_data_low),
            .compare_success (compare_success_cifar10)
        );
    generate
        if(CIFAR_10 == 1)begin
            always@(posedge clk)begin
                if(compare_success_cifar10)begin
                    max_index_cifar10 <= max_index_low;
                end
            end
        end
        else begin
            always@(posedge clk)begin
                if(compare_success_cifar10 == 1'b1)begin
                    case({max_data_low[15],sim_neuron[10][15]})
                        2'b00,2'b11:begin
                            if(max_data_low >= sim_neuron[10])begin
                                max_index_cifar10 <= max_index_low;					
                            end
                            else begin
                                max_index_cifar10 <= 10;
                            end
                        end

                        2'b10:begin
                            max_index_cifar10 <= 10;
                        end

                        2'b01:begin
                            max_index_cifar10 <= max_index_low;	
                        end
                        default:max_index_cifar10 <= max_index_low;

                    endcase
                end
            end
        end
    endgenerate

FC_MP_MEM U_FC_MP_MEM (
  .clka(clk),    // input wire clka
  .ena(fc_mp_wb_enable),      // input wire ena
  .wea(fc_mp_wb_enable),      // input wire [0 : 0] wea
  .addra(fc_mp_wb_addr),  // input wire [3 : 0] addra
  .dina(did_time_step == time_step - 1 ? 0 : fc_wb_data),    // input wire [159 : 0] dina

  .clkb(clk),    // input wire clkb
  .enb(fc_mp_rd_enable),      // input wire enb
  .addrb(fc_mp_rd_addr),  // input wire [3 : 0] addrb
  .doutb(fc_mp_sram_out)  // output wire [159 : 0] doutb
);

generate
    for(i=0;i<10; i= i+1)begin
        assign fc_wb_data[15+16*i:16*i] = sim_neuron[i];
    end
endgenerate

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        base_index_bias <= 0;
    end
    else if(fc_cal_enable)begin
        base_index_bias <= 0;
    end
    else if(compare_success_cifar10)begin
        base_index_bias <= base_index_bias + 10;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_weight_base_addr <= 0;
    end
    else if(fc_cal_enable)begin
        fc_weight_base_addr <= 0;
    end
    else if(compare_success_cifar10)begin
        fc_weight_base_addr <= fc_weight_base_addr + 512;
    end
end

always@(posedge clk)begin
    if(compare_success_cifar10 && success_loop_number == 0)begin
        saved_max_index <= max_index_low;
        saved_max_data <= max_data_low;
    end
    else if(compare_success_cifar10)begin
        case({max_data_low[15],saved_max_data[15]})
            2'b00,2'b11:begin
                if(max_data_low >= saved_max_data)begin
                    saved_max_index <= base_index_bias + max_index_low;
                    saved_max_data <= max_data_low;
                end
                else begin
                    saved_max_index <= saved_max_index;
                    saved_max_data <= saved_max_data;
                end
            end

            2'b10:begin
                saved_max_index <= saved_max_index;
                saved_max_data <= saved_max_data;
            end

            2'b01:begin
                saved_max_index <= base_index_bias + max_index_low;
                saved_max_data <= max_data_low;
            end
            default: begin
                saved_max_index <= saved_max_index;
                saved_max_data <= saved_max_data;
            end
        endcase
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        success_loop_number <= 0;
    end
    else if(fc_cal_enable)begin
        success_loop_number <= 0;
    end
    else if(compare_success_cifar10)begin
        success_loop_number <= success_loop_number + 1;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_cmp_busy <= 0;
    end
    else if(fc_cal_enable)begin
        fc_cmp_busy <= 1;
    end
    else if(compare_success_cifar10 && success_loop_number == loop_number - 1)begin
        fc_cmp_busy <= 0;
    end
end

reg fc_cmp_busy_ff1;

always@(posedge clk)begin
    fc_cmp_busy_ff1 <= fc_cmp_busy;
end

assign fc_cal_finish = ~fc_cmp_busy &fc_cmp_busy_ff1;
assign fc_cal_res = saved_max_index;

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_internal_enable <= 0;
    end
    else if(fc_cmp_busy == 1 && state == IDLE && fc_internal_enable == 0)begin
        fc_internal_enable <= 1;
    end
    else begin
        fc_internal_enable <= 0;
    end
end

always@(posedge clk)begin
    fc_mp_rd_enable <= fc_internal_enable;
    fc_mp_set_enable <= fc_mp_rd_enable;
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_mp_rd_addr <= 0;
    end
    else if(fc_cal_enable)begin
        fc_mp_rd_addr <= 0;
    end
    else if(fc_mp_rd_enable)begin
        fc_mp_rd_addr <= fc_mp_rd_addr + 1;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_mp_wb_enable <= 1'b0;
    end
    else if(state == COMPARE && next_state == IDLE)begin
        fc_mp_wb_enable <= 1'b1;
    end
    else begin
        fc_mp_wb_enable <= 0;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        fc_mp_wb_addr <= 0;
    end
    else if(fc_cal_enable == 1)begin
        fc_mp_wb_addr <= 0;
    end
    else if(fc_mp_wb_enable)begin
        fc_mp_wb_addr <= fc_mp_wb_addr + 1;
    end
end

endmodule

module FC_CORE#(
    parameter CIFAR_10 = 1
)(
    input   wire          clk                   ,
    input   wire          rst_n                 , 
    input   wire [ 7:0]   did_time_step         ,
    input   wire [15:0]   i_feature_map_len     ,
    input   wire          fc_cal_enable         , 
    output  reg           fc_rd_en              ,
    input   wire [15:0]   base_addr_from_spike_sim,
    output  reg  [15:0]   fc_rd_addr            ,
    input   wire [1023:0] fc_rd_spike           ,

    output  wire          fc_cal_finish         ,
    output  wire [7:0]    fc_cal_res        

);
    localparam  IDLE             = 4'b0001;
    localparam  CHECK_POSITION   = 4'b0010;
    localparam  CHECK_SPIKE      = 4'b0100;
    localparam  COMPARE          = 4'b1000;

    reg [3 :0]  state, next_state;
    reg [15:0]  position;
    reg         neuron_spike_valid;
    wire        no_valid_spike;
    wire [8:0]  absolute_addr;
    wire        absolute_addr_valid;
    wire        idle;
    wire        compare_success_cifar10;
    reg [7:0]  max_index_cifar10;
    reg [175:0] fc_weight;

    assign fc_cal_finish = compare_success_cifar10;
    assign fc_cal_res    = max_index_cifar10;

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@(*)begin
        case(state)
            IDLE:begin
                if(fc_cal_enable)begin
                    next_state = CHECK_POSITION;
                end
                else begin
                    next_state = IDLE;
                end
            end

            CHECK_POSITION:begin
                if(position == i_feature_map_len)begin
                    next_state = COMPARE;
                end
                else begin
                    next_state = CHECK_SPIKE;
                end
            end

            CHECK_SPIKE:begin
                if(idle & ~neuron_spike_valid & ~fc_rd_en)begin
                    next_state = CHECK_POSITION;
                end
                else begin
                    next_state = CHECK_SPIKE;
                end
            end

            COMPARE:begin
                if(compare_success_cifar10)begin
                    next_state = IDLE;
                end
                else begin
                    next_state = COMPARE;
                end
            end

            default:begin
                next_state = IDLE;
            end
        endcase
    end 

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            position <= 0;
        end
        else if(fc_cal_enable)begin
            position <= 0;
        end
        else if(state == CHECK_POSITION)begin
            position <= position + 1;
        end
    end

    // assign fc_rd_addr = position;
    // assign fc_rd_en = (state == CHECK_POSITION) && (position != i_feature_map_len);

    always@(posedge clk)begin
        fc_rd_addr <= position + base_addr_from_spike_sim;
        fc_rd_en <= (state == CHECK_POSITION) && (position != i_feature_map_len);
    end

    always@(posedge clk)begin
        neuron_spike_valid <= fc_rd_en;
    end

    TOP_FAST_FILTER U_TOP_FAST_FILTER(
        .clk                 ( clk                 ),
        .rst_n               ( rst_n               ),
        .neuron_spike        ( fc_rd_spike[511:0]  ),
        .neuron_spike_valid  ( neuron_spike_valid  ),
        .generate_next_en    ( 1'b1                ),
        .no_valid_spike      ( no_valid_spike      ),
        .absolute_addr       ( absolute_addr       ),
        .absolute_addr_valid ( absolute_addr_valid ),
        .idle                ( idle                )
    );

    // full-connected neuron state update
    // Xilinx Block RAM Generation
    wire [175:0] fc_weight_mem_dout; 
    `ifdef VGG11_CIFAR10
        VGG11_CIFAR10_FC_WEIGHT_MEM U_FC_WEIGHT_MEM (
            .clka(clk),    // input wire clka
            .ena(absolute_addr_valid),      // input wire ena
            .addra(absolute_addr),  // input wire [8 : 0] addra
            .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
        );
    `elsif ResNet18_CIFAR10
        ResNet18_CIFAR10_FC_WEIGHT_MEM U_FC_WEIGHT_MEM (
            .clka(clk),    // input wire clka
            .ena(absolute_addr_valid),      // input wire ena
            .addra(absolute_addr),  // input wire [8 : 0] addra
            .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
        );
    `elsif ST4_CIFAR10
        ST4_CIFAR10_FC_WEIGHT_MEM U_FC_WEIGHT_MEM (
            .clka(clk),    // input wire clka
            .ena(absolute_addr_valid),      // input wire ena
            .addra(absolute_addr),  // input wire [8 : 0] addra
            .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
        );
    `elsif ST2_CIFAR100
        ST2_CIFAR100_FC_WEIGHT_MEM U_FC_WEIGHT_MEM (
            .clka(clk),    // input wire clka
            .ena(absolute_addr_valid),      // input wire ena
            .addra(absolute_addr),  // input wire [8 : 0] addra
            .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
        );
    `else
        VGG11_CIFAR10_FC_WEIGHT_MEM your_instance_name (
            .clka(clk),    // input wire clka
            .ena(absolute_addr_valid),      // input wire ena
            .addra(absolute_addr),  // input wire [8 : 0] addra
            .douta(fc_weight_mem_dout)  // output wire [159 : 0] douta
        );
    `endif
    always@(*)begin
        fc_weight = fc_weight_mem_dout;
    end
    // reg [159:0] fc_weight_mem [0:511];

    // initial begin
    //     $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/Hardware/test_fc_weight.txt", fc_weight_mem);
    // end

    // // read fc_weight
    // 

    // always@(posedge clk)begin
    //     if(absolute_addr_valid)begin
    //         fc_weight <= fc_weight_mem[absolute_addr];
    //     end
    // end
    ////////////MEM AREA///////////////
    
    // calculate 
    reg add_en, mp_eb_en;
    always@(posedge clk)begin
        add_en <= absolute_addr_valid;
    end

    wire [15:0] sim_neuron [0:10];
    wire [159:0] fc_bias;
    wire fc_bias_add;
    reg compare_start_before, compare_start;

    assign fc_bias_add = compare_start_before;//state == CHECK_POSITION && next_state == COMPARE;
    assign fc_bias = 160'b0;//160'hfea2ffc200040095ff68ffab011e000dfe82ffc4;

    generate
        genvar i;
        for(i = 0; i < 10; i = i + 1)begin
            FC_NEURON U_FC_NEURON(
                .clk           ( clk                            ),
                .rst_n         ( rst_n                          ),
                .shift_en      ( fc_cal_enable  && did_time_step != 0),
                .set_mem_p_en  ( fc_cal_enable  && did_time_step == 0),
                .synaptic_w    ( add_en ? fc_weight[15+16*i:16*i] : fc_bias[15+16*i:16*i]        ),
                .add_en        ( add_en | fc_bias_add            ),
                .out_mem_p     ( sim_neuron[i]        )
            );

            // assign sim_neuron[i] = out_mem_p[15+16*i:16*i];
        end
    endgenerate

    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            compare_start_before <= 1'b0;
        end
        else if(state == CHECK_POSITION && next_state == COMPARE)begin
            compare_start_before <= 1'b1;
        end
        else begin
            compare_start_before <= 0;
        end
    end
    always@(posedge clk)begin
        compare_start <= compare_start_before;
    end

    wire  [7:0] max_index_low;
    wire [15:0] max_data_low;

    RECO_COMPARE #(
        .DATA_WIDTH(16)
    ) 
    U_RECO_COMPARE (
            .CLK             (clk),
            .RST_N           (rst_n),
            .comapre_start   (compare_start),
            .data_in0        (sim_neuron[0]),
            .data_in1        (sim_neuron[1]),
            .data_in2        (sim_neuron[2]),
            .data_in3        (sim_neuron[3]),
            .data_in4        (sim_neuron[4]),
            .data_in5        (sim_neuron[5]),
            .data_in6        (sim_neuron[6]),
            .data_in7        (sim_neuron[7]),
            .data_in8        (sim_neuron[8]),
            .data_in9        (sim_neuron[9]),
            .max_index       (max_index_low),
            .max_data        (max_data_low),
            .compare_success (compare_success_cifar10)
        );
    generate
        if(CIFAR_10 == 1)begin
            always@(posedge clk)begin
                if(compare_success_cifar10)begin
                    max_index_cifar10 <= max_index_low;
                end
            end
        end
        else begin
            always@(posedge clk)begin
                if(compare_success_cifar10 == 1'b1)begin
                    case({max_data_low[15],sim_neuron[10][15]})
                        2'b00,2'b11:begin
                            if(max_data_low >= sim_neuron[10])begin
                                max_index_cifar10 <= max_index_low;					
                            end
                            else begin
                                max_index_cifar10 <= 10;
                            end
                        end

                        2'b10:begin
                            max_index_cifar10 <= 10;
                        end

                        2'b01:begin
                            max_index_cifar10 <= max_index_low;	
                        end
                        default:max_index_cifar10 <= max_index_low;

                    endcase
                end
            end
        end
    endgenerate
    

endmodule