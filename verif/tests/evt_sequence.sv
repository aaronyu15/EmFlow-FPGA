`ifndef EVT_AGENT_SEQUENCE
`define EVT_AGENT_SEQUENCE

class evt_sequence extends uvm_sequence #(evt_agent_transaction);

    `uvm_object_utils(evt_sequence)
    `uvm_declare_p_sequencer(evt_agent_sequencer)

    evt_agent_transaction obj;

    function new(string name="evt_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), $sformatf("Starting sequence"), UVM_LOW)

        forever begin
            obj = evt_agent_transaction::type_id::create("obj");
            assert(obj.randomize());

            start_item(obj);

            finish_item(obj);
        end
    endtask

endclass

`endif




