library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_moving_average_filter is
end tb_moving_average_filter;

architecture sim of tb_moving_average_filter is

    constant CLK_PERIOD : time := 5.52 ns; -- ~181 MHz
    constant TDATA_WIDTH : integer := 24;
    constant FILTER_ORDER_POWER : integer := 5;
    constant FILTER_LEN : integer := 2 ** FILTER_ORDER_POWER;

    signal aclk           : std_logic := '0';
    signal aresetn        : std_logic := '0';
    signal s_axis_tvalid  : std_logic := '0';
    signal s_axis_tdata   : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast   : std_logic := '0';
    signal s_axis_tready  : std_logic;
    signal m_axis_tvalid  : std_logic;
    signal m_axis_tdata   : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tlast   : std_logic;
    signal m_axis_tready  : std_logic := '1';
    signal enable_filter  : std_logic := '0';

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
            m_axis_tready  : in  std_logic;
            enable_filter  : in  std_logic
        );
    end component;

begin

    -- Clock generation
    clk_gen : process
    begin
        while true loop
            aclk <= '0';
            wait for CLK_PERIOD/2;
            aclk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- DUT instantiation
    dut: moving_average_filter
        generic map (
            FILTER_ORDER_POWER => FILTER_ORDER_POWER,
            TDATA_WIDTH => TDATA_WIDTH
        )
        port map (
            aclk           => aclk,
            aresetn        => aresetn,
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

    -- Stimuli process
    stim_proc : process
        procedure send_packet(val : integer) is
            variable v : signed(TDATA_WIDTH-1 downto 0);
        begin
            -- Send left channel sample
            v := to_signed(val, TDATA_WIDTH);
            s_axis_tdata  <= std_logic_vector(v);
            s_axis_tlast  <= '0';
            s_axis_tvalid <= '1';
            wait until rising_edge(aclk) and s_axis_tready = '1';

            -- Send right channel sample
            s_axis_tdata  <= std_logic_vector(v);
            s_axis_tlast  <= '1';
            -- Keep tvalid high during right channel also
            wait until rising_edge(aclk) and s_axis_tready = '1';

            -- After sending both samples, disable tvalid
            s_axis_tvalid <= '0';
            s_axis_tlast  <= '0';  -- clear tlast for safety
            s_axis_tdata  <= (others => '0');

            -- Small gap between packets to let DUT process
            wait for CLK_PERIOD * 2;
        end procedure;

        -- Input sample values
        type int_array is array (0 to 63) of integer;
        constant values : int_array := (
            0, 1, 2, 3, 4, 5, 6, 7,
            8, 9, 10, 11, 12, 13, 14, 15,
            16, 17, 18, 19, 20, 21, 22, 23,
            24, 25, 26, 27, 28, 29, 30, 31,
            32, 33, 34, 35, 36, 37, 38, 39,
            40, 41, 42, 43, 44, 45, 46, 47,
            48, 49, 50, 51, 52, 53, 54, 55,
            56, 57, 58, 59, 60, 61, 62, 63
        );

    begin
        -- Reset pulse
        aresetn <= '0';
        wait for 20 ns;
        aresetn <= '1';
        wait for 2 * CLK_PERIOD;

        report "Sending with enable_filter = 0 (pass-through)";
        enable_filter <= '0';
        for i in 0 to 63 loop
            send_packet(values(i));
        end loop;

        wait for 200 ns;

        report "Sending with enable_filter = 1 (filter active)";
        enable_filter <= '1';
        for i in 0 to 63 loop
            send_packet(values(i));
        end loop;

        wait for 4000 ns;
        report "Simulation finished";
        wait;  -- keep simulation running

    end process;

end sim;
 
