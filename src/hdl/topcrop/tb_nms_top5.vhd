library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_nms_top5 is
end entity;

architecture sim of tb_nms_top5 is

    constant NFRAMES : integer := 9;
    constant NPIX    : integer := 1600;

    signal clk    : std_logic := '0';
    signal rst_n  : std_logic := '0';
    signal tvalid : std_logic := '0';
    signal tdata  : std_logic_vector(15 downto 0) := (others => '0');
    signal tlast  : std_logic := '0';
    signal done   : std_logic;

    signal tv0, tv1, tv2, tv3, tv4 : std_logic_vector(15 downto 0);
    signal tx0, tx1, tx2, tx3, tx4 : std_logic_vector(5 downto 0);
    signal ty0, ty1, ty2, ty3, ty4 : std_logic_vector(5 downto 0);

    signal sim_end : boolean := false;
    signal errors  : integer := 0;

begin

    clk <= not clk after 2.5 ns when not sim_end else '0';   -- 200 MHz

    dut : entity work.nms_top5
        port map (
            clk => clk, rst_n => rst_n,
            tvalid => tvalid, tdata => tdata, tlast => tlast, done => done,
            top_val_0 => tv0, top_val_1 => tv1, top_val_2 => tv2,
            top_val_3 => tv3, top_val_4 => tv4,
            top_x_0 => tx0, top_x_1 => tx1, top_x_2 => tx2,
            top_x_3 => tx3, top_x_4 => tx4,
            top_y_0 => ty0, top_y_1 => ty1, top_y_2 => ty2,
            top_y_3 => ty3, top_y_4 => ty4);

    stim : process
        file     fs, fe   : text;
        variable ls, le   : line;
        variable pix      : integer;
        variable ev, ex, ey : integer_vector(0 to 4);
        variable ol       : line;
        variable nerr     : integer := 0;

        procedure chk(name : string; frame, slot, got, exp : integer) is
            variable l : line;
        begin
            if got /= exp then
                write(l, string'("MISMATCH frame "));
                write(l, frame); write(l, string'(" slot ")); write(l, slot);
                write(l, string'(" ")); write(l, name);
                write(l, string'(" got ")); write(l, got);
                write(l, string'(" exp ")); write(l, exp);
                writeline(output, l);
                nerr := nerr + 1;
            end if;
        end procedure;
    begin
        file_open(fs, "stim.txt", read_mode);
        file_open(fe, "expect.txt", read_mode);

        rst_n <= '0';
        wait for 25 ns;
        wait until rising_edge(clk);
        rst_n <= '1';
        wait until rising_edge(clk);

        for f in 0 to NFRAMES-1 loop
            -- drive one frame; insert tvalid gaps on odd frames to prove the
            -- window only advances on valid beats
            for i in 0 to NPIX-1 loop
                readline(fs, ls);
                read(ls, pix);

                if (f mod 2 = 1) and (i mod 37 = 5) then
                    tvalid <= '0';
                    tdata  <= (others => 'X');
                    tlast  <= 'X';
                    wait until rising_edge(clk);
                end if;

                tvalid <= '1';
                tdata  <= std_logic_vector(to_unsigned(pix, 16));
                if i = NPIX-1 then tlast <= '1'; else tlast <= '0'; end if;
                wait until rising_edge(clk);
            end loop;
            tvalid <= '0';
            tlast  <= '0';
            tdata  <= (others => '0');

            -- wait for pass 2
            for w in 0 to 5000 loop
                exit when done = '1';
                wait until rising_edge(clk);
            end loop;
            assert done = '1'
                report "TIMEOUT waiting for done on frame " & integer'image(f)
                severity failure;

            readline(fe, le);
            for s in 0 to 4 loop
                read(le, ev(s)); read(le, ex(s)); read(le, ey(s));
            end loop;

            chk("val", f, 0, to_integer(unsigned(tv0)), ev(0));
            chk("val", f, 1, to_integer(unsigned(tv1)), ev(1));
            chk("val", f, 2, to_integer(unsigned(tv2)), ev(2));
            chk("val", f, 3, to_integer(unsigned(tv3)), ev(3));
            chk("val", f, 4, to_integer(unsigned(tv4)), ev(4));
            chk("x",   f, 0, to_integer(unsigned(tx0)), ex(0));
            chk("x",   f, 1, to_integer(unsigned(tx1)), ex(1));
            chk("x",   f, 2, to_integer(unsigned(tx2)), ex(2));
            chk("x",   f, 3, to_integer(unsigned(tx3)), ex(3));
            chk("x",   f, 4, to_integer(unsigned(tx4)), ex(4));
            chk("y",   f, 0, to_integer(unsigned(ty0)), ey(0));
            chk("y",   f, 1, to_integer(unsigned(ty1)), ey(1));
            chk("y",   f, 2, to_integer(unsigned(ty2)), ey(2));
            chk("y",   f, 3, to_integer(unsigned(ty3)), ey(3));
            chk("y",   f, 4, to_integer(unsigned(ty4)), ey(4));

            write(ol, string'("frame ")); write(ol, f);
            write(ol, string'(" checked, running errors = ")); write(ol, nerr);
            writeline(output, ol);

            -- inter-frame gap; frames 0..3 flow straight into the next frame
            -- without a reset, exercising the auto re-arm path
            wait for 100 ns;
        end loop;

        errors <= nerr;
        wait until rising_edge(clk);

        if nerr = 0 then
            report "==== ALL FRAMES PASS ====" severity note;
        else
            report "==== " & integer'image(nerr) & " MISMATCHES ====" severity error;
        end if;
        sim_end <= true;
        wait;
    end process;

end architecture;
