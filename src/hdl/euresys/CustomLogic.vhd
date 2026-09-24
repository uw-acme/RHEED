--------------------------------------------------------------------------------
-- Project: CustomLogic
--------------------------------------------------------------------------------
--  Module: CustomLogic
--    File: CustomLogic.vhd
--    Date: 2025-XX-XX
--     Rev: 0.7
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
-- 0.6, 2025-XX-XX, --, Added 3-buffer frame pipeline, top-1 detector (argmax),
--                      48x48 crop sequencer feeding the gaussian core, gaussian
--                      result collector, and gaussian overlay band. Structured
--                      so extending to NMS top-5 is a NUM_DET change plus a new
--                      detector block (everything downstream iterates a list).
-- 0.7, 2025-XX-XX, --, Detector extended from top-1 to top-5 streaming argmax
--                      (NUM_DET=5). Sorted-insertion keeps the 5 highest FOLO
--                      cells; raster order preserved on ties. Buffer manager now
--                      latches the full coord list. Downstream (crop/gaussian/
--                      overlay) unchanged - it was already list-driven.
--                      NOTE: this is top-5 BY VALUE, not NMS - 5 hits can land
--                      on one blob. Swap pDetect for an NMS block (same det_list
--                      interface) if spatially-distinct detections are needed.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity CustomLogic is
  generic (
    STREAM_DATA_WIDTH        :     natural                        := 128;
    MEMORY_DATA_WIDTH        :     natural                        := 128
  );
  port (
    ---- CustomLogic Common Interfaces -------------------------------------
    -- Clock/Reset
    clk250                   : in  std_logic; -- Clock 250 MHz
    srst250                  : in  std_logic; -- Global reset (PCIe reset)
    -- General Purpose I/O Interface
    user_output_ctrl         : out std_logic_vector(15 downto 0);
    user_output_status       : in  std_logic_vector(7 downto 0);
    standard_io_set1_status  : in  std_logic_vector(9 downto 0);
    standard_io_set2_status  : in  std_logic_vector(9 downto 0);
    module_io_set_status     : in  std_logic_vector(39 downto 0);
    qdc1_position_status     : in  std_logic_vector(31 downto 0);
    custom_logic_output_ctrl : out std_logic_vector(31 downto 0);
    reserved                 : in  std_logic_vector(511 downto 0) := (others => '0');
    -- Control Slave Interface
    s_ctrl_addr              : in  std_logic_vector(15 downto 0);
    s_ctrl_data_wr_en        : in  std_logic;
    s_ctrl_data_wr           : in  std_logic_vector(31 downto 0);
    s_ctrl_data_rd           : out std_logic_vector(31 downto 0);
    -- On-Board Memory - Parameters
    onboard_mem_base         : in  std_logic_vector(31 downto 0); -- Base address of the CustomLogic partition in the On-Board Memory
    onboard_mem_size         : in  std_logic_vector(31 downto 0); -- Size in bytes of the CustomLogic partition in the On-Board Memory
    -- On-Board Memory - AXI 4 Master Interface
    m_axi_resetn             : in  std_logic; -- AXI 4 Interface reset
    m_axi_awaddr             : out std_logic_vector(31 downto 0);
    m_axi_awlen              : out std_logic_vector(7 downto 0);
    m_axi_awsize             : out std_logic_vector(2 downto 0);
    m_axi_awburst            : out std_logic_vector(1 downto 0);
    m_axi_awlock             : out std_logic;
    m_axi_awcache            : out std_logic_vector(3 downto 0);
    m_axi_awprot             : out std_logic_vector(2 downto 0);
    m_axi_awqos              : out std_logic_vector(3 downto 0);
    m_axi_awvalid            : out std_logic;
    m_axi_awready            : in  std_logic;
    m_axi_wdata              : out std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
    m_axi_wstrb              : out std_logic_vector(MEMORY_DATA_WIDTH / 8 - 1 downto 0);
    m_axi_wlast              : out std_logic;
    m_axi_wvalid             : out std_logic;
    m_axi_wready             : in  std_logic;
    m_axi_bresp              : in  std_logic_vector(1 downto 0);
    m_axi_bvalid             : in  std_logic;
    m_axi_bready             : out std_logic;
    m_axi_araddr             : out std_logic_vector(31 downto 0);
    m_axi_arlen              : out std_logic_vector(7 downto 0);
    m_axi_arsize             : out std_logic_vector(2 downto 0);
    m_axi_arburst            : out std_logic_vector(1 downto 0);
    m_axi_arlock             : out std_logic;
    m_axi_arcache            : out std_logic_vector(3 downto 0);
    m_axi_arprot             : out std_logic_vector(2 downto 0);
    m_axi_arqos              : out std_logic_vector(3 downto 0);
    m_axi_arvalid            : out std_logic;
    m_axi_arready            : in  std_logic;
    m_axi_rdata              : in  std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
    m_axi_rresp              : in  std_logic_vector(1 downto 0);
    m_axi_rlast              : in  std_logic;
    m_axi_rvalid             : in  std_logic;
    m_axi_rready             : out std_logic;
    ---- CustomLogic Device/Channel Interfaces -----------------------------
    -- AXI Stream Slave Interface
    s_axis_resetn            : in  std_logic; -- AXI Stream Interface reset
    s_axis_tvalid            : in  std_logic;
    s_axis_tready            : out std_logic;
    s_axis_tdata             : in  std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
    s_axis_tuser             : in  std_logic_vector(3 downto 0);
    -- Metadata Slave Interface
    s_mdata_StreamId         : in  std_logic_vector(7 downto 0);
    s_mdata_SourceTag        : in  std_logic_vector(15 downto 0);
    s_mdata_Xsize            : in  std_logic_vector(23 downto 0);
    s_mdata_Xoffs            : in  std_logic_vector(23 downto 0);
    s_mdata_Ysize            : in  std_logic_vector(23 downto 0);
    s_mdata_Yoffs            : in  std_logic_vector(23 downto 0);
    s_mdata_DsizeL           : in  std_logic_vector(23 downto 0);
    s_mdata_PixelF           : in  std_logic_vector(15 downto 0);
    s_mdata_TapG             : in  std_logic_vector(15 downto 0);
    s_mdata_Flags            : in  std_logic_vector(7 downto 0);
    s_mdata_Timestamp        : in  std_logic_vector(31 downto 0);
    s_mdata_PixProcFlgs      : in  std_logic_vector(7 downto 0);
    s_mdata_Status           : in  std_logic_vector(31 downto 0);
    -- AXI Stream Master Interface
    m_axis_tvalid            : out std_logic;
    m_axis_tready            : in  std_logic;
    m_axis_tdata             : out std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
    m_axis_tuser             : out std_logic_vector(3 downto 0);
    -- Metadata Master Interface
    m_mdata_StreamId         : out std_logic_vector(7 downto 0);
    m_mdata_SourceTag        : out std_logic_vector(15 downto 0);
    m_mdata_Xsize            : out std_logic_vector(23 downto 0);
    m_mdata_Xoffs            : out std_logic_vector(23 downto 0);
    m_mdata_Ysize            : out std_logic_vector(23 downto 0);
    m_mdata_Yoffs            : out std_logic_vector(23 downto 0);
    m_mdata_DsizeL           : out std_logic_vector(23 downto 0);
    m_mdata_PixelF           : out std_logic_vector(15 downto 0);
    m_mdata_TapG             : out std_logic_vector(15 downto 0);
    m_mdata_Flags            : out std_logic_vector(7 downto 0);
    m_mdata_Timestamp        : out std_logic_vector(31 downto 0);
    m_mdata_PixProcFlgs      : out std_logic_vector(7 downto 0);
    m_mdata_Status           : out std_logic_vector(31 downto 0);
    -- Memento Master Interface
    m_memento_event          : out std_logic;
    m_memento_arg0           : out std_logic_vector(31 downto 0);
    m_memento_arg1           : out std_logic_vector(31 downto 0)
  );
end entity CustomLogic;

