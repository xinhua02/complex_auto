class axi_xbar_uvm_master_sequence extends tvip_axi_master_sequence_base;
  int unsigned master_index;

  function new(string name = "");
    super.new(name);
    set_automatic_phase_objection(0);
  endfunction

  local function bit compare_data(
    input int               index,
    input tvip_axi_address  address,
    input int               burst_size,
    ref   tvip_axi_strobe   strobe[],
    ref   tvip_axi_data     write_data[],
    ref   tvip_axi_data     read_data[]
  );
    int byte_width;
    int byte_offset;

    byte_width = configuration.data_width / 8;
    byte_offset = ((address & get_address_mask(burst_size)) + (burst_size * index)) % byte_width;
    for (int i = 0; i < burst_size; i++) begin
      int byte_index = byte_offset + i;
      if (!strobe[index][byte_index]) begin
        continue;
      end
      if (write_data[index][8*byte_index +: 8] != read_data[index][8*byte_index +: 8]) begin
        return 0;
      end
    end
    return 1;
  endfunction

  local function tvip_axi_address get_address_mask(input int burst_size);
    tvip_axi_address mask;
    mask = '1;
    mask = (mask >> $clog2(burst_size)) << $clog2(burst_size);
    return mask;
  endfunction

  local task run_write_read_pair(
    input tvip_axi_address addr,
    input tvip_axi_id tx_id
  );
    tvip_axi_master_access_sequence wr_seq;
    tvip_axi_master_access_sequence rd_seq;

    wr_seq = tvip_axi_master_access_sequence::type_id::create("wr_seq");
    wr_seq.access_type = TVIP_AXI_WRITE_ACCESS;
    wr_seq.id = tx_id;
    wr_seq.address = addr;
    wr_seq.burst_length = 1;
    wr_seq.burst_size = 8;
    wr_seq.burst_type = TVIP_AXI_INCREMENTING_BURST;
    wr_seq.data = new[1];
    wr_seq.strobe = new[1];
    wr_seq.data[0] = tvip_axi_data'(64'h0123_4567_89ab_cdef);
    wr_seq.strobe[0] = tvip_axi_strobe'('1);
    wr_seq.start(p_sequencer);

    rd_seq = tvip_axi_master_access_sequence::type_id::create("rd_seq");
    rd_seq.access_type = TVIP_AXI_READ_ACCESS;
    rd_seq.id = tx_id;
    rd_seq.address = addr;
    rd_seq.burst_length = wr_seq.burst_length;
    rd_seq.burst_size = wr_seq.burst_size;
    rd_seq.burst_type = TVIP_AXI_INCREMENTING_BURST;
    rd_seq.start(p_sequencer);

    for (int i = 0; i < wr_seq.burst_length; i++) begin
      if (!compare_data(i, wr_seq.address, wr_seq.burst_size, wr_seq.strobe, wr_seq.data, rd_seq.data)) begin
        `uvm_error(get_type_name(), $sformatf("Data mismatch on master %0d at beat %0d", master_index, i))
      end
    end

    foreach (rd_seq.response[i]) begin
      if (rd_seq.response[i] != TVIP_AXI_OKAY) begin
        `uvm_error(get_type_name(), $sformatf("Unexpected READ response %0d on master %0d", rd_seq.response[i], master_index))
      end
    end
    foreach (wr_seq.response[i]) begin
      if (wr_seq.response[i] != TVIP_AXI_OKAY) begin
        `uvm_error(get_type_name(), $sformatf("Unexpected WRITE response %0d on master %0d", wr_seq.response[i], master_index))
      end
    end
  endtask

  local task run_decode_error_check();
    tvip_axi_master_access_sequence rd_seq;
    tvip_axi_master_access_sequence wr_seq;
    tvip_axi_id err_id;

    err_id = tvip_axi_id'(8'hf0 + master_index);

    rd_seq = tvip_axi_master_access_sequence::type_id::create("rd_seq");
    rd_seq.access_type = TVIP_AXI_READ_ACCESS;
    rd_seq.id = err_id;
    rd_seq.address = UnmappedAddr;
    rd_seq.burst_length = 1;
    rd_seq.burst_size = 8;
    rd_seq.burst_type = TVIP_AXI_INCREMENTING_BURST;
    rd_seq.start(p_sequencer);
    if (rd_seq.response.size() != 1 || rd_seq.response[0] != TVIP_AXI_DECODE_ERROR) begin
      `uvm_error(get_type_name(), $sformatf("Expected DECERR read on master %0d", master_index))
    end

    wr_seq = tvip_axi_master_access_sequence::type_id::create("wr_seq");
    wr_seq.access_type = TVIP_AXI_WRITE_ACCESS;
    wr_seq.id = err_id;
    wr_seq.address = (UnmappedAddr + 32'h40);
    wr_seq.burst_length = 1;
    wr_seq.burst_size = 8;
    wr_seq.burst_type = TVIP_AXI_INCREMENTING_BURST;
    wr_seq.data = new[1];
    wr_seq.strobe = new[1];
    wr_seq.data[0] = tvip_axi_data'(64'h55aa_55aa_55aa_55aa);
    wr_seq.strobe[0] = tvip_axi_strobe'('1);
    wr_seq.start(p_sequencer);
    if (wr_seq.response.size() != 1 || wr_seq.response[0] != TVIP_AXI_DECODE_ERROR) begin
      `uvm_error(get_type_name(), $sformatf("Expected DECERR write on master %0d", master_index))
    end
  endtask

  local task run_same_id_cross_target_stress();
    tvip_axi_master_access_sequence wr_seq_0;
    tvip_axi_master_access_sequence wr_seq_1;
    tvip_axi_id id_to_dst0;
    tvip_axi_id id_to_dst1;

    id_to_dst0 = tvip_axi_id'(master_index + 8);
    id_to_dst1 = tvip_axi_id'(master_index + 12);

    wr_seq_0 = tvip_axi_master_access_sequence::type_id::create("wr_seq_0");
    wr_seq_1 = tvip_axi_master_access_sequence::type_id::create("wr_seq_1");

    wr_seq_0.access_type = TVIP_AXI_WRITE_ACCESS;
    wr_seq_0.id = id_to_dst0;
    wr_seq_0.address = MappedBase[0] + (master_index * 32'h40);
    wr_seq_0.burst_length = 1;
    wr_seq_0.burst_size = 8;
    wr_seq_0.burst_type = TVIP_AXI_INCREMENTING_BURST;
    wr_seq_0.data = new[1];
    wr_seq_0.strobe = new[1];
    wr_seq_0.data[0] = tvip_axi_data'(64'h1111_2222_3333_4444);
    wr_seq_0.strobe[0] = tvip_axi_strobe'('1);

    wr_seq_1.access_type = TVIP_AXI_WRITE_ACCESS;
    wr_seq_1.id = id_to_dst1;
    wr_seq_1.address = MappedBase[1] + (master_index * 32'h80);
    wr_seq_1.burst_length = 1;
    wr_seq_1.burst_size = 8;
    wr_seq_1.burst_type = TVIP_AXI_INCREMENTING_BURST;
    wr_seq_1.data = new[1];
    wr_seq_1.strobe = new[1];
    wr_seq_1.data[0] = tvip_axi_data'(64'haaaa_bbbb_cccc_dddd);
    wr_seq_1.strobe[0] = tvip_axi_strobe'('1);

    wr_seq_0.start(p_sequencer);
    wr_seq_1.start(p_sequencer);

    foreach (wr_seq_0.response[i]) begin
      if (wr_seq_0.response[i] != TVIP_AXI_OKAY) begin
        `uvm_error(get_type_name(), $sformatf("Cross-target WRITE0 response error on master %0d", master_index))
      end
    end
    foreach (wr_seq_1.response[i]) begin
      if (wr_seq_1.response[i] != TVIP_AXI_OKAY) begin
        `uvm_error(get_type_name(), $sformatf("Cross-target WRITE1 response error on master %0d", master_index))
      end
    end
  endtask

  task body();
    run_write_read_pair(MappedBase[master_index], tvip_axi_id'(master_index + 2));
    run_write_read_pair(MappedBase[1 - master_index] + 32'h20, tvip_axi_id'(master_index + 4));
    run_same_id_cross_target_stress();
    run_decode_error_check();
  endtask

  `uvm_object_utils_begin(axi_xbar_uvm_master_sequence)
    `uvm_field_int(master_index, UVM_DEFAULT | UVM_DEC)
  `uvm_object_utils_end
endclass
