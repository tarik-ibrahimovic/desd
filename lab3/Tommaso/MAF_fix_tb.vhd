
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_moving_average_filter is
end tb_moving_average_filter;

architecture Behavioral of tb_moving_average_filter is

    constant TDATA_WIDTH        : integer := 24;
    constant FILTER_ORDER_POWER : integer := 5;
    constant CLK_PERIOD         : time := 6.94 ns;

    signal clk            : std_logic := '0';
    signal rst_n          : std_logic := '0';

    signal s_axis_tvalid  : std_logic := '0';
    signal s_axis_tdata   : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast   : std_logic := '0';
    signal s_axis_tready  : std_logic;

    signal m_axis_tvalid  : std_logic;
    signal m_axis_tdata   : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tlast   : std_logic;
    signal m_axis_tready  : std_logic := '1';

    signal enable_filter  : std_logic := '0';

    component moving_average_filter
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
    end component;

    procedure send_sample(
        signal data  : out std_logic_vector;
        signal valid : out std_logic;
        signal last  : out std_logic;
        signal ready : in  std_logic;
        value        : in integer;
        is_last      : in std_logic;
        signal clk   : in std_logic
    ) is
    begin
        data  <= std_logic_vector(to_signed(value, data'length));
        valid <= '1';
        last  <= is_last;
        wait until rising_edge(clk);

        -- Mantieni VALID finché non è accettato
        while ready = '0' loop
            wait until rising_edge(clk);
        end loop;

        wait until rising_edge(clk); -- garantisce almeno un ciclo di handshake

        valid <= '0';
        last  <= '0';
        wait for CLK_PERIOD;
    end procedure;

begin

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- DUT
    DUT: moving_average_filter
        generic map (
            FILTER_ORDER_POWER => FILTER_ORDER_POWER,
            TDATA_WIDTH        => TDATA_WIDTH
        )
        port map (
            aclk           => clk,
            aresetn        => rst_n,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            s_axis_tready  => s_axis_tready,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tlast   => m_axis_tlast,
            m_axis_tready  => m_axis_tready,
            enable_filter  => enable_filter
        );

    -- Stimulus
    stimulus: process
    begin
        rst_n <= '0';
        wait for 20 ns;
        rst_n <= '1';
        wait for 20 ns;

        report "Invio 4 coppie L/R (bypass)";
        enable_filter <= '0';

        for i in 0 to 3 loop
            send_sample(s_axis_tdata, s_axis_tvalid, s_axis_tlast, s_axis_tready, i,       '0', clk); -- LEFT
            send_sample(s_axis_tdata, s_axis_tvalid, s_axis_tlast, s_axis_tready, i + 100, '1', clk); -- RIGHT
        end loop;

        wait for 50 ns;

        report "Invio 4 coppie L/R (filtro attivo)";
        enable_filter <= '1';

        for i in 4 to 7 loop
            send_sample(s_axis_tdata, s_axis_tvalid, s_axis_tlast, s_axis_tready, i,       '0', clk); -- LEFT
            send_sample(s_axis_tdata, s_axis_tvalid, s_axis_tlast, s_axis_tready, i + 100, '1', clk); -- RIGHT
        end loop;

        wait for 200 ns;

        report "Fine simulazione." severity failure;
    end process;

    -- Monitor
    monitor: process(clk)
    begin
        if rising_edge(clk) then
            if m_axis_tvalid = '1' then
                report "OUT = " & integer'image(to_integer(signed(m_axis_tdata))) &
                       " | LAST = " & std_logic'image(m_axis_tlast);
            end if;
        end if;
    end process;

end Behavioral;
