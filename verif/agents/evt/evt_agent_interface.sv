`ifndef EVT_AGENT_INTERFACE
`define EVT_AGENT_INTERFACE

interface evt_agent_interface (
    input logic aclk,
    aresetn
);
    parameter C_AXIS_TDATA_WIDTH = 64;
    typedef enum logic [3:0] {
        EVT_POS = 4'b0001,
        EVT_NEG = 4'b0000,
        EVT_TIME_HIGH = 4'b1000
    } evt_type_e;

    logic [C_AXIS_TDATA_WIDTH-1:0] axis_tdata;
    logic axis_tlast;
    logic axis_tvalid;
    logic axis_tready;

    evt_type_e evt_type;
    logic [27:0] evt_timestamp;
    logic [10:0] evt_x;
    logic [10:0] evt_y;
    logic [31:0] evt_valid;

    clocking cb @(posedge aclk);
        default input #1step output #0;
        output axis_tdata;
        output axis_tlast;
        output axis_tvalid;
        input axis_tready;
    endclocking


    always @(*) begin
        evt_type = evt_type_e'(axis_tdata[63:60]);
        if (evt_type == EVT_TIME_HIGH) begin
            evt_timestamp = axis_tdata[59:32];
            evt_x = 'z;
            evt_y = 'z;
            evt_valid = 'z;
        end else begin
            evt_timestamp = axis_tdata[59:54];
            evt_x = axis_tdata[53:43];
            evt_y = axis_tdata[42:32];
            evt_valid = axis_tdata[31:0];
        end
    end



endinterface

`endif
