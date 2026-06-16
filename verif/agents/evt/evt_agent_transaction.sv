`ifndef EVT_AGENT_TRANSACTION
`define EVT_AGENT_TRANSACTION

class evt_agent_transaction extends uvm_sequence_item;

    // EVT2.1 CD event fields
    typedef enum {
        EVT_POS,
        EVT_NEG,
        EVT_TIME_HIGH
    } evt_type_e;

    rand evt_type_e          evt_type;
    rand int unsigned        evt_timestamp;
    rand int unsigned        evt_x;
    rand int unsigned        evt_y;
    rand logic        [31:0] evt_valid;

    `uvm_object_utils_begin(evt_agent_transaction)
        `uvm_field_enum(evt_type_e, evt_type, UVM_ALL_ON)
        `uvm_field_int(evt_timestamp, UVM_ALL_ON)
        `uvm_field_int(evt_x, UVM_ALL_ON)
        `uvm_field_int(evt_y, UVM_ALL_ON)
        `uvm_field_int(evt_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "evt_agent_transaction");
        super.new(name);
        `uvm_info(get_type_name(), $sformatf("Creating transaction"), UVM_DEBUG)
    endfunction

    function void pre_randomize();
    endfunction

    function string convert2string();
    endfunction

    constraint evt_x_c {
        evt_x inside {[0 : `X_MAX - 1]};
        evt_x % 32 == 0;
    }

    constraint evt_y_c {evt_y inside {[0 : `Y_MAX - 1]};}

    constraint evt_ts_c0 {
        if (evt_type == EVT_TIME_HIGH)
        evt_timestamp inside {[28'h0 : 28'hfff_ffff]};
        else
        evt_timestamp inside {[6'h0 : 6'h3f]};
    }

    constraint evt_v_c {
        evt_valid inside {[32'h1 : 32'hffff_ffff]};
    }



endclass


`endif


