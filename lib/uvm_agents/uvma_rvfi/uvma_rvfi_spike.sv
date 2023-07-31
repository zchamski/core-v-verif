// Copyright 2023 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


`ifndef __UVMA_RVFI_SPIKE_SV__
`define __UVMA_RVFI_SPIKE_SV__

import "DPI-C" function int spike_create(string filename);

import "DPI-C" function void spike_set_param_uint64_t(string base, string name, longint unsigned value);
import "DPI-C" function void spike_set_param_str(string base, string name, string value);
import "DPI-C" function void spike_set_default_params(string profile);

import "DPI-C" function void spike_step(output st_rvfi rvfi);

/**
 * Component writing Rvfi monitor transactions rvfi data to disk as plain text.
 */
class uvma_rvfi_spike#(int ILEN=DEFAULT_ILEN,
                                  int XLEN=DEFAULT_XLEN
) extends uvma_rvfi_reference_model;

    localparam config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg;
   `uvm_component_param_utils(uvma_rvfi_spike)

   /**
    * Default constructor.
    */
   function new(string name="uvma_rvfi_spike", uvm_component parent=null);
       string binary, rtl_isa;

       super.new(name, parent);

       $value$plusargs("elf_file=%s", binary);

       `uvm_info("Spike Tandem", $sformatf("Setting up Spike with binary %s...", binary), UVM_NONE);

        rtl_isa = $sformatf("RV%-2dIM%s%s%s%s",
                            riscv::XLEN,
                            CVA6Cfg.RVA ? "A" : "",
                            CVA6Cfg.RVF ? "F" : "",
                            CVA6Cfg.RVD ? "D" : "",
                            CVA6Cfg.RVC ? "C" : "");
        // TODO Fixme
        //if (CVA6Cfg.CVA6ConfigBExtEn) begin
        //    rtl_isa = $sformatf("%s_zba_zbb_zbc_zbs", rtl_isa);
        //end

       assert(binary != "") else $error("We need a preloaded binary for tandem verification");


       void'(spike_set_default_params("cva6"));
       void'(spike_set_param_uint64_t("/top/core/0/", "boot_addr", 'h80000000));
       void'(spike_set_param_str("/top/", "isa", rtl_isa));
       void'(spike_set_param_str("/top/core/0/", "isa", rtl_isa));
       void'(spike_create(binary));

   endfunction : new

   /**
    * Build phase
    */
   function void build_phase(uvm_phase phase);
       super.build_phase(phase);

   endfunction : build_phase

   /**
    * Step function - Steps the core and returns a rvfi transaction
    */
   virtual function uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) step (int i, uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);
       st_rvfi rvfi;
       uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_reference_model;

       spike_step(rvfi);

       t_reference_model = new("t_reference_model");
       t_reference_model.rvfi2seq(rvfi);
       return t_reference_model;

   endfunction : step

endclass : uvma_rvfi_spike


`endif // __UVMA_RVFI_SPIKE_SV__

