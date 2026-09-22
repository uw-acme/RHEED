--==============================================================================
-- nms_top5 -- two-pass top-5 peak picker with 8-pixel spatial exclusion
--------------------------------------------------------------------------------
-- Port-compatible replacement for the single-pass SystemVerilog nms_top5.
--
-- PASS 1  (streaming, 1 pixel/clock, no feedback):
--   A 5x5 sliding window built from four 35-deep line buffers flags each strict
--   local maximum.  Ties are broken by raster order (strict '>' against
--   neighbours that precede the centre, '>=' against those that follow), so a
--   plateau yields exactly one winner.  Survivors are written to a candidate
--   RAM.  Because no two winners can occupy the same 5x5 window, they are at
--   least 3 px apart in Chebyshev distance, bounding the count at
--   ceil(40/3)^2 = 196 -- MAX_CAND = 256 can never overflow, so no backpressure
--   is required.  Out-of-grid neighbours are masked, so border peaks survive.
--
-- PASS 2  (during the inter-frame gap, ~1000 clocks):
--   Five sweeps of the candidate RAM.  Sweep k accepts the highest-valued
--   candidate that is not within 8 px (dx^2+dy^2 < 64) of any peak accepted in
--   sweeps 0..k-1.  The accepted set is constant within a sweep, so every
--   distance test is combinational against fixed registers.  Output is
--   inherently sorted descending -- no sort network exists anywhere.
--
-- No multipliers: dx^2+dy^2 < 64 is evaluated as an early-out on dx>=8 or
-- dy>=8 followed by two 3-bit square-table lookups and a 7-bit add.
--
-- TIMING / CONTRACT DIFFERENCES vs the SystemVerilog original:
--   * 'done' now asserts after pass 2 completes (~1000 clocks after tlast),
--     not one clock after tlast.  Outputs are final when done rises.
--   * 'done' holds until reset OR until the first tvalid of the next frame,
--     which clears it and starts a new capture automatically.
--   * Results are exact greedy NMS over all local maxima; the original was
--     order-dependent and could permanently lose a peak.
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nms_top5 is
    generic (
        GRID_W   : integer := 40;
        GRID_H   : integer := 40;
        MAX_CAND : integer := 256    -- must be >= ceil(GRID_W/3)*ceil(GRID_H/3)
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;   -- active-low synchronous reset
        tvalid    : in  std_logic;
        tdata     : in  std_logic_vector(15 downto 0);
        tlast     : in  std_logic;
        done      : out std_logic;
        top_val_0 : out std_logic_vector(15 downto 0);
        top_val_1 : out std_logic_vector(15 downto 0);
        top_val_2 : out std_logic_vector(15 downto 0);
        top_val_3 : out std_logic_vector(15 downto 0);
        top_val_4 : out std_logic_vector(15 downto 0);
        top_x_0   : out std_logic_vector(5 downto 0);
        top_x_1   : out std_logic_vector(5 downto 0);
        top_x_2   : out std_logic_vector(5 downto 0);
        top_x_3   : out std_logic_vector(5 downto 0);
        top_x_4   : out std_logic_vector(5 downto 0);
        top_y_0   : out std_logic_vector(5 downto 0);
        top_y_1   : out std_logic_vector(5 downto 0);
        top_y_2   : out std_logic_vector(5 downto 0);
        top_y_3   : out std_logic_vector(5 downto 0);
        top_y_4   : out std_logic_vector(5 downto 0)
    );
end entity nms_top5;


