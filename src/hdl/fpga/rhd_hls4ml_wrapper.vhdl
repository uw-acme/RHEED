--------------------------------------------------------------------------
--  File         : rhd_hls4ml_wrapper.vhdl
----------------------------------------------------------------------------
--  Description  : Wrapper around the HLS4ML output file. 
--                 Mainly to maintain consistent naming of ports.
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;

use     work.rhd_fpga_pkg.all;

entity rhd_hls4ml is
port(
    ap_clk              : in  std_logic;
    ap_rst_n            : in  std_logic;
                              
    -- Control signals        
    ap_start            : in  std_logic;
    ap_done             : out std_logic;
    ap_ready            : out std_logic;
    ap_idle             : out std_logic;
    
    -- Pixel data       
    pixel_din_tdata     : in  std_logic_vector( 7 downto 0);
    pixel_din_tvalid    : in  std_logic;
    pixel_din_tready    : out std_logic;
    
  --pixel_dout_tdata    : out std_logic_vector( 7 downto 0);
  --pixel_dout_tvalid   : out std_logic;
  --pixel_dout_tready   : in  std_logic;

    -- Set of results from one crop box
    result0_tdata       : out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
    result0_tvalid      : out std_logic;                                                
    result0_tready      : in  std_logic; 
    
    result1_tdata       : out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
    result1_tvalid      : out std_logic;                                                
    result1_tready      : in  std_logic; 
    
    result2_tdata       : out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
    result2_tvalid      : out std_logic;                                                 
    result2_tready      : in  std_logic;  
    
    result3_tdata       : out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
    result3_tvalid      : out std_logic;                                                 
    result3_tready      : in  std_logic;  
    
    result4_tdata       : out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
    result4_tvalid      : out std_logic;                                                 
    result4_tready      : in  std_logic;  
    
    debug               : out std_logic_vector( 3 downto 0)
);
end rhd_hls4ml;

------------------------------------------------------------------------
-- Dummy architecture of HLS4ML output
-- Outputs sets of 5 N-bit results
------------------------------------------------------------------------
architecture wrapper of rhd_hls4ml is

begin

    -------------------------------------------------------------
    -- HLS4ML output
    -------------------------------------------------------------
    u_myproject : entity work.myproject_small  -- ap_fixed_16_15_small
    port map (
    (
        -- Clock and Reset
        ap_clk                          => ap_clk,
        ap_rst_n                        => ap_rst_n,
         
        -- Control signals
        ap_start                        => ap_start,
        ap_done                         => ap_done,
        ap_ready                        => ap_ready,
        ap_idle                         => ap_idle

        -- Input pixel data AXI-Stream bus
        conv2d_input_V_data_0_V_TDATA   => pixel_din_tdata,
        conv2d_input_V_data_0_V_TVALID  => pixel_din_tvalid,
        conv2d_input_V_data_0_V_TREADY  => pixel_din_tready,
        
        -- Result outputs 
        layer9_out_V_data_0_V_TDATA     => result0_tdata,
        layer9_out_V_data_0_V_TVALID    => result0_tvalid,
        layer9_out_V_data_0_V_TREADY    => result0_tready,
        
        layer9_out_V_data_1_V_TDATA     => result1_tdata,
        layer9_out_V_data_1_V_TVALID    => result1_tvalid,
        layer9_out_V_data_1_V_TREADY    => result1_tready,
        
        layer9_out_V_data_2_V_TDATA     => result2_tdata,
        layer9_out_V_data_2_V_TVALID    => result2_tvalid,
        layer9_out_V_data_2_V_TREADY    => result2_tready,
        
        layer9_out_V_data_3_V_TDATA     => result3_tdata,
        layer9_out_V_data_3_V_TVALID    => result3_tvalid,
        layer9_out_V_data_3_V_TREADY    => result3_tready,
        
        layer9_out_V_data_4_V_TDATA     => result4_tdata,
        layer9_out_V_data_4_V_TVALID    => result4_tvalid,
        layer9_out_V_data_4_V_TREADY    => result4_tready
    );
    
    debug   <= (others=>'0');
    

end wrapper;


