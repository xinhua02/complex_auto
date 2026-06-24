`ifndef DV_MACROS_SVH
`define DV_MACROS_SVH

`define uvm_object_new \
  function new(string name = ""); \
    super.new(name); \
  endfunction

`define uvm_component_new \
  function new(string name, uvm_component parent); \
    super.new(name, parent); \
  endfunction

`endif
