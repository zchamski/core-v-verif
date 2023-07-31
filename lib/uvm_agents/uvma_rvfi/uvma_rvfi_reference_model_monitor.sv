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


`ifndef __UVMA_RVFI_REFERENCE_MODEL_MONITOR_SV__
`define __UVMA_RVFI_REFERENCE_MODEL_MONITOR_SV__

/**
 * Component writing Rvfi monitor transactions rvfi data to disk as plain text.
 */
class uvma_rvfi_reference_model_monitor#(int ILEN=DEFAULT_ILEN,
                                  int XLEN=DEFAULT_XLEN) extends uvm_component;

    // Objects
    uvma_rvfi_cfg_c    cfg;

    uvm_analysis_imp_rvfi_instr#(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN), uvma_rvfi_reference_model_monitor) m_analysis_imp;
    uvm_analysis_port#(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN), uvma_rvfi_reference_model_monitor) m_analysis_port;

    uvma_rvfi_reference_model m_reference_model;

   `uvm_component_param_utils(uvma_rvfi_reference_model_monitor)

   /**
    * Default constructor.
    */
   function new(string name="uvma_rvfi_mon_trn_logger", uvm_component parent=null);

        super.new(name, parent);

        m_analysis_imp = new("m_analysis_imp", this);
        m_analysis_port = new("m_analysis_port", this);
        m_reference_model = uvma_rvfi_reference_model#(ILEN,XLEN)::type_id::create("m_reference_model", this);

   endfunction : new

   /**
    * Build phase - attempt to load a firmware itb file (instruction table file)
    */
   function void build_phase(uvm_phase phase);

    void'(uvm_config_db#(uvma_rvfi_cfg_c#(ILEN,XLEN))::get(this, "", "cfg", cfg));
    if (!cfg) begin
        `uvm_fatal("CFG", "Configuration handle is null")
    end

   endfunction : build_phase

   virtual function void write_rvfi_instr(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);

       uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_reference_model = m_reference_model.step(1, t);
       m_analysis_port.write(t_reference_model);

   endfunction : write_rvfi_instr

endclass : uvma_rvfi_reference_model_monitor


`endif // __UVMA_RVFI_REFERENCE_MODEL_MONITOR_SV__

