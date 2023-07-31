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


`ifndef __UVMA_RVFI_SCOREBOARD_SV__
`define __UVMA_RVFI_SCOREBOARD_SV__

`uvm_analysis_imp_decl(_rvfi_instr_reference_model)
`uvm_analysis_imp_decl(_rvfi_instr_core)

enum {
    INSTR_ADDR_MISALIGNED, INSTR_ACCESS_FAULT, ILLEGAL_INSTR, BREAKPOINT,
    LD_ADDR_MISALIGNED, LD_ACCESS_FAULT, ST_ADDR_MISALIGNED, ST_ACCESS_FAULT,
    USER_ECALL, SUPERVISOR_ECALL, VIRTUAL_SUPERVISOR_ECALL, MACHINE_ECALL,
    FETCH_PAGE_FAULT, LOAD_PAGE_FAULT, STORE_PAGE_FAULT, FETCH_GUEST_PAGE_FAULT,
    LOAD_GUEST_PAGE_FAULT, VIRTUAL_INSTRUCTION, STORE_GUEST_PAGE_FAULT
} e_exception_type;

/**
 * Component writing Rvfi monitor transactions rvfi data to disk as plain text.
 */
class uvma_rvfi_scoreboard_c#(int ILEN=DEFAULT_ILEN,
                                  int XLEN=DEFAULT_XLEN) extends uvm_scoreboard#(
   .T_TRN  (uvml_trn_seq_item_c),
   .T_CFG  (uvma_rvfi_cfg_c    ),
   .T_CNTXT(uvma_rvfi_cntxt_c  )
);

   uvm_analysis_imp_rvfi_instr_reference_model#(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN), uvma_rvfi_scoreboard_c) m_imp_reference_model;
   uvm_analysis_imp_rvfi_instr_core#(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN), uvma_rvfi_scoreboard_c) m_imp_core;

   `uvm_component_param_utils(uvma_rvfi_scoreboard_c)

    uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) core[$];
    uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) reference_model[$];

   /**
    * Default constructor.
    */
    function new(string name="uvma_rvfi_scoreboard_c", uvm_component parent=null);
        super.new(name, parent);

        m_imp_reference_model = new("m_imp_reference_model", this);
        m_imp_core = new("m_imp_core", this);

    endfunction : new

   /**
    *  Run Phase
    */
   extern task run_phase(uvm_phase phase);

   extern virtual function void write_rvfi_instr_reference_model(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);

   extern virtual function void write_rvfi_instr_core(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);

    // TODO make this function generic for struct st_rvfi so it can be used in
    // the tandem module
   extern virtual function void compare(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_core, uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_reference_model);


endclass : uvma_rvfi_scoreboard_c

task uvma_rvfi_scoreboard_c::run_phase(uvm_phase phase);
    uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_reference_model;
    uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_core;

    t_reference_model = new("t_reference_model");
    t_core = new("t_core");
    forever begin
        @(reference_model.size > 0);
        t_reference_model = reference_model.pop_front();
        t_core = core.pop_front();

        compare(t_core, t_reference_model);
    end


endtask : run_phase

function void uvma_rvfi_scoreboard_c::write_rvfi_instr_reference_model(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);
    reference_model.push_back(t);
endfunction : write_rvfi_instr_reference_model

function void uvma_rvfi_scoreboard_c::write_rvfi_instr_core(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t);
    core.push_back(t);

endfunction : write_rvfi_instr_core

function void uvma_rvfi_scoreboard_c::compare(uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_core, uvma_rvfi_instr_seq_item_c#(ILEN,XLEN) t_reference_model);
    int core_pc64, reference_model_pc64;
    string cause;
    bit error;

    core_pc64 = {{riscv::XLEN-riscv::VLEN{t_core.pc_rdata[riscv::VLEN-1]}}, t_core.pc_rdata};
    reference_model_pc64 = {{riscv::XLEN-riscv::VLEN{t_reference_model.pc_rdata[riscv::VLEN-1]}}, t_reference_model.pc_rdata};

    assert (t_core.trap === t_reference_model.trap) else begin
        error = 1;
        cause = $sformatf("%s\nInterrupt Mismatch [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, t_reference_model.trap, t_core.trap);
    end
    assert (core_pc64 === reference_model_pc64) else begin
        error = 1;
        cause = $sformatf("%s\nPC Mismatch      [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, reference_model_pc64, core_pc64);
    end

    assert (t_core.insn === t_reference_model.insn) else begin
        error = 1;
        cause = $sformatf("%s\nINSN Mismatch    [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, t_reference_model.insn, t_core.insn);
    end

    assert (t_core.mode === t_reference_model.mode) else begin
        error = 1;
        cause = $sformatf("%s\nPRIV Mismatch    [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, t_reference_model.mode, t_core.mode);
    end

    if (t_core.rd1_addr != 0 | t_reference_model.rd1_addr != 0) begin
        assert (t_core.rd1_addr[4:0] === t_reference_model.rd1_addr[4:0]) else begin
            error = 1;
            cause = $sformatf("%s\nRD ADDR Mismatch [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, t_reference_model.rd1_addr[4:0], t_core.rd1_addr[4:0]);
        end
        assert (t_core.rd1_wdata === t_reference_model.rd1_wdata) else begin
            error = 1;
            cause = $sformatf("%s\nRD VAL Mismatch  [REF]: 0x%-16h [CVA6]: 0x%-16h", cause, t_reference_model.rd1_wdata, t_core.rd1_wdata);
        end
    end

    `uvm_info("rvfi_scoreboard", $sformatf("PC:%-8h INSN:%-8h RD:%-2h RDVAL:%-8h", t_reference_model.pc_rdata, t_reference_model.insn,
            t_reference_model.rd1_addr[4:0], t_reference_model.rd1_wdata), UVM_NONE)
    if (error) begin
        `uvm_fatal("uvm_scoreboard", cause)
    end


endfunction : compare


`endif // __UVMA_RVFI_MON_TRN_LOGGER_SV__

