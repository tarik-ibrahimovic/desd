library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity moving_average_filter is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer := 5;

		TDATA_WIDTH			: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

        enable_filter   : in std_logic
	);
end moving_average_filter;

architecture Behavioral of moving_average_filter is

    constant FILTER_LEN  : integer := 2 ** FILTER_ORDER_POWER;
    constant SUM_WIDTH   : integer := TDATA_WIDTH + FILTER_ORDER_POWER;

    subtype sample_t is signed(TDATA_WIDTH-1 downto 0);
    type buffer_t is array(0 to FILTER_LEN - 1) of sample_t;

    -- separated buffer for both channels
    signal buffer_left, buffer_right : buffer_t := (others => (others => '0'));

    signal sum_left, sum_right : signed(SUM_WIDTH downto 0) := (others => '0');
    signal idx_left, idx_right : integer range 0 to FILTER_LEN-1 := 0;

    -- Pipeline
    signal avg_q      : sample_t := (others => '0');
    signal valid_q    : std_logic := '0';
    signal tlast_q    : std_logic := '0';

    signal s_ready    : std_logic;

begin

    -- AXI4-Stream handshake
    s_ready <= '1' when (valid_q = '0' or m_axis_tready = '1') else '0';
    s_axis_tready <= s_ready;

    process(aclk)
        variable new_sample : sample_t;
        variable old_sample : sample_t;
        variable temp_sum   : signed(SUM_WIDTH downto 0);
        variable temp_avg   : sample_t;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                buffer_left  <= (others => (others => '0'));
                buffer_right <= (others => (others => '0'));
                sum_left     <= (others => '0');
                sum_right    <= (others => '0');
                idx_left     <= 0;
                idx_right    <= 0;
                avg_q        <= (others => '0');
                valid_q      <= '0';
                tlast_q      <= '0';

            else
                if s_axis_tvalid = '1' and s_ready = '1' then
                    new_sample := signed(s_axis_tdata);
                    tlast_q    <= s_axis_tlast;

                    if s_axis_tlast = '0' then  -- SX
                        old_sample := buffer_left(idx_left);
                        buffer_left(idx_left) <= new_sample;
                        temp_sum := sum_left - resize(old_sample, SUM_WIDTH+1) + resize(new_sample, SUM_WIDTH+1);
                        sum_left <= temp_sum;

                        if enable_filter = '1' then
                            temp_avg := resize(temp_sum(SUM_WIDTH downto FILTER_ORDER_POWER), TDATA_WIDTH);
                            avg_q <= temp_avg;
                        else
                            avg_q <= new_sample;
                        end if;

                        idx_left <= (idx_left + 1) mod FILTER_LEN;

                    else  -- DX
                        old_sample := buffer_right(idx_right);
                        buffer_right(idx_right) <= new_sample;
                        temp_sum := sum_right - resize(old_sample, SUM_WIDTH+1) + resize(new_sample, SUM_WIDTH+1);
                        sum_right <= temp_sum;

                        if enable_filter = '1' then
                            temp_avg := resize(temp_sum(SUM_WIDTH downto FILTER_ORDER_POWER), TDATA_WIDTH);
                            avg_q <= temp_avg;
                        else
                            avg_q <= new_sample;
                        end if;

                        idx_right <= (idx_right + 1) mod FILTER_LEN;
                    end if;

                    valid_q <= '1';

                elsif valid_q = '1' and m_axis_tready = '1' then
                    valid_q <= '0';
                end if;
            end if;
        end if;
    end process;

    -- AXI4-Stream output
    m_axis_tvalid <= valid_q;
    m_axis_tdata  <= std_logic_vector(avg_q);
    m_axis_tlast  <= tlast_q;

end Behavioral;
