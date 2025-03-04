--------------------------------------------------------------------------
--  File         : 
----------------------------------------------------------------------------
--  Description  : 
----------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rhd_fpga_pkg.all;

entity rhd_hls4ml is
port(
        clk             : in  std_logic;
        reset           : in  std_logic;
		
		-- All sets of 32-bit crop box co-ordinates
        parameters      : in  std_logic_vector((32*C_NUM_CROP_BOX)-1 downto 0);
		parameters_dv   : in  std_logic;
		
		-- Set of results from one crop box
    	results         : out std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
    	results_dv      : out std_logic;         										-- Output from HLS4ML logic
		
        debug           : out std_logic_vector( 3 downto 0);
		
		-- Pixel data		
        pixel_din             : in  std_logic_vector( 7 downto 0);
        pixel_din_dv          : in  std_logic;
		pixel_din_tready      : out std_logic;
		
        pixel_dout            : out std_logic_vector( 7 downto 0);
        pixel_dout_dv         : out std_logic;
		pixel_dout_tready     : in  std_logic
);
end rhd_hls4ml;

------------------------------------------------------------------------
-- Dummy architecture of HLS4ML output
-- Takes 5 2x16b crop box co-ordinates
-- Outputs 5 sets of 5 8-bit results
------------------------------------------------------------------------
architecture wrapper of rhd_hls4ml is

begin

    -------------------------------------------------------------
	-- HLS4ML output
    -------------------------------------------------------------
	u_hls4ml_gaussian : entity work.hls4ml_gaussian
	port map (
        p_clock_50              => clk              , -- in    std_logic;          -- Clock input
        p_reset_n               => p_reset_n        , -- in    std_logic;          -- Reset (pushbtn_n[0])

	
	entity myproject dut (
		-- Input pixel data AXI-Stream bus
		conv2d_input_V_data_0_V_TDATA 	=> pixel_din_tdata,
        conv2d_input_V_data_0_V_TVALID	=> pixel_din_tvalid,
        conv2d_input_V_data_0_V_TREADY  => pixel_din_tready,
		
		-- Result outputs 
        layer15_out_V_data_0_V_TDATA 	=> result0_tdata,
        layer15_out_V_data_0_V_TVALID	=> result0_tvalid,
        layer15_out_V_data_0_V_TREADY	=> result0_tready,
		
        layer15_out_V_data_1_V_TDATA 	=> result1_tdata,
        layer15_out_V_data_1_V_TVALID	=> result1_tvalid,
        layer15_out_V_data_1_V_TREADY	=> result1_tready,
		
        layer15_out_V_data_2_V_TDATA 	=> result2_tdata,
        layer15_out_V_data_2_V_TVALID	=> result2_tvalid,
        layer15_out_V_data_2_V_TREADY	=> result2_tready,
		
        layer15_out_V_data_3_V_TDATA 	=> result3_tdata,
        layer15_out_V_data_3_V_TVALID	=> result3_tvalid,
        layer15_out_V_data_3_V_TREADY	=> result3_tready,
		
        layer15_out_V_data_4_V_TDATA 	=> result4_tdata,
        layer15_out_V_data_4_V_TVALID	=> result4_tvalid,
        layer15_out_V_data_4_V_TREADY	=> result4_tready,
		
		-- Clock and Reset
        ap_clk							=> ap_clk,
        ap_rst_n						=> ap_rst_n,
		 
		-- Control signals
        ap_start						=> ap_start,
        ap_done							=> ap_done,
        ap_ready						=> ap_ready,
        ap_idle							=> ap_idle
	);
	
	debug	<= (others=>'0');
	
    -------------------------------------------------------------------------------
    -- Simple process to pass though pixel data and convert the crop box
	-- parameters into a series of result outputs
    -------------------------------------------------------------------------------
    pr_main : process (reset, clk)
    begin
        if (reset = '1') then
        
        	dout            	<= (others=>'0');
        	dout_dv         	<= '0';
			
			cnt_interval_result	<= (others=>'0');
			ncnt_result			<= 0;

        elsif rising_edge(clk) then

        	dout            <= din;
        	dout_dv         <= din_dv;
			
			if (din_dv = '1') and (ncnt_result < C_NUM_CROP_BOX) then
			
				if (cnt_interval_result = C_INVERVAL_RESULT-1) then	-- Output a result
					cnt_interval_result	<= (others=>'0');
					ncnt_result			<= ncnt_result + 1;
					results_dv			<= '1';
					results				<= std_logic_vector(to_unsigned(ncnt_result,8)) & parameters((32*ncnt_result+31) downto (32*ncnt_result));
					
				else	
					cnt_interval_result	<= cnt_interval_result + 1;
					results_dv			<= '0';
					results				<= (others=>'0');
				end if;
			
			else
				results_dv			<= '0';
				results				<= (others=>'0');
			end if;
				
        end if;
		
    end process;


    -------------------------------------------------------------------------------
	-- Generate a 'tready' to upstream data source when parameters_dv = '1'
    -------------------------------------------------------------------------------
    pr_tready : process (reset, clk)
    begin
        if (reset = '1') then
        
        	din_tready      <= '0';

        elsif rising_edge(clk) then

        	din_tready      <= parameters_dv;
				
        end if;
		
    end process;

end dummy;


