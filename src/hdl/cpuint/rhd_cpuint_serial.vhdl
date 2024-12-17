-------------------------------------------------------------------------------
-- File       : rhd_cpuint_serial.vhd
-- Bidir interface between serial port and CPU bus.
-- Contains UART
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rhd_serial_pkg.all;
use     work.rhd_fpga_pkg.all;

entity rhd_cpuint is
port (
    clk             : in  std_logic;
    reset           : in  std_logic;
    tick_msec       : in  std_logic;    -- Used to reset interface if a message is corrupted

    -- RS232 serial interface
    rxd             : in  std_logic;    -- UART Receive data
    txd             : out std_logic;    -- UART Transmit data

    -- CPU interface signals
    cpu_rd          : out std_logic;
    cpu_wr          : out std_logic;
    cpu_sel         : out std_logic;
    cpu_addr        : out std_logic_vector(15 downto 0);
    cpu_wdata       : out std_logic_vector(31 downto 0);

    cpu_rdata_dv    : in  std_logic;
    cpu_rdata       : in  std_logic_vector(31 downto 0);

    debug           : out std_logic_vector( 3 downto 0)
);
end rhd_cpuint;

architecture serial of rhd_cpuint is

signal tied_low         : std_logic;

signal data_rx          : std_logic_vector( 7 downto 0);
signal data_rx_dv       : std_logic;
signal data_rx_err      : std_logic;

signal cpu2uart_busy    : std_logic;    -- cpu2int is transmitting a reply message
signal tx_msg_busy      : std_logic;    -- cpu2int is transmitting a reply message
signal tx_ready         : std_logic;    -- UART ready for new character
signal tx_active        : std_logic;    -- 
signal data_tx_wr       : std_logic;
signal data_tx          : std_logic_vector( 7 downto 0);

signal cpuint_rd        : std_logic;
signal cpuint_wr        : std_logic;
signal cpuint_addr      : std_logic_vector(15 downto 0);
signal cpuint_wdata     : std_logic_vector(31 downto 0);
signal cpuint_rdata_dv  : std_logic;
signal cpuint_rdata     : std_logic_vector(31 downto 0);

begin

    tied_low    <= '0';

    debug(0)    <= data_rx_dv;
    debug(1)    <= data_rx_err;
    debug(2)    <= tx_ready;
    debug(3)    <= tx_msg_busy;


    ---------------------------------------------------------------------
    -- Bidir UART connected to RS-232 port
    ---------------------------------------------------------------------
    u_rhd_uart : entity work.rhd_uart
    port map (
        clk             => clk          , -- in  std_logic;
        reset           => reset        , -- in  std_logic;
        bitwidth        => RS232_BDIV   , -- in  std_logic_vector(11 downto 0);
        parity_on       => tied_low     , -- in  std_logic;
        parity_odd      => tied_low     , -- in  std_logic;
        data_tx         => data_tx      , -- in  std_logic_vector( 7 downto 0);
        data_tx_wr      => data_tx_wr   , -- in  std_logic;
        tx_ready        => tx_ready     , -- out std_logic;
        tx_active       => tx_active    , -- out std_logic                         -- Serial output is active
        data_rx         => data_rx      , -- out std_logic_vector( 7 downto 0);
        data_rx_dv      => data_rx_dv   , -- out std_logic;
        data_rx_err     => data_rx_err  , -- out std_logic;
        rxd             => rxd          , -- in  std_logic;
        txd             => txd            -- out std_logic
    );

    ---------------------------------------------------------------------
    -- Convert received messages to write/read the set of data to the CPU bus
    ---------------------------------------------------------------------
    u_rhd_uart2cpu : entity work.rhd_uart2cpu
    port map (
        clk             => clk          , -- in  std_logic;
        reset           => reset        , -- in  std_logic;
        tick_msec       => tick_msec    , -- in  std_logic;    -- Used to reset interface if a message is corrupted
        data_rx         => data_rx      , -- in  std_logic_vector( 7 downto 0);
        data_rx_dv      => data_rx_dv   , -- in  std_logic;
        data_rx_err     => data_rx_err  , -- in  std_logic;
        cpu_rd          => cpuint_rd    , -- out std_logic;
        cpu_wr          => cpuint_wr    , -- out std_logic;
        cpu_addr        => cpuint_addr  , -- out std_logic_vector(15 downto 0);
        cpu_wdata       => cpuint_wdata   -- out std_logic_vector(31 downto 0)
    );

    ---------------------------------------------------------------------
    -- When cpu_rdata_dv is set, send cpu_rdata to UART
    -- (N bytes of data, prefixed with a header byte.)
    ---------------------------------------------------------------------
    u_rhd_cpu2uart : entity work.rhd_cpu2uart
    port map (
        clk             => clk              , -- in  std_logic;
        reset           => reset            , -- in  std_logic;
        busy            => cpu2uart_busy    , -- out std_logic;
        cpu_rdata       => cpuint_rdata     , -- in  std_logic_vector(31 downto 0);
        cpu_rdata_dv    => cpuint_rdata_dv  , -- in  std_logic;
        tx_ready        => tx_ready         , -- in  std_logic;
        data_tx_wr      => data_tx_wr       , -- out std_logic;
        data_tx         => data_tx            -- out std_logic_vector( 7 downto 0)
    );

    -- Combine busy signals to make a signal that is active until the last
    -- bit of a message has been transmitted
    tx_msg_busy     <= cpu2uart_busy or tx_active;


    -------------------------------------------------------------------------------
    -- Combine rd/wr into cpu_sel
    -------------------------------------------------------------------------------
    pr_cpubus : process (reset, clk)
    begin

        if (reset = '1') then

            cpu_rd      <= '0';
            cpu_wr      <= '0';
            cpu_sel     <= '0';
            cpu_addr    <= (others=>'0');
            cpu_wdata   <= (others=>'0');

        elsif rising_edge(clk) then

            cpu_rd      <= cpuint_rd;
            cpu_wr      <= cpuint_wr;
            cpu_sel     <= cpuint_rd or cpuint_wr;
            cpu_addr    <= cpuint_addr;
            cpu_wdata   <= cpuint_wdata;

        end if;

    end process;

    cpuint_rdata_dv  <= cpu_rdata_dv;
    cpuint_rdata     <= cpu_rdata;
            
end serial;

