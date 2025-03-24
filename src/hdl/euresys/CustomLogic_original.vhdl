--------------------------------------------------------------------------------
-- Project: CustomLogic
--------------------------------------------------------------------------------
--  Module: CustomLogic
--    File: CustomLogic.vhd
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
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- For testbenching
use std.textio.all;
use ieee.std_logic_textio.all;

entity CustomLogic is
	generic (
		STREAM_DATA_WIDTH			: natural := 128;
	    MEMORY_DATA_WIDTH			: natural := 128
	);
    port (
		---- CustomLogic Common Interfaces -------------------------------------
        -- Clock/Reset
		clk250						: in  std_logic;	-- Clock 250 MHz
		srst250						: in  std_logic; 	-- Global reset (PCIe reset)
		-- General Purpose I/O Interface
		user_output_ctrl			: out std_logic_vector( 15 downto 0);
		user_output_status			: in  std_logic_vector(  7 downto 0);
		standard_io_set1_status		: in  std_logic_vector(  9 downto 0);
		standard_io_set2_status		: in  std_logic_vector(  9 downto 0);
		module_io_set_status		: in  std_logic_vector( 39 downto 0);
		qdc1_position_status		: in  std_logic_vector( 31 downto 0);
		custom_logic_output_ctrl	: out std_logic_vector( 31 downto 0);
		reserved					: in  std_logic_vector(511 downto 0) := (others=>'0');
		-- Control Slave Interface
		s_ctrl_addr					: in  std_logic_vector( 15 downto 0);
		s_ctrl_data_wr_en			: in  std_logic;
		s_ctrl_data_wr				: in  std_logic_vector( 31 downto 0);
		s_ctrl_data_rd				: out std_logic_vector( 31 downto 0);
		-- On-Board Memory - Parameters
		onboard_mem_base			: in  std_logic_vector( 31 downto 0);	-- Base address of the CustomLogic partition in the On-Board Memory
		onboard_mem_size			: in  std_logic_vector( 31 downto 0);	-- Size in bytes of the CustomLogic partition in the On-Board Memory
		-- On-Board Memory - AXI 4 Master Interface
		m_axi_resetn 				: in  std_logic;	-- AXI 4 Interface reset
		m_axi_awaddr 				: out std_logic_vector( 31 downto 0);
		m_axi_awlen 				: out std_logic_vector(  7 downto 0);
		m_axi_awsize 				: out std_logic_vector(  2 downto 0);
		m_axi_awburst 				: out std_logic_vector(  1 downto 0);
		m_axi_awlock 				: out std_logic;
		m_axi_awcache 				: out std_logic_vector(  3 downto 0);
		m_axi_awprot 				: out std_logic_vector(  2 downto 0);
		m_axi_awqos 				: out std_logic_vector(  3 downto 0);
		m_axi_awvalid 				: out std_logic;
		m_axi_awready 				: in  std_logic;
		m_axi_wdata 				: out std_logic_vector(MEMORY_DATA_WIDTH   - 1 downto 0);
		m_axi_wstrb 				: out std_logic_vector(MEMORY_DATA_WIDTH/8 - 1 downto 0);
		m_axi_wlast 				: out std_logic;
		m_axi_wvalid 				: out std_logic;
		m_axi_wready 				: in  std_logic;
		m_axi_bresp 				: in  std_logic_vector(  1 downto 0);
		m_axi_bvalid 				: in  std_logic;
		m_axi_bready 				: out std_logic;
		m_axi_araddr 				: out std_logic_vector( 31 downto 0);
		m_axi_arlen 				: out std_logic_vector(  7 downto 0);
		m_axi_arsize 				: out std_logic_vector(  2 downto 0);
		m_axi_arburst 				: out std_logic_vector(  1 downto 0);
		m_axi_arlock 				: out std_logic;
		m_axi_arcache 				: out std_logic_vector(  3 downto 0);
		m_axi_arprot 				: out std_logic_vector(  2 downto 0);
		m_axi_arqos 				: out std_logic_vector(  3 downto 0);
		m_axi_arvalid 				: out std_logic;
		m_axi_arready 				: in  std_logic;
		m_axi_rdata 				: in  std_logic_vector(MEMORY_DATA_WIDTH - 1 downto 0);
		m_axi_rresp 				: in  std_logic_vector(  1 downto 0);
		m_axi_rlast 				: in  std_logic;
		m_axi_rvalid 				: in  std_logic;
		m_axi_rready 				: out std_logic;	
		---- CustomLogic Device/Channel Interfaces -----------------------------
		-- AXI Stream Slave Interface
		s_axis_resetn				: in  std_logic;	-- AXI Stream Interface reset
		s_axis_tvalid				: in  std_logic;
		s_axis_tready				: out std_logic;
		s_axis_tdata				: in  std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
		s_axis_tuser				: in  std_logic_vector(  3 downto 0);
		-- Metadata Slave Interface
		s_mdata_StreamId			: in  std_logic_vector( 7 downto 0);
		s_mdata_SourceTag			: in  std_logic_vector(15 downto 0);
		s_mdata_Xsize				: in  std_logic_vector(23 downto 0);
		s_mdata_Xoffs				: in  std_logic_vector(23 downto 0);
		s_mdata_Ysize				: in  std_logic_vector(23 downto 0);
		s_mdata_Yoffs				: in  std_logic_vector(23 downto 0);
		s_mdata_DsizeL				: in  std_logic_vector(23 downto 0);
		s_mdata_PixelF				: in  std_logic_vector(15 downto 0);
		s_mdata_TapG				: in  std_logic_vector(15 downto 0);
		s_mdata_Flags				: in  std_logic_vector( 7 downto 0);
		s_mdata_Timestamp			: in  std_logic_vector(31 downto 0);
		s_mdata_PixProcFlgs			: in  std_logic_vector( 7 downto 0);
		s_mdata_Status				: in  std_logic_vector(31 downto 0);
		-- AXI Stream Master Interface
		m_axis_tvalid				: out std_logic;
		m_axis_tready				: in  std_logic;
		m_axis_tdata				: out std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
		m_axis_tuser				: out std_logic_vector(  3 downto 0);
		-- Metadata Master Interface
		m_mdata_StreamId			: out std_logic_vector( 7 downto 0);
		m_mdata_SourceTag			: out std_logic_vector(15 downto 0);
		m_mdata_Xsize				: out std_logic_vector(23 downto 0);
		m_mdata_Xoffs				: out std_logic_vector(23 downto 0);
		m_mdata_Ysize				: out std_logic_vector(23 downto 0);
		m_mdata_Yoffs				: out std_logic_vector(23 downto 0);
		m_mdata_DsizeL				: out std_logic_vector(23 downto 0);
		m_mdata_PixelF				: out std_logic_vector(15 downto 0);
		m_mdata_TapG				: out std_logic_vector(15 downto 0);
		m_mdata_Flags				: out std_logic_vector( 7 downto 0);
		m_mdata_Timestamp			: out std_logic_vector(31 downto 0);
		m_mdata_PixProcFlgs			: out std_logic_vector( 7 downto 0);
		m_mdata_Status				: out std_logic_vector(31 downto 0);
		-- Memento Master Interface
		m_memento_event				: out std_logic;
		m_memento_arg0				: out std_logic_vector(31 downto 0);
		m_memento_arg1				: out std_logic_vector(31 downto 0)
    );
