library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_balance_controller is
end tb_balance_controller;

architecture sim of tb_balance_controller is
    -- Generics
    constant TDATA_WIDTH    : positive := 24;
    constant BALANCE_WIDTH  : positive := 10;
    constant BALANCE_STEP_2 : positive := 6;

    -- Clock period definition
    constant CLK_PERIOD : time := 10 ns;

    -- DUT signals
    signal aclk          : std_logic := '0';
    signal aresetn       : std_logic := '0';

    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tready : std_logic;
    signal s_axis_tlast  : std_logic := '0';

    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tready : std_logic := '1';
    signal m_axis_tlast  : std_logic;

    signal balance       : std_logic_vector(BALANCE_WIDTH-1 downto 0) := (others => '0');
begin
    -- Clock generation
    aclk <= not aclk after 5 ns;
    s_axis_tvalid <= not s_axis_tvalid after 80 ns;
    m_axis_tready <= not m_axis_tready after 120 ns;

    -- DUT instantiation
    uut: entity work.balance_controller
        generic map (
            TDATA_WIDTH    => TDATA_WIDTH,
            BALANCE_WIDTH  => BALANCE_WIDTH,
            BALANCE_STEP_2 => BALANCE_STEP_2
        )
        port map (
            aclk           => aclk,
            aresetn        => aresetn,
            s_axis_tvalid  => s_axis_tvalid,
            s_axis_tdata   => s_axis_tdata,
            s_axis_tready  => s_axis_tready,
            s_axis_tlast   => s_axis_tlast,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tready  => m_axis_tready,
            m_axis_tlast   => m_axis_tlast,
            balance        => balance
        );

    -- Stimulus process
    stim_proc: process
    begin
        
        balance <= std_logic_vector(to_signed(130, BALANCE_WIDTH));
        -- Reset
        aresetn <= '0';
        wait for 2 * CLK_PERIOD;
        aresetn <= '1';
        wait for CLK_PERIOD;

        wait until rising_edge(aclk);
        for i in 20 to 300 loop
            s_axis_tdata <= std_logic_vector(to_signed(-i, s_axis_tdata'length));
            s_axis_tlast <= not s_axis_tlast;
            balance <= std_logic_vector(signed(balance) + 10);
            wait until s_axis_tready = '1' and s_axis_tvalid = '1';
            
        end loop;
    end process;

end architecture sim;