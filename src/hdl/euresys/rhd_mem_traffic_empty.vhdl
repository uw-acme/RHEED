--------------------------------------------------------------------------------
-- Project: CustomLogic
--------------------------------------------------------------------------------
--  Module: mem_traffic_gen
--    File: mem_traffic_gen.vhd
--    Date: 2018-01-22
--     Rev: 0.1
--  Author: PP
--------------------------------------------------------------------------------
-- Reference Design: Memory Traffic Generator for AXI4 Master Interface
--------------------------------------------------------------------------------
-- 0.1, 2018-01-22, PP, Initial release
--
-- Empty arch by GJ
--------------------------------------------------------------------------------


library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;


entity mem_traffic_gen is
generic (
    DATA_WIDTH              : natural := 256
);
port (
    -- Clock
    clk                     : in  std_logic;
    -- Control/Status
    MemTrafficGen_en        : in  std_logic;
    Wraparound_pls          : out std_logic;
    Wraparound_cnt          : out std_logic_vector(31 downto 0);
    -- AXI4 Master Interface
    m_axi_resetn            : in  std_logic;    -- AXI 4 Interface reset
    m_axi_awaddr            : out std_logic_vector( 31 downto 0);
    m_axi_awlen             : out std_logic_vector(  7 downto 0);
    m_axi_awsize            : out std_logic_vector(  2 downto 0);
    m_axi_awburst           : out std_logic_vector(  1 downto 0);
    m_axi_awlock            : out std_logic;
    m_axi_awcache           : out std_logic_vector(  3 downto 0);
    m_axi_awprot            : out std_logic_vector(  2 downto 0);
    m_axi_awqos             : out std_logic_vector(  3 downto 0);
    m_axi_awvalid           : out std_logic;
    m_axi_awready           : in  std_logic;
    m_axi_wdata             : out std_logic_vector(DATA_WIDTH   - 1 downto 0);
    m_axi_wstrb             : out std_logic_vector(DATA_WIDTH/8 - 1 downto 0);
    m_axi_wlast             : out std_logic;
    m_axi_wvalid            : out std_logic;
    m_axi_wready            : in  std_logic;
    m_axi_bresp             : in  std_logic_vector(  1 downto 0);
    m_axi_bvalid            : in  std_logic;
    m_axi_bready            : out std_logic;
    m_axi_araddr            : out std_logic_vector( 31 downto 0);
    m_axi_arlen             : out std_logic_vector(  7 downto 0);
    m_axi_arsize            : out std_logic_vector(  2 downto 0);
    m_axi_arburst           : out std_logic_vector(  1 downto 0);
    m_axi_arlock            : out std_logic;
    m_axi_arcache           : out std_logic_vector(  3 downto 0);
    m_axi_arprot            : out std_logic_vector(  2 downto 0);
    m_axi_arqos             : out std_logic_vector(  3 downto 0);
    m_axi_arvalid           : out std_logic;
    m_axi_arready           : in  std_logic;
    m_axi_rdata             : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_axi_rresp             : in  std_logic_vector(  1 downto 0);
    m_axi_rlast             : in  std_logic;
    m_axi_rvalid            : in  std_logic;
    m_axi_rready            : out std_logic
);
end entity mem_traffic_gen;

architecture empty of mem_traffic_gen is

begin

    Wraparound_pls      <= '0';             -- out std_logic;
    Wraparound_cnt      <= (others=>'0');   -- out std_logic_vector( 31 downto 0);

    -- AXI4 Master Interface
    m_axi_awaddr        <= (others=>'0');   -- out std_logic_vector( 31 downto 0);
    m_axi_awlen         <= (others=>'0');   -- out std_logic_vector(  7 downto 0);
    m_axi_awsize        <= (others=>'0');   -- out std_logic_vector(  2 downto 0);
    m_axi_awburst       <= (others=>'0');   -- out std_logic_vector(  1 downto 0);
    m_axi_awlock        <= '0';             -- out std_logic;
    m_axi_awcache       <= (others=>'0');   -- out std_logic_vector(  3 downto 0);
    m_axi_awprot        <= (others=>'0');   -- out std_logic_vector(  2 downto 0);
    m_axi_awqos         <= (others=>'0');   -- out std_logic_vector(  3 downto 0);
    m_axi_awvalid       <= '0';             -- out std_logic;
    m_axi_wdata         <= (others=>'0');   -- out std_logic_vector(DATA_WIDTH   - 1 downto 0);
    m_axi_wstrb         <= (others=>'0');   -- out std_logic_vector(DATA_WIDTH/8 - 1 downto 0);
    m_axi_wlast         <= '0';             -- out std_logic;
    m_axi_wvalid        <= '0';             -- out std_logic;
    m_axi_bready        <= '1';             -- out std_logic;
    m_axi_araddr        <= (others=>'0');   -- out std_logic_vector( 31 downto 0);
    m_axi_arlen         <= (others=>'0');   -- out std_logic_vector(  7 downto 0);
    m_axi_arsize        <= (others=>'0');   -- out std_logic_vector(  2 downto 0);
    m_axi_arburst       <= (others=>'0');   -- out std_logic_vector(  1 downto 0);
    m_axi_arlock        <= '0';             -- out std_logic;
    m_axi_arcache       <= (others=>'0');   -- out std_logic_vector(  3 downto 0);
    m_axi_arprot        <= (others=>'0');   -- out std_logic_vector(  2 downto 0);
    m_axi_arqos         <= (others=>'0');   -- out std_logic_vector(  3 downto 0);
    m_axi_arvalid       <= (others=>'0');   -- out std_logic;
    m_axi_rready        <= '1';             -- out std_logic
    
end empty; 
