class axi_xbar_uvm_test extends tue_test #(
  .CONFIGURATION(axi_xbar_uvm_configuration)
);
  tvip_axi_master_agent master_agent[TbNumMasters];
  tvip_axi_slave_agent slave_agent[TbNumSlaves];
  tvip_axi_master_sequencer master_sequencer[TbNumMasters];
  tvip_axi_slave_sequencer slave_sequencer[TbNumSlaves];
  axi_xbar_uvm_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void create_configuration();
    super.create_configuration();

    foreach (configuration.mst_cfg[i]) begin
      void'(uvm_config_db #(tvip_axi_vif)::get(null, "", $sformatf("mst_vif[%0d]", i), configuration.mst_cfg[i].vif));
    end
    foreach (configuration.slv_cfg[i]) begin
      void'(uvm_config_db #(tvip_axi_vif)::get(null, "", $sformatf("slv_vif[%0d]", i), configuration.slv_cfg[i].vif));
    end

    if (!configuration.randomize()) begin
      `uvm_fatal(get_type_name(), "Failed to randomize axi_xbar_uvm_configuration")
    end

    `uvm_info(get_type_name(), $sformatf("configuration\n%s", configuration.sprint()), UVM_LOW)
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    scoreboard = axi_xbar_uvm_scoreboard::type_id::create("scoreboard", this);
    foreach (master_agent[i]) begin
      master_agent[i] = tvip_axi_master_agent::type_id::create($sformatf("master_agent[%0d]", i), this);
      master_agent[i].set_configuration(configuration.mst_cfg[i]);
    end
    foreach (slave_agent[i]) begin
      slave_agent[i] = tvip_axi_slave_agent::type_id::create($sformatf("slave_agent[%0d]", i), this);
      slave_agent[i].set_configuration(configuration.slv_cfg[i]);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    foreach (master_sequencer[i]) begin
      master_sequencer[i] = master_agent[i].sequencer;
      master_agent[i].item_port.connect(scoreboard.ingress_tap[i].analysis_export);
    end
    foreach (slave_sequencer[i]) begin
      slave_sequencer[i] = slave_agent[i].sequencer;
      slave_agent[i].item_port.connect(scoreboard.egress_tap[i].analysis_export);
    end
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    foreach (slave_sequencer[i]) begin
      uvm_config_db #(uvm_object_wrapper)::set(
        slave_sequencer[i],
        "run_phase",
        "default_sequence",
        tvip_axi_slave_default_sequence::type_id::get()
      );
    end
  endfunction

  task main_phase(uvm_phase phase);
    axi_xbar_uvm_master_sequence seq[TbNumMasters];
    super.main_phase(phase);
    phase.raise_objection(this);
    foreach (seq[i]) begin
      seq[i] = axi_xbar_uvm_master_sequence::type_id::create($sformatf("seq[%0d]", i));
      seq[i].master_index = i;
    end

    fork
      seq[0].start(master_sequencer[0]);
      seq[1].start(master_sequencer[1]);
    join

    phase.drop_objection(this);
  endtask

  `uvm_component_utils(axi_xbar_uvm_test)
endclass
