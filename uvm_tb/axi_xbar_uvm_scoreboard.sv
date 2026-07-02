class axi_xbar_uvm_scoreboard extends uvm_component;
  typedef struct {
    bit  valid;
    int  last_dst;
    time last_resp_end;
  } id_order_state_t;

  axi_xbar_uvm_item_tap ingress_tap[TbNumMasters];
  axi_xbar_uvm_item_tap egress_tap[TbNumSlaves];

  int unsigned route_hits[TbNumMasters][TbNumSlaves];
  int unsigned ingress_seen[TbNumMasters];
  int unsigned decerr_reads[TbNumMasters];
  int unsigned decerr_writes[TbNumMasters];
  int unsigned mapped_decerr;
  int unsigned egress_unknown_src;
  int unsigned same_id_cross_dst_checks[TbNumMasters];
  int unsigned same_id_cross_dst_violations[TbNumMasters];
  id_order_state_t order_state[TbNumMasters][tvip_axi_id];

  covergroup cg_xbar with function sample(
    int src,
    int dst,
    bit decerr,
    int burst_len,
    int burst_size,
    bit is_write
  );
    option.per_instance = 1;
    cp_src: coverpoint src {
      bins src_bins[] = {[0:TbNumMasters-1]};
      illegal_bins src_oob = default;
    }
    cp_dst: coverpoint dst {
      bins mapped_dst[] = {[0:TbNumSlaves-1]};
      bins decerr_dst = {TbNumSlaves};
      illegal_bins dst_oob = default;
    }
    cp_decerr: coverpoint decerr {
      bins no_decerr = {1'b0};
      bins has_decerr = {1'b1};
    }
    cp_burst_len: coverpoint burst_len {
      bins single = {1};
      bins short = {[2:4]};
      bins mid_len = {[5:8]};
      bins long = {[9:16]};
    }
    cp_burst_size: coverpoint burst_size {
      bins byte_1 = {1};
      bins byte_2 = {2};
      bins byte_4 = {4};
      bins byte_8 = {8};
    }
    cp_is_write: coverpoint is_write;
    x_route: cross cp_src, cp_dst;
    x_src_decerr: cross cp_src, cp_decerr;
    x_rw_burst: cross cp_is_write, cp_burst_len, cp_burst_size;
    x_src_burst_size: cross cp_src, cp_burst_size;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_xbar = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    foreach (ingress_tap[i]) begin
      ingress_tap[i] = axi_xbar_uvm_item_tap::type_id::create($sformatf("ingress_tap[%0d]", i), this);
      ingress_tap[i].scoreboard = this;
      ingress_tap[i].tap_idx = i;
      ingress_tap[i].ingress_side = 1'b1;
    end
    foreach (egress_tap[i]) begin
      egress_tap[i] = axi_xbar_uvm_item_tap::type_id::create($sformatf("egress_tap[%0d]", i), this);
      egress_tap[i].scoreboard = this;
      egress_tap[i].tap_idx = i;
      egress_tap[i].ingress_side = 1'b0;
    end
  endfunction

  function automatic int predict_dst(input tvip_axi_address addr);
    for (int i = 0; i < TbNumSlaves; i++) begin
      if ((addr >= MappedBase[i]) && (addr < (MappedBase[i] + MappedSize))) begin
        return i;
      end
    end
    return -1;
  endfunction

  function automatic int decode_src_from_egress_id(input tvip_axi_id id);
    return int'(id >> TbAxiIdWidthMasters);
  endfunction

  function automatic bit has_decerr(input tvip_axi_item item);
    foreach (item.response[i]) begin
      if (item.response[i] == TVIP_AXI_DECODE_ERROR) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  function void observe_ingress(input int ingress_idx, input tvip_axi_item item);
    int dst;
    bit decerr;
    id_order_state_t st;

    if ((ingress_idx < 0) || (ingress_idx >= TbNumMasters)) begin
      `uvm_error(get_type_name(), $sformatf("Invalid ingress index %0d", ingress_idx))
      return;
    end

    ingress_seen[ingress_idx]++;
    dst = predict_dst(item.address);
    decerr = has_decerr(item);

    if (decerr) begin
      if (item.is_write()) begin
        decerr_writes[ingress_idx]++;
      end else begin
        decerr_reads[ingress_idx]++;
      end
      if (dst >= 0) begin
        mapped_decerr++;
        `uvm_error(get_type_name(), $sformatf(
          "DECERR observed for mapped address 0x%0h on ingress %0d",
          item.address,
          ingress_idx
        ))
      end
    end

    // AXI xbar must stall same-ID transactions to different destinations on one ingress
    // until the previous transaction has completed.
    if (dst >= 0) begin
      if (order_state[ingress_idx].exists(item.id)) begin
        st = order_state[ingress_idx][item.id];
        if (st.valid && (st.last_dst != dst)) begin
          same_id_cross_dst_checks[ingress_idx]++;
          if (item.address_begin_time < st.last_resp_end) begin
            same_id_cross_dst_violations[ingress_idx]++;
            `uvm_error(get_type_name(), $sformatf(
              "Ordering violation: ingress=%0d id=0x%0h dst_prev=%0d dst_now=%0d addr_begin=%0t prev_resp_end=%0t",
              ingress_idx,
              item.id,
              st.last_dst,
              dst,
              item.address_begin_time,
              st.last_resp_end
            ))
          end
        end
      end
      order_state[ingress_idx][item.id] = '{valid: 1'b1, last_dst: dst, last_resp_end: item.response_end_time};
    end

    cg_xbar.sample(
      ingress_idx,
      (dst >= 0) ? dst : TbNumSlaves,
      decerr,
      item.burst_length,
      item.burst_size,
      item.is_write()
    );
  endfunction

  function void observe_egress(input int egress_idx, input tvip_axi_item item);
    int src;

    if ((egress_idx < 0) || (egress_idx >= TbNumSlaves)) begin
      `uvm_error(get_type_name(), $sformatf("Invalid egress index %0d", egress_idx))
      return;
    end

    src = decode_src_from_egress_id(item.id);
    if ((src < 0) || (src >= TbNumMasters)) begin
      egress_unknown_src++;
      `uvm_warning(get_type_name(), $sformatf(
        "Cannot decode ingress source from egress id 0x%0h on egress %0d",
        item.id,
        egress_idx
      ))
      return;
    end

    route_hits[src][egress_idx]++;
    cg_xbar.sample(src, egress_idx, 1'b0, item.burst_length, item.burst_size, item.is_write());
  endfunction

  function void report_phase(uvm_phase phase);
    real cg_cov;

    super.report_phase(phase);

    cg_cov = cg_xbar.get_coverage();
    `uvm_info(get_type_name(), $sformatf("cg_xbar coverage = %0.2f%%", cg_cov), UVM_LOW)

    foreach (route_hits[i, j]) begin
      `uvm_info(get_type_name(), $sformatf("route_hits[%0d][%0d] = %0d", i, j, route_hits[i][j]), UVM_LOW)
    end
    foreach (decerr_reads[i]) begin
      `uvm_info(get_type_name(), $sformatf("decerr_reads[%0d] = %0d, decerr_writes[%0d] = %0d", i, decerr_reads[i], i, decerr_writes[i]), UVM_LOW)
    end
    foreach (same_id_cross_dst_checks[i]) begin
      `uvm_info(
        get_type_name(),
        $sformatf(
          "same_id_cross_dst_checks[%0d] = %0d, violations[%0d] = %0d",
          i,
          same_id_cross_dst_checks[i],
          i,
          same_id_cross_dst_violations[i]
        ),
        UVM_LOW
      )
    end

    foreach (route_hits[i, j]) begin
      if (route_hits[i][j] == 0) begin
        `uvm_error(get_type_name(), $sformatf("No routed transaction observed for ingress %0d -> egress %0d", i, j))
      end
    end

    foreach (decerr_reads[i]) begin
      if (decerr_reads[i] == 0) begin
        `uvm_error(get_type_name(), $sformatf("No DECERR read observed on ingress %0d", i))
      end
      if (decerr_writes[i] == 0) begin
        `uvm_error(get_type_name(), $sformatf("No DECERR write observed on ingress %0d", i))
      end
      if (same_id_cross_dst_checks[i] == 0) begin
        `uvm_error(get_type_name(), $sformatf("No same-ID cross-destination ordering check was exercised on ingress %0d", i))
      end
      if (same_id_cross_dst_violations[i] != 0) begin
        `uvm_error(get_type_name(), $sformatf("Detected %0d same-ID cross-destination ordering violations on ingress %0d", same_id_cross_dst_violations[i], i))
      end
    end

    if (mapped_decerr != 0) begin
      `uvm_error(get_type_name(), $sformatf("Observed %0d DECERR transactions on mapped ranges", mapped_decerr))
    end
    if (egress_unknown_src != 0) begin
      `uvm_error(get_type_name(), $sformatf("Observed %0d egress transactions with undecodable source ID", egress_unknown_src))
    end
  endfunction

  `uvm_component_utils(axi_xbar_uvm_scoreboard)
endclass
