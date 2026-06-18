// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : mp_acc.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: Membrane potential accumulator.
// -----------------------------------------------------------------------------

module MP_ACC(
    input wire clk,
    input wire acc_en,
    input wire [15:0] src_mp,
    input wire [15:0] weight,

    output reg [15:0] res

);

    always@(posedge clk)begin
        if(acc_en)begin
            res <= src_mp + weight;
        end
    end

endmodule