architecture behav of CustomLogic is

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------
  -- Image
  constant BITS_PER_PIXEL     : natural                                          := 8;
  constant WORDS_PER_STREAM   : natural                                          := STREAM_DATA_WIDTH / BITS_PER_PIXEL;            -- 16 pixels per 128b word
  constant IMG_DIM            : natural                                          := 320;                                           -- frame is IMG_DIM x IMG_DIM
  constant PIXELS_PER_FRAME   : natural                                          := IMG_DIM * IMG_DIM;                             -- 102400
  constant WORDS_PER_FRAME    : natural                                          := PIXELS_PER_FRAME / WORDS_PER_STREAM;           -- 6400

  -- Sequentializer
  constant SEQ_CNT_WIDTH      : natural                                          := integer(ceil(log2(real(WORDS_PER_STREAM))));   -- 4

  -- FOLO
  constant FOLO_OUT_WIDTH     : natural                                          := 16;
  constant FOLO_OUTS_PER_WORD : natural                                          := STREAM_DATA_WIDTH / FOLO_OUT_WIDTH;            -- 8 outputs per 128b word
  constant GRID_DIM           : natural                                          := 40;                                            -- FOLO output is GRID_DIM x GRID_DIM
  constant FOLO_OUT_VALUES    : natural                                          := GRID_DIM * GRID_DIM;                           -- 1600 outputs per frame
  constant OVERLAY_WORDS      : natural                                          := FOLO_OUT_VALUES / FOLO_OUTS_PER_WORD;          -- 200 words per result
  constant OVERLAY_START      : natural                                          := WORDS_PER_FRAME - OVERLAY_WORDS;               -- 6200 (bottom 10 rows)

  -- GAUS
  constant GAUS_IN_WIDTH      : natural                                          := 16;
  constant GAUS_OUT_WIDTH     : natural                                          := 112;

  -- Detection list (top-N). NUM_DET = 5 now: streaming top-5 argmax (the 5
  -- highest FOLO cells, by value). Everything downstream (crop loop, gaussian
  -- collector, overlay band) iterates [0..NUM_DET-1], so this is the only knob.
  -- For spatially-distinct detections, replace pDetect with an NMS block that
  -- fills the same det_list interface; nothing else changes.
  constant NUM_DET            : natural                                          := 5;                                             -- detections processed per frame now
  constant NUM_DET_MAX        : natural                                          := 5;                                             -- reserved capacity (overlay band, counters)

  -- Crop (un-scaled bounding box streamed into gaussian)
  constant CELL_SIZE          : natural                                          := IMG_DIM / GRID_DIM;                            -- 8  (un-scale factor)
  constant CELL_HALF          : natural                                          := CELL_SIZE / 2;                                 -- 4  (cell-centre offset)
  constant CROP_DIM           : natural                                          := 48;                                            -- 48 x 48 box
  constant BOX_HALF           : natural                                          := CROP_DIM / 2;                                  -- 24
  constant CROP_PIXELS        : natural                                          := CROP_DIM * CROP_DIM;                           -- 2304 px per box (always, padding incl.)
  constant BOX_ORIGIN_OFFS    : integer                                          := CELL_HALF - BOX_HALF;                          -- -20 : box top-left = 8*cell + OFFS

  -- Gaussian overlay band : NUM_DET_MAX words reserved immediately above the
  -- FOLO band; result i lands in word GAUS_OVL_START + i (112b payload, 16 MSB
  -- padding). Top-1 -> word 6195 ; top-5 -> words 6195..6199.
  constant GAUS_OVL_WORDS     : natural                                          := NUM_DET_MAX;                                   -- 5 reserved
  constant GAUS_OVL_START     : natural                                          := OVERLAY_START - GAUS_OVL_WORDS;                -- 6195

  -- Derived address widths
  constant FB_AWORD           : natural                                          := integer(ceil(log2(real(WORDS_PER_FRAME))));    -- 13
  constant RB_AWORD           : natural                                          := integer(ceil(log2(real(OVERLAY_WORDS))));      -- 8
  constant VAL_CNT_WIDTH      : natural                                          := integer(ceil(log2(real(FOLO_OUT_VALUES))));    -- 11
  constant SLOT_BITS          : natural                                          := integer(ceil(log2(real(FOLO_OUTS_PER_WORD)))); -- 3
  constant GRID_AWIDTH        : natural                                          := integer(ceil(log2(real(GRID_DIM))));           -- 6  (cell col/row 0..39)
  constant CROP_AWIDTH        : natural                                          := integer(ceil(log2(real(CROP_DIM))));           -- 6  (crop col/row 0..47)
  constant GAUS_SLOT_BITS     : natural                                          := integer(ceil(log2(real(NUM_DET_MAX))));        -- 3

  ----------------------------------------------------------------------------
  -- Types
  ----------------------------------------------------------------------------
  type frame_buf_t is array (0 to WORDS_PER_FRAME - 1) of std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
  type res_buf_t is array (0 to OVERLAY_WORDS - 1) of std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);

  type cap_state_t is (C_IDLE, C_ARM, C_WRITE);
  type feed_state_t is (F_IDLE, F_WAIT, F_WAIT2, F_LOAD, F_RUN);
  type crop_state_t is (XC_IDLE, XC_PREP1, XC_PREP1B, XC_PREP2, XC_PIPE, XC_FET1, XC_FET2, XC_FET3, XC_DRIVE, XC_DONE);

  -- 3-deep frame ring : a buffer walks EMPTY -> FILLED (FOLO domain) ->
  -- DETECTED (crop domain) -> EMPTY. Distinct cursors own each stage so the
  -- three stages overlap (capture N+2 / FOLO N+1 / crop N).
  type buf_state_t is (B_EMPTY, B_FILLED, B_DETECTED);
  type buf_state_arr_t is array (0 to 2) of buf_state_t;

  -- Detection coordinate list rides along with the frame buffer it came from.
  type det_coord_t is record
    cx                        : unsigned(GRID_AWIDTH - 1 downto 0);                                                                -- cell column 0..39
    cy                        : unsigned(GRID_AWIDTH - 1 downto 0);                                                                -- cell row    0..39
  end record det_coord_t;
  type det_list_t is array (0 to NUM_DET_MAX - 1) of det_coord_t;                                                                  -- sized to MAX; only [0..NUM_DET-1] used
  type buf_coord_arr_t is array (0 to 2) of det_list_t;

  -- Running value array for the top-N detector (one score per kept detection).
