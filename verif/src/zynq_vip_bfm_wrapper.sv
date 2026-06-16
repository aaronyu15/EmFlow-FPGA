import uvm_pkg::*;
`include "uvm_macros.svh"

//`define ZYNQ_VIP_0 $root.tb_top.DUT.zynq_ultra_ps_e_0.inst
`define ZYNQ_VIP_0 $root.tb_top.DUT.kv260_i.zynq_processing_system.inst

package zynq_bfm_pkg;

    // Calling API from testbench https://stackoverflow.com/questions/35660637/calling-a-task-hierarchically-without-defines
    // API "documentation" for the Zynq BFM https://docs.amd.com/v/u/en-US/ds941-zynq-ultra-ps-e-vip
    virtual class zynq_bfm_api;

        function automatic integer clogb2;
            input [31:0] value;
            begin
                value = value - 1;
                for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                    value = value >> 1;
                end
            end
        endfunction

        parameter addr_width = 40;  // maximum address width
        parameter data_width = 32;  // maximum data width.
        parameter axi_mgp_data_width = 32;

        /* local */
        parameter max_chars = 128;  // max characters for file name
        parameter mem_width = data_width / 8;  /// memory width in bytes
        parameter shft_addr_bits = clogb2(mem_width);  /// Address to be right shifted
        parameter int_width = 32;  //integre width

        /* for internal read/write APIs used for data transfers */
        parameter max_burst_len = 256;  /// maximum brst length on axi 
        parameter max_data_width = 128;  // maximum data width for internal AXI bursts 
        parameter max_burst_bits = (max_data_width * max_burst_len);  // maximum data width for internal AXI bursts 
        parameter max_burst_bytes = (max_burst_bits) / 8;  // maximum data bytes in each transfer 
        parameter max_burst_bytes_width = clogb2(max_burst_bytes);  // maximum data width for internal AXI bursts 

        parameter max_registers = 32;
        parameter max_regs_width = clogb2(max_registers);

        parameter REG_MEM = 2'b00, DDR_MEM = 2'b01, OCM_MEM = 2'b10, INVALID_MEM_TYPE = 2'b11;

        parameter ALL_RANDOM = 2'b00;
        parameter ALL_ZEROS = 2'b01;
        parameter ALL_ONES = 2'b10;

        /* AXI transfer types */
        parameter AXI_FIXED = 2'b00;
        parameter AXI_INCR = 2'b01;
        parameter AXI_WRAP = 2'b10;

        /* Exclusive Access */
        parameter AXI_NRML = 2'b00;
        parameter AXI_EXCL = 2'b01;
        parameter AXI_LOCK = 2'b10;

        /* AXI Response types */
        parameter AXI_OK = 2'b00;
        parameter AXI_EXCL_OK = 2'b01;
        parameter AXI_SLV_ERR = 2'b10;
        parameter AXI_DEC_ERR = 2'b11;

        /* Display */
        parameter DISP_INFO = "*ZYNQ_MPSoC_BFM_INFO";
        parameter DISP_WARN = "*ZYNQ_MPSoC_BFM_WARNING";
        parameter DISP_ERR = "*ZYNQ_MPSoC_BFM_ERROR";
        parameter DISP_INT_INFO = "ZYNQ_MPSoC_BFM_INT_INFO";

        /* Latency types */
        parameter BEST_CASE = 0;
        parameter AVG_CASE = 1;
        parameter WORST_CASE = 2;
        parameter RANDOM_CASE = 3;

        /* ID VALID and INVALID */
        parameter secure_access_enabled = 0;
        parameter id_invalid = 0;
        parameter id_valid = 1;

        parameter ddr_start_addr = 40'h0_0000_0000;
        parameter ddr_end_addr = 40'h0_7FFF_FFFF;
        parameter high_ddr_start_addr = 40'h8_0000_0000;

        parameter ocm_start_addr = 40'h0_FFFC_0000;
        parameter ocm_end_addr = 40'h0_FFFF_FFFF;

        parameter reg_start_addr = 40'h0_F900_0000;
        parameter reg_end_addr = 40'h0_FFF0_0000;

        parameter m_axi_gp0_baseaddr = 40'h0_A000_0000;
        parameter m_axi_gp0_highaddr = 40'h0_AFFF_FFFF;
        parameter m_axi_gp0_mid_baseaddr = 40'h4_0000_0000;
        parameter m_axi_gp0_mid_highaddr = 40'h4_FFFF_FFFF;
        parameter m_axi_gp0_high_baseaddr = 40'h10_0000_0000;
        parameter m_axi_gp0_high_highaddr = 40'h47_FFFF_FFFF;

        parameter m_axi_gp1_baseaddr = 40'h0_B000_0000;
        parameter m_axi_gp1_highaddr = 40'h0_BFFF_FFFF;
        parameter m_axi_gp1_mid_baseaddr = 40'h5_0000_0000;
        parameter m_axi_gp1_mid_highaddr = 40'h5_FFFF_FFFF;
        parameter m_axi_gp1_high_baseaddr = 40'h48_0000_0000;
        parameter m_axi_gp1_high_highaddr = 40'h7F_FFFF_FFFF;

        parameter m_axi_gp2_baseaddr = 40'h0_8000_0000;
        parameter m_axi_gp2_highaddr = 40'h0_9FFF_FFFF;

        /* for Master port APIs and AXI protocol related signal widths*/
        parameter axi_burst_len = 256;
        parameter axi_len_width = 8;
        parameter axi_size_width = 3;
        parameter axi_brst_type_width = 2;
        parameter axi_lock_width = 1;
        parameter axi_cache_width = 4;
        parameter axi_prot_width = 3;
        parameter axi_rsp_width = 2;
        parameter axi_qos_width = 4;
        parameter axi_max_mdata_width = 128;
        parameter max_transfer_bytes = 256;  // For Master APIs.
        parameter max_transfer_bytes_width = clogb2(max_transfer_bytes);  // For Master APIs.

        /* Interrupt bits supported */
        parameter irq_width = 16;

        /* API for setting the STOP_ON_ERROR*/
        pure virtual task set_stop_on_error(input int level);

        /* API for setting the verbosity for channel level info*/
        pure virtual task set_channel_level_info(input bit [1023:0] name, input int level);

        /* API for setting the verbosity for function level info*/
        pure virtual task set_function_level_info(input bit [1023:0] name, input int level);

        /* API for setting the Message verbosity */
        pure virtual task set_debug_level_info(input int LEVEL);


        /* API for setting ARQos Values */
        pure virtual task set_arqos(input bit [1023:0] name, input bit [axi_qos_width-1:0] value);

        /* API for setting AWQos Values */
        pure virtual task set_awqos(input bit [1023:0] name, input bit [axi_qos_width-1:0] value);

        /* API for por and strb reset control */
        pure virtual task por_srstb_reset(input bit por_reset_ctrl);

        /* API for soft reset control */
        pure virtual task fpga_soft_reset(input bit [data_width-1:0] reset_ctrl);

        /* API for pre-loading memories from (DDR/OCM model) */
        pure virtual task pre_load_mem_from_file(input bit [(max_chars*16)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);

        /* API for pre-loading memories (DDR/OCM) */
        pure virtual task pre_load_mem(input bit [1:0] data_type, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);

        /* API for backdoor write to memories (DDR/OCM) */
        pure virtual task write_mem(input bit [max_burst_bits-1 : 0] data, input bit [addr_width-1:0] start_addr, input bit [max_burst_bytes_width:0] no_of_bytes);

        /* read_memory */
        pure virtual task read_mem(input bit [addr_width-1:0] start_addr, input bit [max_burst_bytes_width : 0] no_of_bytes, output bit [max_burst_bits-1 : 0] data);

        /* API for backdoor read to memories (DDR/OCM) */
        pure virtual task peek_mem_to_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);

        /* API to read interrupt status */
        pure virtual task read_interrupt(output bit [irq_width-1:0] irq_status);

        /* API to wait on interrup */
        pure virtual task wait_interrupt(input bit [3:0] irq, output bit [irq_width-1:0] irq_status);

        /* API to wait for a certain match pattern*/
        pure virtual task wait_mem_update(input bit [addr_width-1:0] address, input bit [data_width-1:0] data_in, output bit [data_width-1:0] data_out);

        /* API to initiate a WRITE transaction on one of the AXI-Master ports*/
        pure virtual task write_from_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] wr_size, output bit [axi_rsp_width-1:0] response);

        /* API to initiate a READ transaction on one of the AXI-Master ports*/
        pure virtual task read_to_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] rd_size, output bit [axi_rsp_width-1:0] response);

        /* API to initiate a WRITE transaction(<= 128 bytes) on one of the AXI-Master ports*/
        pure virtual task write_data(input bit [addr_width-1:0] start_addr, input bit [max_transfer_bytes_width:0] wr_size, input bit [(max_transfer_bytes*8)-1:0] wr_data, output bit [axi_rsp_width-1:0] response);

        /* API to initiate a READ transaction(<= 128 bytes) on one of the AXI-Master ports*/
        pure virtual task read_data(input bit [addr_width-1:0] start_addr, input bit [max_transfer_bytes_width:0] rd_size, output bit [(max_transfer_bytes*8)-1:0] rd_data, output bit [axi_rsp_width-1:0] response);

        /* Hooks to call to BFM APIs */
        pure virtual task write_burst(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache,
                                      input bit [axi_prot_width-1:0] prot, input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input integer datasize, output bit [axi_rsp_width-1:0] response);

        /* Hooks to call to BFM APIs */
        pure virtual task write_burst_strb(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache,
                                           input bit [axi_prot_width-1:0] prot, input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input bit strb_en, input bit [(axi_mgp_data_width*axi_burst_len)/8-1:0] strb, input integer datasize, output bit [axi_rsp_width-1:0] response);

        pure virtual task write_burst_concurrent(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache,
                                                 input bit [axi_prot_width-1:0] prot, input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input integer datasize, output bit [axi_rsp_width-1:0] response);

        pure virtual task read_burst(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache,
                                     input bit [axi_prot_width-1:0] prot, output bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, output bit [(axi_rsp_width*axi_burst_len)-1:0] response);

        pure virtual task wait_reg_update(input bit [addr_width-1:0] addr, input bit [data_width-1:0] data_i, input bit [data_width-1:0] mask_i, input bit [int_width-1:0] time_interval, input bit [int_width-1:0] time_out, output bit [data_width-1:0] data_o);

        /* API to read register map */
        pure virtual task read_register_map(input bit [addr_width-1:0] start_addr, input bit [max_regs_width:0] no_of_registers, output bit [max_burst_bits-1 : 0] data);

        /* API to read single register */
        pure virtual task read_register(input bit [addr_width-1:0] addr, output bit [data_width-1:0] data);

        /* API to set the AXI-Slave profile*/
        pure virtual task set_slave_profile(input bit [1023:0] name, input bit [1:0] latency);
    endclass



endpackage

module zynq_vip_bfm_wrapper;
    import zynq_bfm_pkg::*;

    class wrapper extends zynq_bfm_api;

        /* API for setting the STOP_ON_ERROR*/
        task set_stop_on_error(input int level);
            `ZYNQ_VIP_0.set_stop_on_error(level);
        endtask

        /* API for setting the verbosity for channel level info*/
        task set_channel_level_info(input bit [1023:0] name, input int level);
            `ZYNQ_VIP_0.set_channel_level_info(name, level);
        endtask


        /* API for setting the verbosity for function level info*/
        task set_function_level_info(input bit [1023:0] name, input int level);
            `ZYNQ_VIP_0.set_function_level_info(name, level);
        endtask

        /* API for setting the Message verbosity */
        task set_debug_level_info(input int LEVEL);
            `ZYNQ_VIP_0.set_debug_level_info(LEVEL);
        endtask

        /* API for setting ARQos Values */
        task set_arqos(input bit [1023:0] name, input bit [axi_qos_width-1:0] value);
            `ZYNQ_VIP_0.set_arqos(name, value);
        endtask

        /* API for setting AWQos Values */
        task set_awqos(input bit [1023:0] name, input bit [axi_qos_width-1:0] value);
            `ZYNQ_VIP_0.set_awqos(name, value);
        endtask

        /* API for por and strb reset control */
        task por_srstb_reset(input bit por_reset_ctrl);
            `ZYNQ_VIP_0.por_srstb_reset(por_reset_ctrl);
        endtask

        /* API for soft reset control */
        task fpga_soft_reset(input bit [data_width-1:0] reset_ctrl);
            `ZYNQ_VIP_0.fpga_soft_reset(reset_ctrl);
        endtask

        /* API for pre-loading memories from (DDR/OCM model) */
        task pre_load_mem_from_file(input bit [(max_chars*16)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);
            `ZYNQ_VIP_0.pre_load_mem_from_file(file_name, start_addr, no_of_bytes);
        endtask

        /* API for pre-loading memories (DDR/OCM) */
        task pre_load_mem(input bit [1:0] data_type, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);
            `ZYNQ_VIP_0.pre_load_mem(data_type, start_addr, no_of_bytes);
        endtask

        /* API for backdoor write to memories (DDR/OCM) */
        task write_mem(input bit [max_burst_bits-1 : 0] data, input bit [addr_width-1:0] start_addr, input bit [max_burst_bytes_width:0] no_of_bytes);
            `ZYNQ_VIP_0.write_mem(data, start_addr, no_of_bytes);
        endtask

        /* read_memory */
        task read_mem(input bit [addr_width-1:0] start_addr, input bit [max_burst_bytes_width : 0] no_of_bytes, output bit [max_burst_bits-1 : 0] data);
            `ZYNQ_VIP_0.read_mem(start_addr, no_of_bytes, data);
        endtask

        /* API for backdoor read to memories (DDR/OCM) */
        task peek_mem_to_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] no_of_bytes);
            `ZYNQ_VIP_0.peek_mem_to_file(file_name, start_addr, no_of_bytes);
        endtask

        /* API to read interrupt status */
        task read_interrupt(output bit [irq_width-1:0] irq_status);
            `ZYNQ_VIP_0.read_interrupt(irq_status);
        endtask

        /* API to wait on interrup */
        task wait_interrupt(input bit [3:0] irq, output bit [irq_width-1:0] irq_status);
            `ZYNQ_VIP_0.wait_interrupt(irq, irq_status);
        endtask

        /* API to wait for a certain match pattern*/
        task wait_mem_update(input bit [addr_width-1:0] address, input bit [data_width-1:0] data_in, output bit [data_width-1:0] data_out);
            `ZYNQ_VIP_0.wait_mem_update(address, data_in, data_out);
        endtask

        /* API to initiate a WRITE transaction on one of the AXI-Master ports*/
        task write_from_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] wr_size, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.write_from_file(file_name, start_addr, wr_size, response);
        endtask

        /* API to initiate a READ transaction on one of the AXI-Master ports*/
        task read_to_file(input bit [(max_chars*8)-1:0] file_name, input bit [addr_width-1:0] start_addr, input bit [int_width-1:0] rd_size, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.read_to_file(file_name, start_addr, rd_size, response);
        endtask

        /* API to initiate a WRITE transaction(<= 128 bytes) on one of the AXI-Master ports*/
        task write_data(input bit [addr_width-1:0] start_addr, input bit [max_transfer_bytes_width:0] wr_size, input bit [(max_transfer_bytes*8)-1:0] wr_data, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.write_data(start_addr, wr_size, wr_data, response);
        endtask

        /* API to initiate a READ transaction(<= 128 bytes) on one of the AXI-Master ports*/
        task read_data(input bit [addr_width-1:0] start_addr, input bit [max_transfer_bytes_width:0] rd_size, output bit [(max_transfer_bytes*8)-1:0] rd_data, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.read_data(start_addr, rd_size, rd_data, response);
        endtask

        /* Hooks to call to BFM APIs */
        task write_burst(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache, input bit [axi_prot_width-1:0] prot,
                         input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input integer datasize, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.write_burst(start_addr, len, siz, burst, lck, cache, prot, data, datasize, response);
        endtask

        /* Hooks to call to BFM APIs */
        task write_burst_strb(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache, input bit [axi_prot_width-1:0] prot,
                              input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input bit strb_en, input bit [(axi_mgp_data_width*axi_burst_len)/8-1:0] strb, input integer datasize, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.write_burst_strb(start_addr, len, siz, burst, lck, cache, prot, data, strb_en, strb, datasize, response);
        endtask

        task write_burst_concurrent(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache, input bit [axi_prot_width-1:0] prot,
                                    input bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, input integer datasize, output bit [axi_rsp_width-1:0] response);
            `ZYNQ_VIP_0.write_burst_concurrent(start_addr, len, siz, burst, lck, cache, prot, data, datasize, response);
        endtask

        task read_burst(input bit [addr_width-1:0] start_addr, input bit [axi_len_width-1:0] len, input bit [axi_size_width-1:0] siz, input bit [axi_brst_type_width-1:0] burst, input bit [axi_lock_width-1:0] lck, input bit [axi_cache_width-1:0] cache, input bit [axi_prot_width-1:0] prot,
                        output bit [(axi_max_mdata_width*axi_burst_len)-1:0] data, output bit [(axi_rsp_width*axi_burst_len)-1:0] response);
            `ZYNQ_VIP_0.read_burst(start_addr, len, siz, burst, lck, cache, prot, data, response);
        endtask

        task wait_reg_update(input bit [addr_width-1:0] addr, input bit [data_width-1:0] data_i, input bit [data_width-1:0] mask_i, input bit [int_width-1:0] time_interval, input bit [int_width-1:0] time_out, output bit [data_width-1:0] data_o);
            `ZYNQ_VIP_0.wait_reg_update(addr, data_i, mask_i, time_interval, time_out, data_o);
        endtask

        /* API to read register map */
        task read_register_map(input bit [addr_width-1:0] start_addr, input bit [max_regs_width:0] no_of_registers, output bit [max_burst_bits-1 : 0] data);
            `ZYNQ_VIP_0.read_register_map(start_addr, no_of_registers, data);
        endtask

        /* API to read single register */
        task read_register(input bit [addr_width-1:0] addr, output bit [data_width-1:0] data);
            `ZYNQ_VIP_0.read_register(addr, data);
        endtask

        /* API to set the AXI-Slave profile*/
        task set_slave_profile(input bit [1023:0] name, input bit [1:0] latency);
            `ZYNQ_VIP_0.set_slave_profile(name, latency);
        endtask


    endclass : wrapper


    wrapper m_bfm_api = new();

endmodule
