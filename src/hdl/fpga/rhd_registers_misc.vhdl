----------------------------------------------------------------------------
--  File         : rhd_registers_misc.vhd
----------------------------------------------------------------------------
-- Description  : Serial interface to Miscellaneous signals interface. 
--                Contains version register and LED control register.
--                Contains 5 32-bit read/write registers for setting parameter values 
--                and 10 32-bit read-only registers to read back the 5 8-bit results from 
--                the CNN for each of the 5 crop boxes
--
-- The parameter registers are intended for holding 16-bit pixel locations
-- for five crop windows. Each register holds the upper left x co-ordinate and y-coord of an image window.
-- 31:16 x-coord  
-- 15:0  y-coord 
--
-- The readback registers will contain 5 8-bit results from the CNN for each of the 5 crop boxes
-- reg16 contains 4 8-bit values  from crop0.
-- reg17 contains the 5th 8-bit value from crop0.
-- reg18 and reg19 hold results from crop1
-- ...
-- reg22 and reg23 hold results from crop4 
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_misc.all;

use     work.rhd_fpga_pkg.all;
use     work.rhd_version_pkg.all;

entity rhd_registers_misc is
port (
    clk             : in  std_logic;
    reset           : in  std_logic;

    -- UART interface to CPU              
    cpuint_rxd      : in  std_logic;    -- UART Receive data
    cpuint_txd      : out std_logic;    -- UART Transmit data 

    leds            : out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive

    debug           : out std_logic_vector( 3 downto 0);

    results         : in  std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
    results_dv      : in  std_logic;         	

	parameters      : out std_logic_vector(((32*C_NUM_CROP_BOX) - 1) downto 0);    	-- Input to HLS4ML logic
	parameters_dv   : out std_logic                                                 -- Input to HLS4ML logic
);
end rhd_registers_misc;


---------------------------------------------------------------------------------
-- Register block containing Parameter registers, Version number reg, LEDs control
-- Debug has two bits used. One for parameters_dv and the other for results_all_dv
---------------------------------------------------------------------------------
architecture rtl of rhd_registers_misc is

signal reg_leds         : std_logic_vector( 7 downto 0); 
signal reg_status       : std_logic_vector( 7 downto 0); 
signal pulse            : std_logic_vector( 1 downto 0); 
signal pulse_stretched  : std_logic_vector( 1 downto 0);
signal tick_msec        : std_logic;                        -- Single cycle high every 1 msec. Used by serial interface
signal flash            : std_logic;                        -- For blinking an LED 

type t_arr_regs_ro is array (0 to C_NUM_RO_REGS32-1) of std_logic_vector(31 downto 0);
signal arr_regs_ro      : t_arr_regs_ro;

type t_arr_regs_rw is array (0 to C_NUM_RW_REGS32-1) of std_logic_vector(31 downto 0);
signal arr_regs_rw      : t_arr_regs_rw;

signal cpu_wr           : std_logic;
signal cpu_sel          : std_logic;
signal cpu_addr         : std_logic_vector(15 downto 0);
signal cpu_wdata        : std_logic_vector(31 downto 0);
signal cpu_rdata_dv     : std_logic;
signal cpu_rdata        : std_logic_vector(31 downto 0);

signal cpuint_txd_i     : std_logic;	-- Internal use
signal parameters_dv_i  : std_logic;	-- Internal use

signal results_all_dv   : std_logic;	-- Flag set when all resuts in a frame have been seen
signal ncnt_results     : integer := 0;	-- Counter for results in a frame

