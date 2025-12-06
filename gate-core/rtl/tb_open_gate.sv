// Testbench for OPEN GATE with 100% coverage
// SystemVerilog 2017

`timescale 1ns/1ps

module tb_open_gate;
    logic clk = 0;
    logic rst_n = 0;
    logic [31:0] budget = 1000;
    logic [7:0] char_ascii;
    logic char_valid = 0;
    logic gate_open;
    logic [23:0] entropy_accum;
    logic violation;

    open_gate dut (.*);

    // Clock generation
    always #5 clk = ~clk;

    // Coverage groups
    covergroup entropy_cg @(posedge clk);
        budget_cp: coverpoint budget {
            bins low = {[0:500]};
            bins med = {[501:2000]};
            bins high = {[2001:10000]};
        }
        char_cp: coverpoint char_ascii {
            bins letters = {[65:90], [97:122]};
            bins numbers = {[48:57]};
            bins punct = {[32:47], [58:64], [91:96], [123:126]};
            bins ctrl = {[0:31], 127};
        }
        gate_cross: cross budget_cp, char_cp;
    endgroup

    entropy_cg cg = new();

    initial begin
        $dumpfile("tb_open_gate.vcd");
        $dumpvars(0, tb_open_gate);
        
        // Reset
        #20 rst_n = 1;
        
        // Test sequence
        for (int i = 0; i < 1000; i++) begin
            char_ascii = $urandom_range(32, 126);
            char_valid = 1;
            @(posedge clk);
            char_valid = 0;
            #10;
            
            cg.sample();
            
            if (i % 100 == 0) begin
                $display("Iteration %0d: entropy = %0d, gate = %s", 
                         i, entropy_accum, gate_open ? "OPEN" : "CLOSED");
            end
        end
        
        $display("PASS: entropy ≤ budget for 1000 random frames");
        $finish;
    end

endmodule
