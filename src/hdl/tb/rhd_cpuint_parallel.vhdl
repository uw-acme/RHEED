-------------------------------------------------------------------------------
-- File       : rhd_cpuint_serial.vhd
-- Bidir interface between serial port and CPU bus.
-- Contains UART
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     std.textio.all; 

use     work.std_iopak.all;

use     work.rhd_serial_pkg.all;
use     work.rhd_fpga_pkg.all;
use     work.rhd_version_pkg.all;

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

architecture parallel of rhd_cpuint is

signal tied_low         : std_logic := '0';
signal tied_high        : std_logic := '1';
signal sim_done         : boolean := false;
signal rdata            : std_logic_vector(31 downto 0);
signal cpuint_rd        : std_logic;
signal cpuint_wr        : std_logic;
signal cpuint_addr      : std_logic_vector(15 downto 0);
signal cpuint_wdata     : std_logic_vector(31 downto 0);
signal cpuint_rdata_dv  : std_logic;
signal cpuint_rdata     : std_logic_vector(31 downto 0);

-------------------------------------------------------------
-- CPU write procedure. Address in hex. Data in hex
-------------------------------------------------------------
procedure cpu_write( 
    signal clk          : in  std_logic;
    constant a          : in  std_logic_vector(15 downto 0);
    constant d          : in  std_logic_vector(31 downto 0);
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0)
) is
begin
    wait until clk'event and clk='0';
    cpu_sel     <= '1';
    cpu_wr      <= '1';
    cpu_addr    <= a;
    cpu_wdata   <= std_logic_vector(d);
    wait until clk'event and clk='0';
    cpu_sel     <= '0';
    cpu_wr      <= '0';
    cpu_addr    <= (others=>'0');
    cpu_wdata   <= (others=>'0');
    wait until clk'event and clk='0';
end;

-------------------------------------------------------------
-- CPU write procedure. Address in decimal. Data in hex
-------------------------------------------------------------
procedure cpu_write( 
    signal clk          : in  std_logic;
    constant a          : in  integer;
    constant d          : in  std_logic_vector(31 downto 0);
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0)
) is
begin
    wait until clk'event and clk='0';
    cpu_sel     <= '1';
    cpu_wr      <= '1';
    cpu_addr    <= std_logic_vector(to_unsigned(a, 16));
    cpu_wdata   <= std_logic_vector(d);
    wait until clk'event and clk='0';
    cpu_sel     <= '0';
    cpu_wr      <= '0';
    cpu_addr    <= (others=>'0');
    cpu_wdata   <= (others=>'0');
    wait until clk'event and clk='0';
end;


-------------------------------------------------------------
-- CPU write procedure. Address and Data in decimal
-------------------------------------------------------------
procedure cpu_write( 
    signal clk          : in  std_logic;
    constant a          : in  integer;
    constant d          : in  integer;
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0)
) is
begin
    cpu_write(clk, a , std_logic_vector(to_unsigned(d,32)), cpu_sel, cpu_wr, cpu_addr, cpu_wdata);
end;


-------------------------------------------------------------
-- CPU read procedure with test of returned data.
-- Address integer. Expected Data in hex
-------------------------------------------------------------
procedure cpu_test( 
    signal clk          : in  std_logic;
    constant a          : in  integer;
    constant exp_d      : in  std_logic_vector(31 downto 0);
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0);
    signal cpu_rdata    : in  std_logic_vector(31 downto 0);
    signal cpu_rdata_dv : in  std_logic
) is
variable v_bdone    : boolean := false; 
variable str_out    : string(1 to 256);
begin
    wait until clk'event and clk='0';
    cpu_sel     <= '1';
    cpu_wr      <= '0';
    cpu_addr    <= std_logic_vector(to_unsigned(a, 16));
    cpu_wdata   <= (others=>'0');
    while (v_bdone = false) loop
        wait until clk'event and clk='0';
        if (cpu_rdata_dv = '1') then
            if (cpu_rdata /= exp_d) then
                fprint(str_out, "Test  exp: 0x%s  actual: 0x%s\n", to_string(to_bitvector(exp_d),"%08X"), to_string(to_bitvector(cpu_rdata),"%08X"));
                report str_out severity error;
            end if;
            v_bdone := true; 
            cpu_sel     <= '0';
            cpu_addr    <= (others=>'0');
        end if;
    end loop;
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';

end;

-------------------------------------------------------------
-- CPU read procedure. Address hex. No Expected Data
-------------------------------------------------------------
procedure cpu_read( 
    signal clk          : in  std_logic;
    constant a          : in  std_logic_vector(15 downto 0);
	
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0);
    signal cpu_rdata    : in  std_logic_vector(31 downto 0);
    signal cpu_rdata_dv : in  std_logic;
	signal rdata        : out std_logic_vector(31 downto 0)
) is
variable v_bdone    : boolean := false; 
variable str_out    : string(1 to 256);
begin
    wait until clk'event and clk='0';
    cpu_sel     <= '1';
    cpu_wr      <= '0';
    cpu_addr    <= a;
    cpu_wdata   <= (others=>'0');
    while (v_bdone = false) loop
        wait until clk'event and clk='0';
        if (cpu_rdata_dv = '1') then 
			rdata	<= cpu_rdata;
            v_bdone := true; 
            cpu_sel     <= '0';
            cpu_addr    <= (others=>'0');
        end if;
    end loop;
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';