--  type det_val_arr_t is array (0 to NUM_DET_MAX - 1) of unsigned(FOLO_OUT_WIDTH - 1 downto 0);

  -- Gaussian result set (one 112b vector per detection), double buffered.
  type gaus_res_set_t is array (0 to NUM_DET_MAX - 1) of std_logic_vector(GAUS_OUT_WIDTH - 1 downto 0);

  ----------------------------------------------------------------------------
  -- Components
  ----------------------------------------------------------------------------
  component folo is
    port (
      input_3_TDATA      : in  std_logic_vector(FOLO_OUT_WIDTH - 1 downto 0);
      layer16_out_TDATA  : out std_logic_vector(FOLO_OUT_WIDTH - 1 downto 0);
      ap_clk             : in  std_logic;
      ap_rst_n           : in  std_logic;
      input_3_TVALID     : in  std_logic;
      input_3_TREADY     : out std_logic;
      ap_start           : in  std_logic;
      layer16_out_TVALID : out std_logic;
      layer16_out_TREADY : in  std_logic;
      ap_done            : out std_logic;
      ap_ready           : out std_logic;
      ap_idle            : out std_logic
    );
  end component folo;

  component gaussian is
    port (
      InputLayer_TDATA   : in  std_logic_vector(GAUS_IN_WIDTH - 1 downto 0);
      layer32_out_TDATA  : out std_logic_vector(GAUS_OUT_WIDTH - 1 downto 0);
      ap_clk             : in  std_logic;
      ap_rst_n           : in  std_logic;
      InputLayer_TVALID  : in  std_logic;
      InputLayer_TREADY  : out std_logic;
      ap_start           : in  std_logic;
      layer32_out_TVALID : out std_logic;
      layer32_out_TREADY : in  std_logic;
      ap_done            : out std_logic;
      ap_ready           : out std_logic;
      ap_idle            : out std_logic
    );
  end component gaussian;

  component nms_top5 is
    generic (
      GRID_W   : integer := 40;
      GRID_H   : integer := 40;
      MAX_CAND : integer := 256
    );
    port (
      clk               : in  std_logic;
      rst_n             : in  std_logic;
      tvalid            : in  std_logic;
      tdata             : in  std_logic_vector(15 downto 0);
      tlast             : in  std_logic;
      done              : out std_logic;
      top_val_0         : out std_logic_vector(15 downto 0);
      top_val_1         : out std_logic_vector(15 downto 0);
      top_val_2         : out std_logic_vector(15 downto 0);
      top_val_3         : out std_logic_vector(15 downto 0);
      top_val_4         : out std_logic_vector(15 downto 0);
      top_x_0           : out std_logic_vector(5 downto 0);
      top_x_1           : out std_logic_vector(5 downto 0);
      top_x_2           : out std_logic_vector(5 downto 0);
      top_x_3           : out std_logic_vector(5 downto 0);
      top_x_4           : out std_logic_vector(5 downto 0);
      top_y_0           : out std_logic_vector(5 downto 0);
      top_y_1           : out std_logic_vector(5 downto 0);
      top_y_2           : out std_logic_vector(5 downto 0);
      top_y_3           : out std_logic_vector(5 downto 0);
      top_y_4           : out std_logic_vector(5 downto 0)
    );
  end component nms_top5;

  ----------------------------------------------------------------------------
  -- Functions
  ----------------------------------------------------------------------------
  function inc3 (v : unsigned) return unsigned is
  begin
    if v = to_unsigned(2, v'length) then
      return to_unsigned(0, v'length);
    else
      return v + 1;
    end if;
  end function inc3;

  ----------------------------------------------------------------------------
  -- Signals
  ----------------------------------------------------------------------------
  -- Buffer manager (3-deep ring)
  signal buf_state            : buf_state_arr_t                                  := (others => B_EMPTY);
  signal buf_coords           : buf_coord_arr_t;
  signal cap_ptr              : unsigned(1 downto 0)                             := (others => '0');                               -- capture writes this buffer
  signal folo_ptr             : unsigned(1 downto 0)                             := (others => '0');                               -- FOLO feed reads this buffer
  signal folo_res_ptr         : unsigned(1 downto 0)                             := (others => '0');                               -- buffer whose FOLO results complete next
  signal crop_ptr             : unsigned(1 downto 0)                             := (others => '0');                               -- crop reads this buffer
  signal cap_commit           : std_logic                                        := '0';                                           -- 1-cyc: capture committed buf cap_ptr
  signal folo_done            : std_logic                                        := '0';                                           -- 1-cyc: FOLO feed drained buf folo_ptr
  signal crop_done            : std_logic                                        := '0';                                           -- 1-cyc: crop drained buf crop_ptr
  signal cap_buf_free         : std_logic;                                                                                         -- buf cap_ptr is empty
  signal folo_buf_rdy         : std_logic;                                                                                         -- buf folo_ptr is filled
  signal crop_buf_rdy         : std_logic;                                                                                         -- buf crop_ptr is detected

  -- Frame buffers (block RAM x3) + ports
  signal frame_buf0           : frame_buf_t;
  signal frame_buf1           : frame_buf_t;
  signal frame_buf2           : frame_buf_t;
  signal fb_wr_en             : std_logic                                        := '0';
  signal fb_wr_idx            : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');
  signal fb_wr_data           : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal rd_addr0             : unsigned(FB_AWORD - 1 downto 0);
  signal rd_addr1             : unsigned(FB_AWORD - 1 downto 0);
  signal rd_addr2             : unsigned(FB_AWORD - 1 downto 0);
  signal rd_data0             : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal rd_data1             : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal rd_data2             : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal folo_rd_idx          : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');                               -- FOLO feed read index (combinational)
  signal fb_folo_rd_data      : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);                                                  -- registered read for FOLO feed
  signal crop_rd_idx          : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');                               -- crop read index (registered)
  signal fb_crop_rd_data      : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);                                                  -- registered read for crop

  -- Capture engine
  signal cap_state            : cap_state_t                                      := C_IDLE;
  signal cap_word_cnt         : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');

  -- FOLO feed engine
  signal feed_state           : feed_state_t                                     := F_IDLE;
  signal feed_word_idx        : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');
  signal feed_pix_cnt         : unsigned(SEQ_CNT_WIDTH - 1 downto 0)             := (others => '0');
  signal cur_word             : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- FOLO handshake
  signal folo_in_tdata        : std_logic_vector(FOLO_OUT_WIDTH - 1 downto 0)    := (others => '0');
  signal folo_out_tdata       : std_logic_vector(FOLO_OUT_WIDTH - 1 downto 0)    := (others => '0');
  signal folo_in_tvalid       : std_logic                                        := '0';
  signal folo_out_tvalid      : std_logic                                        := '0';
  signal folo_in_tready       : std_logic                                        := '0';

  -- Collector + result buffers (distributed RAM) -> FOLO overlay map
  signal res_buf0             : res_buf_t;
  signal res_buf1             : res_buf_t;
  signal res_val_cnt          : unsigned(VAL_CNT_WIDTH - 1 downto 0)             := (others => '0');
  signal pack_word            : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal res_wptr             : std_logic                                        := '0';
  signal res_wr_en            : std_logic                                        := '0';
  signal res_wr_idx           : unsigned(RB_AWORD - 1 downto 0)                  := (others => '0');
  signal res_wr_data          : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal res_ready_pulse      : std_logic                                        := '0';
  signal res_ready_buf        : std_logic                                        := '0';

  -- Detector (streaming top-5 argmax, in the collector domain). db_best* hold
  -- the running 5-best (sorted descending: index 0 = highest). det_list is the
  -- published coordinate list, finalized on the last value so it is valid the
  -- same cycle res_ready_pulse asserts.
--  signal db_col               : unsigned(GRID_AWIDTH - 1 downto 0)               := (others => '0');
--  signal db_row               : unsigned(GRID_AWIDTH - 1 downto 0)               := (others => '0');
--  signal db_best_val          : det_val_arr_t                                    := (others => (others => '0'));
--  signal db_best              : det_list_t                                       := (others => (cx => (others => '0'), cy => (others => '0')));
--  signal det_list             : det_list_t                                       := (others => (cx => (others => '0'), cy => (others => '0')));
  
  signal nms_done_d           : std_logic := '0';
  signal nms_done_pulse       : std_logic;
  
  -- nms_top5 (NMS top-5) interface
  signal nms_in_tvalid         : std_logic                                        := '0';
  signal nms_in_tdata          : std_logic_vector(15 downto 0)                    := (others => '0');
  signal nms_in_tlast          : std_logic                                        := '0';
  signal nms_done              : std_logic;
  signal nms_top_val_0         : std_logic_vector(15 downto 0);
  signal nms_top_val_1         : std_logic_vector(15 downto 0);
  signal nms_top_val_2         : std_logic_vector(15 downto 0);
  signal nms_top_val_3         : std_logic_vector(15 downto 0);
  signal nms_top_val_4         : std_logic_vector(15 downto 0);
  signal nms_top_x_0           : std_logic_vector(5 downto 0);
  signal nms_top_x_1           : std_logic_vector(5 downto 0);
  signal nms_top_x_2           : std_logic_vector(5 downto 0);
  signal nms_top_x_3           : std_logic_vector(5 downto 0);
  signal nms_top_x_4           : std_logic_vector(5 downto 0);
  signal nms_top_y_0           : std_logic_vector(5 downto 0);
  signal nms_top_y_1           : std_logic_vector(5 downto 0);
  signal nms_top_y_2           : std_logic_vector(5 downto 0);
  signal nms_top_y_3           : std_logic_vector(5 downto 0);
  signal nms_top_y_4           : std_logic_vector(5 downto 0);

  -- Crop sequencer
  signal crop_state           : crop_state_t                                     := XC_IDLE;
  signal crop_det_i           : integer range 0 to NUM_DET_MAX - 1               := 0;
  signal crop_c               : unsigned(CROP_AWIDTH - 1 downto 0)               := (others => '0');
  signal crop_r               : unsigned(CROP_AWIDTH - 1 downto 0)               := (others => '0');
  signal crop_x0              : signed(11 downto 0)                              := (others => '0');
  signal crop_y0              : signed(11 downto 0)                              := (others => '0');
  signal cw                   : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal cw_idx               : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');
  signal cw_valid             : std_logic                                        := '0';
  -- for the pipelined stage maintaining the requests from memory
  signal req_word             : unsigned(FB_AWORD-1 downto 0)                    := (others => '0');
  signal req_byte             : natural range 0 to WORDS_PER_STREAM-1            := 0;
  signal req_inb              : std_logic                                        := '0';
  signal req_fetch            : std_logic                                        := '0';
  signal w_i_reg              : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');
  signal b_i_reg              : natural range 0 to WORDS_PER_STREAM - 1          := 0;
  signal inb_reg              : std_logic                                        := '0';
  --signal px_i_reg             : natural range 0 to WORDS_PER_STREAM - 1          := 0;
  signal px_i_reg             : integer range -32 to IMG_DIM + 32                := 0;
  signal w_mult_reg : unsigned(15 downto 0) := (others => '0');  -- py_i * 20, pre-add
  
  -- frame buffer
  signal fb_folo_rd_data_r    : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal fb_crop_rd_data_r    : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0) := (others => '0');

  -- Gaussian input buffer
  signal gaus_in_post_buf_tdata        : std_logic_vector(GAUS_IN_WIDTH - 1 downto 0)     := (others => '0');
  signal gaus_in_post_buf_tvalid       : std_logic                                        := '0';
  
  -- Gaussian handshake
  signal gaus_in_tdata        : std_logic_vector(GAUS_IN_WIDTH - 1 downto 0)     := (others => '0');
  signal gaus_in_tvalid       : std_logic                                        := '0';
  signal gaus_in_tready       : std_logic                                        := '0';
  signal gaus_out_tdata       : std_logic_vector(GAUS_OUT_WIDTH - 1 downto 0)    := (others => '0');
  signal gaus_out_tvalid      : std_logic                                        := '0';

  -- Gaussian collector + result buffers (double-buffered, async read for overlay)
  signal gaus_res0            : gaus_res_set_t;
  signal gaus_res1            : gaus_res_set_t;
  signal gaus_out_idx         : integer range 0 to NUM_DET_MAX - 1               := 0;
  signal gaus_wptr            : std_logic                                        := '0';
  signal gaus_ready_pulse     : std_logic                                        := '0';
  signal gaus_ready_buf       : std_logic                                        := '0';
  signal gaus_slot            : unsigned(GAUS_SLOT_BITS - 1 downto 0);
  signal gaus_rd_val          : std_logic_vector(GAUS_OUT_WIDTH - 1 downto 0);

  -- Overlay mux (shared output word index; independent FOLO / gaussian arming)
  signal ovl_idx              : unsigned(FB_AWORD - 1 downto 0)                  := (others => '0');
  signal cur_idx              : unsigned(FB_AWORD - 1 downto 0);
  signal ovl_armed            : std_logic                                        := '0';
  signal ovl_rd_ptr           : std_logic                                        := '0';
  signal pending_valid        : std_logic                                        := '0';
  signal pending_buf          : std_logic                                        := '0';
  signal overlay_sel          : std_logic;
  signal res_rd_idx           : unsigned(RB_AWORD - 1 downto 0);
  signal res_rd_data          : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
  signal gaus_armed           : std_logic                                        := '0';
  signal gaus_rd_ptr          : std_logic                                        := '0';
  signal gaus_pending_valid   : std_logic                                        := '0';
  signal gaus_pending_buf     : std_logic                                        := '0';
  signal gaus_ovl_sel         : std_logic;
  signal gaus_word            : std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);

  -- Debug
  signal folo_in_cnt          : unsigned(31 downto 0)                            := (others => '0');
  signal folo_out_cnt         : unsigned(31 downto 0)                            := (others => '0');
  signal gaus_in_cnt          : unsigned(31 downto 0)                            := (others => '0');
  signal gaus_out_cnt         : unsigned(31 downto 0)                            := (others => '0');


  ----------------------------------------------------------------------------
  -- Attributes (RAM inference hints)
  ----------------------------------------------------------------------------
  attribute ram_style         : string;
  attribute ram_style of frame_buf0 : signal is "block";
  attribute ram_style of frame_buf1 : signal is "block";
  attribute ram_style of frame_buf2 : signal is "block";
  attribute ram_style of res_buf0 : signal is "distributed";
  attribute ram_style of res_buf1 : signal is "distributed";
  
  -- Attributes for pipeline stage crop
  attribute keep      : string;
  attribute dont_touch : string;
  attribute keep of w_mult_reg : signal is "true";
  attribute dont_touch of w_mult_reg : signal is "true";

