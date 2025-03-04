-------------------------------------------------------------------------------
-- Filename :   rhd_fpga_pkg.vhd
--
-- Package for FPGA type definitions, clock freq, and address map constants
--
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;

--------------------------------------------------------------------------------
-- External clock is 50 MHz
-------------------------------------------------------------------------------
package rhd_fpga_pkg is

-- FPGA clock freq expressed in MHz
constant C_CLK_MHZ          : real	:=  50.0; 

-- Clock period
constant C_CLK_PERIOD       : time	:= integer(1.0E+6/(C_CLK_MHZ)) * 1 ps;

--------------------------------------------------------------------------------
-- Define the number of parameter registers that are loaded through the serial
-- interface.
--------------------------------------------------------------------------------
constant C_NUM_CROP_BOX     : integer := 5;
constant C_NUM_RW_REGS32    : integer := C_NUM_CROP_BOX;	-- Each crop box needs two 16-bit parameters

--------------------------------------------------------------------------------
-- Define the number of result registers that are read through the serial
-- interface.
--------------------------------------------------------------------------------
constant C_NUM_RESULTS      	: integer := 5;						-- Number of results from CNN for each crop box
constant C_BITWIDTH_RESULTS 	: integer := 8;						-- Number of bits in each result from CNN
constant C_BITS_PER_CROP_RESULT	: integer := C_NUM_RESULTS * C_BITWIDTH_RESULTS; -- 40
constant C_REGS_PER_CROP_RESULT	: integer := integer(ceil(real(C_BITS_PER_CROP_RESULT)/32.0)); -- 2

constant C_NUM_RO_REGS32    	: integer := C_NUM_CROP_BOX * C_REGS_PER_CROP_RESULT; 	-- Results from each box require N 32-bit registers

--------------------------------------------------------------------------------
-- Register addresses
--------------------------------------------------------------------------------
constant ADR_REG_PARAM0     : integer := 0;                						-- First parameter register address
constant ADR_REG_PARAM_LAST : integer := ADR_REG_PARAM0 + C_NUM_RW_REGS32 - 1; 	-- Last parameter register address

constant ADR_REG_RESULT0    : integer := 16;                					-- First result register address
constant ADR_REG_RESULT_LAST: integer := ADR_REG_RESULT0 + C_NUM_RO_REGS32 - 1;	-- Last last register address

constant ADR_REG_VERSION    : integer := 32;                 					-- Read-only register containing HDL code version number
constant ADR_REG_LEDS       : integer := 33;                 					-- '1' sets LED on
constant ADR_REG_STATUS     : integer := 34;                 					-- Status register
constant ADR_REG_NONE       : integer := 63;                 					-- Non-existant register to test default readback

end package;

package body rhd_fpga_pkg is

end package body;

