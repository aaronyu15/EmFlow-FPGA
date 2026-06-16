`timescale 1ns/1ps

module timer_inf #(
    parameter int unsigned CLK_FREQ_HZ = 125_000_000
) (
    input  wire clk,
    input  wire arstn,             // active-low async reset
    input  wire en,
    (* dont_touch = "true" *) output logic pulse_5ms,
    input wire [31:0] timer_count
);

    localparam int unsigned CYCLES_PER_US = CLK_FREQ_HZ / 1_000_000;

    // Wide enough for timer_count * CYCLES_PER_US
    logic [63:0] target_cycles;
    logic [63:0] counter;

    always_ff @(posedge clk) begin
        target_cycles <= timer_count * CYCLES_PER_US;
    end

    always_ff @(posedge clk) begin
        if (!arstn) begin
            counter    <= 64'd0;
            pulse_5ms  <= 1'b0;
        end else begin
            pulse_5ms <= 1'b0;

            if (en) begin
                if (counter == target_cycles - 1) begin
                    pulse_5ms <= 1'b1;
                    counter   <= 64'd0;
                end else begin
                    counter   <= counter + 1'b1;
                end
            end else begin
                counter <= 64'd0;
            end
        end
    end

endmodule

