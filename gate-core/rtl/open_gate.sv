// OPEN GATE Hardware Enthalpy Counter
// SystemVerilog 2017
// MIT License

`timescale 1ns/1ps

module open_gate #(
    parameter int BUDGET_W = 32,
    parameter int ENTROPY_W = 24
)(
    input logic clk,
    input logic rst_n,
    input logic [BUDGET_W-1:0] budget_i,
    input logic [7:0] char_ascii_i,
    input logic char_valid_i,
    output logic gate_open_o,
    output logic [ENTROPY_W-1:0] entropy_accum_o,
    output logic violation_o
);

    // Λ-table for English orthographic entropy (pJ/letter)
    // Derived from Coq proofs in gate-core/proofs/
    localparam logic [ENTROPY_W-1:0] LAMBDA_TABLE [256] = '{
        // Control chars: 0-31
        32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
        32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
        32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
        32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
        // Space and punctuation
        32'd50, 32'd100, 32'd100, 32'd150, 32'd100, 32'd100, 32'd100, 32'd50,
        32'd150, 32'd150, 32'd100, 32'd200, 32'd50, 32'd50, 32'd50, 32'd100,
        // Numbers 0-9
        32'd200, 32'd180, 32'd170, 32'd160, 32'd150, 32'd140, 32'd130, 32'd120,
        32'd110, 32'd100, 32'd100, 32'd100, 32'd100, 32'd100, 32'd100, 32'd100,
        // @, A-Z, [, \, ], ^, _, `
        32'd150, 32'd450, 32'd420, 32'd400, 32'd380, 32'd360, 32'd350, 32'd340,
        32'd330, 32'd320, 32'd310, 32'd300, 32'd290, 32'd280, 32'd270, 32'd260,
        32'd250, 32'd240, 32'd230, 32'd220, 32'd210, 32'd200, 32'd190, 32'd180,
        32'd170, 32'd160, 32'd150, 32'd100, 32'd100, 32'd100, 32'd100, 32'd100,
        // a-z
        32'd150, 32'd400, 32'd380, 32'd360, 32'd340, 32'd320, 32'd300, 32'd280,
        32'd260, 32'd240, 32'd220, 32'd200, 32'd180, 32'd160, 32'd140, 32'd120,
        32'd100, 32'd90, 32'd80, 32'd70, 32'd60, 32'd50, 32'd40, 32'd30,
        32'd20, 32'd10, 32'd100, 32'd100, 32'd100, 32'd100, 32'd0, 32'd0
        // Rest are zero (extended ASCII)
    };

    logic [ENTROPY_W-1:0] entropy_accum_q;
    logic gate_open_q;
    logic [ENTROPY_W-1:0] char_entropy;

    // Combinational lookup
    assign char_entropy = LAMBDA_TABLE[char_ascii_i];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_accum_q <= '0;
            gate_open_q <= 1'b1;  // Gate starts open
        end else if (char_valid_i) begin
            if (gate_open_q) begin
                entropy_accum_q <= entropy_accum_q + char_entropy;
                if ((entropy_accum_q + char_entropy) > budget_i[ENTROPY_W-1:0]) begin
                    gate_open_q <= 1'b0;  // Slam gate shut
                end
            end
        end
    end

    assign gate_open_o = gate_open_q;
    assign entropy_accum_o = entropy_accum_q;
    assign violation_o = (entropy_accum_q > budget_i[ENTROPY_W-1:0]);

endmodule
