--------------------------------------------------------------------------
--  File         : rhd_hls4ml.vhd
----------------------------------------------------------------------------
--  Description  : Dummy block to be replaced with actual HLS4ML output
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
        parameters_dv   : in  std_logic;
        debug           : out std_logic_vector( 3 downto 0);

        din_tdata       : in  std_logic_vector( 7 downto 0);
        din_tvalid      : in  std_logic;

        dout_tdata      : out std_logic_vector( 7 downto 0);
        dout_tvalid     : out std_logic
);
end rhd_hls4ml;

------------------------------------------------------------------------
-- Dummy
------------------------------------------------------------------------
architecture dummy of rhd_hls4ml is


begin

    -------------------------------------------------------------------------------
    -- Simple pipeline delay 
    -------------------------------------------------------------------------------
    pr_main : process (reset, clk)
    begin
        if (reset = '1') then
        
        	dout            <= (others=>'0');
        	dout_dv         <= '0';

        elsif rising_edge(clk) then

        	dout_tdata      <= din_tdata or parameters(7 downto 0);
        	dout_tvalid     <= din_tvalid;

        end if;
    end process;

    debug   <= parameters(3 downto 0);

end dummy;