architecture rtl of nms_top5 is

    ----------------------------------------------------------------------------
    -- Geometry constants
    ----------------------------------------------------------------------------
    constant TOP_N    : integer := 5;
    constant WSIZE      : integer := 5;                  -- 5x5 detection window
    constant HALF     : integer := WSIZE/2;              -- 2
    constant LB_DEPTH : integer := GRID_W - WSIZE;       -- 35
    -- Latency from newest pixel to window centre: HALF rows + HALF columns.
    constant WARMUP   : integer := HALF*GRID_W + HALF; -- 82
    -- Shifts of zeros needed after tlast to push the last centre through,
    -- plus slack for the two detection pipeline stages.
    constant FLUSH_N  : integer := WARMUP + 6;         -- 88

    ----------------------------------------------------------------------------
    -- Squared-distance table: exclusion radius 8 -> only offsets 0..7 matter
    ----------------------------------------------------------------------------
    type sq_tbl_t is array (0 to 7) of unsigned(6 downto 0);
    constant SQ_TBL : sq_tbl_t := (
        to_unsigned( 0,7), to_unsigned( 1,7), to_unsigned( 4,7), to_unsigned( 9,7),
        to_unsigned(16,7), to_unsigned(25,7), to_unsigned(36,7), to_unsigned(49,7));
    constant MIN_DIST_SQ : unsigned(6 downto 0) := to_unsigned(64,7);

    -- True when (xa,ya) and (xb,yb) are closer than 8.0 px Euclidean.
    function is_near (xa, ya, xb, yb : unsigned(5 downto 0)) return boolean is
        variable dx, dy : unsigned(5 downto 0);
    begin
        if xa >= xb then dx := xa - xb; else dx := xb - xa; end if;
        if ya >= yb then dy := ya - yb; else dy := yb - ya; end if;
        if dx(5 downto 3) /= "000" or dy(5 downto 3) /= "000" then
            return false;                              -- early out, no adder
        end if;
        return (SQ_TBL(to_integer(dx(2 downto 0))) +
                SQ_TBL(to_integer(dy(2 downto 0)))) < MIN_DIST_SQ;
    end function is_near;

    ----------------------------------------------------------------------------
    -- Pass 1: sliding window
    ----------------------------------------------------------------------------
    type row_arr is array (0 to WSIZE-1)      of unsigned(15 downto 0);
    type win_arr is array (0 to WSIZE-1)      of row_arr;
    type lb_arr  is array (0 to LB_DEPTH-1) of unsigned(15 downto 0);
    type lb_set  is array (0 to WSIZE-2)      of lb_arr;

    -- win(r)(c): row 4 is newest.  Maps to grid (cx + HALF - c, cy + r - HALF).
    -- Initial values match Xilinx FF/SRL power-on state and keep simulation
    -- free of 'U' during the 82-cycle warm-up (results are gated by d1_valid).
    signal win : win_arr := (others => (others => (others => '0')));
    signal lb  : lb_set  := (others => (others => (others => '0')));

    signal shift_en : std_logic;
    signal shifted  : std_logic;                       -- window updated last clk
    signal pix_in   : unsigned(15 downto 0);

    signal warm   : integer range 0 to WARMUP := 0;
    signal win_ok : std_logic;                         -- centre is a real pixel
    signal cx, cy : unsigned(5 downto 0);              -- centre coordinates

    -- Detection stage 1 registers
    type rowok_arr is array (0 to WSIZE-1) of std_logic;
    signal d1_rowok : rowok_arr;
    signal d1_valid : std_logic;
    signal d1_val   : unsigned(15 downto 0);
    signal d1_x     : unsigned(5 downto 0);
    signal d1_y     : unsigned(5 downto 0);
    signal d1_ismax   : std_logic;                     -- combinational AND
    signal d1_nonzero : std_logic;

    ----------------------------------------------------------------------------
    -- Candidate RAM: {val[15:0], x[5:0], y[5:0]}
    ----------------------------------------------------------------------------
    type cand_ram_t is array (0 to MAX_CAND-1) of std_logic_vector(27 downto 0);
    signal cand_ram  : cand_ram_t;
    signal cand_cnt  : integer range 0 to MAX_CAND;
    signal wr_en     : std_logic;
    signal rd_addr   : integer range 0 to MAX_CAND-1;
    signal ram_q     : std_logic_vector(27 downto 0);

    ----------------------------------------------------------------------------
    -- Control FSM
    ----------------------------------------------------------------------------
    type state_t is (S_IDLE, S_STREAM, S_FLUSH,
                     S_SW_INIT, S_SW_SCAN, S_SW_DRAIN, S_SW_ACC,
                     S_FINISH, S_DONE);
    signal state     : state_t;
    signal flush_cnt : integer range 0 to FLUSH_N;
    signal drain_cnt : integer range 0 to 7;

    ----------------------------------------------------------------------------
    -- Pass 2: sweep pipeline and accepted-peak registers
    ----------------------------------------------------------------------------
    signal scan_addr : integer range 0 to MAX_CAND-1;
    signal p1_valid  : std_logic;
    signal p2_valid  : std_logic;
    signal p2_elig   : std_logic;
    signal p2_val    : unsigned(15 downto 0);
    signal p2_x      : unsigned(5 downto 0);
    signal p2_y      : unsigned(5 downto 0);

    signal best_val  : unsigned(15 downto 0);
    signal best_x    : unsigned(5 downto 0);
    signal best_y    : unsigned(5 downto 0);

    type val_arr is array (0 to TOP_N-1) of unsigned(15 downto 0);
    type crd_arr is array (0 to TOP_N-1) of unsigned(5 downto 0);
    signal acc_val  : val_arr;
    signal acc_x    : crd_arr;
    signal acc_y    : crd_arr;
    signal acc_used : std_logic_vector(TOP_N-1 downto 0);
    signal k_idx    : integer range 0 to TOP_N-1;

    signal o_val : val_arr;
    signal o_x   : crd_arr;
    signal o_y   : crd_arr;

