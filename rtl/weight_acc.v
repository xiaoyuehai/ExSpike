`include "defines.vh"
// module WEIGHT_ACC(
//     input wire          clk                 ,
//     input wire          rst_n               ,
//     input wire  [15:0]  synapse_weight      ,
//     input wire          w_accumulation_en   ,
//     input wire          overlap_cal_en      ,
//     input wire          overlap_clear       ,
//     input wire          new_row_col         ,
//     input wire          event_valid         ,
//     input wire          conv_code_layer_en  ,
//     input wire  [3:0]   did_bit_num         ,
    
//     output reg  [15:0]  weight_acc_res      
// );
//     // reg				[15:0]			synapse_weight_buffer	;
//     // always@(*)begin
//     //     if(!conv_code_layer_en)begin
//     //         synapse_weight_buffer <=  {{8{synapse_weight[7]}},synapse_weight[7:0]};
//     //     end
//     //     else begin
//     //         case(did_bit_num)
//     //             0:synapse_weight_buffer <= {{8{synapse_weight[7]}},synapse_weight[7:0]};
//     //             1:synapse_weight_buffer <= {{7{synapse_weight[7]}},synapse_weight[7:0],1'b0};
//     //             2:synapse_weight_buffer <= {{6{synapse_weight[7]}},synapse_weight[7:0],2'b0};
//     //             3:synapse_weight_buffer <= {{5{synapse_weight[7]}},synapse_weight[7:0],3'b0};
//     //             4:synapse_weight_buffer <= {{4{synapse_weight[7]}},synapse_weight[7:0],4'b0};
//     //             5:synapse_weight_buffer <= {{3{synapse_weight[7]}},synapse_weight[7:0],5'b0};
//     //             6:synapse_weight_buffer <= {{2{synapse_weight[7]}},synapse_weight[7:0],6'b0};
//     //             // 7:synapse_weight_buffer <= {~synapse_weight[12+8*i:8*i],7'h7f} + 1;
//     //             7:synapse_weight_buffer <= {~synapse_weight[7],~synapse_weight[7:0],7'h7f} + 1;
//     //             default:;
//     //         endcase
//     //     end
//     // end

//     reg [15:0] overlap_cal_res;

//     // wire [16:0] pre_acc = weight_acc_res + synapse_weight;
//     // wire p_carry = ~weight_acc_res[15] & ~synapse_weight[15] & pre_acc[15];
//     // wire n_carry =  weight_acc_res[15] &  synapse_weight[15] & ~pre_acc[15]; 

//     reg [15:0] a;
//     wire [15:0] c;

//     always@(*)begin
//         if(overlap_cal_en)begin
//             a = overlap_cal_res;
//         end
//         else begin
//             a = weight_acc_res;
//         end
//     end

//     ADDER u_ADDER(
//         .a ( a ),
//         .b ( synapse_weight ),
//         .c  ( c  )
//     );


//     always@(posedge clk or negedge rst_n)begin
//         if(rst_n == 1'b0)begin
//             weight_acc_res <= 16'b0;
//         end
//         else if(event_valid && new_row_col)begin
//             weight_acc_res <= overlap_cal_res;//16'b0;
//         end
//         else if(w_accumulation_en == 1'b1)begin
//             weight_acc_res <= c;//pre_acc[16]&conv_code_layer_en ? 16'hFFFF : pre_acc[15:0];//weight_acc_res + synapse_weight;
//         end
//     end

//     always@(posedge clk or negedge rst_n)begin
//         if(rst_n == 1'b0)begin
//             overlap_cal_res <= 0;
//         end
//         else if(overlap_clear)begin
//             overlap_cal_res <= 0;
//         end
//         else if(w_accumulation_en && overlap_cal_en)begin
//             overlap_cal_res <= c;
//         end
//     end



// endmodule

// module ADDER(
//     input wire [15:0] a,
//     input wire [15:0] b,
//     output wire [15:0] c
// );
//     assign c = a + b;

// endmodule
module WEIGHT_ACC(
    input wire          clk                 ,
    input wire          rst_n               ,
    input wire  [15:0]  synapse_weight      ,
    input wire          w_accumulation_en   ,
    input wire          overlap_cal_en      ,
    input wire          overlap_clear       ,
    input wire          new_row_col         ,
    input wire          event_valid         ,
    input wire          conv_code_layer_en  ,
    input wire  [3:0]   did_bit_num         ,
    
    output reg  [15:0]  weight_acc_res      
);
    // reg				[15:0]			synapse_weight_buffer	;
    // always@(*)begin
    //     if(!conv_code_layer_en)begin
    //         synapse_weight_buffer <=  {{8{synapse_weight[7]}},synapse_weight[7:0]};
    //     end
    //     else begin
    //         case(did_bit_num)
    //             0:synapse_weight_buffer <= {{8{synapse_weight[7]}},synapse_weight[7:0]};
    //             1:synapse_weight_buffer <= {{7{synapse_weight[7]}},synapse_weight[7:0],1'b0};
    //             2:synapse_weight_buffer <= {{6{synapse_weight[7]}},synapse_weight[7:0],2'b0};
    //             3:synapse_weight_buffer <= {{5{synapse_weight[7]}},synapse_weight[7:0],3'b0};
    //             4:synapse_weight_buffer <= {{4{synapse_weight[7]}},synapse_weight[7:0],4'b0};
    //             5:synapse_weight_buffer <= {{3{synapse_weight[7]}},synapse_weight[7:0],5'b0};
    //             6:synapse_weight_buffer <= {{2{synapse_weight[7]}},synapse_weight[7:0],6'b0};
    //             // 7:synapse_weight_buffer <= {~synapse_weight[12+8*i:8*i],7'h7f} + 1;
    //             7:synapse_weight_buffer <= {~synapse_weight[7],~synapse_weight[7:0],7'h7f} + 1;
    //             default:;
    //         endcase
    //     end
    // end
    reg [15:0] overlap_cal_res;

    wire [16:0] pre_acc = weight_acc_res + synapse_weight;
    // wire p_carry = ~weight_acc_res[15] & ~synapse_weight[15] & pre_acc[15];
    // wire n_carry =  weight_acc_res[15] &  synapse_weight[15] & ~pre_acc[15]; 
    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            weight_acc_res <= 16'b0;
        end
        else if(event_valid && new_row_col)begin
            weight_acc_res <= `GROUP_NUMBER == 1 ? 16'b0 : overlap_cal_res;//16'b0;
        end
        else if(w_accumulation_en == 1'b1)begin
            weight_acc_res <= pre_acc[15:0];//pre_acc[16]&conv_code_layer_en ? 16'hFFFF : pre_acc[15:0];//weight_acc_res + synapse_weight;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            overlap_cal_res <= 0;
        end
        else if(overlap_clear)begin
            overlap_cal_res <= 0;
        end
        else if(w_accumulation_en && overlap_cal_en)begin
            overlap_cal_res <= overlap_cal_res + synapse_weight;
        end
    end

endmodule