begin

  ----------------------------------------------------------------------------
  -- Buffer manager : owns the 3-deep ring (cursors, per-buffer state, coords).
  --   Each event pulse targets a DIFFERENT buffer in any cycle, because the
  --   four cursors sit on buffers in mutually-exclusive states, so there is
  --   never a same-index write race.
  --     EMPTY    --cap_commit-->     FILLED      (capture done)
  --     FILLED   --folo_done-->      FILLED      (feed done; folo_ptr advances)
  --     FILLED   --res_ready_pulse-> DETECTED    (results in, coords latched)
  --     DETECTED --crop_done-->      EMPTY       (all boxes cropped)
  ----------------------------------------------------------------------------
  cap_buf_free <= '1' when buf_state(to_integer(cap_ptr)) = B_EMPTY else '0';
  folo_buf_rdy <= '1' when buf_state(to_integer(folo_ptr)) = B_FILLED else '0';
  crop_buf_rdy <= '1' when buf_state(to_integer(crop_ptr)) = B_DETECTED else '0';

  pBufMgr: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        buf_state                                   <= (others => B_EMPTY);
        cap_ptr                                     <= (others => '0');
        folo_ptr                                    <= (others => '0');
        folo_res_ptr                                <= (others => '0');
        crop_ptr                                    <= (others => '0');
      else
        if cap_commit = '1' then
          buf_state(to_integer(cap_ptr))            <= B_FILLED;
          cap_ptr                                   <= inc3(cap_ptr);
        end if;
        if folo_done = '1' then
          folo_ptr                                  <= inc3(folo_ptr);
        end if;
        if nms_done_pulse = '1' then
          buf_state(to_integer(folo_res_ptr))           <= B_DETECTED;
          buf_coords(to_integer(folo_res_ptr))(0).cx    <= unsigned(nms_top_x_0);
          buf_coords(to_integer(folo_res_ptr))(0).cy    <= unsigned(nms_top_y_0);
          buf_coords(to_integer(folo_res_ptr))(1).cx    <= unsigned(nms_top_x_1);
          buf_coords(to_integer(folo_res_ptr))(1).cy    <= unsigned(nms_top_y_1);
          buf_coords(to_integer(folo_res_ptr))(2).cx    <= unsigned(nms_top_x_2);
          buf_coords(to_integer(folo_res_ptr))(2).cy    <= unsigned(nms_top_y_2);
          buf_coords(to_integer(folo_res_ptr))(3).cx    <= unsigned(nms_top_x_3);
          buf_coords(to_integer(folo_res_ptr))(3).cy    <= unsigned(nms_top_y_3);
          buf_coords(to_integer(folo_res_ptr))(4).cx    <= unsigned(nms_top_x_4);
          buf_coords(to_integer(folo_res_ptr))(4).cy    <= unsigned(nms_top_y_4);
          folo_res_ptr                                  <= inc3(folo_res_ptr);
        end if;
        
        -- from arg max
