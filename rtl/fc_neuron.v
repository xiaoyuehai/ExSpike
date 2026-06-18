// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : fc_neuron.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Fully-connected neuron processing unit.
// -----------------------------------------------------------------------------

module FC_NEURON_CIFAR100(
    input wire          clk             ,
    input wire          rst_n           ,

    input wire          set_mem_p_en    ,
    input wire          shift_en        ,
    input wire  [15:0]  set_mem_p       ,

    input wire  [15:0]   synaptic_w      ,
    input wire          add_en          ,

    output wire [15:0]  out_mem_p       
);

    reg [15:0] internal_mem_p;
    wire [15:0] pre_acc = internal_mem_p + synaptic_w;
    wire p_carry = ~internal_mem_p[15] & ~synaptic_w[15] & pre_acc[15];
    wire n_carry =  internal_mem_p[15] &  synaptic_w[15] & ~pre_acc[15];
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            internal_mem_p <= 0;
        end
        else if(shift_en)begin
            internal_mem_p <= internal_mem_p;//{internal_mem_p[15], internal_mem_p[15:1]};
        end
        else if(set_mem_p_en == 1'b1)begin
            internal_mem_p <= set_mem_p;
        end
        else if(add_en == 1'b1)begin
            if(p_carry)begin
                internal_mem_p <= 16'b0111100000000000;
            end
            else if(n_carry)begin
                internal_mem_p <= 16'b1000100000000000;
            end
            else
                internal_mem_p <= pre_acc;//internal_mem_p + synaptic_w;
        end
    end

    assign out_mem_p = internal_mem_p;

    


endmodule

module FC_NEURON(
    input wire          clk             ,
    input wire          rst_n           ,

    input wire          set_mem_p_en    ,
    input wire          shift_en        ,
    // input wire  [15:0]  mem_p           ,

    input wire  [15:0]   synaptic_w      ,
    input wire          add_en          ,

    output wire [15:0]  out_mem_p       
);

    reg [15:0] internal_mem_p;
    wire [15:0] pre_acc = internal_mem_p + synaptic_w;
    wire p_carry = ~internal_mem_p[15] & ~synaptic_w[15] & pre_acc[15];
    wire n_carry =  internal_mem_p[15] &  synaptic_w[15] & ~pre_acc[15];
    
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            internal_mem_p <= 0;
        end
        else if(shift_en)begin
            internal_mem_p <= internal_mem_p;//{internal_mem_p[15], internal_mem_p[15:1]};
        end
        else if(set_mem_p_en == 1'b1)begin
            internal_mem_p <= 0;
        end
        else if(add_en == 1'b1)begin
            if(p_carry)begin
                internal_mem_p <= 16'b0111100000000000;
            end
            else if(n_carry)begin
                internal_mem_p <= 16'b1000100000000000;
            end
            else
                internal_mem_p <= pre_acc;//internal_mem_p + synaptic_w;
        end
    end

    assign out_mem_p = internal_mem_p;

    


endmodule