----------------------------------------------------------------------------
--  File         : rhd_registers_misc.vhd
----------------------------------------------------------------------------
-- Description  : Serial interface to Miscellaneous signals interface. 
--                Contains version register and LED control register 
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rhd_fpga_pkg.all;
use     work.rhd_version_pkg.all;

entity rhd_registers_misc is
generic (
    G_NUM_REGS32    : integer := 10
);
port (
    clk             : in  std_logic;
    reset           : in  std_logic;

    -- UART interface to CPU              
    cpuint_rxd      : in  std_logic;    -- UART Receive data
    cpuint_txd      : out std_logic;    -- UART Transmit data 

    leds            : out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive

    debug           : out std_logic_vector( 3 downto 0);

    parameters      : out std_logic_vector(((32*G_NUM_REGS32) - 1) downto 0)     -- Input to HLS4ML logic
);
end rhd_registers_misc;


---------------------------------------------------------------------------------
-- Register block containing Parameter registers, Version number reg, LEDs control
-- Debug control that can be written
---------------------------------------------------------------------------------
architecture rtl of rhd_registers_misc is

signal reg_leds         : std_logic_vector( 7 downto 0); 
signal pulse            : std_logic_vector( 1 downto 0); 
signal pulse_stretched  : std_logic_vector( 1 downto 0);
signal tick_msec        : std_logic;                        -- Single cycle high every 1 msec. Used by serial interface
signal flash            :  std_logic;                       -- For blinking an LED 

type t_arr_regs is array (0 to G_NUM_REGS32-1) of std_logic_vector(31 downto 0);
signal arr_regs         : t_arr_regs;

signal cpu_wr           : std_logic;
signal cpu_sel          : std_logic;
signal cpu_addr         : std_logic_vector(15 downto 0);
signal cpu_wdata        : std_logic_vector(31 downto 0);
signal cpu_rdata_dv     : std_logic;
signal cpu_rdata        : std_logic_vector(31 downto 0);

signal cpuint_txd_i     : std_logic;	-- Internal use

begin  

	cpuint_txd          <= cpuint_txd_i;
	
    
    --------------------------------------------------------------------
    -- Serial interface to CPU
    --------------------------------------------------------------------
    u_cpuint : entity work.rhd_cpuint
    port map(
        clk                 => clk              , -- in  std_logic;
        reset               => reset            , -- in  std_logic;
        tick_msec           => tick_msec        , -- in  std_logic;    -- Used to reset interface if a message is corrupted

        rxd                 => cpuint_rxd       , -- in  std_logic;    -- UART Receive data
        txd                 => cpuint_txd_i     , -- out std_logic;    -- UART Transmit data 

        cpu_rd              => open             , -- out std_logic;
        cpu_wr              => cpu_wr           , -- out std_logic;
        cpu_sel             => cpu_sel          , -- out std_logic; 
        cpu_addr            => cpu_addr         , -- out std_logic_vector(15 downto 0);
        cpu_wdata           => cpu_wdata        , -- out std_logic_vector(31 downto 0);
                                  
        cpu_rdata_dv        => cpu_rdata_dv     , -- in  std_logic;
        cpu_rdata           => cpu_rdata        , -- in  std_logic_vector(31 downto 0);

        debug               => debug              -- out std_logic_vector( 3 downto 0)
    );


    --------------------------------------------------------------------
    -- Flash can be used to blink an LED.
    -- Pulse inputs get stretched to make them visible on LEDs.
    -- The 'tick_msec' signal is used by the serial interface to
    -- reset the serial interface if a message is corrupted.
    --------------------------------------------------------------------
    u_blink : entity work.rhd_blink
    generic map (
        G_NBITS                => 2,
        G_INTERVAL_TICK_SLOW   => 10  -- TODO 20. Set flash and stretch timing 
    )
    port map(
        reset      => reset             , -- in   std_logic;
        clk        => clk               , -- in   std_logic;
        flash      => flash             , -- out  std_logic;
        tick_sec   => open              , -- out  std_logic;    -- Slower tick rate
        tick_msec  => tick_msec         , -- out  std_logic;
        tick_usec  => open              , -- out  std_logic;
        pulse      => pulse             , -- in   std_logic_vector(NBITS-1 downto 0);
        stretched  => pulse_stretched     -- out  std_logic_vector(NBITS-1 downto 0)
    );

    pulse(0)        <= cpuint_rxd;
    pulse(1)        <= cpuint_txd_i;
    
    leds(0)         <= flash              or reg_leds(0);
    leds(1)         <= pulse_stretched(0) or reg_leds(1);
    leds(2)         <= pulse_stretched(1) or reg_leds(2);
    leds(3)         <=                       reg_leds(3);
    leds(4)         <=                       reg_leds(4);
    leds(5)         <=                       reg_leds(5);
    leds(6)         <=                       reg_leds(6);
    leds(7)         <=                       reg_leds(7);

    
    ---------------------------------------------------------------------------------
    -- CPU uses serial interface to write to these registers
    ---------------------------------------------------------------------------------
    pr_cpu_rw : process (clk)
    variable v_addr : integer range 0 to 15;
    begin
    
        if rising_edge(clk) then

            v_addr:= to_integer(unsigned(cpu_addr(3 downto 0)));
            cpu_rdata_dv  <= '0';
                
            if (reset='1') then
            
                reg_leds            <= (others=>'0');

                for I in 0 to G_NUM_REGS32-1 loop
                    arr_regs(I)     <= (others=>'0');
                end loop;
                
            -- Write registers
            elsif (cpu_sel='1' and cpu_wr='1') then
    
                if (v_addr = ADR_REG_LEDS) then
                    reg_leds            <= cpu_wdata( 7 downto 0);
                elsif (v_addr < G_NUM_REGS32) then
                    arr_regs(v_addr)     <= cpu_wdata;
                end if;
    
            -- Read registers
            elsif (cpu_sel='1' and cpu_wr='0') then
    
                if (v_addr = ADR_REG_LEDS) then
                    cpu_rdata       <= X"000000" & reg_leds;
                    
                elsif (v_addr = ADR_REG_VERSION) then
                    cpu_rdata       <= C_RHD_VERSION;
                    
                elsif (v_addr < G_NUM_REGS32) then
                    cpu_rdata       <= arr_regs(v_addr);
                
                else
                    cpu_rdata        <= X"DEADBEEF";
                
                end if;
    
                cpu_rdata_dv  <= '1';
    
            end if;
    
        end if;
    
    end process;
    
    
    ---------------------------------------------------------------------------------
    -- Drive registers onto parameter port
    ---------------------------------------------------------------------------------
    pr_parameters : process (arr_regs)
    begin
                for I in 0 to G_NUM_REGS32-1 loop
                    parameters((32*(I+1)-1) downto 32*I)  <= arr_regs(I);
                end loop;
    end process;
    
    
end;

