---------------------------------------------------------------
--  File         : rhd_fpga_top.vhd
--  Description  : Top-level of PRRT-POD FPGA
----------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

use     work.rhd_fpga_pkg.all;

entity rhd_fpga_top is
port (
    p_clock_50              : in    std_logic;          -- Clock input
    p_reset_n               : in    std_logic;          -- Reset

    -- Input and output data  
    p_din                   : in    std_logic_vector( 7 downto 0);
    p_din_dv                : in    std_logic;
    p_dout                  : out   std_logic_vector( 7 downto 0);
    p_dout_dv               : out   std_logic;

    -- Indicator LEDs
    p_leds                  : out   std_logic_vector( 7 downto 0);      -- '1' = Lit

    -- Switches and pushbuttons
  --p_sw_dip                : in    std_logic_vector( 3 downto 0);      -- 
  --p_pushbtn_n             : in    std_logic;                          -- Debounced. Normally pulled up

    -- Serial interface to user
    p_serial_rxd            : in    std_logic;          -- UART Receive data 
    p_serial_txd            : out   std_logic;          -- UART Transmit data 

    -- Debug port 
    p_debug_out             : out   std_logic_vector( 7 downto 0)
);
end entity;


---------------------------------------------------------------
-- Architecture containing clock generator, serial port registers
-- and HLS4ML top level.
---------------------------------------------------------------
architecture rtl of rhd_fpga_top is

signal reset                : std_logic;
signal clk                  : std_logic;
signal pll_lock             : std_logic;

signal regs_parameters      : std_logic_vector((32*C_NUM_REGS32)-1 downto 0);

signal cpuint_rxd           : std_logic;    -- UART Receive data
signal cpuint_txd           : std_logic;    -- UART Transmit data 

signal regs_debug           : std_logic_vector( 3 downto 0);
signal hls_debug            : std_logic_vector( 3 downto 0);

begin

    --------------------------------------------------------------------
    -- Power on reset circuit, PLL clock generation.
    --------------------------------------------------------------------
    --u_clk_reset : entity work.rhd_clkreset
    --port map(
    --    -- Reset and clock from pads
    --    p_reset_n    => p_reset_n   , -- in  std_logic;
    --    p_clk        => p_clock_50  , -- in  std_logic;
    --
    --    -- Reset and clock outputs to all internal logic
    --    clk          => clk         , -- out std_logic;
    --    lock         => pll_lock    , -- out std_logic;
    --    reset        => reset         -- out std_logic
    --);
    reset   <= not(p_reset_n);
    clk     <= p_clock_50;


    --------------------------------------------------------------------
    -- HLS4ML output block
    --------------------------------------------------------------------
    u_hls4ml : entity work.rhd_hls4ml
    port map(
        clk             => clk                    , -- in  std_logic;
        reset           => reset                  , -- in  std_logic;
        parameters      => regs_parameters        , -- in  std_logic_vector((32*C_NUM_REGS32)-1 downto 0);
        debug           => hls_debug              , -- out std_logic_vector( 3 downto 0);

        din             => p_din                  , -- in  std_logic_vector( 7 downto 0);
        din_dv          => p_din_dv               , -- in  std_logic;
        dout            => p_dout                 , -- out std_logic_vector( 7 downto 0);
        dout_dv         => p_dout_dv                -- out std_logic;
    );


    ---------------------------------------------------------------------------------
    -- Serial interface for loading parameters
    ---------------------------------------------------------------------------------
    u_rhd_regs : entity work.rhd_registers_misc
    generic map(
        G_NUM_REGS32    => C_NUM_REGS32       -- integer := 5
    )
    port map(
        clk             => clk              , -- in  std_logic;
        reset           => reset            , -- in  std_logic;

        debug           => regs_debug       , -- out std_logic_vector( 3 downto 0);

        -- UART interface to CPU              
        cpuint_rxd      => cpuint_rxd       , -- in  std_logic;    -- UART Receive data
        cpuint_txd      => cpuint_txd       , -- out std_logic;    -- UART Transmit data 

        leds            => p_leds           , -- out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive

        parameters      => regs_parameters    -- out std_logic_vector(((32*C_NUM_REGS32) - 1) downto 0)
    );


    ---------------------------------------------------------------------------------
    -- UART pins
    ---------------------------------------------------------------------------------
    cpuint_rxd          <= p_serial_rxd;
    p_serial_txd        <= cpuint_txd;


    ---------------------------------------------------------------------------------
    -- Debug output
    ---------------------------------------------------------------------------------
    pr_dbg : process (clk)
    begin
    
        if rising_edge(clk) then

            p_debug_out(0)              <= pll_lock;
            p_debug_out(1)              <= cpuint_rxd;	 -- Copies of serial port signals
            p_debug_out(2)              <= cpuint_txd;
            p_debug_out(3)              <= '0';
            p_debug_out(4)              <= '0';
            p_debug_out(5)              <= '0';
            p_debug_out(6)              <= '0';
            p_debug_out(7)              <= '0';

        end if;
        
    end process;


end rtl;