end entity CustomLogic;

architecture behav of CustomLogic is
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
	-- Constants
	----------------------------------------------------------------------------
	

	----------------------------------------------------------------------------
	-- Types
	----------------------------------------------------------------------------


	----------------------------------------------------------------------------
	-- Functions
	----------------------------------------------------------------------------


	----------------------------------------------------------------------------
	-- Components
	----------------------------------------------------------------------------


	----------------------------------------------------------------------------
	-- Signals
	----------------------------------------------------------------------------
	-- Control Registers
	signal MemTrafficGen_en		    	: std_logic;
	signal Frame2Line_bypass	    	: std_logic;
	signal MementoEvent_en		    	: std_logic;
	signal MementoEvent_arg0	    	: std_logic_vector(31 downto 0);
	signal PixelLut_bypass		    	: std_logic;
	signal PixelLut_coef_start	    	: std_logic;
	signal PixelLut_coef		    	: std_logic_vector( 7 downto 0);
	signal PixelLut_coef_vld	    	: std_logic;
	signal PixelLut_coef_done	    	: std_logic;
	signal PixelThreshold_bypass    	: std_logic;
	signal PixelThreshold_level			: std_logic_vector( 7 downto 0);
	
	-- Pixel LUT
	signal PixelLut_tvalid		    	: std_logic;
	signal PixelLut_tready		    	: std_logic;
	signal PixelLut_tdata		    	: std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
	signal PixelLut_tuser		    	: std_logic_vector( 3 downto 0);
	signal PixelLut_StreamId			: std_logic_vector( 7 downto 0);
	signal PixelLut_SourceTag			: std_logic_vector(15 downto 0);
	signal PixelLut_Xsize				: std_logic_vector(23 downto 0);
	signal PixelLut_Xoffs				: std_logic_vector(23 downto 0);
	signal PixelLut_Ysize				: std_logic_vector(23 downto 0);
	signal PixelLut_Yoffs				: std_logic_vector(23 downto 0);
	signal PixelLut_DsizeL				: std_logic_vector(23 downto 0);
	signal PixelLut_PixelF				: std_logic_vector(15 downto 0);
	signal PixelLut_TapG				: std_logic_vector(15 downto 0);
	signal PixelLut_Flags				: std_logic_vector( 7 downto 0);
	signal PixelLut_Timestamp			: std_logic_vector(31 downto 0);
	signal PixelLut_PixProcFlgs			: std_logic_vector( 7 downto 0);
	signal PixelLut_Status				: std_logic_vector(31 downto 0);
	
	-- HLS Pixel Threshold
	signal HlsPixTh_tvalid		    	: std_logic;
	signal HlsPixTh_tready		    	: std_logic;
	signal HlsPixTh_tdata		    	: std_logic_vector(STREAM_DATA_WIDTH - 1 downto 0);
	signal HlsPixTh_tuser		    	: std_logic_vector( 3 downto 0);
	signal HlsPixTh_StreamId			: std_logic_vector( 7 downto 0);
	signal HlsPixTh_SourceTag			: std_logic_vector(15 downto 0);
	signal HlsPixTh_Xsize				: std_logic_vector(23 downto 0);
	signal HlsPixTh_Xoffs				: std_logic_vector(23 downto 0);
	signal HlsPixTh_Ysize				: std_logic_vector(23 downto 0);
	signal HlsPixTh_Yoffs				: std_logic_vector(23 downto 0);
	signal HlsPixTh_DsizeL				: std_logic_vector(23 downto 0);
	signal HlsPixTh_PixelF				: std_logic_vector(15 downto 0);
	signal HlsPixTh_TapG				: std_logic_vector(15 downto 0);
	signal HlsPixTh_Flags				: std_logic_vector( 7 downto 0);
	signal HlsPixTh_Timestamp			: std_logic_vector(31 downto 0);
	signal HlsPixTh_PixProcFlgs			: std_logic_vector( 7 downto 0);
	signal HlsPixTh_Status				: std_logic_vector(31 downto 0);
	
	-- Memento Events
	signal Wraparound_pls		    	: std_logic;
	signal Wraparound_cnt		    	: std_logic_vector(31 downto 0);


	----------------------------------------------------------------------------
	-- Debug
	----------------------------------------------------------------------------
	-- attribute mark_debug : string;
	-- attribute mark_debug of s_axis_resetn	: signal is "true";
	-- attribute mark_debug of s_axis_tvalid	: signal is "true";
	-- attribute mark_debug of s_axis_tready	: signal is "true";
	-- attribute mark_debug of s_axis_tuser		: signal is "true";

	----------------------------------------------------------------------------
	-- FPGAs for RHEED
	----------------------------------------------------------------------------

	-- Parameters (constant for now)
	constant PIXEL_BIT_WIDTH : integer  := 16;
	constant PIXELS_PER_BURST : integer := 16;
	constant USER_WIDTH : integer := 4;
	constant IN_ROWS : integer := 104;
	constant IN_COLS : integer := 160;
	constant OUT_ROWS : integer := 48;
	constant OUT_COLS : integer := 48;

	-- Stuff for testbenching
	constant CROP_Y0_CONST : integer := 0;
	constant CROP_X0_CONST : integer := 0;
	
	-- synthesis translate_off
	constant BENCHMARK_FILE    : string  := "/home/aelabd/RHEED/CoaxlinkQuadCxp12_1cam/tb_data/ap_fixed_" & integer'image(PIXEL_BIT_WIDTH) & 
											"_" & integer'image(PIXEL_BIT_WIDTH-1) & "/" & 
											integer'image(IN_ROWS) & "x" & integer'image(IN_COLS) & 
											"_to_" & integer'image(OUT_ROWS) & "x" & integer'image(OUT_COLS) & 
											"x1/Y1_" & integer'image(CROP_Y0_CONST) &"/X1_" & integer'image(CROP_X0_CONST) & 
											"/img_postcrop_INDEX.txt";
	
	type mem_array is array (0 to OUT_ROWS*OUT_COLS-1) of std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
	signal cf_out_mem          : mem_array;
    signal cf_out_benchmark_mem: mem_array;
	signal idx_cf_out : integer := 0;
	signal reset : std_logic;
	-- synthesis translate_on
	signal lfsr_16bit_out : std_logic_vector(15 downto 0);
	
	
	-- Crop-coordinates 
  	signal crop_x0   : std_logic_vector(clog2(IN_COLS)-1 downto 0);
	signal crop_y0   : std_logic_vector(clog2(IN_ROWS)-1 downto 0);

	-- Custom downstream tready signal for randomized testbenching
	signal my_m_axis_tready : std_logic;

	-- Sequentializer output signals
	signal seq_s_axis_tready : std_logic; 
	signal seq_m_axis_tvalid : std_logic;
	signal seq_m_axis_tdata : std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
	signal seq_m_axis_tuser : std_logic_vector(USER_WIDTH-1 downto 0);
	signal seq_cnt_col : std_logic_vector(clog2(IN_COLS)-1 downto 0);
	signal seq_cnt_row : std_logic_vector(clog2(IN_ROWS)-1 downto 0);

	signal seq_ap_done : std_logic;

	-- Crop-filter output signals
	signal cf_s_axis_tready : std_logic;
	signal cf_m_axis_tvalid : std_logic;
	signal cf_m_axis_tdata : std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
	signal cf_m_axis_tuser : std_logic_vector(USER_WIDTH-1 downto 0);

	signal cf_ap_done : std_logic;

