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

architecture behave of tb_rheed1 is 

signal clk              : std_logic;
signal reset            : std_logic;
signal p_reset_n        : std_logic;
signal p_debug_out      : std_logic_vector( 7 downto 0); 

-- Uart I/O
signal uart_data_tx     : std_logic_vector( 7 downto 0);    -- Data to transmit
signal uart_data_tx_wr  : std_logic;                        -- Write control for data_tx
signal uart_tx_ready    : std_logic;                        -- Ready for transmit data
signal uart_tx_active   : std_logic;                        -- Serial output is active
signal uart_data_rx     : std_logic_vector( 7 downto 0);    -- Received data
signal uart_data_rx_dv  : std_logic;                        -- Received data valid

-- Input and output data  
signal p_din            : std_logic_vector( 7 downto 0);
signal p_din_dv         : std_logic;
signal p_dout           : std_logic_vector( 7 downto 0);
signal p_dout_dv        : std_logic;

-- Indicator LEDs
signal p_leds           : std_logic_vector( 7 downto 0);      -- '1' = Lit

-- Serial interface
signal p_serial_rxd     : std_logic; 
signal p_serial_txd     : std_logic;

-- Halts simulation by stopping clock when set true
signal sim_done         : boolean   := false;

signal tied_low         : std_logic; 

constant CMD_WR         : character := 'W';
constant CMD_RD         : character := 'R';

-------------------------------------------------------------
-- UART write procedure. Address in 16-bit hex. Data in 32-bit hex
-------------------------------------------------------------
procedure uart_tx( 
    signal clk              : in  std_logic;
    constant cmd            : in  character;
    constant a              : in  std_logic_vector(15 downto 0);
    constant d              : in  std_logic_vector(31 downto 0);
    signal uart_tx_ready    : in  std_logic;                        -- Ready for transmit data
    signal uart_data_tx     : out std_logic_vector( 7 downto 0);    -- Data to transmit
    signal uart_data_tx_wr  : out std_logic                         -- Write control for data_tx
) is
 
begin
    --wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    if (cmd = 'W') then
        uart_data_tx        <= X"57";
    elsif (cmd = 'R') then
        uart_data_tx        <= X"52";
    else     
        uart_data_tx        <= X"58"; -- 'X'
    end if;
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= a(15 downto 8);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= a(7 downto 0);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= d(31 downto 24);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= d(23 downto 16);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= d(15 downto 8);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until uart_tx_ready = '1';
    wait until clk'event and clk='0';
    uart_data_tx        <= d(7 downto 0);
    uart_data_tx_wr     <= '1';
    wait until clk'event and clk='0';
    uart_data_tx_wr     <= '0';
    wait until clk'event and clk='0';

    wait until clk'event and clk='0';
end;


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
    tied_low    <= '0';

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
        p_dout                  => p_dout           , -- out   std_logic_vector( 7 downto 0);
        p_dout_dv               => p_dout_dv        , -- out   std_logic;

        -- Indicator LEDs
        p_leds                  => p_leds           , -- out   std_logic_vector( 7 downto 0);      -- '1' = Lit

        -- Serial interface to user
        p_serial_rxd            => p_serial_rxd     , -- in    std_logic; 
        p_serial_txd            => p_serial_txd     , -- out   std_logic;

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
        uart_data_tx    <= X"00";
        uart_data_tx_wr <= '0';


        cpu_print_msg("Simulation start");
        clk_delay(5);
        reset       <= '0';
        wait for 100 ns;    -- Time for PLL to lock
		clk_delay(2);

        -- Write message
        if (uart_tx_ready = '1') then
            uart_tx( clk, CMD_WR, X"0000", X"00020001", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        end if;

        wait until uart_tx_ready = '1';
        uart_tx( clk, CMD_WR, X"0001", X"00040003", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        wait until uart_tx_ready = '1';
        uart_tx( clk, CMD_WR, X"0002", X"00060005", uart_tx_ready, uart_data_tx, uart_data_tx_wr);

        -- Comment out some writes for a faster simulation
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0003", X"00080007", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0004", X"000A0009", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0005", X"000C000B", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0006", X"000E000D", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0007", X"0010000F", uart_tx_ready, uart_data_tx, uart_data_tx_wr);
        --wait until uart_tx_ready = '1';
        --uart_tx( clk, CMD_WR, X"0008", X"00120011", uart_tx_ready, uart_data_tx, uart_data_tx_wr);

        wait until uart_tx_ready = '1';
        uart_tx( clk, CMD_WR, X"0009", X"00140013", uart_tx_ready, uart_data_tx, uart_data_tx_wr);

        -- Send a read command
        wait until uart_tx_ready = '1';
        uart_tx( clk, CMD_RD, X"0002", X"00000000", uart_tx_ready, uart_data_tx, uart_data_tx_wr);

        wait until uart_tx_ready = '1';
        wait for 1000 us;
        cpu_print_msg("Simulation done");
        clk_delay(5);
		
        sim_done    <= true;
        wait;

    end process;


    -------------------------------------------------------------
    -- UART to send commands to FPGA and receive readback data.
    -------------------------------------------------------------
    u_tb_uart : entity work.rhd_uart
    port map
    (
        clk             => clk              , -- in  std_logic;
        reset           => reset            , -- in  std_logic;

        bitwidth        => RS232_BDIV       , -- in  std_logic_vector(11 downto 0);
        parity_on       => tied_low         , -- in  std_logic;
        parity_odd      => tied_low         , -- in  std_logic;

        data_tx         => uart_data_tx     , -- in  std_logic_vector( 7 downto 0);
        data_tx_wr      => uart_data_tx_wr  , -- in  std_logic;
        tx_ready        => uart_tx_ready    , -- out std_logic;
        tx_active       => uart_tx_active   , -- out std_logic                         -- Serial output is active

        data_rx         => uart_data_rx     , -- out std_logic_vector( 7 downto 0);
        data_rx_dv      => uart_data_rx_dv  , -- out std_logic;
        data_rx_err     => open             , -- out std_logic;

        rxd             => p_serial_txd     , -- in  std_logic;     -- FROM FPGA
        txd             => p_serial_rxd       -- out std_logic      -- TO FPGA
    );  


    -------------------------------------------------------------
    -- TODO : Process to watch uart_data_rx_dv and build received messages
    -- State machine to wait for dv = '1' and data = X"41" ('A')
    -- then capture 4 bytes of data.
    -------------------------------------------------------------
    --pr_uart_rcv : process
    --begin
    --end process;


end behave;