end;


-------------------------------------------------------------
-- CPU read test procedure. Address integer. Expected Data integer
-------------------------------------------------------------
procedure cpu_test( 
    signal clk          : in  std_logic;
    constant a          : in  integer;
    constant exp_d      : in  integer;
    signal cpu_sel      : out std_logic;
    signal cpu_wr       : out std_logic;
    signal cpu_addr     : out std_logic_vector(15 downto 0);
    signal cpu_wdata    : out std_logic_vector(31 downto 0);
    signal cpu_rdata    : in  std_logic_vector(31 downto 0);
    signal cpu_rdata_dv : in  std_logic
) is
begin
    cpu_test(clk, a , std_logic_vector(to_unsigned(exp_d,32)), cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
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


    debug    	<= (others=>'0');
	txd			<= tied_high;

   -------------------------------------------------------------
    -- Drive CPU bus 
    -------------------------------------------------------------
    pr_main : process	
	variable v_naddr : integer range 0 to 63;
	variable v_ndata : integer;
	variable v_box_x : integer;
	variable v_box_y : integer;
	variable v_data  : std_logic_vector(31 downto 0);
	variable v_bdone : boolean := false;
    begin
        
        cpu_sel     <= '0';
        cpu_wr      <= '0';
		cpu_wdata   <= (others=>'0');
		cpu_addr  	<= (others=>'0');

        cpu_print_msg("Simulation start");
        clk_delay(5);

        wait for 100 ns;    -- Time for PLL to lock
		clk_delay(2);
		-- Check status reg
        cpu_test( clk, ADR_REG_STATUS , X"00000000"   , cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);

        -- Write parameters
		v_naddr := ADR_REG_PARAM0;
		v_box_x 	:= 1;
		v_box_y 	:= 10;
		
		-- Set each crop box parameter register
        for N in 0 to C_NUM_CROP_BOX-1 loop
			v_naddr := ADR_REG_PARAM0 + N;
			v_data  := std_logic_vector(to_unsigned(v_box_x,16) & to_unsigned(v_box_y,16));
            cpu_write( clk, v_naddr, v_data, cpu_sel, cpu_wr, cpu_addr, cpu_wdata);
			v_box_x 	:= v_box_x + 16;
			v_box_y 	:= v_box_y + 256;
        end loop;
		
		-- Set LEDs and try to overwrite version
        cpu_write( clk, ADR_REG_LEDS,    X"55555555", cpu_sel, cpu_wr, cpu_addr, cpu_wdata);
        cpu_write( clk, ADR_REG_VERSION, X"00000000", cpu_sel, cpu_wr, cpu_addr, cpu_wdata);
        clk_delay(20);
		
		-- Read back crop box parameters and check them
		v_box_x 	:= 1;
		v_box_y 	:= 10;
        for N in 0 to C_NUM_CROP_BOX-1 loop
			v_naddr := ADR_REG_PARAM0 + N;
			v_data  := std_logic_vector(to_unsigned(v_box_x,16) & to_unsigned(v_box_y,16));
            cpu_test( clk, v_naddr, v_data, cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
			v_box_x 	:= v_box_x + 16;
			v_box_y 	:= v_box_y + 256;
        end loop;
		
        cpu_print_msg("Parameter reg test done");  
		
		-- Read LED and version registers
        cpu_test( clk, ADR_REG_LEDS   , X"00000055"   , cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
        cpu_test( clk, ADR_REG_VERSION, C_RHD_VERSION , cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
        cpu_test( clk, ADR_REG_NONE   , X"DEADBEEF"   , cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
        cpu_test( clk, ADR_REG_STATUS , X"00000001"   , cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
		cpu_print_msg("LEDs and version reg test done");

		-- Wait until bit-1 (results done) of status reg is set
		v_bdone := false;
		while (v_bdone = false) loop
			cpu_read( clk, std_logic_vector(to_unsigned(ADR_REG_STATUS,16)), cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv, rdata);
			if (rdata(1) = '1') then
			    v_bdone := true;
			end if;
		end loop;
		
		
		-- Read result registers.   
		-- Even result regs 0,2,4 etc contain the original crop box parameters
		-- Odd registers contain the result number 0 to N in the lower 8 bits.
		v_box_x 	:= 1;
		v_box_y 	:= 10;
        for N in 0 to C_NUM_RO_REGS32-1 loop
		
			v_naddr := ADR_REG_RESULT0 + N;
			
			if (to_unsigned(N,8)(0) = '0') then  -- Even
				v_data  := std_logic_vector(to_unsigned(v_box_x,16) & to_unsigned(v_box_y,16));
				cpu_test( clk, v_naddr, v_data, cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
				v_box_x 	:= v_box_x + 16;
				v_box_y 	:= v_box_y + 256;
			else
				v_data  := std_logic_vector(to_unsigned((N/2),32));
				cpu_test( clk, v_naddr, v_data, cpu_sel, cpu_wr, cpu_addr, cpu_wdata, cpu_rdata, cpu_rdata_dv);
			end if;
			
        end loop;
        cpu_print_msg("Result reg test done");

        clk_delay(20);
		

        cpu_print_msg("Simulation done");
        clk_delay(5);
		
        sim_done    <= true;
        wait;

    end process;
            
end parallel;

