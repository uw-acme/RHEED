RHEED usage

The RHEED example shows how the cpuint block can be used.

I created a wrapper (rhd_registers_misc) for the serial interface that contains 10 32-bit registers along with some other useful functions.
The 10 32-bit registers can be written and read back through the serial interface. 
See the testbench code in tb_rheed1. 
The registers are combined into a single bus that is connected to the dummy HLS4ML block.


tb_rheed1	(Testbench with clock and reset, procedures for UART I/O, FPGA and UART)
  |
  |---- rhd_uart	(Same as UART in CPUINT. Use to send/recv serial messages)
  |
  |---- rhd_fpga_top 	(FPGA top)
        |
        |---- rhd_hls4ml	(This is a placeholder for actual HLS4ML output code)
        |
        |---- rhd_registers_misc	(Serial interface,blink block and registers)
              |
              |---- rhd_cpuint		(The serial interface)
              |	    |
              |	    |---- rhd_uart		(Serial-to-parallel shifter, for rx/tx data transfer)
              |	    |---- rhd_uart2cpu	(State machine to turn uart output into a write cmd)
              |	    |---- rhd_cpu2uart	(State machine to send readback msg to uart) 
              |
              |---- rhd_blink		(A utility block for timing pulses, flashing LEDs etc.
              |
              |---- 10x 32-bit registers for parameters  (Downloaded values for HLS4ML block)
              |---- Read-only version number
              |---- LED control reg
              
