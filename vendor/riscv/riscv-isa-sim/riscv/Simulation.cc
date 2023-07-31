// See LICENSE for license details.

#include "Simulation.h"
#include "mmu.h"
#include <map>
#include <iostream>
#include <sstream>
#include <climits>
#include <cstdlib>
#include <cassert>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <inttypes.h>
#include <stdio.h>
#include "Simulation.h"

using namespace openhw;

std::vector<std::pair<reg_t, abstract_device_t*>> plugin_devs;

void sim_thread_main(void* arg)
{
      ((sim_t*)arg)->run();
      std::cout << "[SPIKE-TANDEM] Simulation has exited" << std::endl;
      ((sim_t*)arg)->switch_to_host(); // To get the first point
}

// FIXME TODO Review settings of dm_config below.
debug_module_config_t dm_config = {
  .progbufsize = 2,
  .max_sba_data_width = 0,
  .require_authentication = false,
  .abstract_rti = 0,
  .support_hasel = true,
  .support_abstract_csr_access = true,
  .support_abstract_fpr_access = true,
  .support_haltgroups = true,
  .support_impebreak = true
};

Simulation::Simulation(const cfg_t *cfg, bool halted,
        std::vector<std::pair<reg_t, mem_t*>> mems,
        std::vector<std::pair<reg_t, abstract_device_t*>> plugin_devices,
        const std::vector<std::string>& args,
        const debug_module_config_t &dm_config, const char *log_path,
        bool dtb_enabled, const char *dtb_file,
        bool socket_enabled,
        FILE *cmd_file, // needed for command line option --cmd
        openhw::Params& params)
    : sim_t(cfg, halted, mems, plugin_devices, args, dm_config, log_path,
            dtb_enabled, dtb_file, socket_enabled, cmd_file, params)
{
  // It seems mandatory to set cache block size for MMU.
  // FIXME TODO: Use actual cache configuration (on/off, # of ways/sets).
  // FIXME TODO: Support multiple cores.
  get_core(0)->get_mmu()->set_cache_blocksz(reg_t(64));

  this->params.set("/top/", "isa", any(std::string("RV32GC")));

  this->params.set("/top/", "bootrom", std::any(true));
  this->params.set("/top/", "bootrom_base", std::any(0x10000UL));
  this->params.set("/top/", "bootrom_size", std::any(0x1000UL));

  this->params.set("/top/", "dram", std::any(true));
  this->params.set("/top/", "dram_base", std::any(0x80000000UL));
  this->params.set("/top/", "dram_size", std::any(0x64UL * 1024 * 1024));

  this->params.set("/top/", "log_commits", std::any(true));

  this->params.set("/top/", "max_steps_enabled", std::any(false));
  this->params.set("/top/", "max_steps", std::any(200000UL));

  ParseParams("/top/", this->params, params);

  const std::vector<mem_cfg_t> layout;

  this->make_mems(layout);

  for (auto& x : this->mems)
    bus.add_device(x.first, x.second);

  string isa_str = std::any_cast<string>(this->params["/top/isa"]);
  this->isa = isa_parser_t (isa_str.c_str(), DEFAULT_PRIV);
  std::cout << "[SPIKE-TANDEM] Configure simulation with isa " << isa_str << std::endl;

  this->reset();

  bool commitlog = std::any_cast<bool>(this->params["/top/log_commits"]);
  this->configure_log(commitlog, commitlog);

  this->max_steps = std::any_cast<uint64_t>(this->params["/top/max_steps"]);
  this->max_steps_enabled = std::any_cast<bool>(this->params["/top/max_steps_enabled"]);

  std::cerr << "[SPIKE-TANDEM] Max steps : " << this->max_steps_enabled << " " << this->max_steps << std::endl;

  std::cerr << "[SPIKE-TANDEM] Simulator instantiated" << std::endl;
  target.init(sim_thread_main, this);
  std::cout << "[SPIKE_TANDEM] Initializaing context" << std::endl;
  host = context_t::current();
  target.switch_to(); // To get the first point

}

Simulation::Simulation(const cfg_t *cfg, string elf_path,
             Params& params)
    : Simulation(cfg,   // cfg
          false,  // halted
          std::vector<std::pair<reg_t, mem_t*>>(),  // mems
          plugin_devs,
          std::vector<std::string>() = {elf_path},
          dm_config,
          "tandem.log",  // log_path
          true, // dtb_enabled
          nullptr,  // dtb_file
          false, // socket_enabled
          NULL,  // cmd_file
          params)
{

}

Simulation::~Simulation()
{
}

