--------------------------------------------------------------------------------
-- Project: CustomLogic
--------------------------------------------------------------------------------
--  Module: CustomLogic
--    File: CustomLogic.vhdl
--    Date: 2023-03-07
--     Rev: 0.5
--  Author: PP
--------------------------------------------------------------------------------
-- CustomLogic wrapper for the user design
--------------------------------------------------------------------------------
-- 0.1, 2017-12-15, PP, Initial release
-- 0.2, 2019-07-12, PP, Updated CustomLogic interfaces
-- 0.3, 2019-10-24, PP, Added General Purpose I/O Interface
-- 0.4, 2021-02-25, PP, Added *mem_base and *mem_size ports into the On-Board
--                      Memory interface
-- 0.5, 2023-03-07, MH, Added CustomLogic output control
-- 1.0  2025-03-04, GJ  Modified for RHEED
--------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity CustomLogic is
generic (
    STREAM_DATA_WIDTH           : natural := 128;
    MEMORY_DATA_WIDTH           : natural := 128
);
port (
    ---- CustomLogic Common Interfaces -------------------------------------
    -- Clock/Reset
    clk250                      : in  std_logic;    -- Clock 250 MHz
    srst250                     : in  std_logic;    -- Global reset (PCIe reset)

    -- General Purpose I/O Interface
    user_output_ctrl            : out std_logic_vector( 15 downto 0);
    user_output_status          : in  std_logic_vector(  7 downto 0);
    standard_io_set1_status     : in  std_logic_vector(  9 downto 0);
    standard_io_set2_status     : in  std_logic_vector(  9 downto 0);
    module_io_set_status        : in  std_logic_vector( 39 downto 0);
    qdc1_position_status        : in  std_logic_vector( 31 downto 0);
    custom_logic_output_ctrl    : out std_logic_vector( 31 downto 0);
    reserved                    : in  std_logic_vector(511 downto 0) := (others=>'0');

    -- Control Slave Interface
    s_ctrl_addr                 : in  std_logic_vector( 15 downto 0);
    s_ctrl_data_wr_en           : in  std_logic;
    s_ctrl_data_wr              : in  std_logic_vector( 31 downto 0);
    s_ctrl_data_rd              : out std_logic_vector( 31 downto 0);

    -- On-Board Memory - Parameters
    onboard_mem_base            : in  std_logic_vector( 31 downto 0);   -- Base address of the CustomLogic partition in the On-Board Memory
    onboard_mem_size            : in  std_logic_vector( 31 downto 0);   -- Size in bytes of the CustomLogic partition in the On-Board Memory

    -- On-Board Memory - AXI 4 Master Interface
    m_axi_resetn                : in  std_logic;    -- AXI 4 Interface reset
    m_axi_awaddr                : out std_logic_vector( 31 downto 0);
    m_axi_awlen                 : out std_logic_vector(  7 downto 0);
    m_axi_awsize                : out std_logic_vector(  2 downto 0);
    m_axi_awburst               : out std_logic_vector(  1 downto 0);
    m_axi_awlock                : out std_logic;
    m_axi_awcache               : out std_logic_vector(  3 downto 0);
    m_axi_awprot                : out std_logic_vector(  2 downto 0);
    m_axi_awqos                 : out std_logic_vector(  3 downto 0);
    m_axi_awvalid               : out std_logic;
    m_axi_awready               : in  std_logic;
    m_axi_wdata                 : out std_logic_vector(MEMORY_DATA_WIDTH   - 1 downto 0);
    m_axi_wstrb                 : out std_logic_vector(MEMORY_DATA_WIDTH/8 - 1 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wvalid                : out std_logic;
    m_axi_wready                : in  std_logic;
    m_axi_bresp                 : in  std_logic_vector(  1 downto 0);
    m_axi_bvalid                : in  std_logic;
    m_axi_bready                : out std_logic;
    m_axi_araddr                : out std_logic_vector( 31 downto 0);
    m_axi_arlen                 : out std_logic_vector(  7 downto 0);
    m_axi_arsize                : out std_logic_vector(  2 downto 0);
    m_axi_arburst               : out std_logic_vector(  1 downto 0);
    m_axi_arlock                : out std_logic;
    m_axi_arcache               : out std_logic_vector(  3 downto 0);
    m_axi_arprot                : out std_logic_vector(  2 downto 0);
    m_axi_arqos                 : out std_logic_vector(  3 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_rdata                 : in  std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(  1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic;    

    ---- CustomLogic Device/Channel Interfaces -----------------------------

    -- AXI Stream Slave Interface (Input image data)
    s_axis_resetn               : in  std_logic;    -- AXI Stream Interface reset
    s_axis_tvalid               : in  std_logic;
    s_axis_tready               : out std_logic;
    s_axis_tdata                : in  std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
    s_axis_tuser                : in  std_logic_vector(  3 downto 0);

    -- Metadata Slave Interface
    s_mdata_StreamId            : in  std_logic_vector( 7 downto 0);
    s_mdata_SourceTag           : in  std_logic_vector(15 downto 0);
    s_mdata_Xsize               : in  std_logic_vector(23 downto 0);
    s_mdata_Xoffs               : in  std_logic_vector(23 downto 0);
    s_mdata_Ysize               : in  std_logic_vector(23 downto 0);
    s_mdata_Yoffs               : in  std_logic_vector(23 downto 0);
    s_mdata_DsizeL              : in  std_logic_vector(23 downto 0);
    s_mdata_PixelF              : in  std_logic_vector(15 downto 0);
    s_mdata_TapG                : in  std_logic_vector(15 downto 0);
    s_mdata_Flags               : in  std_logic_vector( 7 downto 0);
    s_mdata_Timestamp           : in  std_logic_vector(31 downto 0);
    s_mdata_PixProcFlgs         : in  std_logic_vector( 7 downto 0);
    s_mdata_Status              : in  std_logic_vector(31 downto 0);

    -- AXI Stream Master Interface (Output image data) 
    m_axis_tvalid               : out std_logic;
    m_axis_tready               : in  std_logic;
    m_axis_tdata                : out std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
    m_axis_tuser                : out std_logic_vector(  3 downto 0);

    -- Metadata Master Interface
    m_mdata_StreamId            : out std_logic_vector( 7 downto 0);
    m_mdata_SourceTag           : out std_logic_vector(15 downto 0);
    m_mdata_Xsize               : out std_logic_vector(23 downto 0);
    m_mdata_Xoffs               : out std_logic_vector(23 downto 0);
    m_mdata_Ysize               : out std_logic_vector(23 downto 0);
    m_mdata_Yoffs               : out std_logic_vector(23 downto 0);
    m_mdata_DsizeL              : out std_logic_vector(23 downto 0);
    m_mdata_PixelF              : out std_logic_vector(15 downto 0);
    m_mdata_TapG                : out std_logic_vector(15 downto 0);
    m_mdata_Flags               : out std_logic_vector( 7 downto 0);
    m_mdata_Timestamp           : out std_logic_vector(31 downto 0);
    m_mdata_PixProcFlgs         : out std_logic_vector( 7 downto 0);
    m_mdata_Status              : out std_logic_vector(31 downto 0);

    -- Memento Master Interface
    m_memento_event             : out std_logic;
    m_memento_arg0              : out std_logic_vector(31 downto 0);
    m_memento_arg1              : out std_logic_vector(31 downto 0)
);
end entity CustomLogic;

architecture rtl of CustomLogic is

    function clog2(n : integer) return integer is
        variable m, p : integer;
    begin
        m := 0;
        p := 1;
        while p < n loop
        m := m + 1;
        p := p * 2;
        end loop;
        return m;
    end function;


----------------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------------
-- attribute mark_debug : string;
-- attribute mark_debug of s_axis_resetn    : signal is "true";
-- attribute mark_debug of s_axis_tvalid    : signal is "true";
-- attribute mark_debug of s_axis_tready    : signal is "true";
-- attribute mark_debug of s_axis_tuser     : signal is "true";

----------------------------------------------------------------------------
-- FPGAs for RHEED
----------------------------------------------------------------------------

-- Parameters (constant for now)
constant PIXEL_BIT_WIDTH    : integer :=  8;
constant PIXELS_PER_BURST   : integer :=  8;
constant USER_WIDTH         : integer :=  4;
constant IN_ROWS            : integer := 104;
constant IN_COLS            : integer := 160;
constant OUT_ROWS           : integer := 48;
constant OUT_COLS           : integer := 48;

-- Crop-coordinates 
signal crop_x0              : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal crop_y0              : std_logic_vector(clog2(IN_ROWS)-1 downto 0);
signal crop_x1              : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal crop_y1              : std_logic_vector(clog2(IN_ROWS)-1 downto 0);
signal crop_x2              : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal crop_y2              : std_logic_vector(clog2(IN_ROWS)-1 downto 0);
signal crop_x3              : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal crop_y3              : std_logic_vector(clog2(IN_ROWS)-1 downto 0);
signal crop_x4              : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal crop_y4              : std_logic_vector(clog2(IN_ROWS)-1 downto 0);

-- Sequentializer output signals
signal seq_s_axis_tready    : std_logic; 
signal seq_m_axis_tvalid    : std_logic;
signal seq_m_axis_tdata     : std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
signal seq_m_axis_tuser     : std_logic_vector(USER_WIDTH-1 downto 0);
signal seq_cnt_col          : std_logic_vector(clog2(IN_COLS)-1 downto 0);
signal seq_cnt_row          : std_logic_vector(clog2(IN_ROWS)-1 downto 0);

signal seq_ap_done          : std_logic;

-- Crop-filter output axi-stream signals
signal cf_s_axis_tready     : std_logic;
signal cf_m_axis_tvalid     : std_logic;
signal cf_m_axis_tdata      : std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
signal cf_m_axis_tuser      : std_logic_vector(USER_WIDTH-1 downto 0);

signal cf_ap_done           : std_logic;

-- HLS4ML Gausian control signals
signal hls_ap_start         : std_logic;
signal hls_ap_done          : std_logic;
signal hls_ap_ready         : std_logic;
signal hls_ap_idle          : std_logic;

-- HLS4ML output results
signal hls_result0_tdata    : std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
signal hls_result0_tvalid   : std_logic;                                                 
signal hls_result0_tready   : std_logic; 
signal hls_result1_tdata    : std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
signal hls_result1_tvalid   : std_logic;                                                 
signal hls_result1_tready   : std_logic; 
signal hls_result2_tdata    : std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
signal hls_result2_tvalid   : std_logic;                                                  
signal hls_result2_tready   : std_logic;  
signal hls_result3_tdata    : std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
signal hls_result3_tvalid   : std_logic;                                                  
signal hls_result3_tready   : std_logic;  
signal hls_result4_tdata    : std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
signal hls_result4_tvalid   : std_logic;                                                  
signal hls_result4_tready   : std_logic;  
-- Combined results
signal hls_results_tdata    : std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
signal hls_results_tvalid   : std_logic;         	

begin
    
    ----------------------------------------------------------------------------
    -- Control Registers (Accessed through Euresys API)
    ----------------------------------------------------------------------------
    u_controlregs : entity work.rhd_control_registers
    port map (
        clk                         => clk250,
        srst                        => srst250,

        s_ctrl_addr                 => s_ctrl_addr,
        s_ctrl_data_wr_en           => s_ctrl_data_wr_en,
        s_ctrl_data_wr              => s_ctrl_data_wr,
        s_ctrl_data_rd              => s_ctrl_data_rd,

        -- Registers
        leds                        => open                 , -- out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive

        results                     => hls_results_tdata    , -- in  std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
        results_dv                  => hls_results_tvalid   , -- in  std_logic;            

        parameters                  => open                 , -- out std_logic_vector(((32*C_NUM_CROP_BOX) - 1) downto 0);     -- Input to HLS4ML logic
        parameters_dv               => open                   -- out std_logic                                                 -- Input to HLS4ML logic
    );


    ----------------------------------------------------------------------------
    -- Control Registers (Accessed through serial interface)
    -- UART interface to CPU              
    ----------------------------------------------------------------------------
    entity rhd_registers_misc
    port map(
        clk                     => clk250   , -- in  std_logic;
        reset                   => srst250  , -- in  std_logic;
        cpuint_rxd              => cpuint_rxd               , -- in  std_logic;    -- UART Receive data
        cpuint_txd              => cpuint_txd               , -- out std_logic;    -- UART Transmit data 
        leds                    => leds                     , -- out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive
        debug                   => debug                    , -- out std_logic_vector( 3 downto 0);
        results                 => hls_results_tdata        , -- in  std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
        results_dv              => hls_results_tvalid       , -- in  std_logic;         	
	    parameters              => parameters               , -- out std_logic_vector(((32*C_NUM_CROP_BOX) - 1) downto 0);    	-- Input to HLS4ML logic
	    parameters_dv           => parameters_dv              -- out std_logic                                                 -- Input to HLS4ML logic
    );
    crop_x0     <= parameters(15 downto  0);
    crop_y0     <= parameters(31 downto 16);
    crop_x1     <= parameters(47 downto 32);
    crop_y1     <= parameters(63 downto 48);
    --TODO remaining 3 boxes
        

    ----------------------------------------------------------------------------
    -- Read/Write On-Board Memory
    --
    -- *** UNUSED ***
    ----------------------------------------------------------------------------
    u_memtrafficgen : entity work.mem_traffic_gen
    generic map (
        DATA_WIDTH          => MEMORY_DATA_WIDTH
    )
    port map (
        clk                 => clk250,
        MemTrafficGen_en    => MemTrafficGen_en,
        Wraparound_pls      => Wraparound_pls,
        Wraparound_cnt      => Wraparound_cnt,
        m_axi_resetn        => m_axi_resetn,
        m_axi_awaddr        => m_axi_awaddr,
        m_axi_awlen         => m_axi_awlen,
        m_axi_awsize        => m_axi_awsize,
        m_axi_awburst       => m_axi_awburst,
        m_axi_awlock        => m_axi_awlock,
        m_axi_awcache       => m_axi_awcache,
        m_axi_awprot        => m_axi_awprot,
        m_axi_awqos         => m_axi_awqos,
        m_axi_awvalid       => m_axi_awvalid,
        m_axi_awready       => m_axi_awready,
        m_axi_wdata         => m_axi_wdata,
        m_axi_wstrb         => m_axi_wstrb,
        m_axi_wlast         => m_axi_wlast,
        m_axi_wvalid        => m_axi_wvalid,
        m_axi_wready        => m_axi_wready,
        m_axi_bresp         => m_axi_bresp,
        m_axi_bvalid        => m_axi_bvalid,
        m_axi_bready        => m_axi_bready,
        m_axi_araddr        => m_axi_araddr,
        m_axi_arlen         => m_axi_arlen,
        m_axi_arsize        => m_axi_arsize,
        m_axi_arburst       => m_axi_arburst,
        m_axi_arlock        => m_axi_arlock,
        m_axi_arcache       => m_axi_arcache,
        m_axi_arprot        => m_axi_arprot,
        m_axi_arqos         => m_axi_arqos,
        m_axi_arvalid       => m_axi_arvalid,
        m_axi_arready       => m_axi_arready,
        m_axi_rdata         => m_axi_rdata,
        m_axi_rresp         => m_axi_rresp,
        m_axi_rlast         => m_axi_rlast,
        m_axi_rvalid        => m_axi_rvalid,
        m_axi_rready        => m_axi_rready
    );
    

    m_memento_event     <= '0';
    m_memento_arg0      <= (others=>'0');
    m_memento_arg1      <= (others=>'0');


    s_axis_tready <= seq_s_axis_tready; -- For clarity's sake

    ----------------------------------------------------------------------------
    -- Sequentializer. 
    -- Convert multiple pixel-width input into a stream of single pixels
    ----------------------------------------------------------------------------
    u_sequentializer: entity work.sequentializer 
    generic map (
        PIXEL_BIT_WIDTH     => PIXEL_BIT_WIDTH,
        PIXELS_PER_BURST    => PIXELS_PER_BURST,
        USER_WIDTH          => USER_WIDTH, 
        IN_ROWS             => IN_ROWS,
        IN_COLS             => IN_COLS, 
        OUT_ROWS            => OUT_ROWS,
        OUT_COLS            => OUT_COLS
    )
    port map (
        clk                 => clk250   , 
        srst                => srst250  , 

        ap_done             => seq_ap_done,

        -- Camera pixel data in
        s_axis_resetn       => s_axis_resetn,
        s_axis_tvalid       => s_axis_tvalid,
        s_axis_tready       => seq_s_axis_tready,
        s_axis_tdata        => s_axis_tdata,
        s_axis_tuser        => s_axis_tuser,

        -- Camera data out
        m_axis_tvalid       => seq_m_axis_tvalid,
        m_axis_tready       => seq_m_axis_tready,
        m_axis_tdata        => seq_m_axis_tdata,
        m_axis_tuser        => seq_m_axis_tuser,

        cnt_col             => seq_cnt_col,
        cnt_row             => seq_cnt_row
    );


    ----------------------------------------------------------------------------
    -- Crop-filter
    -- 
    -- Box images are output sequentially
    -- AXI-stream TUSER bits SOF, EOF are set for each box
    ----------------------------------------------------------------------------
    u_crop_filter : entity work.crop_filter
    generic map(
        PIXEL_BIT_WIDTH => PIXEL_BIT_WIDTH,
        USER_WIDTH      => USER_WIDTH,
        IN_ROWS         => IN_ROWS,
        IN_COLS         => IN_COLS, 
        OUT_ROWS        => OUT_ROWS,
        OUT_COLS        => OUT_COLS
    )
    port map (
        clk             => clk250, 
        srst            => srst250, 

        s_axis_resetn   => s_axis_resetn,
        s_axis_tvalid   => seq_m_axis_tvalid,
        s_axis_tready   => seq_s_axis_tready,
        s_axis_tdata    => seq_m_axis_tdata,
        s_axis_tuser    => seq_m_axis_tuser,

        -- Five crop box corner co-ordinates
        crop_x0         => crop_x0,
        crop_y0         => crop_y0,
        crop_x1         => crop_x1,
        crop_y1         => crop_y1,
        crop_x2         => crop_x2,
        crop_y2         => crop_y2,
        crop_x3         => crop_x3,
        crop_y3         => crop_y3,
        crop_x4         => crop_x4,
        crop_y4         => crop_y4,

        -- Cropped image box pixels output streams.
        m_axis_tvalid   => cf_m_axis_tvalid,
        m_axis_tready   => cf_m_axis_tready,
        m_axis_tdata    => cf_m_axis_tdata,
        m_axis_tuser    => cf_m_axis_tuser,

        cnt_col         => seq_cnt_col,
        cnt_row         => seq_cnt_row,

        ap_done         => cf_ap_done
    );


    ----------------------------------------------------------------------------
    --  Wrapper around the HLS4ML Gaussian CNN file. 
    ----------------------------------------------------------------------------
    u_rhd_hls4ml : rhd_hls4ml
    port map(
        ap_clk              => ap_clk               , -- in  std_logic;
        ap_rst_n            => ap_rst_n             , -- in  std_logic;

        -- Control signals        
        ap_start            => hls_ap_start         , -- in  std_logic;
        ap_done             => hls_ap_done          , -- out std_logic;
        ap_ready            => hls_ap_ready         , -- out std_logic;
        ap_idle             => hls_ap_idle          , -- out std_logic;

        -- Pixel data from crop filter      
        pixel_din_tdata     => cf_m_axis_tdata      , -- in  std_logic_vector( 7 downto 0);
        pixel_din_tvalid    => cf_m_axis_tvalid     , -- in  std_logic;
        pixel_din_tready    => cf_m_axis_tready     , -- out std_logic;

      --pixel_dout_tdata    => pixel_dout_tdata     , -- out std_logic_vector( 7 downto 0);
      --pixel_dout_tvalid   => pixel_dout_tvalid    , -- out std_logic;
      --pixel_dout_tready   => pixel_dout_tready    , -- in  std_logic

        -- Set of results from one crop box
        result0_tdata       => hls_result0_tdata    , -- out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
        result0_tvalid      => hls_result0_tvalid   , -- out std_logic;                                                 
        result0_tready      => hls_result0_tready   , -- in  std_logic; 

        result1_tdata       => hls_result1_tdata    , -- out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0);
        result1_tvalid      => hls_result1_tvalid   , -- out std_logic;                                                 
        result1_tready      => hls_result1_tready   , -- in  std_logic; 

        result2_tdata       => hls_result2_tdata    , -- out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
        result2_tvalid      => hls_result2_tvalid   , -- out std_logic;                                                  
        result2_tready      => hls_result2_tready   , -- in  std_logic;  

        result3_tdata       => hls_result3_tdata    , -- out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
        result3_tvalid      => hls_result3_tvalid   , -- out std_logic;                                                  
        result3_tready      => hls_result3_tready   , -- in  std_logic;  

        result4_tdata       => hls_result4_tdata    , -- out std_logic_vector((C_BITWIDTH_RESULTS - 1) downto 0); 
        result4_tvalid      => hls_result4_tvalid   , -- out std_logic;                                                  
        result4_tready      => hls_result4_tready   , -- in  std_logic;  

        debug               => debug                  -- out std_logic_vector( 3 downto 0);
    );


    -- Merge results 
    hls_results_tdata       <= result4_tdata & result3_tdata & result2_tdata & result1_tdata & result0_tdata;

    hls_result4_ready       <= '1';
    hls_result3_ready       <= '1';
    hls_result2_ready       <= '1';
    hls_result1_ready       <= '1';
    hls_result0_ready       <= '1';

    hls_results_tvalid      <= hls_result4_tvalid and hls_result3_tvalid
                           and hls_result2_tvalid and hls_result1_tvalid 
                           and hls_result0_tvalid; 


    ----------------------------------------------------------------------------
    -- Metadata Master Interface is just a pipeline delay of metadata input
    ----------------------------------------------------------------------------
    pr_metadata : process(clk)
    begin
        if rising_edge(clk) then

            m_mdata_StreamId            <= s_mdata_StreamId;
            m_mdata_SourceTag           <= s_mdata_SourceTag;
            m_mdata_Xsize               <= s_mdata_Xsize;
            m_mdata_Xoffs               <= s_mdata_Xoffs;
            m_mdata_Ysize               <= s_mdata_Ysize;
            m_mdata_Yoffs               <= s_mdata_Yoffs;
            m_mdata_DsizeL              <= s_mdata_DsizeL;
            m_mdata_PixelF              <= s_mdata_PixelF;
            m_mdata_TapG                <= s_mdata_TapG;
            m_mdata_Flags               <= s_mdata_Flags;
            m_mdata_Timestamp           <= s_mdata_Timestamp;
            m_mdata_PixProcFlgs         <= s_mdata_PixProcFlgs;
            m_mdata_Status              <= s_mdata_Status;
        
        end if;

    end process;


    ----------------------------------------------------------------------------
    -- Pass-through of image input
    ----------------------------------------------------------------------------
    m_axis_tvalid  <= s_axis_tvalid; -- out std_logic;
    s_axis_tready  <= m_axis_tready; -- in  std_logic;
    m_axis_tdata   <= s_axis_tdata;  -- out std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
    m_axis_tuser   <= s_axis_tuser;  -- out std_logic_vector(  3 downto 0);
        
end rtl;

