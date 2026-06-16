`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;

module sum (
    input  wire              clk,
    input  wire              rst_n,
    input  state_sum_t       state_sel,
    input  wire        [7:0] dim,
    output logic             readout_done,
    output logic             sum_ready,

    input wire        [        8:0] x,
    input wire        [        8:0] y,
    input wire signed [K_WIDTH-1:0] kv      [C_PCHANNELS],
    input wire                      xy_valid[C_PCHANNELS],
    input wire        [        8:0] y_line,
    input wire        [        8:0] x_line,


    output logic        [          8:0] sum_x,
    output logic        [          8:0] sum_y,
    output logic signed [SUM_WIDTH-1:0] sum_out  [C_PCHANNELS],
    output logic                        sum_valid,

    input wire done_proc_in,
    output logic done_proc_out

);

    // synthesis translate_off
    logic [17:0] yx_concat;
    assign yx_concat = {y, x};
    // synthesis translate_on

    logic [8:0] x_reg[5];

    logic [8:0] y_reg;

    logic signed [K_WIDTH-1:0] kv_reg[5][C_PCHANNELS];

    logic valid_reg[5][C_PCHANNELS];
    logic [4:0] any_valid;
    logic [3:0] any_valid_reg;

    logic        [7:0] dim_reg;

    logic ram_we;

    logic ram_en[5];
    logic res;

    logic [SUM_AWIDTH-1:0] ram_addra;
    logic [SUM_DWIDTH-1:0] ram_dina;
    // synthesis translate_off
    logic signed [SUM_WIDTH-1:0] ram_dina_kv[C_PCHANNELS];
    // synthesis translate_on

    logic [SUM_AWIDTH-1:0] ram_addrb[5];
    logic [SUM_DWIDTH-1:0] ram_doutb;
    // synthesis translate_off
    logic signed [SUM_WIDTH-1:0] ram_doutb_kv[C_PCHANNELS];
    // synthesis translate_on

    logic [SUM_AWIDTH-1:0] ram40_addr;
    logic [8:0] ram40_x;
    logic [8:0] ram40_y;

    logic [SUM_AWIDTH-1:0] ram80_addr;
    logic [8:0] ram80_x;
    logic [8:0] ram80_y;

    state_sum_t state, state_next;
    state_sum_t state_sel_d;

    logic [8:0] y_wr_out;
    logic [8:0] y_rd_out;

    logic [1:0] y_wr_line[6];
    logic [1:0] y_rd_line;

    logic [3:0][159:0] buffer_hit;

    logic any[4][4];
    logic [7:0] idx[4][4];
    logic any_reg[4][4];
    logic [7:0] idx_reg[4][4];

    logic [1:0] hit_column;

    logic temp_valid[4];
    logic [8:0] temp_x_reg[4];
    logic [8:0] temp_y_reg[4];

    logic stall;

    logic done_proc_sticky;


    // synthesis translate_off
    assign ram_dina_kv = '{
            ram_dina[0*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[1*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[2*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[3*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[4*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[5*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[6*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[7*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[8*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[9*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[10*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[11*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[12*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[13*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[14*SUM_WIDTH+:SUM_WIDTH],
            ram_dina[15*SUM_WIDTH+:SUM_WIDTH]
        };

    assign ram_doutb_kv = '{
            ram_doutb[0*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[1*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[2*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[3*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[4*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[5*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[6*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[7*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[8*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[9*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[10*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[11*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[12*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[13*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[14*SUM_WIDTH+:SUM_WIDTH],
            ram_doutb[15*SUM_WIDTH+:SUM_WIDTH]
        };


    // synthesis translate_on



    typedef enum {
        TEMP_WRITE,
        TEMP_READ
    } temp_buff_state_t;

    temp_buff_state_t temp_state, temp_state_next;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= SUM_IDLE;
            state_sel_d <= SUM_IDLE;
            temp_state <= TEMP_WRITE;
        end else begin
            state <= state_next;
            temp_state <= temp_state_next;

            state_sel_d <= state_sel;
        end
    end


    always_comb begin
        state_next = state;
        temp_state_next = temp_state;
        sum_ready = 1'b0;

        case (state)
            SUM_IDLE: begin
                sum_ready = 1'b1;
                case (state_sel)
                    SUM_IDLE:       begin state_next = SUM_IDLE;    end
                    SUM_ACCUM:      begin state_next = SUM_ACCUM;   end
                    SUM_TEMP_BUFF:  begin state_next = SUM_TEMP_BUFF; end
                    default:        begin state_next = SUM_IDLE; end
                endcase
            end
            SUM_RESET: begin
                if (state_sel_d == SUM_READOUT_40) state_next = SUM_READOUT_40;
                else if (state_sel_d == SUM_READOUT_80) state_next = SUM_READOUT_80;
                else if (state_sel_d == SUM_TEMP_BUFF) state_next = SUM_TEMP_BUFF;
            end
            SUM_ACCUM: begin
                if (!(|any_valid_reg)) begin // only transition if nothing is in the pipeline
                    sum_ready = 1'b1; // note that this does not affect kernel except for in layer_e1
                    case (state_sel)
                        SUM_IDLE:       state_next = SUM_IDLE;
                        SUM_RESET:      state_next = SUM_RESET;  // IDLE then to reset to reset addra
                        SUM_ACCUM:      state_next = SUM_ACCUM;
                        SUM_READOUT_40: begin state_next = SUM_RESET; sum_ready = 1'b0; end
                        SUM_READOUT_80: begin state_next = SUM_RESET; sum_ready = 1'b0; end
                        default:        state_next = SUM_IDLE;
                    endcase
                end
            end
            SUM_READOUT_40: begin
                if (readout_done) state_next = SUM_IDLE;
            end
            SUM_READOUT_80: begin
                if (readout_done) state_next = SUM_IDLE;
            end
            SUM_TEMP_BUFF: begin
                if (state_sel == SUM_IDLE) state_next = SUM_IDLE;

                sum_ready = 1'b1;
                case (temp_state)
                    // Alternate between writing and reading when the saved y coordinate != line y coordinate
                    TEMP_WRITE: begin
                        if ((y_line >> 1) != y_wr_out) begin  // if the difference in raw y coordinates is 2
                            sum_ready = 1'b0;
                            if (!(|any_valid_reg)) // only transition if nothing is in the pipeline
                                temp_state_next = TEMP_READ;
                        end

                        // for the case where there may not be ANY input events... dont want states to get stuck
                        if(!(|any_valid_reg)) begin
                            if (done_proc_sticky) begin
                                temp_state_next = TEMP_READ;
                                //readout_done  <= 1'b1;  // if we have processed all lines, signal done
                                //done_proc_out <= 1;
                            end
                        end

                    end
                    TEMP_READ: begin
                        sum_ready = 1'b0;
                        if (y_rd_line == y_wr_line[0]) begin  // if rd_line pointer has caught up
                            temp_state_next = TEMP_WRITE;
                        end

                    end
                    default: begin
                        sum_ready = 1'b0;
                        temp_state_next = TEMP_WRITE;
                    end

                endcase
            end
            default: state_next = SUM_IDLE;
        endcase



    end


    always_comb begin
        for (int j = 0; j < 5; j++) begin
            any_valid[j] = 0;
            for (int i = 0; i < C_PCHANNELS; i++) begin
                any_valid[j] = any_valid[j] | valid_reg[j][i];
            end
        end
    end
    // delay logic
    always_ff @(posedge clk) begin
        dim_reg <= dim;

        // Same clock cycle
        x_reg[0] <= x;
        y_reg <= y;
        for (int i = 0; i < C_PCHANNELS; i++) begin
            kv_reg[0][i] <= kv[i];
            valid_reg[0][i] <= xy_valid[i];
        end

        if (y == y_wr_out) begin  // use y_wr_line[1] to indicate the tracked line being written
            y_wr_line[1] <= y_wr_line[0];
        end else if (y == y_wr_out + 1) begin
            y_wr_line[1] <= y_wr_line[0] + 1'b1;
        end

        for (int i = 2; i < 6; i++) begin
            y_wr_line[i] <= y_wr_line[i-1];
        end


        any_valid_reg[0] <= any_valid[0];
        // same clock cycle
        for (int i = 1; i < 5; i++) begin
            x_reg[i]  <= x_reg[i-1];
            ram_en[i] <= ram_en[i-1];
            for (int j = 0; j < C_PCHANNELS; j++) begin
                kv_reg[i][j] <= kv_reg[i-1][j];
                valid_reg[i][j] <= valid_reg[i-1][j];
            end
            ram_addrb[i] <= ram_addrb[i-1];
        end
        for (int i = 1; i < 4; i++) begin
            any_valid_reg[i] <= any_valid[i];
        end

        if (state == SUM_RESET) begin
            for (int i = 1; i < 5; i++) begin
                ram_addrb[i] <= 0;
                ram_en[i] <= 0;
            end
        end


    end

    logic [1:0] y_wr_line_ovflow;
    // main write FSM
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // reset logic for outputs and internal registers
            readout_done <= 1'b0;
            ram_addra <= 0;

            ram_en[0] <= 1'b0;
            ram_we <= 1'b0;

            y_wr_out <= 0;
            y_wr_line[0] <= 0;
            y_rd_line <= 0;
            stall <= 1'b0;
            hit_column <= 0;
            sum_valid <= 0;
            temp_valid <= '{default: 0};
            done_proc_sticky <= 1'b0;
        end else begin
            if (done_proc_in) begin
                done_proc_sticky <= 1'b1;
            end

            ram_en[0] <= 1'b0;
            ram_we <= 1'b0;
            readout_done <= 1'b0;

            temp_valid[0] <= 1'b0;
            // two
            for (int i = 1; i < 4; i++) begin
                temp_valid[i] <= temp_valid[i-1];
                temp_x_reg[i] <= temp_x_reg[i-1];
                temp_y_reg[i] <= temp_y_reg[i-1];
            end

            // used by SUM_TEMP_BUFF state
            sum_x <= temp_x_reg[2];
            sum_y <= temp_y_reg[2];
            sum_valid <= temp_valid[3];
            for (int i = 0; i < C_PCHANNELS/2; i++) begin
                sum_out[i] <= ram_doutb[i*SUM_WIDTH+:SUM_WIDTH];
            end

            case (state)
                SUM_IDLE: begin
                    ram_addra <= 0;
                    done_proc_sticky <= 1'b0;
                    done_proc_out <= 1'b0;

                end
                SUM_RESET: begin
                    // reset logic for outputs and internal registers
                    ram_addra <= 0;
                    ram_addrb[0] <= 0;
                    ram_en[0] <= 0;
                    ram_we <= 1'b0;

                    y_wr_out <= 0;
                    y_wr_line[0] <= 0;
                    y_rd_line <= 0; // reset for next timestep
                    done_proc_sticky <= 1'b0;
                    done_proc_out <= 1'b0;
                end
                SUM_TEMP_BUFF: begin
                    ram_en[0] <= 1'b1;

                    case (temp_state)
                        TEMP_WRITE: begin
                            // y_line = raw y line coordinate from kernel (320)
                            // y_wr_out = stored y_line >> 1 
                            if (!(|any_valid_reg)) begin
                                if ((y_line >> 1) - y_wr_out == 1) begin  // if the difference in raw y coordinates is 2
                                    y_wr_out <= y_line >> 1;
                                    y_wr_line[0] <= y_wr_line[0] + 2'b1;
                                    y_rd_out <= y_wr_out;
                                end else if ((y_line >> 1) - y_wr_out > 1) begin
                                    y_wr_out <= y_line >> 1;
                                    y_wr_line[0] <= y_wr_line[0] + 2'b10;
                                    y_rd_out <= y_wr_out;
                                end
                            end

                            if (y_reg == y_wr_out) begin
                                y_wr_line_ovflow = y_wr_line[0];
                                ram_addrb[0] <= y_wr_line_ovflow * 160 + x_reg[0];  // calculate address based on x and y
                            end else if (y_reg == y_wr_out + 1'b1) begin
                                y_wr_line_ovflow = y_wr_line[0] + 1'b1;
                                ram_addrb[0] <= y_wr_line_ovflow * 160 + x_reg[0];  // calculate address based on x and y
                            end  // synced with valid_reg[1]

                            // three stage pipeline
                            ram_addra <= ram_addrb[3];  // addrb is one delayed since it comes from x_reg[0]
                            ram_we <= res;
                            for (int i = 0; i < C_PCHANNELS/2; i++) begin
                                if (valid_reg[4][i]) begin
                                    ram_dina[i*SUM_WIDTH+:SUM_WIDTH] <= $signed(ram_doutb[i*SUM_WIDTH+:SUM_WIDTH]) + $signed(kv_reg[4][i]);
                                end

                            end


                        end
                        TEMP_READ: begin

                            // one
                            ram_addra <= ram_addrb[0];
                            ram_we <= temp_valid[0];
                            ram_dina <= '{default: 'b0};

                            if (y_rd_line != y_wr_line[0]) begin
                                stall <= 1'b1;
                                if (any_reg[y_rd_line][hit_column]) begin
                                    if (stall) begin
                                        ram_addrb[0]  <= y_rd_line * 160 + idx_reg[y_rd_line][hit_column];  // calculate address based on x and y
                                        temp_x_reg[0] <= idx_reg[y_rd_line][hit_column];
                                        temp_y_reg[0] <= y_rd_out;
                                        temp_valid[0] <= 1'b1;
                                    end
                                    stall <= ~stall;
                                end else if (hit_column > 2) begin
                                    y_rd_line  <= y_rd_line + 1;
                                    y_rd_out   <= y_rd_out + 1;
                                    hit_column <= hit_column + 1;
                                end else begin
                                    hit_column <= hit_column + 1;
                                end
                            end else begin
                                if (done_proc_sticky) begin
                                    readout_done  <= 1'b1;  // if we have processed all lines, signal done
                                    done_proc_out <= 1;
                                end
                            end

                        end

                        default: begin
                        end
                    endcase


                end
                SUM_ACCUM: begin
                    ram_en[0] <= 1'b1;

                    ram_addrb[0] <= y_reg * dim_reg + x_reg[0];  // register dim to improve timing

                    // three stage pipeline
                    ram_addra <= ram_addrb[3];  // addrb is one delayed since it comes from x_reg[0]
                    ram_we <= res;

                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        if (valid_reg[4][i]) begin
                            ram_dina[i*SUM_WIDTH+:SUM_WIDTH] <= $signed(ram_doutb[i*SUM_WIDTH+:SUM_WIDTH]) + $signed(kv_reg[4][i]);
                        end
                    end

                end
                SUM_READOUT_40: begin
                    //// set sum_valid to 1 for the appropriate channels when their sums are ready to be read out
                    ram_en[0] <= 1'b1;

                    // one
                    ram_addrb[0] <= ram_addrb[0] + ram_en[0];

                    // two
                    ram40_addr <= ram_addrb[1];

                    // four
                    sum_x <= ram40_x;  // use ROM one for 40x40m one for 80x80
                    sum_y <= ram40_y;  // use ROM
                    sum_valid <= ram_en[3];
                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        sum_out[i] <= $signed(ram_doutb[i*13+:13]);
                    end

                    if (ram_addrb[3] >= C_W * C_H - 1) begin
                        readout_done <= 1'b1;
                        done_proc_out <= 1'b1;
                    end
                    if (state_next == SUM_IDLE) sum_valid <= 1'b0;

                    // reset path
                    ram_addra <= ram_addrb[0];
                    ram_we <= ram_en[0];
                    ram_dina <= '{default: 192'b0};

                end
                SUM_READOUT_80: begin

                    //// set sum_valid to 1 for the appropriate channels when their sums are ready to be read out
                    ram_en[0] <= 1'b1;

                    // one
                    ram_addrb[0] <= ram_addrb[0] + ram_en[0];

                    // two
                    ram80_addr <= ram_addrb[1];

                    // four
                    sum_x <= ram80_x;  // use ROM one for 40x40m one for 80x80
                    sum_y <= ram80_y;  // use ROM
                    sum_valid <= ram_en[3];
                    for (int i = 0; i < C_PCHANNELS/2; i++) begin
                        sum_out[i] <= $signed(ram_doutb[i*SUM_WIDTH+:SUM_WIDTH]);
                    end

                    if (ram_addrb[3] >= 4 * C_W * C_H - 1) begin
                        readout_done <= 1'b1;
                        done_proc_out <= 1'b1;
                    end
                    if (state_next == SUM_IDLE) sum_valid <= 1'b0;

                    // reset path
                    ram_addra <= ram_addrb[0];
                    ram_we <= ram_en[0];
                    ram_dina <= '{default: 'b0};


                end
            endcase
        end
    end

    always_ff @(posedge clk) begin

        //write to buffer_hit
        if (res) buffer_hit[y_wr_line[5]][x_reg[4]] <= 1'b1;

        // clear buffer hit
        if (y_rd_line != y_wr_line[0]) begin
            if (any_reg[y_rd_line][hit_column]) begin
                buffer_hit[y_rd_line][idx_reg[y_rd_line][hit_column]] <= 1'b0;
            end
        end
    end


    always_comb begin
        res = 0;
        for (int i = 0; i < C_PCHANNELS; i++) begin
            res = res | valid_reg[4][i];
        end

        idx[0][0] = encoder(buffer_hit[0][0+:40], any[0][0]);
        idx[0][1] = encoder(buffer_hit[0][40+:40], any[0][1]) + 40;
        idx[0][2] = encoder(buffer_hit[0][80+:40], any[0][2]) + 80;
        idx[0][3] = encoder(buffer_hit[0][120+:40], any[0][3]) + 120;

        idx[1][0] = encoder(buffer_hit[1][0+:40], any[1][0]);
        idx[1][1] = encoder(buffer_hit[1][40+:40], any[1][1]) + 40;
        idx[1][2] = encoder(buffer_hit[1][80+:40], any[1][2]) + 80;
        idx[1][3] = encoder(buffer_hit[1][120+:40], any[1][3]) + 120;

        idx[2][0] = encoder(buffer_hit[2][0+:40], any[2][0]);
        idx[2][1] = encoder(buffer_hit[2][40+:40], any[2][1]) + 40;
        idx[2][2] = encoder(buffer_hit[2][80+:40], any[2][2]) + 80;
        idx[2][3] = encoder(buffer_hit[2][120+:40], any[2][3]) + 120;

        idx[3][0] = encoder(buffer_hit[3][0+:40], any[3][0]);
        idx[3][1] = encoder(buffer_hit[3][40+:40], any[3][1]) + 40;
        idx[3][2] = encoder(buffer_hit[3][80+:40], any[3][2]) + 80;
        idx[3][3] = encoder(buffer_hit[3][120+:40], any[3][3]) + 120;
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                idx_reg[i][j] <= idx[i][j];
                any_reg[i][j] <= any[i][j];
            end
        end
    end

    // uram is sized 4k x 192
    // has 16 "channels" per word, 12 bits each
    // for 40x40, need 1600 addresses
    // for 80x80, need 6400 addresses, but uses 8 channels. Store 2 pixels per address
    // port a write port b read
    ram_sum ram_sum_inst (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (ram_en[0]),

        .wea  (ram_we),
        .addra(ram_addra),
        .dina (ram_dina),

        .addrb      (ram_addrb[0]),
        .doutb      (ram_doutb),
        .doutb_valid()
    );

    rom_addr_40 rom_addr_40_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .addr(ram40_addr),
        .x   (ram40_x),
        .y   (ram40_y)
    );

    rom_addr_80 rom_addr_80_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .addr(ram80_addr),
        .x   (ram80_x),
        .y   (ram80_y)
    );

    function automatic logic [5:0] encoder(input logic [39:0] v, output logic a);
        logic [5:0] idx;
        a   = 1'b0;
        idx = '0;
        for (int k = 0; k < 40; k++) begin
            if (!a && v[k]) begin
                idx = k;
                a   = 1'b1;
            end
        end
        return idx;
    endfunction

endmodule
