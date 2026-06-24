`ifndef TB_AXI_XBAR_UVM_PKG_SV
`define TB_AXI_XBAR_UVM_PKG_SV

package tb_axi_xbar_uvm_pkg;
  import uvm_pkg::*;
  import tue_pkg::*;
  import tvip_axi_types_pkg::*;
  import tvip_axi_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"
  `include "tue_macros.svh"

  localparam int unsigned TbNumMasters = 2;
  localparam int unsigned TbNumSlaves = 2;
  localparam int unsigned TbAxiIdWidthMasters = 4;
  localparam int unsigned TbAxiAddrWidth = 32;
  localparam int unsigned TbAxiDataWidth = 64;
  localparam int unsigned TbAxiIdWidthSlaves = TbAxiIdWidthMasters + $clog2(TbNumMasters);

  localparam logic [TbAxiAddrWidth-1:0] MappedBase[2] = '{32'h0000_0000, 32'h0001_0000};
  localparam logic [TbAxiAddrWidth-1:0] MappedSize = 32'h0000_1000;
  localparam logic [TbAxiAddrWidth-1:0] UnmappedAddr = 32'h8000_0000;

  typedef class axi_xbar_uvm_scoreboard;

  `include "axi_xbar_uvm_configuration.sv"
  `include "axi_xbar_uvm_master_sequence.sv"
  `include "axi_xbar_uvm_item_tap.sv"
  `include "axi_xbar_uvm_scoreboard.sv"
  `include "axi_xbar_uvm_test.sv"

endpackage

`endif