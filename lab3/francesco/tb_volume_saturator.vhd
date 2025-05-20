-- Testbench for volume_saturator
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_volume_saturator is
end entity tb_volume_saturator;

architecture sim of tb_volume_saturator is
    -- Generics from DUT
    constant TDATA_WIDTH      : positive := 24;
    constant VOLUME_WIDTH     : positive := 10;
    constant VOLUME_STEP_2    : positive := 6;
    constant HIGHER_BOUND     : integer  := 2**15 - 1;
    constant LOWER_BOUND      : integer  := -2**15;
    -- Derived input data width
    constant INPUT_EXT_WIDTH  : integer := 2**(VOLUME_WIDTH-VOLUME_STEP_2-1);
    constant S_DATA_WIDTH     : integer := TDATA_WIDTH + INPUT_EXT_WIDTH;

    -- Clock period
    constant clk_period : time := 10 ns;

    -- Signals
    signal aclk           : std_logic := '0';
    signal aresetn        : std_logic := '0';

    signal s_axis_tvalid  : std_logic := '0';
    signal s_axis_tdata   : std_logic_vector(S_DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast   : std_logic := '0';
    signal s_axis_tready  : std_logic;

    signal m_axis_tvalid  : std_logic;
    signal m_axis_tdata   : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tlast   : std_logic;
    signal m_axis_tready  : std_logic := '1';

    -- Test vectors
    type int_array is array(natural range <>) of integer;
    constant test_samples : int_array := (
        0,
        HIGHER_BOUND/2,
        HIGHER_BOUND,
        HIGHER_BOUND + 10000,
        LOWER_BOUND,
        LOWER_BOUND - 10000,
        12345,
        -12345
    );

begin
    -- DUT instantiation
    DUT: entity work.volume_saturator
        generic map(
            TDATA_WIDTH   => TDATA_WIDTH,
            VOLUME_WIDTH  => VOLUME_WIDTH,
            VOLUME_STEP_2 => VOLUME_STEP_2,
            HIGHER_BOUND  => HIGHER_BOUND,
            LOWER_BOUND   => LOWER_BOUND
        )
        port map(
            aclk           => aclk,
            aresetn        => aresetn,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tlast   => s_axis_tlast,
            s_axis_tready  => s_axis_tready,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tlast   => m_axis_tlast,
            m_axis_tready  => m_axis_tready
        );

    -- Clock generation
    clk_proc: process
    begin
        while true loop
            aclk <= '0';
            wait for clk_period/2;
            aclk <= '1';
            wait for clk_period/2;
        end loop;
    end process;

    -- Stimulus
    stim_proc: process
        variable idx : integer := 0;
        variable sample_ext : integer := 0;
    begin
        -- Reset
        aresetn <= '0';
        wait for 2*clk_period;
        aresetn <= '1';
        wait until rising_edge(aclk);
        s_axis_tvalid <= not s_axis_tvalid;
        wait for clk_period;

        -- Send test samples
        for idx in test_samples'range loop
            -- extend sample to input width
            sample_ext := test_samples(idx);
            -- saturate to represent input width sign extension
            s_axis_tdata <= std_logic_vector(resize(signed(to_signed(sample_ext, S_DATA_WIDTH)), S_DATA_WIDTH));

            if idx = test_samples'high then
                s_axis_tlast <= '1';
            else
                s_axis_tlast <= '0';
            end if;
            wait until rising_edge(aclk);
            wait until s_axis_tready = '1';
            wait until rising_edge(aclk);
        end loop;

--        s_axis_tvalid <= '0';
        s_axis_tlast  <= '0';

        -- Wait for output flushing
        wait for 50 ns;
        wait;
    end process;

    -- Monitor outputs
    monitor_proc: process(aclk)
    begin
        if rising_edge(aclk) then
            if m_axis_tvalid = '1' then
                report "Output: " & integer'image(to_integer(signed(m_axis_tdata))) &
                       " last=" & std_logic'image(m_axis_tlast) severity note;
            end if;
        end if;
    end process;

end architecture sim;