begin
	
	-- Control Registers
	iControlRegs : entity work.control_registers
		port map (
			clk							=> clk250,
			srst						=> srst250,
			s_ctrl_addr					=> s_ctrl_addr,
			s_ctrl_data_wr_en			=> s_ctrl_data_wr_en,
			s_ctrl_data_wr				=> s_ctrl_data_wr,
			s_ctrl_data_rd				=> s_ctrl_data_rd,
			MemTrafficGen_en			=> MemTrafficGen_en,
			UserOutput_ctrl				=> user_output_ctrl,
			UserOutput_status			=> user_output_status,
			StandardIoSet1_status		=> standard_io_set1_status,
			StandardIoSet2_status		=> standard_io_set2_status,
			ModuleIoSet_status			=> module_io_set_status,
			Qdc1Position_status			=> qdc1_position_status,
			CustomLogicOutput_ctrl		=> custom_logic_output_ctrl,
			Frame2Line_bypass(0)		=> Frame2Line_bypass,
			MementoEvent_en(0)			=> MementoEvent_en,
			MementoEvent_arg0			=> MementoEvent_arg0,
			PixelLut_bypass(0)			=> PixelLut_bypass,
			PixelLut_coef_start(0)		=> PixelLut_coef_start,
			PixelLut_coef_vld(0)		=> PixelLut_coef_vld,
			PixelLut_coef				=> PixelLut_coef,
			PixelLut_coef_done(0)		=> PixelLut_coef_done,
			PixelThreshold_bypass(0)	=> PixelThreshold_bypass,
			PixelThreshold_level		=> PixelThreshold_level
		);
		
	-- Read/Write On-Board Memory
	iMemTrafficGen : entity work.mem_traffic_gen
		generic map (
			DATA_WIDTH 			=> MEMORY_DATA_WIDTH
		)
		port map (
			clk					=> clk250,
			MemTrafficGen_en	=> MemTrafficGen_en,
			Wraparound_pls		=> Wraparound_pls,
			Wraparound_cnt		=> Wraparound_cnt,
			m_axi_resetn		=> m_axi_resetn,
			m_axi_awaddr 		=> m_axi_awaddr,
			m_axi_awlen 		=> m_axi_awlen,
			m_axi_awsize 		=> m_axi_awsize,
			m_axi_awburst 		=> m_axi_awburst,
			m_axi_awlock 		=> m_axi_awlock,
			m_axi_awcache 		=> m_axi_awcache,
			m_axi_awprot 		=> m_axi_awprot,
			m_axi_awqos 		=> m_axi_awqos,
			m_axi_awvalid 		=> m_axi_awvalid,
			m_axi_awready 		=> m_axi_awready,
			m_axi_wdata 		=> m_axi_wdata,
			m_axi_wstrb 		=> m_axi_wstrb,
			m_axi_wlast 		=> m_axi_wlast,
			m_axi_wvalid 		=> m_axi_wvalid,
			m_axi_wready 		=> m_axi_wready,
			m_axi_bresp 		=> m_axi_bresp,
			m_axi_bvalid 		=> m_axi_bvalid,
			m_axi_bready 		=> m_axi_bready,
			m_axi_araddr 		=> m_axi_araddr,
			m_axi_arlen 		=> m_axi_arlen,
			m_axi_arsize 		=> m_axi_arsize,
			m_axi_arburst 		=> m_axi_arburst,
			m_axi_arlock 		=> m_axi_arlock,
			m_axi_arcache 		=> m_axi_arcache,
			m_axi_arprot 		=> m_axi_arprot,
			m_axi_arqos 		=> m_axi_arqos,
			m_axi_arvalid 		=> m_axi_arvalid,
			m_axi_arready 		=> m_axi_arready,
			m_axi_rdata 		=> m_axi_rdata,
			m_axi_rresp 		=> m_axi_rresp,
			m_axi_rlast 		=> m_axi_rlast,
			m_axi_rvalid 		=> m_axi_rvalid,
			m_axi_rready 		=> m_axi_rready
		);
	

	m_memento_event 	<= MementoEvent_en or Wraparound_pls;
	m_memento_arg0		<= MementoEvent_arg0;
	m_memento_arg1		<= Wraparound_cnt;

	---------------------- Bypassed connections ----------------------
	-- m_axis_tdata <= s_axis_tdata;
	-- m_axis_tuser <= s_axis_tuser;
	-- m_axis_tvalid <= '1';


	---------------------- Sequentializer ----------------------
	
	s_axis_tready <= seq_s_axis_tready; -- For clarity's sake

	iSequentializer: entity work.sequentializer 
    generic map (
      PIXEL_BIT_WIDTH => PIXEL_BIT_WIDTH,
      PIXELS_PER_BURST => PIXELS_PER_BURST,
      USER_WIDTH => USER_WIDTH, 
      IN_ROWS => IN_ROWS,
      IN_COLS => IN_COLS, 
      OUT_ROWS => OUT_ROWS,
      OUT_COLS => OUT_COLS
    )
    port map (
      clk => clk250, 
      srst => srst250, 

	  ap_done => seq_ap_done,

	  s_axis_resetn => s_axis_resetn,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => seq_s_axis_tready,
      s_axis_tdata => s_axis_tdata,
      s_axis_tuser => s_axis_tuser,
	  m_axis_tvalid => seq_m_axis_tvalid,
	  m_axis_tready => cf_s_axis_tready,
	  m_axis_tdata => seq_m_axis_tdata,
	  m_axis_tuser => seq_m_axis_tuser,
	  cnt_col => seq_cnt_col,
	  cnt_row => seq_cnt_row
    );



	---------------------- Crop-filter ----------------------

	iCropFilter: entity work.crop_filter
	generic map(
	  PIXEL_BIT_WIDTH => PIXEL_BIT_WIDTH,
	  USER_WIDTH => USER_WIDTH,
      IN_ROWS => IN_ROWS,
      IN_COLS => IN_COLS, 
      OUT_ROWS => OUT_ROWS,
      OUT_COLS => OUT_COLS
	  )
	port map(
	  clk => clk250, 
	  srst => srst250, 
	  s_axis_resetn => s_axis_resetn,

	  s_axis_tvalid => seq_m_axis_tvalid,
	  s_axis_tready => cf_s_axis_tready,
	  s_axis_tdata => seq_m_axis_tdata,
	  s_axis_tuser => seq_m_axis_tuser,

	  crop_x0 => crop_x0,
	  crop_y0 => crop_y0,

	  m_axis_tvalid => cf_m_axis_tvalid,
	  m_axis_tready => my_m_axis_tready,
	  m_axis_tdata => cf_m_axis_tdata,
	  m_axis_tuser => cf_m_axis_tuser,
	  cnt_col => seq_cnt_col,
	  cnt_row => seq_cnt_row,

	  ap_done => cf_ap_done
	);

	----------------------- For testbenching -----------------------

	-- Drive downstream treadt
	-- my_m_axis_tready <= '1';
	-- my_m_axis_tready <= m_axis_tready;
	iRBG: entity work.lfsr_16bit
	port map (
		clk => clk250,
		reset => srst250,
		Q => lfsr_16bit_out
	);
	my_m_axis_tready <= lfsr_16bit_out(0);

	crop_y0 <= std_logic_vector(to_unsigned(CROP_Y0_CONST, clog2(IN_ROWS)));
	crop_x0 <= std_logic_vector(to_unsigned(CROP_X0_CONST, clog2(IN_COLS)));

	-- synthesis translate_off

	-- Read benchmark file into memory
    load_benchmark: process
        file file_handle       : text;
        variable line_content  : line;
        variable temp_vector   : std_logic_vector(PIXEL_BIT_WIDTH-1 downto 0);
        variable row, col      : integer;
    begin
        file_open(file_handle, BENCHMARK_FILE, read_mode);
        
        for row in 0 to OUT_ROWS-1 loop
            readline(file_handle, line_content);
            for col in 0 to OUT_COLS-1 loop
                -- Read hexadecimal value from line
                hread(line_content, temp_vector);
                -- Calculate 1D index from 2D coordinates
                cf_out_benchmark_mem(row * OUT_COLS + col) <= temp_vector;
            end loop;
        end loop;
        
        file_close(file_handle);
        wait;
    end process;

	-- Data capture and verification process
	reset <= (not s_axis_resetn) or srst250;
    data_capture: process(clk250)
    begin
        if rising_edge(clk250) then
            if reset = '1' or idx_cf_out = OUT_ROWS*OUT_COLS then -- TODO: why not OUT_ROWS*OUT_COLS-1 ?
                idx_cf_out <= 0;
            else
                if cf_m_axis_tvalid = '1' and my_m_axis_tready = '1' then
                    -- Capture DUT output
                    cf_out_mem(idx_cf_out) <= cf_m_axis_tdata;
                    
                    -- Verify against benchmark
                    assert cf_out_benchmark_mem(idx_cf_out) = cf_m_axis_tdata
                        report "Mismatch at index " & integer'image(idx_cf_out) 
                               & " (Row=" & integer'image(idx_cf_out/OUT_COLS) 
                               & ", Col=" & integer'image(idx_cf_out mod OUT_COLS) & ")" 
                               & " Expected: " & integer'image(to_integer(unsigned(cf_out_benchmark_mem(idx_cf_out))))
							   & " Received: " & integer'image(to_integer(unsigned(cf_m_axis_tdata)))  
                        severity error;

                    -- Increment index
                    idx_cf_out <= idx_cf_out + 1;
                end if;
            end if;
        end if;
	end process;
	-- synthesis translate_on
	
end behav;