int Simulation::run()
{
    // TODO make this prettier
    while(!sim_t::done()) {
        st_rvfi rvfi = this->nstep(1);
    }
    return sim_t::exit_code();
}

void Simulation::make_mems(const std::vector<mem_cfg_t> &layout)
{

  for (const auto &cfg : layout) {
    mems.push_back(std::make_pair(cfg.get_base(), new mem_t(cfg.get_size())));
  }

  bool bootrom = std::any_cast<bool>(this->params["/top/bootrom"]);
  uint64_t bootrom_base = std::any_cast<uint64_t>(this->params["/top/bootrom_base"]);
  uint64_t bootrom_size = std::any_cast<uint64_t>(this->params["/top/bootrom_size"]);
  if (bootrom) {
    auto bootrom_device = std::make_pair(bootrom_base, new mem_t(bootrom_size));

    std::cerr << "[Spike Tandem] Initializing memories...\n";
    uint8_t rom_check_buffer[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
  // Populate the ROM.  Reset vector size is in 32-bit words and must be scaled.
#include "bootrom.h"
    if (!bootrom_device.second->store(reg_t(0), reset_vec_size << 2, (const uint8_t *) reset_vec))
        std::cerr << "[Spike Tandem] *** ERROR: Failed to initialize ROM!\n";
        bootrom_device.second->load(reg_t(0), 8, rom_check_buffer);
    fprintf(stderr, "[SPIKE] ROM content head(8) = %02x %02x %02x %02x %02x %02x %02x %02x\n",
        rom_check_buffer[0], rom_check_buffer[1], rom_check_buffer[2], rom_check_buffer[3],
        rom_check_buffer[4], rom_check_buffer[5], rom_check_buffer[6], rom_check_buffer[7]);

    this->mems.push_back(bootrom_device);
  }

  bool dram = std::any_cast<bool>(this->params["/top/dram"]);
  uint64_t dram_base = std::any_cast<uint64_t>(this->params["/top/dram_base"]);
  uint64_t dram_size = std::any_cast<uint64_t>(this->params["/top/dram_size"]);
  if (dram)
    this->mems.push_back(std::make_pair(dram_base, new mem_t(dram_size)));

}

st_rvfi Simulation::nstep(size_t n)
{

  // The state PC is the *next* insn fetch address.
  // Catch it before exec which yields a new value.
  st_rvfi rvfi = ((Processor*)procs[0])->step(1);

  host = context_t::current();
  if (!sim_t::done())
  {
      if (this->max_steps_enabled && (this->max_steps < this->total_steps))
      {
          std::cout << "[SPIKE-TANDEM] Max steps excided" << std::endl;
          throw;
      }

      ++total_steps;
      target.switch_to();
  }

  return rvfi;
}


#if 0 // FORNOW Unused code, disable until needed.
void Simulation::set_debug(bool value)
{
  debug = value;
}

void Simulation::set_log(bool value)
{
  log = value;
}

void Simulation::set_histogram(bool value)
{
  histogram_enabled = value;
  for (size_t i = 0; i < procs.size(); i++) {
    procs[i]->set_histogram(histogram_enabled);
  }
}

void Simulation::set_procs_debug(bool value)
{
  for (size_t i=0; i< procs.size(); i++)
    procs[i]->set_debug(value);
}

bool Simulation::mmio_load(reg_t addr, size_t len, uint8_t* bytes)
{
  if (addr + len < addr)
    return false;
  return bus.load(addr, len, bytes);
}

bool Simulation::mmio_store(reg_t addr, size_t len, const uint8_t* bytes)
{
  if (addr + len < addr)
    return false;
  return bus.store(addr, len, bytes);
}

void Simulation::make_bootrom()
{
  start_pc = 0x80000000;

  #include "bootrom.h"

  std::vector<char> rom((char*)reset_vec, (char*)reset_vec + sizeof(reset_vec));

  boot_rom.reset(new rom_device_t(rom));
  bus.add_device(DEFAULT_RSTVEC, boot_rom.get());
}

char* Simulation::addr_to_mem(reg_t addr) {
  auto desc = bus.find_device(addr);
  if (auto mem = dynamic_cast<mem_t*>(desc.second))
    if (addr - desc.first < mem->size())
      return mem->contents() + (addr - desc.first);
  return NULL;
}
#endif

// TODO if we want to do it fancier
int Simulation::loadElf(string path_elf)
{
}

void Simulation::addCore(Processor& core)
{

}

void Simulation::delCore(Processor& core)
{
}

//void Simulation::addMemory(Memory& memory)
//{
//}
//
//void Simulation::delMemory(Memory& memory)
//{
//}
//
