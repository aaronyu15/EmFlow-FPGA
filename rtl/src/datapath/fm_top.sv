`timescale 1ps / 1ps 
`default_nettype none
import design_pkg::*;

module fm_top (
    input wire clk,
    input wire rst_n,

    input  state_fm_t       state_sel,
    input  wire       [8:0] dim,          // 160,80,40
    output logic            fm_top_ready,

    input wire [8:0] x,
    input wire [8:0] y,
    input wire       xy_valid[C_PCHANNELS], // valid for each channel, but x and y are the same across channels

    input  wire  [$clog2(C_NUM_FM)-1:0] fm_rd_sel,
    input  wire  [       FM_AWIDTH-1:0] fm_addr,
    input  wire                         fm_addr_valid,
    output logic [       FM_DWIDTH-1:0] fm_dout,
    output logic                        fm_dout_valid,

    input wire done_proc_in
);

    // synthesis translate_off
    logic [17:0] yx_concat;
    assign yx_concat = {y, x};
    // synthesis translate_on

    state_fm_t state, next_state;

    logic ena[C_NUM_FM];
    logic wea[C_NUM_FM];
    logic [FM_AWIDTH-1:0] addra;
    logic [FM_DWIDTH-1:0] dina[C_NUM_FM];

    logic enb[C_NUM_FM];
    logic [FM_AWIDTH-1:0] addrb;
    logic [FM_DWIDTH-1:0] doutb[C_NUM_FM];

    logic [2:0] ww;  // word width

    logic rst_done;

    logic [4:0] any_valid;
    logic [4:0] any_valid_reg;

    logic done_proc_sticky;
    logic done_proc_pulse;
    assign done_proc_pulse = done_proc_in && !done_proc_sticky;

    genvar i_ram;  // rams for spike storage
    generate
        for (i_ram = 0; i_ram < C_NUM_FM; i_ram = i_ram + 1) begin : ram_loop

            // 2k x 32
            ram_fm u_feature_map (
                .clk  (clk),
                .rst_n(rst_n),

                // port a for writing spikes from membrane
                .ena  (ena[i_ram]),
                .wea  (wea[i_ram]),
                .addra(addra),
                .dina (dina[i_ram]),

                // port b for feature map reader
                .enb  (enb[i_ram]),
                .addrb(addrb),
                .doutb(doutb[i_ram])
            );

        end : ram_loop
    endgenerate

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= FM_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state   = state;
        fm_top_ready = 1'b0;

        case (state)
            FM_IDLE: begin
                fm_top_ready = 1'b1;
                case (state_sel)
                    FM_IDLE:  next_state = FM_IDLE;
                    FM_RESET: next_state = FM_RESET;
                    FM_WRITE: next_state = FM_WRITE;
                    FM_READ:  next_state = FM_READ;
                    default:  next_state = FM_IDLE;
                endcase
            end
            FM_RESET: begin
                if (rst_done) next_state = FM_IDLE;
            end
            FM_WRITE: begin
                if (done_proc_sticky) begin
                    fm_top_ready = 1;
                    case (state_sel)
                        FM_IDLE:  next_state = FM_IDLE;
                        FM_RESET: next_state = FM_RESET;
                        FM_WRITE: next_state = FM_WRITE;
                        FM_READ:  next_state = FM_READ;
                        default:  next_state = FM_IDLE;
                    endcase
                end
            end
            FM_READ: begin
                fm_top_ready = 1'b1;
                case (state_sel)
                    FM_IDLE:  next_state = FM_IDLE;
                    FM_RESET: next_state = FM_RESET;
                    FM_WRITE: next_state = FM_WRITE;
                    FM_READ:  next_state = FM_READ;
                    default:  next_state = FM_IDLE;
                endcase
            end
        endcase
    end


    logic [8:0] x_reg;
    logic [8:0] y_reg;
    logic xy_valid_reg[C_PCHANNELS];

    // synthesis translate_off
    logic [4:0] x_reg_idx;
    assign x_reg_idx = x_reg[4:0];
    // synthesis translate_on

    logic fm_valid_reg[2];
    logic [FM_AWIDTH-1:0] addr_d;

    logic [FM_DWIDTH:0] wr_buffer[C_PCHANNELS];
    logic [5:0] current_x_word;
    logic [7:0] current_y_word;  // not really word, more like line


    // feature map stores 160 x 5, 80 x 3 (rounded), 40 x 2 (rounded)
    // in write use ports a to write and b to read
    // in read use port b to read

    // typical: FM_IDLE -> FM_WRITE -> FM_IDLE or FM_READ -> FM_RESET -> FM_IDLE
    always_ff @(posedge clk) begin : fm_writer
        if (!rst_n) begin
            wea <= '{default: 0};
            ena <= '{default: 0};
            enb <= '{default: 0};
            addra <= 0;
            fm_dout <= 0;

            rst_done <= 0;

            current_x_word <= 0;
            current_y_word <= 0;
            wr_buffer <= '{default: 0};
            ww <= 0;

            done_proc_sticky <= 1'b0;
        end else begin
            rst_done <= 0;
            wea <= '{default: 0};
            ena <= '{default: 0};
            enb <= '{default: 0};

            if (done_proc_in) begin
                done_proc_sticky <= 1'b1;
            end

            case (state)
                FM_IDLE: begin
                    xy_valid_reg <= '{default: 0};
                    done_proc_sticky <= 1'b0;
                    current_x_word <= 0;
                    current_y_word <= 0;
                end
                FM_RESET: begin
                    wea   <= '{default: 1};
                    ena   <= '{default: 1};
                    addra <= addra + 1;
                    dina  <= '{default: 0};
                    if (addra >= (1 << FM_AWIDTH) - 1) begin
                        rst_done <= 1;
                    end
                    current_x_word <= 0;
                    wr_buffer <= '{default: 0};
                    done_proc_sticky <= 1'b0;
                end
                FM_WRITE: begin
                    ena <= '{default: 1};
                    enb <= '{default: 1};
                    wea <= '{default: 0};

                    x_reg <= x;
                    y_reg <= y;
                    xy_valid_reg <= xy_valid;

                    // store the word feature map in a buffer as neighbours are received
                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        if (xy_valid_reg[i]) begin
                            wr_buffer[i] <= wr_buffer[i] | (1 << x_reg[4:0]);
                        end
                    end

                    // detect when the selected word is changing, and write contents of buffer into memory
                    if (current_x_word != x >> 5 || current_y_word != y || done_proc_pulse) begin
                        addra <= (y_reg * ww) + (x_reg >> 5);
                        for (int i = 0; i < C_PCHANNELS; i++) begin
                            if (xy_valid_reg[i]) begin  // if current is valid, incorporate x_reg into the dina
                                dina[i] <= wr_buffer[i] | (1 << x_reg[4:0]);
                            end else begin  // if current is not valid just flush wr_buffer
                                dina[i] <= wr_buffer[i];
                            end
                            wea[i] <= 1'b1;
                            wr_buffer[i] <= 0;
                        end
                        current_x_word <= x >> 5;
                        current_y_word <= y;
                    end


                end
                FM_READ: begin

                    // address and valid
                    addrb <= fm_addr;
                    enb[fm_rd_sel] <= fm_addr_valid;
                    fm_valid_reg[0] <= fm_addr_valid;

                    // clear entries as they are read out
                    addra <= addrb;
                    ena[fm_rd_sel] <= enb[fm_rd_sel];
                    wea[fm_rd_sel] <= enb[fm_rd_sel];
                    dina[fm_rd_sel] <= 0;

                    // pipeline delay
                    fm_valid_reg[1] <= fm_valid_reg[0];

                    // output and valid
                    fm_dout_valid <= fm_valid_reg[1];
                    fm_dout <= doutb[fm_rd_sel];

                end
            endcase

            // dim should be set early on so no need to worry that it changes
            case (dim)
                320:     ww <= 5;  // 320 from instruction, but ww = 5 since stride 2
                160:     ww <= 3;  // for 80 
                80:      ww <= 2;  // for 40
                40:      ww <= 2;
                default: ww <= 0;
            endcase

        end
    end



endmodule
