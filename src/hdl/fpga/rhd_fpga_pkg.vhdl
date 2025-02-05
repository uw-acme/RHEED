-------------------------------------------------------------------------------
-- Filename :   rhd_fpga_pkg.vhd
--
-- Package for FPGA type definitions, clock freq, and address map constants
--
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- External clock is 50 MHz
-------------------------------------------------------------------------------
package rhd_fpga_pkg is

-- FPGA clock freq expressed in MHz
constant C_CLK_MHZ              : real      :=  50.0; 

-- Clock period
constant C_CLK_PERIOD           : time      := integer(1.0E+6/(C_CLK_MHZ)) * 1 ps;

--------------------------------------------------------------------------------
-- Define the number of parameter registers that are loaded through the serial
-- interface.
--------------------------------------------------------------------------------
constant C_NUM_REGS32       : integer := 5;

--------------------------------------------------------------------------------
-- Add other FPGA design constants or datatypes here
--------------------------------------------------------------------------------
constant ADR_REG_PARAM0     : integer :=  0;                -- First parameter register
constant ADR_REG_PARAM_LAST : integer :=  C_NUM_REGS32 - 1; -- Last parameter register

constant ADR_REG_VERSION    : integer := 8;                 -- Read-only register containing HDL code version number
constant ADR_REG_LEDS       : integer := 9;                 -- '1' sets LED on

end package;

package body rhd_fpga_pkg is

end package body;

