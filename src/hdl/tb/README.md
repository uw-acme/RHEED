RHEED usage

The RHEED example shows how the cpuint block can be used.

I created a wrapper (rhd_registers_misc) for the serial interface that contains 10 32-bit registers along with some other useful functions.
The 10 32-bit registers can be written and read back through the serial interface. 
See the testbench code in tb_rheed1. 
The registers are combined into a single bus that is connected to the dummy HLS4ML block.

![image](https://github.com/user-attachments/assets/bbc7bb8e-f61a-47d2-beec-40ab2c0f18db)

            
