`timescale 1 ns / 1 ps

module flow_s_axilite #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32
) (
    input wire aclk,
    input wire aresetn,

    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
    input wire                            s_axi_awvalid,
    output logic                            s_axi_awready,

    input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
    input wire                            s_axi_wvalid,
    output logic                            s_axi_wready,

    output logic [1 : 0] s_axi_bresp,
    output logic         s_axi_bvalid,
    input wire         s_axi_bready,

    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
    input wire                            s_axi_arvalid,
    output logic                            s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
    output logic [                   1 : 0] s_axi_rresp,
    output logic                            s_axi_rvalid,
    input wire                            s_axi_rready,

    output logic        en,
    input  wire         busy,
    output logic        enable_count,
    input  wire  [31:0] event_count,
    input  wire  [31:0] busy_count,
    input  wire  [31:0] idle_count,
    input  wire  [31:0] inference_count,
    input  wire  [31:0] layer_e1_count,
    input  wire  [31:0] layer_e2_count,
    input  wire  [31:0] layer_m1_count,
    input  wire  [31:0] layer_m2_count,
    input  wire  [31:0] layer_m3_count,
    input  wire  [31:0] layer_m4_count,
    input  wire  [31:0] layer_d1_count,
    input  wire  [31:0] layer_h_count,
    input  wire  [31:0] layer_h_stall,
    output logic [31:0] timer_count,

    input  wire  [31:0] layer_e1_spike_count,
    input  wire  [31:0] layer_e2_spike_count,
    input  wire  [31:0] layer_m1_spike_count,
    input  wire  [31:0] layer_m2_spike_count,
    input  wire  [31:0] layer_m3_spike_count,
    input  wire  [31:0] layer_m4_spike_count,
    input  wire  [31:0] layer_d1_spike_count
);

    // AXI4LITE signals
    logic [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    logic axi_awready;
    logic axi_wready;
    logic [1 : 0] axi_bresp;
    logic axi_bvalid;
    logic [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    logic axi_arready;
    logic [1 : 0] axi_rresp;
    logic axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 4; // 2^(n+1) = number of registers
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    //-- Number of Slave registers
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;  // 0x0 0: en, 1: busy
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;  // 0x4 0: enable_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;  // 0x8 event_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;  // 0xc busy_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;  // 0x10 idle_count

    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;  // 0x14 number of complete inferences completed
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg6;  // 0x18 layer_e1_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg7;  // 0x1c layer_e2_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg8;  // 0x20 layer_m1_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg9;  // 0x24 layer_m2_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg10;  // 0x28 layer_m3_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg11; // 0x2c layer_m4_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg12;  // 0x30 layer_d1_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg13;  // 0x34 layer_head_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg14;  // 0x38 verify readability 
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg15;  // 0x3c set timer count in us
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg16;  // 0x40 layer_head stall time


    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg17;  // 0x44 layer_e1_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg18;  // 0x48 layer_e2_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg19;  // 0x4c layer_m1_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg20;  // 0x50 layer_m2_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg21;  // 0x54 layer_m3_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg22;  // 0x58 layer_m4_spike_count
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg23;  // 0x5c layer_d1_spike_count

    integer byte_index;


    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            slv_reg2  <= 0;
            slv_reg3  <= 0;
            slv_reg4  <= 0;
            slv_reg5  <= 0;
            slv_reg6  <= 0;
            slv_reg7  <= 0;
            slv_reg8  <= 0;
            slv_reg9  <= 0;
            slv_reg10 <= 0;
            slv_reg11 <= 0;
            slv_reg12 <= 0;
            slv_reg13 <= 0;
            slv_reg14 <= 0;
            slv_reg16 <= 0;

            slv_reg17 <= 0;
            slv_reg18 <= 0;
            slv_reg19 <= 0;
            slv_reg20 <= 0;
            slv_reg21 <= 0;
            slv_reg22 <= 0;
            slv_reg23 <= 0;
        end else begin
            en <= slv_reg0[0];

            enable_count <= slv_reg1[0];

            slv_reg2 <= event_count;
            slv_reg3 <= busy_count;
            slv_reg4 <= idle_count;
            slv_reg5 <= inference_count;
            slv_reg6 <= layer_e1_count;
            slv_reg7 <= layer_e2_count;
            slv_reg8 <= layer_m1_count;
            slv_reg9 <= layer_m2_count;
            slv_reg10 <= layer_m3_count;
            slv_reg11 <= layer_m4_count;
            slv_reg12 <= layer_d1_count;
            slv_reg13 <= layer_h_count;
            slv_reg14 <= 32'hDEADBEEF;  // for testing readability of registers

            slv_reg16 <= layer_h_stall;
            slv_reg17 <= layer_e1_spike_count;
            slv_reg18 <= layer_e2_spike_count;
            slv_reg19 <= layer_m1_spike_count;
            slv_reg20 <= layer_m2_spike_count;
            slv_reg21 <= layer_m3_spike_count;
            slv_reg22 <= layer_m4_spike_count;
            slv_reg23 <= layer_d1_spike_count;

            timer_count <= slv_reg15;
        end
    end

    // I/O Connections assignments

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;
    //state machine varibles 
    //State machine local parameters
    typedef enum {Widle, Waddr, Wdata} write_state_t;
    typedef enum {Ridle, Raddr, Rdata} read_state_t;

    write_state_t state_write;
    read_state_t state_read;
    // Implement Write state machine
    // Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_awready <= 0;
            axi_wready  <= 0;
            axi_bvalid  <= 0;
            axi_bresp   <= 0;
            axi_awaddr  <= 0;
            state_write <= Widle;
        end else begin
            case (state_write)
                Widle: begin
                    if (aresetn == 1'b1) begin
                        axi_awready <= 1'b1;
                        axi_wready  <= 1'b1;
                        state_write <= Waddr;
                    end else state_write <= state_write;
                end
                Waddr:        //At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state                                 
                 begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        axi_awaddr <= s_axi_awaddr;
                        if (s_axi_wvalid) begin
                            axi_awready <= 1'b1;
                            state_write <= Waddr;
                            axi_bvalid  <= 1'b1;
                        end else begin
                            axi_awready <= 1'b0;
                            state_write <= Wdata;
                            if (s_axi_bready && axi_bvalid) axi_bvalid <= 1'b0;
                        end
                    end else begin
                        state_write <= state_write;
                        if (s_axi_bready && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
                Wdata:        //At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length                                 
                 begin
                    if (s_axi_wvalid) begin
                        state_write <= Waddr;
                        axi_bvalid  <= 1'b1;
                        axi_awready <= 1'b1;
                    end else begin
                        state_write <= state_write;
                        if (s_axi_bready && axi_bvalid) axi_bvalid <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.


    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg15 <= 5000; // default 5 ms
        end else begin
            slv_reg0[1] <= busy;

            if (s_axi_wvalid) begin
                case ((s_axi_awvalid) ? s_axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                    5'h0: slv_reg0 <= {30'b0, slv_reg0[1], s_axi_wdata[0]};  // only en is writable, other registers are read-only
                    5'h1: slv_reg1 <= {31'b0, s_axi_wdata[0]};  // Write 1 bit for stop count

                    5'hF: slv_reg15 <= s_axi_wdata;  // Write timer count
                    default: begin
                    end
                endcase
            end
        end
    end

    // Implement read state machine
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            //asserting initial values to all 0's during reset                                       
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 1'b0;
            state_read  <= Ridle;
        end else begin
            case (state_read)
                Ridle:     //Initial state inidicating reset is done and ready to receive read/write transactions                                       
                  begin
                    if (aresetn == 1'b1) begin
                        state_read  <= Raddr;
                        axi_arready <= 1'b1;
                    end else state_read <= state_read;
                end
                Raddr:        //At this state, slave is ready to receive address along with corresponding control signals                                       
                  begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        state_read  <= Rdata;
                        axi_araddr  <= s_axi_araddr;
                        axi_rvalid  <= 1'b1;
                        axi_arready <= 1'b0;
                    end else state_read <= state_read;
                end
                Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                       
                  begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        axi_rvalid  <= 1'b0;
                        axi_arready <= 1'b1;
                        state_read  <= Raddr;
                    end else state_read <= state_read;
                end
            endcase
        end
    end

    assign s_axi_rdata = (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h0) ? slv_reg0 : 
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h1) ? slv_reg1 : 
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h2) ? slv_reg2 : 
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h3) ? slv_reg3 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h4) ? slv_reg4 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h5) ? slv_reg5 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h6) ? slv_reg6 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h7) ? slv_reg7 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h8) ? slv_reg8 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h9) ? slv_reg9 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hA) ? slv_reg10 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hB) ? slv_reg11 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hC) ? slv_reg12 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hD) ? slv_reg13 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hE) ? slv_reg14 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'hF) ? slv_reg15 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h10) ? slv_reg16 : 
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h11) ? slv_reg17 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h12) ? slv_reg18 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h13) ? slv_reg19 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h14) ? slv_reg20 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h15) ? slv_reg21 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h16) ? slv_reg22 :
                         (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 5'h17) ? slv_reg23 : 0;


endmodule
