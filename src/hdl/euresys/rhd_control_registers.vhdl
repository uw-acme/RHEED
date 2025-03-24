--------------------------------------------------------------------------------
-- Project: CustomLogic
--------------------------------------------------------------------------------
--  Module: control_registers
--    File: control_registers.vhd
--    Date: 2023-03-07
--     Rev: 0.4
--  Author: PP
--------------------------------------------------------------------------------
-- Reference Design: Control Registers decoder
--   This module shows how to use the CustomLogic Control Interface as a register
--   map decoder.
--------------------------------------------------------------------------------
-- 0.1, 2018-06-04, PP, Initial release
-- 0.2, 2019-06-24, PP, Added multi-device/pipeline support
-- 0.3, 2019-10-24, PP, Added General Purpose I/O Interface
-- 0.4, 2023-03-07, MH, Added CustomLogic output control
--
-- Modified by GJ to change register usage.
--------------------------------------------------------------------------------


library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rhd_fpga_pkg.all;
use     work.rhd_version_pkg.all;


entity rhd_control_registers is
port (
    -- Clock / Reset
    clk                     : in  std_logic;
    srst                    : in  std_logic;

    -- Control Interface
    s_ctrl_addr             : in  std_logic_vector(15 downto 0);
    s_ctrl_data_wr_en       : in  std_logic;
    s_ctrl_data_wr          : in  std_logic_vector(31 downto 0);
    s_ctrl_data_rd          : out std_logic_vector(31 downto 0);

    -- Registers
    leds                    : out std_logic_vector( 7 downto 0);    -- CPU controlled LED drive

    results                 : in  std_logic_vector((C_BITS_PER_CROP_RESULT - 1) downto 0);  -- Output from HLS4ML logic
    results_dv              : in  std_logic;            

    parameters              : out std_logic_vector(((32*C_NUM_CROP_BOX) - 1) downto 0);     -- Input to HLS4ML logic
    parameters_dv           : out std_logic                                                 -- Input to HLS4ML logic
);
end entity rhd_control_registers;

architecture rtl of rhd_control_registers is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------
    -- Addresses
    constant ADDR_SCRATCHPAD        : std_logic_vector(15 downto 0) := x"0000";
    constant ADDR_VERSION           : std_logic_vector(15 downto 0) := x"0001";
    constant ADDR_LEDS              : std_logic_vector(15 downto 0) := x"0002";

    
    -- Registers
    signal reg_scratchpad           : std_logic_vector(31 downto 0);
    signal reg_leds                 : std_logic_vector( 7 downto 0);
    

    ----------------------------------------------------------------------------
    -- Debug
    ----------------------------------------------------------------------------
    -- attribute mark_debug : string;
    -- attribute mark_debug of s_ctrl_data_wr_en    : signal is "true";
    -- attribute mark_debug of s_ctrl_addr          : signal is "true";
   
    
begin

    -- TODO Add registers for parameter output and result capture
    parameters      <= (others=>'0');
    parameters_dv   <= '0';


    ---- Write decoding --------------------------------------------------------
    pr_write : process(clk) is
    begin
        if rising_edge(clk) then
            
            if srst = '1' then
                reg_scratchpad          <= (others=>'0');
                reg_leds                <= (others=>'0');
            
            elsif (s_ctrl_data_wr_en = '1') then
            
                case s_ctrl_addr is
                    when ADDR_SCRATCHPAD =>
                        reg_scratchpad  <= s_ctrl_data_wr;
                    when ADDR_LEDS =>
                        reg_leds        <= s_ctrl_data_wr;
                    when others =>
                        null;
                end case;
            end if;

        end if;
    end process;
    
    ---- Read decoding ---------------------------------------------------------
    pr_read : process(clk) is
    begin
        if rising_edge(clk) then
            s_ctrl_data_rd <= (others=>'0');
            
            -- Common addresses
            case s_ctrl_addr is
                when ADDR_SCRATCHPAD    =>
                    s_ctrl_data_rd  <= reg_scratchpad;
                when ADDR_LEDS          =>
                    s_ctrl_data_rd  <= reg_leds;
                when  ADDR_VERSION      =>
                    s_ctrl_data_rd  <= C_RHD_VERSION;
                when others =>
                    null;
            end case;
            
        end if;
    end process;
    
end rtl; 
