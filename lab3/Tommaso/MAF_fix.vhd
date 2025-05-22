library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter is
    generic (
        FILTER_ORDER_POWER : integer := 5;
        TDATA_WIDTH        : positive := 24
    );
    port (
        aclk           : in std_logic;
        aresetn        : in std_logic;

        s_axis_tvalid  : in std_logic;
        s_axis_tdata   : in std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tlast   : in std_logic;
        s_axis_tready  : out std_logic;

        m_axis_tvalid  : out std_logic;
        m_axis_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
        m_axis_tlast   : out std_logic;
        m_axis_tready  : in std_logic;

        enable_filter  : in std_logic
    );
end moving_average_filter;

architecture Behavioral of moving_average_filter is

    constant FILTER_LEN  : integer := 2 ** FILTER_ORDER_POWER;
    constant SUM_WIDTH   : integer := TDATA_WIDTH + FILTER_ORDER_POWER;

    subtype sample_t is signed(TDATA_WIDTH-1 downto 0);
    type shift_array_t is array(0 to 31) of sample_t;

    signal shift_reg      : shift_array_t := (others => (others => '0'));
    signal sum_stage1     : signed(SUM_WIDTH downto 0) := (others => '0');
    signal sum_stage2     : signed(SUM_WIDTH downto 0) := (others => '0');
    signal avg_stage1     : sample_t := (others => '0');
    signal avg_stage2     : sample_t := (others => '0');
    signal avg_stage3     : sample_t := (others => '0');

    signal valid_stage1   : std_logic := '0';
    signal valid_stage2   : std_logic := '0';
    signal valid_stage3   : std_logic := '0';

    signal tlast_stage1   : std_logic := '0';
    signal tlast_stage2   : std_logic := '0';
    signal tlast_stage3   : std_logic := '0';

    signal s_ready        : std_logic;

    -- synthesis attribute shreg_extract of shift_reg is "yes"
    -- synthesis attribute use_dsp of sum_stage1 is "yes"

begin

    -- Handshake AXI
    s_ready <= '1' when (valid_stage3 = '0' or m_axis_tready = '1') else '0';
    s_axis_tready <= s_ready;

    process(aclk)
        variable new_sample : sample_t;
        variable old_sample : sample_t;
        variable temp_sum   : signed(SUM_WIDTH downto 0);
        variable temp_avg   : sample_t;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                shift_reg      <= (others => (others => '0'));
                sum_stage1     <= (others => '0');
                sum_stage2     <= (others => '0');
                avg_stage1     <= (others => '0');
                avg_stage2     <= (others => '0');
                avg_stage3     <= (others => '0');
                valid_stage1   <= '0';
                valid_stage2   <= '0';
                valid_stage3   <= '0';
                tlast_stage1   <= '0';
                tlast_stage2   <= '0';
                tlast_stage3   <= '0';

            else
                -- Stage 1: acquisizione e somma
                if s_axis_tvalid = '1' and s_ready = '1' then
                    new_sample := signed(s_axis_tdata);
                    old_sample := shift_reg(FILTER_LEN - 1);

                    for i in FILTER_LEN-1 downto 1 loop
                        shift_reg(i) <= shift_reg(i-1);
                    end loop;
                    shift_reg(0) <= new_sample;

                    temp_sum := sum_stage2 - resize(old_sample, sum_stage2'length) + resize(new_sample, sum_stage2'length);
                    sum_stage1 <= temp_sum;

                    if enable_filter = '1' then
                        temp_avg := resize(temp_sum(SUM_WIDTH downto FILTER_ORDER_POWER), TDATA_WIDTH);
                        avg_stage1 <= temp_avg;
                    else
                        avg_stage1 <= new_sample;
                    end if;

                    valid_stage1 <= '1';
                    tlast_stage1 <= s_axis_tlast;
                else
                    valid_stage1 <= '0';
                end if;

                -- Stage 2: somma pipelined
                if valid_stage1 = '1' then
                    sum_stage2   <= sum_stage1;
                    avg_stage2   <= avg_stage1;
                    valid_stage2 <= '1';
                    tlast_stage2 <= tlast_stage1;
                elsif m_axis_tready = '1' then
                    valid_stage2 <= '0';
                end if;

                -- Stage 3: uscita
                if valid_stage2 = '1' then
                    avg_stage3   <= avg_stage2;
                    valid_stage3 <= '1';
                    tlast_stage3 <= tlast_stage2;
                elsif m_axis_tready = '1' then
                    valid_stage3 <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Output AXI
    m_axis_tvalid <= valid_stage3;
    m_axis_tdata  <= std_logic_vector(avg_stage3);
    m_axis_tlast  <= tlast_stage3;

end Behavioral;
