class axi_xbar_uvm_configuration extends tue_configuration;
  rand tvip_axi_configuration mst_cfg[TbNumMasters];
  rand tvip_axi_configuration slv_cfg[TbNumSlaves];

  constraint c_master_cfg {
    foreach (mst_cfg[i]) {
      mst_cfg[i].protocol == TVIP_AXI4;
      mst_cfg[i].id_width == TbAxiIdWidthMasters;
      mst_cfg[i].address_width == TbAxiAddrWidth;
      mst_cfg[i].data_width == TbAxiDataWidth;
      mst_cfg[i].max_burst_length == 16;
    }
  }

  constraint c_slave_cfg {
    foreach (slv_cfg[i]) {
      slv_cfg[i].protocol == TVIP_AXI4;
      slv_cfg[i].id_width == TbAxiIdWidthSlaves;
      slv_cfg[i].address_width == TbAxiAddrWidth;
      slv_cfg[i].data_width == TbAxiDataWidth;
      slv_cfg[i].max_burst_length == 16;

      // Keep downstream slaves deterministic; decode errors should come from axi_err_slv only.
      slv_cfg[i].response_weight_okay == 1;
      slv_cfg[i].response_weight_exokay == 0;
      slv_cfg[i].response_weight_slave_error == 0;
      slv_cfg[i].response_weight_decode_error == 0;
    }
  }

  function new(string name = "");
    super.new(name);
    foreach (mst_cfg[i]) begin
      mst_cfg[i] = tvip_axi_configuration::type_id::create($sformatf("mst_cfg[%0d]", i));
    end
    foreach (slv_cfg[i]) begin
      slv_cfg[i] = tvip_axi_configuration::type_id::create($sformatf("slv_cfg[%0d]", i));
    end
  endfunction

  `uvm_object_utils_begin(axi_xbar_uvm_configuration)
    `uvm_field_sarray_object(mst_cfg, UVM_DEFAULT)
    `uvm_field_sarray_object(slv_cfg, UVM_DEFAULT)
  `uvm_object_utils_end
endclass
