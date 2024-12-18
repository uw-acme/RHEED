RHEED CPUINT usage

The RHEED example shows how the cpuint block can be used.

I created a wrapper (rhd_registers_misc) for the serial interface that contains 10 32-bit registers along with some other useful functions.
The 10 32-bit registers can be written and read back through the serial interface. 
See the testbench code in tb_rheed1. 
The registers are combined into a single bus that is connected to the dummy HLS4ML block.

![image](https://github.com/user-attachments/assets/bbc7bb8e-f61a-47d2-beec-40ab2c0f18db)

            
Testbench file compilation order

../github/RHEED/src/hdl/fpga/rhd_version_pkg.vhdl
../github/RHEED/src/hdl/fpga/rhd_fpga_pkg.vhdl
../github/RHEED/src/hdl/fpga/rhd_blink.vhdl
../github/RHEED/src/hdl/cpuint/rhd_serial_pkg_50MHz.vhdl 
../github/RHEED/src/hdl/cpuint/rhd_uart.vhdl 
../github/RHEED/src/hdl/cpuint/rhd_uart2cpu.vhdl 
../github/RHEED/src/hdl/cpuint/rhd_cpu2uart.vhdl 
../github/RHEED/src/hdl/cpuint/rhd_cpuint_serial.vhdl 
../github/RHEED/src/hdl/fpga/rhd_registers_misc.vhdl 
../github/RHEED/src/hdl/fpga/rhd_hls4ml.vhdl 
../github/RHEED/src/hdl/fpga/rhd_fpga_top.vhdl 
../github/RHEED/src/hdl/tb/iopakp.vhd 
../github/RHEED/src/hdl/tb/iopakb.vhd 
../github/RHEED/src/hdl/tb/tb_rheed1.vhd
