--------------------------------------------------------------------------
--  File         : clkreset_pll.vhd
----------------------------------------------------------------------------
--  Description  : Wrapper for clock PLL and reset logic
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rhd_fpga_pkg.all;

entity rhd_hls4ml is
port(
        clk             : in  std_logic;
        reset           : in  std_logic;
        parameters      : in  std_logic_vector((32*C_NUM_REGS32)-1 downto 0);
        debug           : out std_logic_vector( 3 downto 0);

        din             : in  std_logic_vector( 7 downto 0);
        din_dv          : in  std_logic;
        dout            : out std_logic_vector( 7 downto 0);
        dout_dv         : out std_logic
);
end rhd_hls4ml;

------------------------------------------------------------------------
------------------------------------------------------------------------
architecture rtl of rhd_hls4ml is


begin

    -------------------------------------------------------------------------------
    --  
    -------------------------------------------------------------------------------
    pr_main : process (reset, clk)
    begin
        if (reset = '1') then
        
        	dout            <= (others=>'0');
        	dout_dv         <= '0';

        elsif rising_edge(clk) then

        	dout            <= din or parameters(7 downto 0);
        	dout_dv         <= din_dv;

        end if;
    end process;

end rtl;


