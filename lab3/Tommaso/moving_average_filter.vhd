library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter is
    generic (
        FILTER_ORDER_POWER : integer := 5;
        TDATA_WIDTH        : positive := 24
    );
    Port (
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

    signal shift_reg  : shift_array_t := (others => (others => '0'));
    signal sum        : signed(SUM_WIDTH downto 0) := (others => '0');
    signal avg        : sample_t := (others => '0');
    signal data_valid : std_logic := '0';
    signal tlast_reg  : std_logic := '0';
    signal s_ready    : std_logic;

begin

    -- Handshake
    s_ready <= '1' when (m_axis_tready = '1' or data_valid = '0') else '0';
    s_axis_tready <= s_ready;

    process(aclk)
        variable new_sample : sample_t;
        variable old_sample : sample_t;
        variable temp_avg   : sample_t;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                shift_reg  <= (others => (others => '0'));
                sum        <= (others => '0');
                avg        <= (others => '0');
                data_valid <= '0';
                tlast_reg  <= '0';
            else
                if s_axis_tvalid = '1' and s_ready = '1' then
                    new_sample := signed(s_axis_tdata);
                    old_sample := shift_reg(FILTER_LEN - 1);

                    -- Shift register update
                    for i in FILTER_LEN-1 downto 1 loop
                        shift_reg(i) <= shift_reg(i-1);
                    end loop;
                    shift_reg(0) <= new_sample;

                    -- Update sum
                    sum <= sum - resize(old_sample, sum'length) + resize(new_sample, sum'length);

                    -- Compute or bypass
                    if enable_filter = '1' then
                        temp_avg := resize(sum(SUM_WIDTH downto FILTER_ORDER_POWER), TDATA_WIDTH);
                        avg <= temp_avg;
                    else
                        avg <= new_sample;
                    end if;

                    -- Set output valid
                    data_valid <= '1';
                    tlast_reg  <= s_axis_tlast;

                elsif data_valid = '1' and m_axis_tready = '1' then
                    data_valid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Outputs
    m_axis_tvalid <= data_valid;
    m_axis_tdata  <= std_logic_vector(avg);
    m_axis_tlast  <= tlast_reg;

end Behavioral;