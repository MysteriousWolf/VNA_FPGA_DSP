lappend auto_path "C:/lscc/radiant/2023.2/scripts/tcl/simulation"
package require tbtemplate_generation

set ::bali::Para(MODNAME) soft_spi_slave
set ::bali::Para(PROJECT) VNA_FPGA_DSP
set ::bali::Para(PRIMITIVEFILE) {"C:/lscc/radiant/2023.2/cae_library/synthesis/verilog/iCE40UP.v=iCE40UP"}
set ::bali::Para(TFT) {"C:/lscc/radiant/2023.2/data/templates/plsitft_ice40tp.tft"}
set ::bali::Para(OUTNAME) soft_spi_slave_tf
set ::bali::Para(EXT) .v
set ::bali::Para(FILELIST) {"C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/source/core.v=work,Verilog,Verilog_2001" "C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/spi_peripheral/rtl/spi_peripheral.v=work,Verilog,Verilog_2001" "C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/pll_core/rtl/pll_core.v=work,Verilog,Verilog_2001" "C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/source/spi.v=work,Verilog,Verilog_2001" }
set ::bali::Para(INCLUDEPATH) {"C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/source" "C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/spi_peripheral/rtl" "C:/Users/matej/iCloudDrive/School/Magistrsko delo/Phase Detector/VNA_FPGA_DSP/pll_core/rtl" }
::bali::GenerateTbTemplate
