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
        din             : in  std_logic_vector( 7 downto 0);
        din_dv          : in  std_logic;
		din_tready      : out std_logic;
		
        dout            : out std_logic_vector( 7 downto 0);
        dout_dv         : out std_logic
);
end rhd_hls4ml;

------------------------------------------------------------------------
-- Dummy architecture of HLS4ML output
-- Takes 5 2x16b crop box co-ordinates
-- Outputs 5 sets of 5 8-bit results
------------------------------------------------------------------------
architecture dummy of rhd_hls4ml is
constant C_INVERVAL_RESULT  : integer := 32;
constant C_MAX_RESULTS      : integer :=  C_NUM_CROP_BOX-1;
signal cnt_interval_result	: unsigned(7 downto 0);
signal ncnt_result			: integer range 0 to C_NUM_CROP_BOX;

begin

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


