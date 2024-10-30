lappend auto_path "C:/lscc/radiant/2023.2/scripts/tcl/simulation"
package require simulation_generation
set ::bali::simulation::Para(DEVICEPM) {ice40tp}
set ::bali::simulation::Para(DEVICEFAMILYNAME) {iCE40UP}
set ::bali::simulation::Para(PROJECT) {core_sim_fifo}
set ::bali::simulation::Para(MDOFILE) {}
set ::bali::simulation::Para(PROJECTPATH) {C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/core_sim_fifo}
set ::bali::simulation::Para(FILELIST) {"C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/source/core.v" "C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/source/spi.v" "C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/spi_counter/rtl/spi_counter.v" "C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/source/ram.v" "C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/testbench/VNA_FPGA_DSP_minimal_tf.v" }
set ::bali::simulation::Para(GLBINCLIST) {}
set ::bali::simulation::Para(INCLIST) {"none" "none" "none" "none" "none"}
set ::bali::simulation::Para(WORKLIBLIST) {"work" "work" "work" "" "" }
set ::bali::simulation::Para(COMPLIST) {"VERILOG" "VERILOG" "VERILOG" "VERILOG" "VERILOG" }
set ::bali::simulation::Para(LANGSTDLIST) {"Verilog 2001" "Verilog 2001" "Verilog 2001" "" "" }
set ::bali::simulation::Para(SIMLIBLIST) {pmi_work ovi_ice40up}
set ::bali::simulation::Para(MACROLIST) {}
set ::bali::simulation::Para(SIMULATIONTOPMODULE) {dsp_core_tf}
set ::bali::simulation::Para(SIMULATIONINSTANCE) {}
set ::bali::simulation::Para(LANGUAGE) {VERILOG}
set ::bali::simulation::Para(SDFPATH)  {}
set ::bali::simulation::Para(INSTALLATIONPATH) {C:/lscc/radiant/2023.2}
set ::bali::simulation::Para(MEMPATH) {C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/adc_counter;C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/pll_core;C:/Users/matej/RadiantProjects/VNA_FPGA_DSP/spi_counter}
set ::bali::simulation::Para(UDOLIST) {}
set ::bali::simulation::Para(ADDTOPLEVELSIGNALSTOWAVEFORM)  {1}
set ::bali::simulation::Para(RUNSIMULATION)  {0}
set ::bali::simulation::Para(SIMULATIONTIME)  {0}
set ::bali::simulation::Para(SIMULATIONTIMEUNIT)  {}
set ::bali::simulation::Para(SIMULATION_RESOLUTION)  {}
set ::bali::simulation::Para(ISRTL)  {1}
set ::bali::simulation::Para(HDLPARAMETERS) {}
::bali::simulation::ModelSim_Run
