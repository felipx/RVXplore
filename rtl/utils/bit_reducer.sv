//# Boolean Bit Reducer

// This module generalizes the usual 2-input Boolean functions to their
// n-input reductions, which are interesting and useful:

// * Trivially calculate *any of these* (OR) or *all of these* (AND) conditions and their negations.
// * Calculate even/odd parity (XOR/XNOR)
// * Selectively invert some of the inputs and you can decode any intermediate condition you care to.

// Beginners can use this module to implement any combinational logic while
// knowing a minimum of Verilog (no always blocks, no blocking/non-blocking
// statements, only wires, etc...).

// Experts generally would not use this module. It's far simpler to [express
// the desired conditions directly](./verilog.html#boolean) in Verilog.
// However, there are a few reasons to use it:

// * It will keep your derived schematics clean of multiple random little gates, and generally preserve the schematic layout.
// * If there is a specific meaning to this reduction, you can name the module descriptively.
// * It will make clear which logic gets moved, in or out of that level of hierarchy, by optimization or retiming post-synthesis.

//## Differences with Verilog Reduction Operators

// The specification of reduction operators in Verilog (2001 or SystemVerilog)
// contains an error which does not perform a true reduction when the Boolean
// operator in the reduction contains an inversion (NOR, NAND, XNOR). Instead,
// the operator will perform a non-inverting reduction (e.g.: XOR), then
// invert the final result. For example, `A = ~^B;` (XNOR reduction) should
// perform the following:

// <pre>(((B[0] ~^ B[1]) ~^ B[2]) ~^ B[3) ... </pre>

// but instead performs the following, which is not always equivalent:

// <pre>~(B[0] ^ B[1] ^ B[2] ^ B[3 ...)</pre>

// To implement the correct logical behaviour, we do the reduction in a loop
// using the alternate implementation described in the [Word
// Reducer](./Word_Reducer.html) module.  The differences were
// [spotted](https://twitter.com/wren6991/status/1259098465835106304) by Luke
// Wren ([@wren6991](https://twitter.com/wren6991)).

//## Errors, Verilog Strings, and Linter Warnings

// There's no clean way to stop the CAD tools if the `OPERATION` parameter is
// missing or incorrect. Here, the logic doesn't get generated, which will
// fail pretty fast...

// The `OPERATION` parameter also reveals how strings are implemented in
// Verilog: just a sequence of 8-bit bytes. Thus, if we give `OPERATION`
// a value of `"OR"` (16 bits), it must first get compared against `"AND"` (24
// bits) and `"NAND"` (32 bits). The Verilator linter throws a width mismatch
// warning at those first two comparisons, of course. Width warnings are
// important to spot bugs, so to keep them relevant we carefully disable width
// checks only during the parameter tests.

module bit_reducer
#(
    parameter string Operation        = "",
    parameter int unsigned InputCount = 0
) (
    input  wire [InputCount-1:0] bits_in,
    output reg                   bit_out
);

    generate

        // verilator lint_off WIDTH
        if (Operation == "AND") begin : gen_and
        // verilator lint_on  WIDTH
            always_comb begin
                bit_out = &bits_in;
            end
        end
        else
        //// verilator lint_off WIDTH
        //if (Operation == "NAND") begin : gen_nand
        //// verilator lint_on  WIDTH
        //    always_comb begin
        //        for(int unsigned i=1; i < InputCount; i=i+1) begin
        //            partial_reduction[i] = ~(partial_reduction[i-1] & bits_in[i]);
        //        end
        //    end
        //end
        //else
        // verilator lint_off WIDTH
        if (Operation == "OR") begin : gen_or
        // verilator lint_on  WIDTH
            always_comb begin
                bit_out = |bits_in;
            end
        end
        //else
        //// verilator lint_off WIDTH
        //if (Operation == "NOR") begin : gen_nor
        //// verilator lint_on  WIDTH
        //    always_comb begin
        //        for(int unsigned i=1; i < InputCount; i=i+1) begin
        //            partial_reduction[i] = ~(partial_reduction[i-1] | bits_in[i]);
        //        end
        //    end
        //end
        //else
        //// verilator lint_off WIDTH
        //if (Operation == "XOR") begin : gen_xor
        //// verilator lint_on  WIDTH
        //    always_comb begin
        //        for(int unsigned i=1; i < InputCount; i=i+1) begin
        //            partial_reduction[i] = partial_reduction[i-1] ^ bits_in[i];
        //        end
        //    end
        //end
        //else
        //// verilator lint_off WIDTH
        //if (Operation == "XNOR") begin : gen_xnor
        //// verilator lint_on  WIDTH
        //    always_comb begin
        //        for(int unsigned i=1; i < InputCount; i=i+1) begin
        //            partial_reduction[i] = ~(partial_reduction[i-1] ^ bits_in[i]);
        //        end
        //    end
        //end

    endgenerate
endmodule
