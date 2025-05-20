-- Testbench for volume_controller
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_volume_controller is
end entity;

architecture sim of tb_volume_controller is
    -- Constants matching DUT generics
    constant TDATA_WIDTH   : positive := 24;
    constant VOLUME_WIDTH  : positive := 10;
    constant VOLUME_STEP_2 : positive := 6;
    constant HIGHER_BOUND  : integer  := 2**23 - 1;
    constant LOWER_BOUND   : integer  := -2**23;

    -- Clock period
    constant clk_period : time := 10 ns;

    -- DUT signals
    signal aclk         : std_logic := '1';
    signal aresetn      : std_logic := '0';

    signal s_axis_tvalid: std_logic := '1';
    signal s_axis_tdata : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast : std_logic := '0';
    signal s_axis_tready: std_logic := '0';

    signal m_axis_tvalid: std_logic;
    signal m_axis_tdata : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal m_axis_tlast : std_logic;
    signal m_axis_tready: std_logic := '1';

    signal volume       : std_logic_vector(VOLUME_WIDTH-1 downto 0) := (others => '0');

    -- Test vectors
    type data_array is array (natural range <>) of integer;
    constant input_samples : data_array := (
        0, 5000000, -5000000, HIGHER_BOUND, LOWER_BOUND, 1234567, -7654321
    );

begin
    -- Instantiate Device Under Test
    DUT: entity work.volume_controller
        generic map (
            TDATA_WIDTH   => TDATA_WIDTH,
            VOLUME_WIDTH  => VOLUME_WIDTH,
            VOLUME_STEP_2 => VOLUME_STEP_2,
            HIGHER_BOUND  => HIGHER_BOUND,
            LOWER_BOUND   => LOWER_BOUND
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tready => s_axis_tready,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tready => m_axis_tready,
            volume        => volume
        );

   aclk <= not aclk after 5 ns;
    m_axis_tready <= not m_axis_tready after 50ns;  
    s_axis_tvalid <= not s_axis_tvalid after 80ns; 
    -- Stimulus process
    stim_proc: process
        variable i : integer := 0;
        
    begin
        -- reset
        aresetn <= '0';
        wait for 20 ns;
        aresetn <= '1';
        wait for clk_period;

        volume <= std_logic_vector(to_signed(200, VOLUME_WIDTH));
        
        
        wait until rising_edge(aclk);
        for i in 20 to 300 loop
            s_axis_tdata <= std_logic_vector(to_signed(-i, s_axis_tdata'length));
            s_axis_tlast <= not s_axis_tlast;
            volume <= std_logic_vector(signed(volume) + 30);
            wait until s_axis_tready = '1' and s_axis_tvalid = '1';
            
        end loop;


--        -- send input samples
--        for idx in input_samples'range loop
--            s_axis_tvalid <= '1';
--            s_axis_tdata  <= std_logic_vector(to_signed(input_samples(idx), TDATA_WIDTH));
--            -- assert tlast on last sample
--            if idx = input_samples'high then
--                s_axis_tlast <= '1';
--            else
--                s_axis_tlast <= '0';
--            end if;
--            wait until rising_edge(aclk);
--            -- wait for ready
--            wait until s_axis_tready = '1';
--            wait until rising_edge(aclk);
--        end loop;
--        s_axis_tvalid <= '0';
--        s_axis_tlast  <= '0';

--        -- wait some cycles for output
--        wait for 50 ns;
--        -- finish simulation
        wait;
    end process;

    -- Monitor outputs
    monitor_proc: process(aclk)
    begin
        if rising_edge(aclk) then
            if m_axis_tvalid = '1' then
                report "Output sample: " & integer'image(to_integer(signed(m_axis_tdata))) severity note;
            end if;
        end if;
    end process;

end architecture sim;