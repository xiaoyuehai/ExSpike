// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : tb/tb_read_membrane_p.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Unit testbench for READ_MEMBRANE_P.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module TB_READ_MEMBRANE_P();
    reg clk;
    reg rst_n;
    reg [4751:0] o_data_from_weight_top;
    reg o_vld_from_weight_top;
    wire o_ready_from_mp_process;

    initial begin
        clk = 0;
        forever begin
            #2.5 clk = ~clk;
        end
    end

    initial begin
        o_data_from_weight_top = 4752'hffffff00ff0100ff0000000101ff01000101003afffcffc9008a000fffe70021ffe6ffb5fff1fffbfff700040000fffffff5fff6fff3001a0002fff1fff900140010fffafff3000700000001fffefffcfff40002fff6fff3000200650053fff3000effd3ffb7ffe1ffcaffe60019002a001200270017ffe90019fff1ffe100230021fff7000c000ffff6ffe9fff8fff3000000070009fff6fff7ffeffff4fff3ffe8ffa7ffe4001dffb20000002affbf0004ffed001a00060001000dfffafff6fffbffecffee0005fffcfffb0003fffa00060006fffe0007ffedffeafff2fff8fff2fffafffdfffbfffc001affcfffce0020000cffd8fff0ffffffe3ffdf0011fff60029004d0021fffc000effe4ffeaffeafff40001fffbfffc000200090006ffeb0039ffdfffe5002b00120009fff3ffedfffe000c0008000c001dfffafff10002fff2ffad001d0024ff9a00140029ffb9ffe9fff9001b0004fff10006fff3fff2fff4ffebfff6ffeaffddffc6fff80010fffbffff0006ffda000b003f0022005b0032ffd80006ffcaffa7fff6fffaffeefff4fff7ffeefff6fff8ffeeff7800080015ffb6004a004dffc00026000efffc0005ffe700120010fff3002300250003ffe4fffbfffefff90021001ffff70009000b00330026ffbb0041fff0ffe5001fffe5fff500300021ffff003a00360013fff500130002fff20030fff1ffff00080012ffeb000dffe80023ffebfff4000400170015fffc0010fff4ffefffd100370009ffcd003dffe5ffdbfff8fffbfffefff7001700090002ffeeffe8fff4ffd9ffe5fff2ffdb0002fff500000010000a;
    end

    initial begin
        rst_n = 1'b0;
        o_vld_from_weight_top = 0;
        #100;
        rst_n = 1'b1;
        #100;
        @(posedge clk);
        o_vld_from_weight_top = 1;
        wait(o_ready_from_mp_process == 1);
        @(posedge clk);
        o_vld_from_weight_top = 0;

        #1000;
        $finish;
    end

    READ_MEMBRANE_P u_READ_MEMBRANE_P(
        .clk                    ( clk                    ),
        .rst_n                  ( rst_n                  ),
        .o_size                 ( 32                 ),
        .o_vld_from_weight_top  ( o_vld_from_weight_top  ),
        .o_data_from_weight_top ( o_data_from_weight_top ),
        .o_ready_from_mp_process  ( o_ready_from_mp_process  )
    );

endmodule