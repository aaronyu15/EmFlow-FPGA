`ifndef EVT_AGENT_DRIVER
`define EVT_AGENT_DRIVER

class evt_agent_driver extends uvm_driver #(evt_agent_transaction);


    `uvm_component_utils(evt_agent_driver)

    evt_agent_transaction       trans;
    virtual evt_agent_interface m_evt_if;


    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual evt_agent_interface)::get(this, "", "m_evt_if", m_evt_if)) `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".m_evt_if"});

    endfunction : build_phase


    virtual task run_phase(uvm_phase phase);
        evt_agent_transaction obj;
        m_evt_if.cb.axis_tvalid <= 0;
        m_evt_if.cb.axis_tdata <= 0;
        m_evt_if.cb.axis_tlast <= 0;
        forever begin
            seq_item_port.get_next_item(obj);
            //`uvm_info(get_full_name(), $sformatf("Received transaction"), UVM_LOW);
            //obj.convert2string();

            drive(obj);
            stall(obj);

            seq_item_port.item_done();
        end
    endtask : run_phase


    task drive(evt_agent_transaction obj);
        logic [63:0] tdata;
        logic [3:0] evt_type;
        logic [27:0] evt_timestamp;
        logic [10:0] evt_x;
        logic [10:0] evt_y;
        logic [31:0] evt_valid;

        case (obj.evt_type)
            evt_agent_transaction::EVT_POS:       evt_type = 4'b0000;
            evt_agent_transaction::EVT_NEG:       evt_type = 4'b0001;
            evt_agent_transaction::EVT_TIME_HIGH: evt_type = 4'b1000;
            default:                              evt_type = 4'b0000;
        endcase

        if (obj.evt_type == evt_agent_transaction::EVT_TIME_HIGH) begin
            evt_timestamp = obj.evt_timestamp[27:0];
        end else begin
            evt_timestamp = obj.evt_timestamp[5:0];
        end

        evt_x = obj.evt_x[10:0];
        evt_y = obj.evt_y[10:0];
        evt_valid = obj.evt_valid[31:0];

        if (obj.evt_type == evt_agent_transaction::EVT_TIME_HIGH) begin
            tdata = {evt_type, evt_timestamp[27:0], {32{1'b0}}};
        end else begin
            tdata = {evt_type, evt_timestamp[5:0], evt_x, evt_y, evt_valid};
        end

        m_evt_if.cb.axis_tvalid <= 1;
        m_evt_if.cb.axis_tdata <= tdata;
        @(m_evt_if.cb);

        while(!m_evt_if.cb.axis_tready) begin
            @(m_evt_if.cb);
        end

        m_evt_if.cb.axis_tvalid <= 0;
        m_evt_if.cb.axis_tdata <= 0;

    endtask


    task stall(evt_agent_transaction obj);
        int temp = $urandom_range(5, 50);
        repeat (temp) @(m_evt_if.cb);
    endtask


endclass : evt_agent_driver

`endif





