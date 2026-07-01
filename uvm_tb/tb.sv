`include "axi/typedef.svh"
`include "uvm_macros.svh"
`include "dv_macros.svh"

module tb;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import tue_pkg::*;
  import tvip_axi_types_pkg::*;
  import tvip_axi_pkg::*;
  import tb_axi_xbar_uvm_pkg::*;

  localparam time CyclTime = 10ns;

  localparam axi_pkg::xbar_cfg_t XbarCfg = '{
    NoSlvPorts:         TbNumMasters,
    NoMstPorts:         TbNumSlaves,
    MaxMstTrans:        8,
    MaxSlvTrans:        8,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_AX,
    PipelineStages:     1,
    AxiIdWidthSlvPorts: TbAxiIdWidthMasters,
    AxiIdUsedSlvPorts:  TbAxiIdWidthMasters,
    UniqueIds:          1'b0,
    AxiAddrWidth:       TbAxiAddrWidth,
    AxiDataWidth:       TbAxiDataWidth,
    NoAddrRules:        TbNumSlaves
  };

  typedef axi_pkg::xbar_rule_32_t rule_t;

  function automatic rule_t [XbarCfg.NoAddrRules-1:0] gen_addr_map();
    for (int unsigned i = 0; i < XbarCfg.NoAddrRules; i++) begin
      gen_addr_map[i] = '{
        idx:        unsigned'(i),
        start_addr: MappedBase[i],
        end_addr:   MappedBase[i] + MappedSize,
        default:    '0
      };
    end
  endfunction

  localparam rule_t [XbarCfg.NoAddrRules-1:0] AddrMap = gen_addr_map();

  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #(CyclTime/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (20) @(posedge clk);
    rst_n = 1'b1;
  end

  AXI_BUS #(
    .AXI_ADDR_WIDTH (TbAxiAddrWidth),
    .AXI_DATA_WIDTH (TbAxiDataWidth),
    .AXI_ID_WIDTH   (TbAxiIdWidthMasters),
    .AXI_USER_WIDTH (1)
  ) slv_ports [TbNumMasters-1:0] ();

  AXI_BUS #(
    .AXI_ADDR_WIDTH (TbAxiAddrWidth),
    .AXI_DATA_WIDTH (TbAxiDataWidth),
    .AXI_ID_WIDTH   (TbAxiIdWidthSlaves),
    .AXI_USER_WIDTH (1)
  ) mst_ports [TbNumSlaves-1:0] ();

  tvip_axi_if mst_vif[TbNumMasters](clk, rst_n);
  tvip_axi_if slv_vif[TbNumSlaves](clk, rst_n);

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_mst_bridge
    assign slv_ports[i].aw_valid = mst_vif[i].awvalid;
    assign slv_ports[i].aw_id    = mst_vif[i].awid[TbAxiIdWidthMasters-1:0];
    assign slv_ports[i].aw_addr  = mst_vif[i].awaddr[TbAxiAddrWidth-1:0];
    assign slv_ports[i].aw_len   = axi_pkg::len_t'(mst_vif[i].awlen);
    assign slv_ports[i].aw_size  = axi_pkg::size_t'(mst_vif[i].awsize);
    assign slv_ports[i].aw_burst = axi_pkg::burst_t'(mst_vif[i].awburst);
    assign slv_ports[i].aw_lock  = 1'b0;
    assign slv_ports[i].aw_cache = axi_pkg::cache_t'(mst_vif[i].awcache);
    assign slv_ports[i].aw_prot  = axi_pkg::prot_t'(mst_vif[i].awprot);
    assign slv_ports[i].aw_qos   = axi_pkg::qos_t'(mst_vif[i].awqos);
    assign slv_ports[i].aw_region = '0;
    assign slv_ports[i].aw_atop  = '0;
    assign slv_ports[i].aw_user  = '0;
    assign slv_ports[i].w_valid  = mst_vif[i].wvalid;
    assign slv_ports[i].w_data   = mst_vif[i].wdata[TbAxiDataWidth-1:0];
    assign slv_ports[i].w_strb   = mst_vif[i].wstrb[TbAxiDataWidth/8-1:0];
    assign slv_ports[i].w_last   = mst_vif[i].wlast;
    assign slv_ports[i].w_user   = '0;
    assign slv_ports[i].b_ready  = mst_vif[i].bready;
    assign slv_ports[i].ar_valid = mst_vif[i].arvalid;
    assign slv_ports[i].ar_id    = mst_vif[i].arid[TbAxiIdWidthMasters-1:0];
    assign slv_ports[i].ar_addr  = mst_vif[i].araddr[TbAxiAddrWidth-1:0];
    assign slv_ports[i].ar_len   = axi_pkg::len_t'(mst_vif[i].arlen);
    assign slv_ports[i].ar_size  = axi_pkg::size_t'(mst_vif[i].arsize);
    assign slv_ports[i].ar_burst = axi_pkg::burst_t'(mst_vif[i].arburst);
    assign slv_ports[i].ar_lock  = 1'b0;
    assign slv_ports[i].ar_cache = axi_pkg::cache_t'(mst_vif[i].arcache);
    assign slv_ports[i].ar_prot  = axi_pkg::prot_t'(mst_vif[i].arprot);
    assign slv_ports[i].ar_qos   = axi_pkg::qos_t'(mst_vif[i].arqos);
    assign slv_ports[i].ar_region = '0;
    assign slv_ports[i].ar_user  = '0;
    assign slv_ports[i].r_ready  = mst_vif[i].rready;

    assign mst_vif[i].awready = slv_ports[i].aw_ready;
    assign mst_vif[i].wready  = slv_ports[i].w_ready;
    assign mst_vif[i].bvalid  = slv_ports[i].b_valid;
    assign mst_vif[i].bid     = tvip_axi_id'(slv_ports[i].b_id);
    assign mst_vif[i].bresp   = tvip_axi_response'(slv_ports[i].b_resp);
    assign mst_vif[i].arready = slv_ports[i].ar_ready;
    assign mst_vif[i].rvalid  = slv_ports[i].r_valid;
    assign mst_vif[i].rid     = tvip_axi_id'(slv_ports[i].r_id);
    assign mst_vif[i].rdata   = tvip_axi_data'(slv_ports[i].r_data);
    assign mst_vif[i].rresp   = tvip_axi_response'(slv_ports[i].r_resp);
    assign mst_vif[i].rlast   = slv_ports[i].r_last;
  end

  for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_slv_bridge
    assign mst_ports[i].aw_ready = slv_vif[i].awready;
    assign mst_ports[i].w_ready  = slv_vif[i].wready;
    assign mst_ports[i].b_valid  = slv_vif[i].bvalid;
    assign mst_ports[i].b_id     = slv_vif[i].bid[TbAxiIdWidthSlaves-1:0];
    assign mst_ports[i].b_resp   = axi_pkg::resp_t'(slv_vif[i].bresp);
    assign mst_ports[i].b_user   = '0;
    assign mst_ports[i].ar_ready = slv_vif[i].arready;
    assign mst_ports[i].r_valid  = slv_vif[i].rvalid;
    assign mst_ports[i].r_id     = slv_vif[i].rid[TbAxiIdWidthSlaves-1:0];
    assign mst_ports[i].r_data   = slv_vif[i].rdata[TbAxiDataWidth-1:0];
    assign mst_ports[i].r_resp   = axi_pkg::resp_t'(slv_vif[i].rresp);
    assign mst_ports[i].r_last   = slv_vif[i].rlast;
    assign mst_ports[i].r_user   = '0;

    assign slv_vif[i].awvalid = mst_ports[i].aw_valid;
    assign slv_vif[i].awid    = tvip_axi_id'(mst_ports[i].aw_id);
    assign slv_vif[i].awaddr  = tvip_axi_address'(mst_ports[i].aw_addr);
    assign slv_vif[i].awlen   = tvip_axi_burst_length'(mst_ports[i].aw_len);
    assign slv_vif[i].awsize  = tvip_axi_burst_size'(mst_ports[i].aw_size);
    assign slv_vif[i].awburst = tvip_axi_burst_type'(mst_ports[i].aw_burst);
    assign slv_vif[i].awcache = tvip_axi_write_cache'(mst_ports[i].aw_cache);
    assign slv_vif[i].awprot  = tvip_axi_protection'(mst_ports[i].aw_prot);
    assign slv_vif[i].awqos   = tvip_axi_qos'(mst_ports[i].aw_qos);
    assign slv_vif[i].wvalid  = mst_ports[i].w_valid;
    assign slv_vif[i].wdata   = tvip_axi_data'(mst_ports[i].w_data);
    assign slv_vif[i].wstrb   = tvip_axi_strobe'(mst_ports[i].w_strb);
    assign slv_vif[i].wlast   = mst_ports[i].w_last;
    assign slv_vif[i].bready  = mst_ports[i].b_ready;
    assign slv_vif[i].arvalid = mst_ports[i].ar_valid;
    assign slv_vif[i].arid    = tvip_axi_id'(mst_ports[i].ar_id);
    assign slv_vif[i].araddr  = tvip_axi_address'(mst_ports[i].ar_addr);
    assign slv_vif[i].arlen   = tvip_axi_burst_length'(mst_ports[i].ar_len);
    assign slv_vif[i].arsize  = tvip_axi_burst_size'(mst_ports[i].ar_size);
    assign slv_vif[i].arburst = tvip_axi_burst_type'(mst_ports[i].ar_burst);
    assign slv_vif[i].arcache = tvip_axi_read_cache'(mst_ports[i].ar_cache);
    assign slv_vif[i].arprot  = tvip_axi_protection'(mst_ports[i].ar_prot);
    assign slv_vif[i].arqos   = tvip_axi_qos'(mst_ports[i].ar_qos);
    assign slv_vif[i].rready  = mst_ports[i].r_ready;
  end

  axi_xbar_intf #(
    .AXI_USER_WIDTH (1),
    .Cfg            (XbarCfg),
    .ATOPS          (1'b0),
    .rule_t         (rule_t)
  ) dut (
    .clk_i                 (clk),
    .rst_ni                (rst_n),
    .test_i                (1'b0),
    .slv_ports             (slv_ports),
    .mst_ports             (mst_ports),
    .addr_map_i            (AddrMap),
    .en_default_mst_port_i ('0),
    .default_mst_port_i    ('0)
  );

  for (genvar i = 0; i < TbNumMasters; i++) begin : gen_mst_vif_cfg
    initial begin
      uvm_config_db #(tvip_axi_vif)::set(null, "", $sformatf("mst_vif[%0d]", i), mst_vif[i]);
    end
  end

  for (genvar i = 0; i < TbNumSlaves; i++) begin : gen_slv_vif_cfg
    initial begin
      uvm_config_db #(tvip_axi_vif)::set(null, "", $sformatf("slv_vif[%0d]", i), slv_vif[i]);
    end
  end

  initial begin
    run_test();
  end

endmodule
