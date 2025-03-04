-----------------------------------------------------------
-- File : tb_rheed1.vhd
-----------------------------------------------------------
-- 
----------------------------------------------------------
library ieee;
use     ieee.numeric_std.all;
use     ieee.std_logic_1164.all; 
use     std.textio.all; 

use     work.std_iopak.all;

use     work.rhd_serial_pkg.all;
use     work.rhd_fpga_pkg.all;

entity tb_rheed1 is
end    tb_rheed1;

architecture parallel of tb_rheed1 is 

signal clk              : std_logic;
signal reset            : std_logic;
signal p_reset_n        : std_logic;
signal p_debug_out      : std_logic_vector( 7 downto 0); 

-- Input and output data  
signal p_din            : std_logic_vector( 7 downto 0);
signal p_din_dv         : std_logic;
signal p_din_tready     : std_logic;

signal p_dout           : std_logic_vector( 7 downto 0);
signal p_dout_dv        : std_logic;

-- Indicator LEDs
signal p_leds           : std_logic_vector( 7 downto 0);      -- '1' = Lit

-- Serial interface
signal p_serial_rxd     : std_logic; 
signal p_serial_txd     : std_logic;

-- Halts simulation by stopping clock when set true
signal sim_done         : boolean   := false;

-- Tie unused UART line
signal tied_high        : std_logic := '1';

signal ncnt_pixels      : integer := 0;


-------------------------------------------------------------
-- Delay
-------------------------------------------------------------
procedure clk_delay(
    constant nclks  : in  integer
) is
begin
    for I in 1 to nclks loop
        wait until clk'event and clk ='0';
    end loop;
end;


----------------------------------------------------------------
-- Print a string with no time or instance path.
----------------------------------------------------------------
procedure cpu_print_msg(
    constant msg    : in    string
) is
variable line_out   : line;
begin
    write(line_out, msg);
    writeline(output, line_out);
end procedure cpu_print_msg;


begin

    p_reset_n   <= not(reset);
    tied_high   <= '1';

    -------------------------------------------------------------
	-- Unit Under Test
    -------------------------------------------------------------
	u_rhd_fpga_top : entity work.rhd_fpga_top
	port map (
        p_clock_50              => clk              , -- in    std_logic;          -- Clock input
        p_reset_n               => p_reset_n        , -- in    std_logic;          -- Reset (pushbtn_n[0])

        -- Input and output data  
        p_din                   => p_din            , -- in    std_logic_vector( 7 downto 0);
        p_din_dv                => p_din_dv         , -- in    std_logic;
        p_din_tready            => p_din_tready     , -- out   std_logic;

        p_dout                  => p_dout           , -- out   std_logic_vector( 7 downto 0);
        p_dout_dv               => p_dout_dv        , -- out   std_logic;

        -- Indicator LEDs
        p_leds                  => p_leds           , -- out   std_logic_vector( 7 downto 0);      -- '1' = Lit

        -- Serial interface to user
        p_serial_rxd            => tied_high        , -- in    std_logic; 
        p_serial_txd            => open             , -- out   std_logic;

        -- Debug port 
        p_debug_out             => p_debug_out        -- out   std_logic_vector( 7 downto 0)       --  DE0-nano JP3
    );

    
    -------------------------------------------------------------
    -- Generate system clock. Halt when sim_done is true.
    -------------------------------------------------------------
    pr_clk : process
    begin
        clk  <= '0';
        wait for C_CLK_PERIOD/2;
        clk  <= '1';
        wait for C_CLK_PERIOD/2;
        if (sim_done=true) then
            wait; 
        end if;
    end process;

  
    -------------------------------------------------------------
    -- Reset and drive CPU bus 
    -------------------------------------------------------------
    pr_main : process
    begin
        -- Reset 
        reset           <= '1';
		
        -- Input and output data  
        p_din           <= (others=>'0');
        p_din_dv        <= '0';

        clk_delay(5);
		reset			<= '0';
		
		wait until p_din_tready = '1';
		
		while (ncnt_pixels < 100) loop
			-- Increment pixel data
			clk_delay(1);
			p_din           <= std_logic_vector(unsigned(p_din) + 1);
			p_din_dv        <= '1';
			
		end loop;

		clk_delay(1);
		p_din           <= (others=>'0');
		p_din_dv        <= '0';
        wait for 100 us;
        cpu_print_msg("Simulation done");
        clk_delay(5);
		
        sim_done    <= true;
        wait;

    end process;


end parallel;

