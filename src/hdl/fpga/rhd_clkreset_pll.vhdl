--------------------------------------------------------------------------
--  File         : clkreset_pll.vhd
----------------------------------------------------------------------------
--  Description  : Wrapper for clock PLL and reset logic
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;


entity rhd_clkreset is
port(
    -- Reset and clock from pads
    p_reset_n    : in  std_logic;
    p_clk        : in  std_logic;

    -- Reset and clock outputs to all internal logic
    clk          : out std_logic;
    clk_fast     : out std_logic;
    lock         : out std_logic;
    reset        : out std_logic
);
end rhd_clkreset;

------------------------------------------------------------------------
------------------------------------------------------------------------
architecture pll of rhd_clkreset is

signal pll_locked       : std_logic;
signal pll_locked_d1    : std_logic := '0';
signal clk_i            : std_logic;
signal cnt_reset        : unsigned(7 downto 0)  := X"00";
signal reset_pll        : std_logic;

------------------------------------------------------------------------
-- 50MHz input, 
-- c0 50MHz     -> clk
-- c1 250MHz    -> clk_fast
------------------------------------------------------------------------
component pll 
port (
    inclk0     :  in  std_logic := '0'; -- refclk.clk
    areset     :  in  std_logic := '0'; -- reset.reset
    c0         :  out std_logic;        -- outclk0.clk
    c1         :  out std_logic;        -- outclk1.clk
    locked     :  out std_logic         -- locked.export
);
end component;

begin

    clk         <= clk_i;
    lock        <= pll_locked;
    reset_pll   <= not(p_reset_n);
     
    ---------------------------------------------------------------------------------
    -- Clock generator. 
    -- 50MHz input clock.
    -- This is ALTERA PLL. Replace with Xilinx if necessary
    ---------------------------------------------------------------------------------
    u_pll : pll 
    port map(
        inclk0      => p_clk       , -- in  std_logic := '0'; -- refclk.clk
        areset      => reset_pll   , -- in  std_logic := '0'; -- reset.reset
        c0          => clk_i       , -- out std_logic;        -- outclk0.clk 50MHz
        locked      => pll_locked    -- out std_logic         -- locked.export
    );


    -------------------------------------------------------------------------------
    -- Keep all external-to-this-block logic reset until PLL locked 
    -------------------------------------------------------------------------------
    pr_reset : process (p_reset_n, pll_locked, clk_i)
    begin
        if (p_reset_n = '0' or pll_locked = '0') then
        
            reset           <= '1';                    
            pll_locked_d1   <= '0';
            cnt_reset       <= X"00";

        elsif rising_edge(clk_i) then

            pll_locked_d1   <= pll_locked;

            if (pll_locked_d1 = '1' and cnt_reset < X"FF") then
                cnt_reset   <= cnt_reset + 1;
            end if;

            if (cnt_reset < X"0F") then
                reset       <= '1';                    
            else    
                reset       <= '0';                    
            end if;

        end if;
    end process;

end pll;