--        if res_ready_pulse = '1' then
--          buf_state(to_integer(folo_res_ptr))       <= B_DETECTED;
--          -- latch the whole top-N coord list (slots 0..NUM_DET-1)
--          for i in 0 to NUM_DET - 1 loop
--            buf_coords(to_integer(folo_res_ptr))(i) <= det_list(i);
--          end loop;
--          folo_res_ptr                              <= inc3(folo_res_ptr);
--        end if;
        if crop_done = '1' then
          buf_state(to_integer(crop_ptr))           <= B_EMPTY;
          crop_ptr                                  <= inc3(crop_ptr);
        end if;
      end if;
    end if;
  end process pBufMgr;

  ----------------------------------------------------------------------------
  -- Frame buffer memory : 3 x (1 write + 1 read) simple-dual-port.
  --   Write : capture, into buf cap_ptr.
  --   Read  : muxed between FOLO feed (folo_ptr) and crop (crop_ptr). FOLO and
  --           crop never read the SAME buffer (FILLED vs DETECTED), and the
  --           owner cursor is stable across a read burst, so no port conflict.
  ----------------------------------------------------------------------------
  rd_addr0 <= folo_rd_idx when folo_ptr = "00" else crop_rd_idx when crop_ptr = "00" else (others => '0');
  rd_addr1 <= folo_rd_idx when folo_ptr = "01" else crop_rd_idx when crop_ptr = "01" else (others => '0');
  rd_addr2 <= folo_rd_idx when folo_ptr = "10" else crop_rd_idx when crop_ptr = "10" else (others => '0');

  pFrameMem: process (clk250) is
  begin
    if rising_edge(clk250) then
      if fb_wr_en = '1' then
        case to_integer(cap_ptr) is
          when 0 =>
            frame_buf0(to_integer(fb_wr_idx))       <= fb_wr_data;
          when 1 =>
            frame_buf1(to_integer(fb_wr_idx))       <= fb_wr_data;
          when others =>
            frame_buf2(to_integer(fb_wr_idx))       <= fb_wr_data;
        end case;
      end if;
      rd_data0                                      <= frame_buf0(to_integer(rd_addr0));
      rd_data1                                      <= frame_buf1(to_integer(rd_addr1));
      rd_data2                                      <= frame_buf2(to_integer(rd_addr2));
    end if;
  end process pFrameMem;

  fb_folo_rd_data <= rd_data0 when folo_ptr = "00" else rd_data1 when folo_ptr = "01" else rd_data2;
  fb_crop_rd_data <= rd_data0 when crop_ptr = "00" else rd_data1 when crop_ptr = "01" else rd_data2;

  ----------------------------------------------------------------------------
  -- Capture engine : snoops the live stream, lands exactly one valid frame into
  --   buf cap_ptr. Commit only if word 6399 carries EOF; drop short/garbled
  --   frames. Runs off the s_axis handshake only - never gates the bus.
  ----------------------------------------------------------------------------
  pCapture: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        cap_state                                   <= C_IDLE;
        cap_word_cnt                                <= (others => '0');
        fb_wr_en                                    <= '0';
        cap_commit                                  <= '0';
      else
        fb_wr_en                                    <= '0';                                                                        -- default
        cap_commit                                  <= '0';                                                                        -- default

        case cap_state is

          when C_IDLE =>
            if cap_buf_free = '1' then
              cap_state                             <= C_ARM;
            end if;

          when C_ARM =>
            if s_axis_tvalid = '1' and m_axis_tready = '1' and s_axis_tuser(0) = '1' then
              fb_wr_en                              <= '1';
              fb_wr_idx                             <= (others => '0');
              fb_wr_data                            <= s_axis_tdata;
              cap_word_cnt                          <= to_unsigned(1, cap_word_cnt'length);
              cap_state                             <= C_WRITE;
            end if;

          when C_WRITE =>
            if s_axis_tvalid = '1' and m_axis_tready = '1' then
              if s_axis_tuser(0) = '1' then
                -- unexpected SOF mid-frame: restart
                fb_wr_en                            <= '1';
                fb_wr_idx                           <= (others => '0');
                fb_wr_data                          <= s_axis_tdata;
                cap_word_cnt                        <= to_unsigned(1, cap_word_cnt'length);
              else
                fb_wr_en                            <= '1';
                fb_wr_idx                           <= cap_word_cnt;
                fb_wr_data                          <= s_axis_tdata;
                if cap_word_cnt = to_unsigned(WORDS_PER_FRAME - 1, cap_word_cnt'length) then
                  cap_commit                        <= '1';
                  cap_word_cnt                      <= (others => '0');
                  cap_state                         <= C_IDLE;
                elsif s_axis_tuser(3) = '1' then
                  -- premature EOF: drop
                  cap_word_cnt                      <= (others => '0');
                  cap_state                         <= C_IDLE;
                else
                  cap_word_cnt                      <= cap_word_cnt + 1;
                end if;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process pCapture;


----------------------------------------------------------------------------
-- Read-data pipeline register : breaks the BRAM cascade (rd_data0/1/2 mux)
--   from the consuming logic (cur_word/folo_in_tdata build, cw capture) so
--   each half only has to beat the clock on its own. Costs FOLO feed and
--   crop fetch one extra cycle of latency per word fetched.
----------------------------------------------------------------------------
  pRdDataReg: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        fb_folo_rd_data_r <= (others => '0');
        fb_crop_rd_data_r <= (others => '0');
      else
        fb_folo_rd_data_r <= fb_folo_rd_data;
        fb_crop_rd_data_r <= fb_crop_rd_data;
      end if;
    end if;
  end process pRdDataReg;

  ----------------------------------------------------------------------------
  -- FOLO feed engine : reads buf folo_ptr, sequentializes 128b -> 16x 8b pixels
  --   at 1 px/cycle, honoring FOLO back-pressure (folo_in_tready) losslessly.
  --   Chains into the next ready buffer; idles with tvalid low if none ready.
  --   folo_rd_idx is combinational; F_WAIT burns one cycle for read latency.
  ----------------------------------------------------------------------------
  folo_rd_idx                                       <= feed_word_idx;
  
  pFeed: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        feed_state                                  <= F_IDLE;
        feed_word_idx                               <= (others => '0');
        feed_pix_cnt                                <= (others => '0');
        cur_word                                    <= (others => '0');
        folo_in_tvalid                              <= '0';
        folo_in_tdata                               <= (others => '0');
        folo_done                                   <= '0';
      else
        folo_done                                   <= '0';                                                                        -- default

        case feed_state is

          when F_IDLE =>
            folo_in_tvalid                          <= '0';
            if folo_buf_rdy = '1' then
              feed_word_idx                         <= (others => '0');                                                            -- request word 0 (via folo_rd_idx)
              feed_state                            <= F_WAIT;
            end if;

--          when F_WAIT =>
--            folo_in_tvalid                          <= '0';
--            feed_state                              <= F_LOAD;

--          when F_LOAD =>
--            cur_word                                <= fb_folo_rd_data;
--            folo_in_tdata                           <= std_logic_vector(resize(unsigned(fb_folo_rd_data(BITS_PER_PIXEL - 1 downto 0)), FOLO_OUT_WIDTH));
--            folo_in_tvalid                          <= '1';
--            feed_pix_cnt                            <= to_unsigned(WORDS_PER_STREAM - 1, feed_pix_cnt'length);                     -- 15 remaining
--            feed_state                              <= F_RUN;

            when F_WAIT =>
              folo_in_tvalid <= '0';
              feed_state     <= F_WAIT2;          -- was: F_LOAD
            
            when F_WAIT2 =>
              folo_in_tvalid <= '0';
              feed_state     <= F_LOAD;
            
            when F_LOAD =>
              cur_word       <= fb_folo_rd_data_r;                                                                     -- was fb_folo_rd_data
              folo_in_tdata  <= std_logic_vector(resize(unsigned(fb_folo_rd_data_r(BITS_PER_PIXEL - 1 downto 0)), FOLO_OUT_WIDTH));
              folo_in_tvalid <= '1';
              feed_pix_cnt   <= to_unsigned(WORDS_PER_STREAM - 1, feed_pix_cnt'length);
              feed_state     <= F_RUN;

          when F_RUN =>
            if folo_in_tready = '1' then
              if feed_pix_cnt = 0 then
                if feed_word_idx = to_unsigned(WORDS_PER_FRAME - 1, feed_word_idx'length) then
                  folo_done                         <= '1';
                  folo_in_tvalid                    <= '0';
                  feed_state                        <= F_IDLE;
                else
                  feed_word_idx                     <= feed_word_idx + 1;
                  folo_in_tvalid                    <= '0';
                  feed_state                        <= F_WAIT;
                end if;
              else
                folo_in_tdata                       <= std_logic_vector(resize(unsigned(cur_word(2 * BITS_PER_PIXEL - 1 downto BITS_PER_PIXEL)), FOLO_OUT_WIDTH));
                cur_word                            <= std_logic_vector(shift_right(unsigned(cur_word), BITS_PER_PIXEL));
                feed_pix_cnt                        <= feed_pix_cnt - 1;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process pFeed;

  ----------------------------------------------------------------------------
  -- FOLO instance (free-running: ap_start tied high, output always accepted)
  ----------------------------------------------------------------------------
  uFolo: component folo
  port map (
    input_3_TDATA      => folo_in_tdata,
    input_3_TVALID     => folo_in_tvalid,
    input_3_TREADY     => folo_in_tready,
    layer16_out_TDATA  => folo_out_tdata,
    layer16_out_TVALID => folo_out_tvalid,
    layer16_out_TREADY => '1',
    ap_clk             => clk250,
    ap_rst_n           => s_axis_resetn,
    ap_start           => '1',
    ap_done            => open,
    ap_ready           => open,
    ap_idle            => open
  );

  ----------------------------------------------------------------------------
  -- Collector : counts FOLO output handshakes, packs 8 x 16b -> 128b word.
  --   Value k (0..1599) -> word k/8, slot k mod 8. Every 1600 values = one
  --   result -> swap buffer. Feeds the FOLO overlay map (res_buf*).
  ----------------------------------------------------------------------------
  pCollect: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        res_val_cnt                                 <= (others => '0');
        pack_word                                   <= (others => '0');
        res_wptr                                    <= '0';
        res_wr_en                                   <= '0';
        res_ready_pulse                             <= '0';
        res_ready_buf                               <= '0';
      else
        res_wr_en                                   <= '0';                                                                        -- default
        res_ready_pulse                             <= '0';                                                                        -- default

        if folo_out_tvalid = '1' then
          if res_val_cnt(SLOT_BITS - 1 downto 0) = to_unsigned(FOLO_OUTS_PER_WORD - 1, SLOT_BITS) then
            res_wr_data                             <= folo_out_tdata & pack_word(STREAM_DATA_WIDTH - 1 downto FOLO_OUT_WIDTH);
            res_wr_idx                              <= res_val_cnt(VAL_CNT_WIDTH - 1 downto SLOT_BITS);
            res_wr_en                               <= '1';
          end if;
          pack_word                                 <= folo_out_tdata & pack_word(STREAM_DATA_WIDTH - 1 downto FOLO_OUT_WIDTH);

          if res_val_cnt = to_unsigned(FOLO_OUT_VALUES - 1, res_val_cnt'length) then
            res_val_cnt                             <= (others => '0');
            res_ready_pulse                         <= '1';
            res_ready_buf                           <= res_wptr;
            res_wptr                                <= not res_wptr;
          else
            res_val_cnt                             <= res_val_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process pCollect;

  ----------------------------------------------------------------------------
  -- Result buffer memory (FOLO overlay map) : 1 write port. Async read below.
  ----------------------------------------------------------------------------
  pResMem: process (clk250) is
  begin
    if rising_edge(clk250) then
      if res_wr_en = '1' then
        if res_wptr = '0' then
          res_buf0(to_integer(res_wr_idx))          <= res_wr_data;
        else
          res_buf1(to_integer(res_wr_idx))          <= res_wr_data;
        end if;
      end if;
    end if;
  end process pResMem;

  res_rd_idx <= resize(cur_idx - to_unsigned(OVERLAY_START, FB_AWORD), RB_AWORD) when (cur_idx >= to_unsigned(OVERLAY_START, FB_AWORD) and cur_idx < to_unsigned(OVERLAY_START + OVERLAY_WORDS, FB_AWORD)) else (others => '0');
  res_rd_data <= res_buf0(to_integer(res_rd_idx)) when ovl_rd_ptr = '0' else res_buf1(to_integer(res_rd_idx));
    
  
  ----------------------------------------------------------------------------
  -- NMS top-5 instance : streaming, spatially-distinct alternative to pDetect.
  --   Consumes the 40x40 FOLO grid 1 px/cycle (raster order) and returns the
  --   5 strongest peaks with a minimum pairwise separation (no frame buffer).
  --   Same det_list-shaped output as pDetect; swap in to replace top-N-by-value.
  ----------------------------------------------------------------------------  
  uNms: component nms_top5
  generic map (
    GRID_W   => GRID_DIM,
    GRID_H   => GRID_DIM,
    MAX_CAND => 256
  )
  port map (
    clk               => clk250,
    rst_n             => s_axis_resetn,
    tvalid            => nms_in_tvalid,
    tdata             => nms_in_tdata,
    tlast             => nms_in_tlast,
    done              => nms_done,
    top_val_0         => nms_top_val_0,
    top_val_1         => nms_top_val_1,
    top_val_2         => nms_top_val_2,
    top_val_3         => nms_top_val_3,
    top_val_4         => nms_top_val_4,
    top_x_0           => nms_top_x_0,
    top_x_1           => nms_top_x_1,
    top_x_2           => nms_top_x_2,
    top_x_3           => nms_top_x_3,
    top_x_4           => nms_top_x_4,
    top_y_0           => nms_top_y_0,
    top_y_1           => nms_top_y_1,
    top_y_2           => nms_top_y_2,
    top_y_3           => nms_top_y_3,
    top_y_4           => nms_top_y_4
  );
  
  ----------------------------------------------------------------------------
  -- Detector : streaming top-5 argmax over the 1600 unsigned FOLO values, in
  --   the collector domain. Maintains a 5-deep list sorted descending by value
  --   (db_best/db_best_val), tracking (col,row) alongside the value stream (no
  --   divider). Each incoming value is inserted by parallel compare-and-shift:
  --   it displaces the first kept entry it is STRICTLY greater than, so on ties
  --   the earlier raster position stays ahead (same convention as the old top-1
  --   '>' rule). Finalizes det_list on the last value, so it is valid the same
  --   cycle res_ready_pulse asserts.
  --
  --   NOTE: this is top-5 BY VALUE, not NMS. Five hits can cluster on a single
  --   bright blob. If you want spatially-distinct detections, replace this
  --   block with an NMS pass (the full map already lives in res_buf*); it just
  --   needs to fill det_list(0..NUM_DET-1) - downstream is unchanged.
  --
  --   Edge case: cells with value 0 are never inserted (strict '>'), so if a
  --   frame has fewer than NUM_DET non-zero cells the unused slots stay at
  --   value 0 / coord (0,0). Those slots still get cropped + run through
  --   gaussian (redundant work on cell (0,0)), but the output stays well-formed
  --   (exactly NUM_DET results). Not an issue for a real confidence map.
  ----------------------------------------------------------------------------
  pDetect: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        nms_done_d    <= '0';
        nms_done_pulse <= '0';
        nms_in_tvalid <= '0';
        nms_in_tdata  <= (others => '0');
        nms_in_tlast  <= '0';
      else
        nms_done_d <= nms_done;
        nms_done_pulse <= nms_done and not nms_done_d;
        nms_in_tvalid <= folo_out_tvalid;
        nms_in_tdata  <= folo_out_tdata;
        if (folo_out_tvalid = '1' and res_val_cnt = to_unsigned(FOLO_OUT_VALUES - 1, VAL_CNT_WIDTH)) then
          nms_in_tlast <= '1';
        else
          nms_in_tlast <= '0';
        end if;
      end if;
    end if;
  end process pDetect;
    

  
  ------------------------ old arg max implmentation -------------------------
--  pDetect: process (clk250) is
--    variable v                : unsigned(FOLO_OUT_WIDTH - 1 downto 0);
--    variable p                : integer range 0 to NUM_DET;                                                                        -- insertion index (NUM_DET = not in top-N)
--    variable nv               : det_val_arr_t;                                                                                     -- next value list
--    variable nc               : det_list_t;                                                                                        -- next coord list
--    variable last             : boolean;
--  begin
--    if rising_edge(clk250) then
--      if s_axis_resetn = '0' then
--        db_col                                      <= (others => '0');
--        db_row                                      <= (others => '0');
--        for i in 0 to NUM_DET - 1 loop
--          db_best_val(i)                            <= (others => '0');
--          db_best(i).cx                             <= (others => '0');
--          db_best(i).cy                             <= (others => '0');
--          det_list(i).cx                            <= (others => '0');
--          det_list(i).cy                            <= (others => '0');
--        end loop;
--      else
--        if folo_out_tvalid = '1' then
--          v                                         := unsigned(folo_out_tdata);

--          -- insertion index: smallest i with v > db_best_val(i) (list is sorted
--          -- descending, so 'downto' makes the last write the smallest such i).
--          p                                         := NUM_DET;
--          for i in NUM_DET - 1 downto 0 loop
--            if v > db_best_val(i) then
--              p                                     := i;
--            end if;
--          end loop;

--          -- build the post-insert list: keep [0..p-1], insert v at p, shift the
--          -- rest down by one (entry NUM_DET-1 falls off the end).
--          for i in 0 to NUM_DET - 1 loop
--            if i = p then
--              nv(i)                                 := v;
--              nc(i).cx                              := db_col;
--              nc(i).cy                              := db_row;
--            elsif i > p then
--              -- shift-down branch; i > p guarantees i >= 1, so i-1 >= 0.
--              -- Index with (i-1) only inside this branch so synthesis never
--              -- elaborates db_best(-1) for i = 0 (i=0 can only hit i<=p above).
--              nv(i)                                 := db_best_val(i - 1);
--              nc(i).cx                              := db_best(i - 1).cx;
--              nc(i).cy                              := db_best(i - 1).cy;
--            else
--              -- i < p : keep
--              nv(i)                                 := db_best_val(i);
--              nc(i).cx                              := db_best(i).cx;
--              nc(i).cy                              := db_best(i).cy;
--            end if;
--          end loop;
          
--          last                                      := (db_col = to_unsigned(GRID_DIM - 1, GRID_AWIDTH)) and (db_row = to_unsigned(GRID_DIM - 1, GRID_AWIDTH));

--          if last then
--            -- publish the final list (incl. this last value) and reset for the
--            -- next frame; det_list is valid the cycle res_ready_pulse asserts.
--            for i in 0 to NUM_DET - 1 loop
--              det_list(i).cx                        <= nc(i).cx;
--              det_list(i).cy                        <= nc(i).cy;
--              db_best_val(i)                        <= (others => '0');
--              db_best(i).cx                         <= (others => '0');
--              db_best(i).cy                         <= (others => '0');
--            end loop;
--            db_col                                  <= (others => '0');
--            db_row                                  <= (others => '0');
--          else
--            for i in 0 to NUM_DET - 1 loop
--              db_best_val(i)                        <= nv(i);
--              db_best(i).cx                         <= nc(i).cx;
--              db_best(i).cy                         <= nc(i).cy;
--            end loop;
--            if db_col = to_unsigned(GRID_DIM - 1, GRID_AWIDTH) then
--              db_col                                <= (others => '0');
--              db_row                                <= db_row + 1;
--            else
--              db_col                                <= db_col + 1;
--            end if;
--          end if;
--        end if;
--      end if;
--    end if;
--  end process pDetect;

  ----------------------------------------------------------------------------
  -- Crop sequencer : for buf crop_ptr, for each detection in the list, un-scale
  --   the cell centre (img = 8*cell + 4), take the 48x48 box top-left at
  --   centre-24 (== 8*cell + BOX_ORIGIN_OFFS), and stream the box raster, 1 px/
  --   cycle, 8b zero-extended to 16b, into gaussian. Out-of-bounds pixels are
  --   streamed as 0x0000 (zero pad) - padding NEVER skips a beat, so every box
  --   is EXACTLY CROP_PIXELS inputs (keeps the free-running gaussian's output
  --   phase locked, exactly like FOLO's 102400-in / 1600-out invariant).
  --   "simple + correct": one cached frame word, refetched only on word change.
  ----------------------------------------------------------------------------
  pCrop: process (clk250) is
    variable px_i             : integer;
    variable py_i             : integer;
    variable lin_i            : integer;
    variable inb              : boolean;
    variable cwd              : unsigned(STREAM_DATA_WIDTH - 1 downto 0);
    variable pix8             : std_logic_vector(BITS_PER_PIXEL - 1 downto 0);
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        crop_state                                  <= XC_IDLE;
        crop_det_i                                  <= 0;
        crop_c                                      <= (others => '0');
        crop_r                                      <= (others => '0');
        crop_x0                                     <= (others => '0');
        crop_y0                                     <= (others => '0');
        crop_rd_idx                                 <= (others => '0');
        cw                                          <= (others => '0');
        cw_idx                                      <= (others => '0');
        cw_valid                                    <= '0';
        gaus_in_tvalid                              <= '0';
        gaus_in_tdata                               <= (others => '0');
        crop_done                                   <= '0';
        req_word                                    <= (others => '0');
        req_byte                                    <= 0;
        req_inb                                     <= '0';
      else
        crop_done                                   <= '0';                                                                        -- default  
        crop_rd_idx                                 <= req_word;
        
        case crop_state is

          when XC_IDLE =>
            gaus_in_tvalid                          <= '0';
            if crop_buf_rdy = '1' then
              crop_det_i                            <= 0;
              crop_c                                <= (others => '0');
              crop_r                                <= (others => '0');
              cw_valid                              <= '0';
              crop_x0                               <= to_signed(to_integer(buf_coords(to_integer(crop_ptr))(0).cx) * CELL_SIZE + BOX_ORIGIN_OFFS, crop_x0'length);
              crop_y0                               <= to_signed(to_integer(buf_coords(to_integer(crop_ptr))(0).cy) * CELL_SIZE + BOX_ORIGIN_OFFS, crop_y0'length);
              crop_state                            <= XC_PREP1;
            end if;
          when XC_PREP1 =>
              px_i := to_integer(crop_x0) + to_integer(crop_c);
              py_i := to_integer(crop_y0) + to_integer(crop_r);
              inb  := (px_i >= 0) and (px_i <= IMG_DIM - 1) and (py_i >= 0) and (py_i <= IMG_DIM - 1);

              w_mult_reg <= to_unsigned(py_i * (IMG_DIM / WORDS_PER_STREAM), 16);  -- multiply only
              b_i_reg    <= px_i mod WORDS_PER_STREAM;
              px_i_reg   <= px_i;
              if inb then
                inb_reg    <= '1';
              else 
                inb_reg    <= '0';
              end if;
              crop_state <= XC_PREP1B;              -- new state
          
--          when XC_PREP1B =>
--              w_i_reg <= resize(w_mult_reg + to_unsigned(px_i_reg / WORDS_PER_STREAM, FB_AWORD), FB_AWORD);
--              crop_state <= XC_PREP2;
          when XC_PREP1B =>
              if px_i_reg >= 0 then
                w_i_reg <= resize(w_mult_reg + to_unsigned(px_i_reg / WORDS_PER_STREAM, FB_AWORD), FB_AWORD);
              else
                w_i_reg <= (others => '0');   -- out-of-bounds; address discarded via req_inb/inb_reg downstream
              end if;
              crop_state <= XC_PREP2;

          when XC_PREP2 =>
              if inb_reg = '1' then
                req_word <= w_i_reg;
              else
                req_word <= (others => '0');   -- safe dummy address; pixel will be zero-padded via req_inb
              end if;
              req_byte  <= b_i_reg;
              req_inb   <= inb_reg;
              if inb_reg = '1' and ((cw_valid = '0') or (w_i_reg /= cw_idx)) then
                req_fetch <= '1';
              else
                req_fetch <= '0';
              end if;
              crop_state <= XC_PIPE;
--          when XC_PREP2 =>
--              req_word  <= w_i_reg;
--              req_byte  <= b_i_reg;
--              req_inb   <= inb_reg;
--              if inb_reg = '1' and ((cw_valid = '0') or (w_i_reg /= cw_idx)) then
--                req_fetch <= '1';
--              else
--                req_fetch <= '0';
--              end if;
--              crop_state <= XC_PIPE;
            
          when XC_PIPE =>
            if (req_fetch = '1') then
              -- need a different frame word: issue read, wait out the latency
              gaus_in_tvalid                        <= '0';
              crop_state                            <= XC_FET1;
            else
              -- data available (cache hit, or OOB -> zero) : present the pixel
              if (req_inb = '1') then
                cwd                                 := shift_right(unsigned(cw), req_byte * BITS_PER_PIXEL);
                pix8                                := std_logic_vector(cwd(BITS_PER_PIXEL - 1 downto 0));
              else
                pix8                                := (others => '0');
              end if;
              gaus_in_tdata                         <= std_logic_vector(resize(unsigned(pix8), GAUS_IN_WIDTH));
              gaus_in_tvalid                        <= '1';
              crop_state                            <= XC_DRIVE;
            end if; 
          when XC_FET1 =>
              -- crop_rd_idx applied this cycle; registered BRAM latches at edge
              gaus_in_tvalid <= '0';
              crop_state     <= XC_FET2;
        
          when XC_FET2 =>
              -- fb_crop_rd_data (rd_data0/1/2 mux) now valid but unregistered; wait one more
              gaus_in_tvalid <= '0';
              crop_state     <= XC_FET3;
        
          when XC_FET3 =>
              -- fb_crop_rd_data_r now holds the requested word, cleanly registered
              cw         <= fb_crop_rd_data_r;    -- was fb_crop_rd_data
              cw_idx     <= crop_rd_idx;
              cw_valid   <= '1';
              req_fetch  <= '0';        --
              crop_state <= XC_PIPE;

          when XC_DRIVE =>
            -- hold tdata/tvalid until gaussian accepts (lossless stall)
            if gaus_in_tready = '1' then
              gaus_in_tvalid                        <= '0';
              if (crop_c = to_unsigned(CROP_DIM - 1, CROP_AWIDTH)) and (crop_r = to_unsigned(CROP_DIM - 1, CROP_AWIDTH)) then
                -- last pixel of this box
                if crop_det_i = NUM_DET - 1 then
                  crop_done                         <= '1';
                  crop_state                        <= XC_DONE;
                else
                  -- advance to the next detection's box
                  crop_det_i                        <= crop_det_i + 1;
                  crop_c                            <= (others => '0');
                  crop_r                            <= (others => '0');
                  cw_valid                          <= '0';
                  crop_x0                           <= to_signed(to_integer(buf_coords(to_integer(crop_ptr))(crop_det_i + 1).cx) * CELL_SIZE + BOX_ORIGIN_OFFS, crop_x0'length);
                  crop_y0                           <= to_signed(to_integer(buf_coords(to_integer(crop_ptr))(crop_det_i + 1).cy) * CELL_SIZE + BOX_ORIGIN_OFFS, crop_y0'length);
                  crop_state                        <= XC_PREP1;
                end if;
              elsif crop_c = to_unsigned(CROP_DIM - 1, CROP_AWIDTH) then
                crop_c                              <= (others => '0');
                crop_r                              <= crop_r + 1;
                crop_state                          <= XC_PREP1;
              else
                crop_c                              <= crop_c + 1;
                crop_state                          <= XC_PREP1;
              end if;
            end if;
          when XC_DONE =>
            -- one bubble cycle: let pBufMgr consume crop_done (buffer ->
            -- B_EMPTY, crop_ptr advances) BEFORE we re-sample crop_buf_rdy.
            -- Without this, crop_done is still in flight while we sit in
            -- XC_IDLE, buf_state(crop_ptr) is still B_DETECTED, and we re-arm
            -- on the SAME buffer -> every frame gets cropped twice.
            gaus_in_tvalid                          <= '0';
            crop_state                              <= XC_IDLE;
        end case;
      end if;
    end if;
  end process pCrop;
  
  ----------------------------------------------------------------------------
  -- Gaussian input buffer : a pipelined stage for the Gaussian input so that
  --   timing constaints are met.
  ----------------------------------------------------------------------------
  pGausInput: process (clk250) is
  begin
    if rising_edge(clk250) then
        if s_axis_resetn = '0' then
            gaus_in_post_buf_tdata                           <= (others => '0');
            gaus_in_post_buf_tvalid                          <= '0';
        else
            gaus_in_post_buf_tdata                           <= gaus_in_tdata;
            gaus_in_post_buf_tvalid                          <= gaus_in_tvalid;
       end if;
    end if;
  end process pGausInput;

  ----------------------------------------------------------------------------
  -- Gaussian instance (free-running, wired identically to FOLO)
  ----------------------------------------------------------------------------
  uGaus: component gaussian
  port map (
    InputLayer_TDATA   => gaus_in_post_buf_tdata,
    InputLayer_TVALID  => gaus_in_post_buf_tvalid,
    InputLayer_TREADY  => gaus_in_tready,
    layer32_out_TDATA  => gaus_out_tdata,
    layer32_out_TVALID => gaus_out_tvalid,
    layer32_out_TREADY => '1',
    ap_clk             => clk250,
    ap_rst_n           => s_axis_resetn,
    ap_start           => '1',
    ap_done            => open,
    ap_ready           => open,
    ap_idle            => open
  );

  ----------------------------------------------------------------------------
  -- Gaussian collector : counts output handshakes (layer34_out_TREADY tied '1',
  --   so handshake == TVALID). Routes output i -> result slot i; after NUM_DET
  --   outputs a result set is complete -> pulse + swap the double buffer.
  ----------------------------------------------------------------------------
  pGausCollect: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        gaus_out_idx                                <= 0;
        gaus_wptr                                   <= '0';
        gaus_ready_pulse                            <= '0';
        gaus_ready_buf                              <= '0';
      else
        gaus_ready_pulse                            <= '0';                                                                        -- default

        if gaus_out_tvalid = '1' then
          if gaus_wptr = '0' then
            gaus_res0(gaus_out_idx)                 <= gaus_out_tdata;
          else
            gaus_res1(gaus_out_idx)                 <= gaus_out_tdata;
          end if;

          if gaus_out_idx = NUM_DET - 1 then
            gaus_out_idx                            <= 0;
            gaus_ready_pulse                        <= '1';
            gaus_ready_buf                          <= gaus_wptr;
            gaus_wptr                               <= not gaus_wptr;
          else
            gaus_out_idx                            <= gaus_out_idx + 1;
          end if;
        end if;
      end if;
    end if;
  end process pGausCollect;

  -- Async read of the gaussian result for the overlay mux
  gaus_slot <= resize(cur_idx - to_unsigned(GAUS_OVL_START, FB_AWORD), GAUS_SLOT_BITS) when (cur_idx >= to_unsigned(GAUS_OVL_START, FB_AWORD) and cur_idx < to_unsigned(GAUS_OVL_START + NUM_DET, FB_AWORD)) else (others => '0');
  gaus_rd_val <= gaus_res0(to_integer(gaus_slot)) when gaus_rd_ptr = '0' else gaus_res1(to_integer(gaus_slot));
  gaus_word                                         <= std_logic_vector(resize(unsigned(gaus_rd_val), STREAM_DATA_WIDTH));         -- 112b payload, 16 MSB = 0

  ----------------------------------------------------------------------------
  -- Overlay mux control : tracks the output-frame word index; arms the latest
  --   completed FOLO map and gaussian result at SOF (latch-at-SOF => one result
  --   per frame, no tear). Each overlay band is cleared at its region end and
  --   re-armed only when a fresh result is pending (shown once).
  ----------------------------------------------------------------------------
  cur_idx <= (others => '0') when (s_axis_tvalid = '1' and s_axis_tuser(0) = '1') else ovl_idx;

  pOverlay: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        ovl_idx                                     <= (others => '0');
        ovl_armed                                   <= '0';
        ovl_rd_ptr                                  <= '0';
        pending_valid                               <= '0';
        pending_buf                                 <= '0';
        gaus_armed                                  <= '0';
        gaus_rd_ptr                                 <= '0';
        gaus_pending_valid                          <= '0';
        gaus_pending_buf                            <= '0';
      else
        -- latch freshly completed results until the next SOF
        if res_ready_pulse = '1' then
          pending_valid                             <= '1';
          pending_buf                               <= res_ready_buf;
        end if;
        if gaus_ready_pulse = '1' then
          gaus_pending_valid                        <= '1';
          gaus_pending_buf                          <= gaus_ready_buf;
        end if;

        -- advance on an output beat (passthrough never stalls the bus)
        if s_axis_tvalid = '1' and m_axis_tready = '1' then
          if s_axis_tuser(0) = '1' then
            ovl_idx                                 <= to_unsigned(1, ovl_idx'length);
            -- FOLO arm
            if res_ready_pulse = '1' then
              ovl_rd_ptr                            <= res_ready_buf;
              ovl_armed                             <= '1';
              pending_valid                         <= '0';
            elsif pending_valid = '1' then
              ovl_rd_ptr                            <= pending_buf;
              ovl_armed                             <= '1';
              pending_valid                         <= '0';
            end if;
            -- gaussian arm
            if gaus_ready_pulse = '1' then
              gaus_rd_ptr                           <= gaus_ready_buf;
              gaus_armed                            <= '1';
              gaus_pending_valid                    <= '0';
            elsif gaus_pending_valid = '1' then
              gaus_rd_ptr                           <= gaus_pending_buf;
              gaus_armed                            <= '1';
              gaus_pending_valid                    <= '0';
            end if;
          else
            ovl_idx                                 <= ovl_idx + 1;
            if ovl_idx = to_unsigned(OVERLAY_START + OVERLAY_WORDS - 1, ovl_idx'length) then
              ovl_armed                             <= '0';
            end if;
            if ovl_idx = to_unsigned(GAUS_OVL_START + NUM_DET - 1, ovl_idx'length) then
              gaus_armed                            <= '0';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process pOverlay;

  ----------------------------------------------------------------------------
  -- Active Outputs
  ----------------------------------------------------------------------------
  -- AXI Stream passthrough (live path, never stalled by FOLO/gaussian)
  s_axis_tready                                     <= m_axis_tready;
  m_axis_tvalid                                     <= s_axis_tvalid;
  m_axis_tuser                                      <= s_axis_tuser;

  -- Overlay splices (disjoint regions: gaussian band 6195.. then FOLO band 6200..)
  overlay_sel <= '1' when (ovl_armed = '1' and cur_idx >= to_unsigned(OVERLAY_START, FB_AWORD) and cur_idx < to_unsigned(OVERLAY_START + OVERLAY_WORDS, FB_AWORD)) else '0';
  gaus_ovl_sel <= '1' when (gaus_armed = '1' and cur_idx >= to_unsigned(GAUS_OVL_START, FB_AWORD) and cur_idx < to_unsigned(GAUS_OVL_START + NUM_DET, FB_AWORD)) else '0';

  m_axis_tdata <= gaus_word when gaus_ovl_sel = '1' else res_rd_data when overlay_sel = '1' else s_axis_tdata;

  -- Metadata passthrough
  m_mdata_StreamId                                  <= s_mdata_StreamId;
  m_mdata_SourceTag                                 <= s_mdata_SourceTag;
  m_mdata_Xsize                                     <= s_mdata_Xsize;
  m_mdata_Xoffs                                     <= s_mdata_Xoffs;
  m_mdata_Ysize                                     <= s_mdata_Ysize;
  m_mdata_Yoffs                                     <= s_mdata_Yoffs;
  m_mdata_DsizeL                                    <= s_mdata_DsizeL;
  m_mdata_PixelF                                    <= s_mdata_PixelF;
  m_mdata_TapG                                      <= s_mdata_TapG;
  m_mdata_Flags                                     <= s_mdata_Flags;
  m_mdata_Timestamp                                 <= s_mdata_Timestamp;
  m_mdata_PixProcFlgs                               <= s_mdata_PixProcFlgs;
  m_mdata_Status                                    <= s_mdata_Status;

  ----------------------------------------------------------------------------
  -- Inactive outputs
  ----------------------------------------------------------------------------
  s_ctrl_data_rd                                    <= (others => '0');
  user_output_ctrl                                  <= (others => '0');
  custom_logic_output_ctrl                          <= (others => '0');

  m_axi_awaddr                                      <= (others => '0');
  m_axi_awlen                                       <= (others => '0');
  m_axi_awsize                                      <= (others => '0');
  m_axi_awburst                                     <= (others => '0');
  m_axi_awlock                                      <= '0';
  m_axi_awcache                                     <= (others => '0');
  m_axi_awprot                                      <= (others => '0');
  m_axi_awqos                                       <= (others => '0');
  m_axi_awvalid                                     <= '0';
  m_axi_wdata                                       <= (others => '0');
  m_axi_wstrb                                       <= (others => '0');
  m_axi_wlast                                       <= '0';
  m_axi_wvalid                                      <= '0';
  m_axi_bready                                      <= '1';
  m_axi_araddr                                      <= (others => '0');
  m_axi_arlen                                       <= (others => '0');
  m_axi_arsize                                      <= (others => '0');
  m_axi_arburst                                     <= (others => '0');
  m_axi_arlock                                      <= '0';
  m_axi_arcache                                     <= (others => '0');
  m_axi_arprot                                      <= (others => '0');
  m_axi_arqos                                       <= (others => '0');
  m_axi_arvalid                                     <= '0';
  m_axi_rready                                      <= '0';

  m_memento_event                                   <= '0';
  m_memento_arg0                                    <= (others => '0');
  m_memento_arg1                                    <= (others => '0');

  ----------------------------------------------------------------------------
  -- Debug
  ----------------------------------------------------------------------------
  pDebug: process (clk250) is
  begin
    if rising_edge(clk250) then
      if s_axis_resetn = '0' then
        folo_in_cnt                                 <= (others => '0');
        folo_out_cnt                                <= (others => '0');
        gaus_in_cnt                                 <= (others => '0');
        gaus_out_cnt                                <= (others => '0');
      else
        if folo_in_tready = '1' and folo_in_tvalid = '1' then
          folo_in_cnt                               <= folo_in_cnt + 1;
        end if;
        if folo_out_tvalid = '1' then
          folo_out_cnt                              <= folo_out_cnt + 1;
        end if;
        if gaus_in_tready = '1' and gaus_in_tvalid = '1' then
          gaus_in_cnt                               <= gaus_in_cnt + 1;
        end if;
        if gaus_out_tvalid = '1' then
          gaus_out_cnt                              <= gaus_out_cnt + 1;
        end if;
      end if;
    end if;
  end process pDebug;

end architecture behav;
