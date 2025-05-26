library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter_en is
    generic (
        FILTER_ORDER_POWER : integer := 5;
        TDATA_WIDTH        : positive := 24
    );
    port (
        aclk           : in  std_logic;
        aresetn        : in  std_logic;
        s_axis_tvalid  : in  std_logic;
        s_axis_tdata   : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tlast   : in  std_logic;
        s_axis_tready  : out std_logic;
        m_axis_tvalid  : out std_logic;
        m_axis_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
        m_axis_tlast   : out std_logic;
        m_axis_tready  : in  std_logic;
        enable_filter  : in  std_logic
    );
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is

    component moving_average_filter is
        generic (
            FILTER_ORDER_POWER : integer := 5;
            TDATA_WIDTH        : positive := 24
        );
        port (
            aclk           : in  std_logic;
            aresetn        : in  std_logic;
            s_axis_tvalid  : in  std_logic;
            s_axis_tdata   : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tlast   : in  std_logic;
            s_axis_tready  : out std_logic;
            m_axis_tvalid  : out std_logic;
            m_axis_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            m_axis_tlast   : out std_logic;
            m_axis_tready  : in  std_logic
        );
    end component;

    signal filt_valid       : std_logic;
    signal filt_data        : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal filt_last        : std_logic;
    signal s_axis_tready_int: std_logic;
    signal mode             : std_logic := '0';

begin

    filter_inst : moving_average_filter
        generic map (
            FILTER_ORDER_POWER => FILTER_ORDER_POWER,
            TDATA_WIDTH        => TDATA_WIDTH
        )
        port map (
            aclk           => aclk,
            aresetn        => aresetn,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            s_axis_tready  => s_axis_tready_int,
            m_axis_tvalid  => filt_valid,
            m_axis_tdata   => filt_data,
            m_axis_tlast   => filt_last,
            m_axis_tready  => m_axis_tready
        );

    s_axis_tready <= s_axis_tready_int;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                mode <= '0';
            elsif s_axis_tvalid = '1' and s_axis_tready_int = '1' and s_axis_tlast = '0' then
                mode <= enable_filter;
            end if;
        end if;
    end process;

    m_axis_tvalid <= filt_valid when mode = '1' else s_axis_tvalid;
    m_axis_tdata  <= filt_data  when mode = '1' else s_axis_tdata;
    m_axis_tlast  <= filt_last  when mode = '1' else s_axis_tlast;

end Behavioral;