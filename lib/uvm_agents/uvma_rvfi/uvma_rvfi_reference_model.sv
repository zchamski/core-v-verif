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


`ifndef __UVMA_RVFI_REFERENCE_MODEL_SV__
`define __UVMA_RVFI_REFERENCE_MODEL_SV__

/**
 * Component writing Rvfi monitor transactions rvfi data to disk as plain text.
 */
class uvma_rvfi_reference_model#(int ILEN=DEFAULT_ILEN,
                                  int XLEN=DEFAULT_XLEN) extends uvm_component;

   `uvm_component_param_utils(uvma_rvfi_reference_model)

   /**
    * Default constructor.
    */
   function new(string name="uvma_rvfi_reference_model", uvm_component parent=null);
       super.new(name, parent);

   endfunction : new

   /**
    * Build phase
    */
   function void build_phase(uvm_phase phase);
       super.build_phase(phase);

   endfunction : build_phase

   virtual function uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) step (int i, uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);
   endfunction : step

endclass : uvma_rvfi_reference_model


`endif // __UVMA_RVFI_REFERENCE_MODEL_SV__

