typedef class axi_xbar_uvm_scoreboard;

class axi_xbar_uvm_item_tap extends uvm_subscriber #(tvip_axi_item);
  axi_xbar_uvm_scoreboard scoreboard;
  int unsigned            tap_idx;
  bit                     ingress_side;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void write(tvip_axi_item t);
    if (scoreboard == null) begin
      `uvm_error(get_type_name(), "scoreboard handle is null")
      return;
    end
    if (ingress_side) begin
      scoreboard.observe_ingress(tap_idx, t);
    end else begin
      scoreboard.observe_egress(tap_idx, t);
    end
  endfunction

  `uvm_component_utils(axi_xbar_uvm_item_tap)
endclass