begin  

	cpuint_txd          <= cpuint_txd_i;
	parameters_dv		<= parameters_dv_i;
	
	debug(0)			<= parameters_dv_i;
	debug(1)			<= results_all_dv;
	debug(2)			<= '0';
	debug(3)			<= '0';
	
    reg_status(0)			<= parameters_dv_i;
	reg_status(1)       	<= results_all_dv;
	reg_status(7 downto 2)	<= (others=>'0');
	
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

        debug               => open               -- out std_logic_vector( 3 downto 0)
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
    leds(3)         <= results_all_dv     or reg_leds(3);
    leds(4)         <= parameters_dv_i    or reg_leds(4);
    leds(5)         <=                       reg_leds(5);
    leds(6)         <=                       reg_leds(6);
    leds(7)         <=                       reg_leds(7);

    
    ---------------------------------------------------------------------------------
    -- CPU uses serial interface to write to these registers
    ---------------------------------------------------------------------------------
    pr_cpu_wr : process (reset, clk)
    variable v_addr : integer range 0 to 63;
    begin
    
		if (reset='1') then
		
			reg_leds            <= (others=>'0');
			parameters_dv_i		<= '0';
			
			for I in 0 to C_NUM_RW_REGS32-1 loop
				arr_regs_rw(I)  <= (others=>'0');
			end loop;
			
        elsif rising_edge(clk) then

            v_addr			:= to_integer(unsigned(cpu_addr(5 downto 0)));
                
            -- Write registers
            if (cpu_sel='1' and cpu_wr='1') then
    
                if (v_addr = ADR_REG_LEDS) then
                    reg_leds            <= cpu_wdata( 7 downto 0);
				
				-- Parameter registers
                elsif (v_addr >= ADR_REG_PARAM0) and (v_addr <= ADR_REG_PARAM_LAST) then
				
                    arr_regs_rw(v_addr)  <= cpu_wdata;
					
					if (v_addr = ADR_REG_PARAM_LAST) then 	-- Set parameters_dv (valid) when last parameter reg is written
					    parameters_dv_i	<= '1';
					else
						parameters_dv_i	<= '0';				-- Clear parameters valid when any other parameter reg is written
					end if;
					
				end if;
				
			end if;
			
        end if;
    
    end process;
	
					
    ---------------------------------------------------------------------------------
    -- CPU uses serial interface to read these registers
    ---------------------------------------------------------------------------------
    pr_cpu_rd : process (reset, clk)
    variable v_addr : integer range 0 to 63;
    begin
    
		if (reset='1') then
			
            cpu_rdata_dv  	<= '0';
			
        elsif rising_edge(clk) then

            v_addr			:= to_integer(unsigned(cpu_addr(5 downto 0)));
            cpu_rdata_dv  	<= '0';
                
			------------------------------------------------------------
            -- Read registers
			------------------------------------------------------------
            if (cpu_sel='1' and cpu_wr='0') then
    
                if (v_addr = ADR_REG_LEDS) then
                    cpu_rdata       <= X"000000" & reg_leds;
                    
                elsif (v_addr = ADR_REG_VERSION) then
                    cpu_rdata       <= C_RHD_VERSION;
                    
                elsif (v_addr = ADR_REG_STATUS) then
                    cpu_rdata       <= X"000000" & reg_status;
                    
                elsif (v_addr >= ADR_REG_PARAM0) and (v_addr <= ADR_REG_PARAM_LAST) then
                    cpu_rdata       <= arr_regs_rw(v_addr-ADR_REG_PARAM0);
                
                elsif (v_addr >= ADR_REG_RESULT0) and (v_addr <= ADR_REG_RESULT_LAST) then
                    cpu_rdata       <= arr_regs_ro(v_addr-ADR_REG_RESULT0);
                
                else
                    cpu_rdata       <= X"DEADBEEF";
                
                end if;
    
                cpu_rdata_dv  <= '1';
				
            end if;
			   
        end if;
    
    end process;
    
    
    ---------------------------------------------------------------------------------
    -- Drive parameter registers onto parameter port
    ---------------------------------------------------------------------------------
    pr_parameters : process (arr_regs_rw)
    begin                                
        for I in 0 to (ADR_REG_PARAM_LAST - ADR_REG_PARAM0) loop
            parameters((32*(I+1)-1) downto 32*I)  <= arr_regs_rw(ADR_REG_PARAM0 + I);
        end loop;
    end process;
    
 
	---------------------------------------------------------------------------------
    -- Capture results ports into arr_regs.
	-- ** NOTE ** separate data valid for each result
    ---------------------------------------------------------------------------------
    pr_results: process (clk)
    begin
		if (reset='1') then
		
			results_all_dv	<= '0';
			ncnt_results	<= 0;
					
			for I in 0 to C_NUM_RO_REGS32-1 loop
				arr_regs_ro(I)  <= (others=>'0');
			end loop;
			
        elsif rising_edge(clk) then
		
			if (results_dv = '1') then
				
				arr_regs_ro(2*ncnt_results)		<= results(31 downto 0);
				
				arr_regs_ro((2*ncnt_results) + 1)((C_BITS_PER_CROP_RESULT-32-1) downto 0)	<= results((C_BITS_PER_CROP_RESULT-1) downto 32);
				arr_regs_ro((2*ncnt_results) + 1)(31 downto (C_BITS_PER_CROP_RESULT-32))	<= (others=>'0');
				
				-- Increment the result counter.
				-- Set the 'all' flag at the last result.
				-- Clear the 'all' flag when a new set of results begins.
				if (ncnt_results < C_NUM_CROP_BOX-1) then 
					ncnt_results	<= ncnt_results + 1;
					results_all_dv	<= '0';
				else
					ncnt_results	<= 0;
					results_all_dv	<= '1';
				end if;
				
			end if;
						
		end if;   
		
    end process;
    
    assign parameters_dv    <= arr_regs_dv;
    
end;