begin

    ----------------------------------------------------------------------------
    -- Stream control: shift enable and input mux
    ----------------------------------------------------------------------------
    shift_en <= '1' when state = S_FLUSH else
                tvalid when (state = S_IDLE or state = S_STREAM or state = S_DONE)
                else '0';

    pix_in <= (others => '0') when state = S_FLUSH else unsigned(tdata);

    ----------------------------------------------------------------------------
    -- Line buffers and 5x5 window.  No reset: warm-up plus border masking makes
    -- stale content harmless, which lets Vivado map the buffers to SRL32E.
    ----------------------------------------------------------------------------
    win_proc : process (clk)
    begin
        if rising_edge(clk) then
            if shift_en = '1' then
                -- newest row
                win(WSIZE-1)(0) <= pix_in;
                for c in 1 to WSIZE-1 loop
                    win(WSIZE-1)(c) <= win(WSIZE-1)(c-1);
                end loop;
                -- older rows fed through the line buffers
                for r in WSIZE-2 downto 0 loop
                    win(r)(0) <= lb(r)(LB_DEPTH-1);
                    for c in 1 to WSIZE-1 loop
                        win(r)(c) <= win(r)(c-1);
                    end loop;
                    lb(r)(0) <= win(r+1)(WSIZE-1);
                    for i in 1 to LB_DEPTH-1 loop
                        lb(r)(i) <= lb(r)(i-1);
                    end loop;
                end loop;
            end if;
        end if;
    end process win_proc;

    ----------------------------------------------------------------------------
    -- Detection stage 1: 25 masked comparisons, AND-reduced per row.
    -- Raster tie-break: '>' vs neighbours that precede the centre, '>=' vs
    -- those that follow, so exactly one member of a plateau survives.
    ----------------------------------------------------------------------------
    det_proc : process (clk)
        variable ctr    : unsigned(15 downto 0);
        variable xi, yi : integer;
        variable ok     : std_logic;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                d1_valid <= '0';
            else
                d1_valid <= shifted and win_ok;
            end if;

            ctr    := win(HALF)(HALF);
            d1_val <= ctr;
            d1_x   <= cx;
            d1_y   <= cy;

            for r in 0 to WSIZE-1 loop
                ok := '1';
                yi := to_integer(cy) + r - HALF;
                for c in 0 to WSIZE-1 loop
                    xi := to_integer(cx) + HALF - c;
                    if (r = HALF and c = HALF) then
                        null;                                   -- the centre
                    elsif (xi < 0 or xi > GRID_W-1 or
                           yi < 0 or yi > GRID_H-1) then
                        null;                                   -- outside grid
                    elsif (r < HALF) or (r = HALF and c > HALF) then
                        if not (ctr > win(r)(c)) then ok := '0'; end if;
                    else
                        if not (ctr >= win(r)(c)) then ok := '0'; end if;
                    end if;
                end loop;
                d1_rowok(r) <= ok;
            end loop;
        end if;
    end process det_proc;

    -- Stage 2 combinational reduction -> candidate RAM write strobe
    d1_nonzero <= '0' when d1_val = 0 else '1';

    d1_ismax <= d1_valid and d1_nonzero and
                d1_rowok(0) and d1_rowok(1) and d1_rowok(2) and
                d1_rowok(3) and d1_rowok(4);

    wr_en <= '1' when (d1_ismax = '1' and cand_cnt < MAX_CAND) else '0';

    ----------------------------------------------------------------------------
    -- Candidate RAM (simple dual port, registered read)
    ----------------------------------------------------------------------------
    ram_proc : process (clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                cand_ram(cand_cnt) <=
                    std_logic_vector(d1_val) &
                    std_logic_vector(d1_x)   &
                    std_logic_vector(d1_y);
            end if;
            ram_q <= cand_ram(rd_addr);
        end if;
    end process ram_proc;

    rd_addr <= scan_addr;

    ----------------------------------------------------------------------------
    -- Main control: frame sequencing, sweep pipeline, output registers
    ----------------------------------------------------------------------------
    ctrl_proc : process (clk)
        variable elig    : std_logic;
        variable cand_xv : unsigned(5 downto 0);
        variable cand_yv : unsigned(5 downto 0);
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state     <= S_IDLE;
                shifted   <= '0';
                warm      <= 0;
                win_ok    <= '0';
                cx        <= (others => '0');
                cy        <= (others => '0');
                cand_cnt  <= 0;
                flush_cnt <= 0;
                drain_cnt <= 0;
                scan_addr <= 0;
                p1_valid  <= '0';
                p2_valid  <= '0';
                k_idx     <= 0;
                acc_used  <= (others => '0');
                best_val  <= (others => '0');
                done      <= '0';
                for j in 0 to TOP_N-1 loop
                    acc_val(j) <= (others => '0');
                    acc_x(j)   <= (others => '0');
                    acc_y(j)   <= (others => '0');
                    o_val(j)   <= (others => '0');
                    o_x(j)     <= (others => '0');
                    o_y(j)     <= (others => '0');
                end loop;
            else
                shifted  <= shift_en;
                p1_valid <= '0';
                p2_valid <= '0';

                ------------------------------------------------------------------
                -- Warm-up counter and centre coordinates, advanced by each shift
                ------------------------------------------------------------------
                if shift_en = '1' then
                    if warm < WARMUP then
                        warm <= warm + 1;
                    else
                        if win_ok = '0' then
                            win_ok <= '1';                      -- centre = (0,0)
                        elsif cx = GRID_W-1 and cy = GRID_H-1 then
                            win_ok <= '0';                      -- frame consumed
                        elsif cx = GRID_W-1 then
                            cx <= (others => '0');
                            cy <= cy + 1;
                        else
                            cx <= cx + 1;
                        end if;
                    end if;
                end if;

                if wr_en = '1' then
                    cand_cnt <= cand_cnt + 1;
                end if;

                ------------------------------------------------------------------
                -- Sweep pipeline (runs on valid flags, independent of state)
                ------------------------------------------------------------------
                cand_xv := unsigned(ram_q(11 downto 6));
                cand_yv := unsigned(ram_q(5 downto 0));
                elig := '1';
                for j in 0 to TOP_N-2 loop
                    if acc_used(j) = '1' and
                       is_near(cand_xv, cand_yv, acc_x(j), acc_y(j)) then
                        elig := '0';
                    end if;
                end loop;
                p2_valid <= p1_valid;
                p2_elig  <= elig;
                p2_val   <= unsigned(ram_q(27 downto 12));
                p2_x     <= cand_xv;
                p2_y     <= cand_yv;

                if p2_valid = '1' and p2_elig = '1' and p2_val > best_val then
                    best_val <= p2_val;
                    best_x   <= p2_x;
                    best_y   <= p2_y;
                end if;

                ------------------------------------------------------------------
                -- Frame / sweep FSM
                ------------------------------------------------------------------
                case state is

                    when S_IDLE =>
                        if tvalid = '1' then
                            if tlast = '1' then
                                state <= S_FLUSH; flush_cnt <= 0;
                            else
                                state <= S_STREAM;
                            end if;
                        end if;

                    when S_STREAM =>
                        if tvalid = '1' and tlast = '1' then
                            state <= S_FLUSH; flush_cnt <= 0;
                        end if;

                    when S_FLUSH =>
                        if flush_cnt = FLUSH_N-1 then
                            state    <= S_SW_INIT;
                            k_idx    <= 0;
                            acc_used <= (others => '0');
                            for j in 0 to TOP_N-1 loop
                                acc_val(j) <= (others => '0');
                                acc_x(j)   <= (others => '0');
                                acc_y(j)   <= (others => '0');
                            end loop;
                        else
                            flush_cnt <= flush_cnt + 1;
                        end if;

                    when S_SW_INIT =>
                        best_val  <= (others => '0');
                        best_x    <= (others => '0');
                        best_y    <= (others => '0');
                        scan_addr <= 0;
                        if cand_cnt = 0 then
                            state <= S_FINISH;
                        else
                            state <= S_SW_SCAN;
                        end if;

                    when S_SW_SCAN =>
                        p1_valid <= '1';
                        if scan_addr = cand_cnt-1 then
                            state     <= S_SW_DRAIN;
                            drain_cnt <= 0;
                        else
                            scan_addr <= scan_addr + 1;
                        end if;

                    when S_SW_DRAIN =>
                        if drain_cnt = 4 then
                            state <= S_SW_ACC;
                        else
                            drain_cnt <= drain_cnt + 1;
                        end if;

                    when S_SW_ACC =>
                        if best_val = 0 then
                            state <= S_FINISH;      -- nothing eligible remains
                        else
                            acc_val(k_idx)  <= best_val;
                            acc_x(k_idx)    <= best_x;
                            acc_y(k_idx)    <= best_y;
                            acc_used(k_idx) <= '1';
                            if k_idx = TOP_N-1 then
                                state <= S_FINISH;
                            else
                                k_idx <= k_idx + 1;
                                state <= S_SW_INIT;
                            end if;
                        end if;

                    when S_FINISH =>
                        -- Greedy selection is monotonically non-increasing, so
                        -- acc_* is already sorted descending.
                        for j in 0 to TOP_N-1 loop
                            o_val(j) <= acc_val(j);
                            o_x(j)   <= acc_x(j);
                            o_y(j)   <= acc_y(j);
                        end loop;
                        done     <= '1';
                        state    <= S_DONE;
                        -- Re-arm pass 1 for the next frame
                        warm     <= 0;
                        win_ok   <= '0';
                        cx       <= (others => '0');
                        cy       <= (others => '0');
                        cand_cnt <= 0;

                    when S_DONE =>
                        if tvalid = '1' then
                            done <= '0';
                            if tlast = '1' then
                                state <= S_FLUSH; flush_cnt <= 0;
                            else
                                state <= S_STREAM;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process ctrl_proc;

    ----------------------------------------------------------------------------
    -- Output assignments
    ----------------------------------------------------------------------------
    top_val_0 <= std_logic_vector(o_val(0));
    top_val_1 <= std_logic_vector(o_val(1));
    top_val_2 <= std_logic_vector(o_val(2));
    top_val_3 <= std_logic_vector(o_val(3));
    top_val_4 <= std_logic_vector(o_val(4));
    top_x_0   <= std_logic_vector(o_x(0));
    top_x_1   <= std_logic_vector(o_x(1));
    top_x_2   <= std_logic_vector(o_x(2));
    top_x_3   <= std_logic_vector(o_x(3));
    top_x_4   <= std_logic_vector(o_x(4));
    top_y_0   <= std_logic_vector(o_y(0));
    top_y_1   <= std_logic_vector(o_y(1));
    top_y_2   <= std_logic_vector(o_y(2));
    top_y_3   <= std_logic_vector(o_y(3));
    top_y_4   <= std_logic_vector(o_y(4));

end architecture rtl;
