// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

import design_pkg::*;
`default_nettype none

module image_buffer (
    input wire clk,
    input wire rstn,
    input wire en,

    input  wire buf_swap,
    output logic buf_swap_ack,

    input  wire      evt_data_valid,
    input  evt_data_t evt_data,
    output logic      evt_data_ready,

    input wire read_reset, // high when flow head is reading, elicit a memory wipe
    input  wire [IMG_AWIDTH-1:0] addr_readout,
    input  wire              addr_readout_valid,
    output logic [IMG_DWIDTH-1:0] data_readout,
    output logic              data_readout_valid

);

    // wr_state machine for handling input event data
    typedef enum {
        IDLE,
        CHECK_TYPE,
        DECODE_VALID,
        CALCULATE_BLOCK,
        CALCULATE_ADDR,
        READ,
        WRITE
    } wr_state_t;
    wr_state_t wr_state, wr_state_next;

    evt_data_t evt_data_reg;
    logic [31:0] x_valid_reg;

    logic [8:0] x_s, y_s;
    logic [3:0] type_s;

    logic [8:0] block_x;
    logic [8:0] block_y;

    logic [IMG_AWIDTH-1:0] block_addr;

    // Two URAMs
    logic mem_en_u0, mem_en_u1;
    logic mem_en_update, mem_en_readout, mem_en_readout_d;

    logic wea_u0, wea_u1;
    logic wea_update, wea_readout;
    logic [IMG_AWIDTH-1:0] addra_u0, addra_u1;
    logic [IMG_AWIDTH-1:0] addra_update, addra_readout;
    logic [IMG_DWIDTH-1:0] dina_u0, dina_u1;
    logic [IMG_DWIDTH-1:0] dina_update, dina_readout;
    logic [IMG_AWIDTH-1:0] addrb_u0, addrb_u1;
    logic [IMG_AWIDTH-1:0] addrb_update, addrb_readout;
    logic [IMG_DWIDTH-1:0] doutb_u0, doutb_u1;
    logic [IMG_DWIDTH-1:0] doutb_update, doutb_readout;

    logic validb_u0, validb_u1;
    logic validb_update, validb_readout;

    logic buf_swap_reg;
    logic buf_sel;


    always_ff @(posedge clk) begin
        if (!rstn) begin
            wr_state <= IDLE;
        end else begin
            wr_state <= wr_state_next;
        end
    end

    always_comb begin : state_update
        wr_state_next  = wr_state;
        evt_data_ready = 1'b0;

        case (wr_state)
            IDLE: begin
                evt_data_ready = 1'b1;
                if (evt_data_valid && en) begin
                    // who on earth put this here evt_data_ready = 1'b0;
                    wr_state_next = CHECK_TYPE;
                end
            end
            CHECK_TYPE: begin
                if (type_s == 4'b0000 || type_s == 4'b0001) wr_state_next = DECODE_VALID;
                else wr_state_next = IDLE;
            end
            DECODE_VALID: begin
                wr_state_next = CALCULATE_BLOCK;
            end
            CALCULATE_BLOCK: begin
                wr_state_next = CALCULATE_ADDR;
            end
            CALCULATE_ADDR: begin
                wr_state_next = READ;
            end
            READ: begin
                if (validb_update)
                    wr_state_next = WRITE;
            end
            WRITE: begin
                wr_state_next = IDLE;
            end
        endcase
    end



    assign x_s = evt_data_reg.x;
    assign y_s = evt_data_reg.y;
    assign type_s = evt_data_reg.evt_type;


    always_ff @(posedge clk) begin : evt_data_update
        if (!rstn) begin
            evt_data_reg <= '0;
        end else begin
            mem_en_update <= 1'b0;
            wea_update <= 1'b0;
            mem_en_readout_d <= mem_en_readout;
            case (wr_state)

                IDLE: begin
                    if (evt_data_valid) begin
                        evt_data_reg <= evt_data;
                        x_valid_reg <= evt_data.x_valid;
                    end
                end
                CHECK_TYPE: begin
                end
                DECODE_VALID: begin
                end
                CALCULATE_BLOCK: begin
                    block_x <= x_s >> 5;
                    block_y <= y_s;
                end
                CALCULATE_ADDR: begin
                    block_addr <= block_y * 10 + block_x;
                end
                READ: begin
                    addrb_update  <= block_addr;
                    mem_en_update <= 1'b1;
                end
                WRITE: begin
                    wea_update <= 1'b1;
                    addra_update <= block_addr;
                    dina_update <=  doutb_update | x_valid_reg;
                    mem_en_update <= 1'b1;

                end
            endcase
        end
    end

    always_ff @(posedge clk) begin : buf_swap_switch
        if (!rstn) begin
            buf_swap_reg <= 1'b0;
            buf_sel <= 1'b0;
            buf_swap_ack <= 1'b0;
        end else begin
            buf_swap_reg <= buf_swap;
            buf_swap_ack <= 1'b0;
            if (buf_swap_reg ^ buf_sel && wr_state == IDLE) begin
                buf_sel <= ~buf_sel;
                buf_swap_ack <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            addra_readout <= '0;
            wea_readout <= 1'b0;
            dina_readout <= '0;
        end else begin
            addra_readout <= addr_readout;
            wea_readout <= 1'b0;
            if (read_reset && addr_readout_valid) begin
                wea_readout <= 1'b1;
                dina_readout <= '0;
            end
        end
    end


    // Mux for memory
    assign mem_en_u0 = ~buf_sel ? mem_en_update : (mem_en_readout | mem_en_readout_d);
    assign mem_en_u1 = buf_sel ? mem_en_update : (mem_en_readout | mem_en_readout_d);

    assign wea_u0 = ~buf_sel ? wea_update : wea_readout;
    assign wea_u1 = buf_sel ? wea_update : wea_readout;

    assign addrb_u0 = ~buf_sel ? addrb_update : addrb_readout;
    assign addrb_u1 = buf_sel ? addrb_update : addrb_readout;

    assign validb_update = ~buf_sel ? validb_u0 : validb_u1;
    assign validb_readout = buf_sel ? validb_u0 : validb_u1;

    assign doutb_update = ~buf_sel ? doutb_u0 : doutb_u1;
    assign doutb_readout = buf_sel ? doutb_u0 : doutb_u1;

    assign addra_u0 = ~buf_sel ? addra_update : addra_readout;
    assign addra_u1 = buf_sel ? addra_update : addra_readout;

    assign dina_u0 = ~buf_sel ? dina_update : dina_readout;
    assign dina_u1 = buf_sel ? dina_update : dina_readout;

    /// Assign to general readout names
    assign data_readout = doutb_readout;
    assign data_readout_valid = validb_readout;
    assign mem_en_readout = addr_readout_valid;
    assign addrb_readout = addr_readout;

    // use data width of 32 to match feature map reader
    ram_image u0 (
        .clk   (clk),
        .mem_en(mem_en_u0),

        .wea  (wea_u0),
        .addra(addra_u0),
        .dina (dina_u0),

        .addrb (addrb_u0),
        .doutb (doutb_u0),
        .validb(validb_u0)
    );

    ram_image  u1 (
        .clk   (clk),
        .mem_en(mem_en_u1),

        .wea  (wea_u1),
        .addra(addra_u1),
        .dina (dina_u1),

        .addrb (addrb_u1),
        .doutb (doutb_u1),
        .validb(validb_u1)
    );




endmodule
