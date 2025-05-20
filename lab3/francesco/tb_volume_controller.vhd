library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_volume_multiplier is
end tb_volume_multiplier;

architecture Behavioral of tb_volume_multiplier is

-- Parametri generici
    constant TDATA_WIDTH    : positive := 24;
    constant VOLUME_WIDTH   : positive := 10;
    constant VOLUME_STEP_2  : positive := 6;
    constant OUTPUT_WIDTH   : natural := TDATA_WIDTH - 1 + 2**(VOLUME_WIDTH - VOLUME_STEP_2 - 1) + 1;
    
    -- Segnali di testbench
    signal aclk             : std_logic := '1';
    signal aresetn          : std_logic := '0';
    
    signal s_axis_tvalid    : std_logic := '1';
    signal s_axis_tdata     : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tlast     : std_logic := '0';
    signal s_axis_tready    : std_logic;
    
    signal m_axis_tvalid    : std_logic;
    signal m_axis_tdata     : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal m_axis_tlast     : std_logic;
    signal m_axis_tready    : std_logic := '0';
    
    signal volume           : std_logic_vector(VOLUME_WIDTH-1 downto 0) := (others => '0');
    
begin

    -- Clock generation
        aclk <= not aclk after 5 ns;
        s_axis_tvalid <= not s_axis_tvalid after 80 ns;
        m_axis_tready <= not m_axis_tready after 120 ns;
        
    -- DUT instantiation
    uut: entity work.volume_multiplier
        generic map (
            TDATA_WIDTH    => TDATA_WIDTH,
            VOLUME_WIDTH   => VOLUME_WIDTH,
            VOLUME_STEP_2  => VOLUME_STEP_2
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
            volume         => volume
        );
    
    -- Stimolo
    stim_proc: process
    begin
        -- Inizializza il reset
        aresetn <= '0';
        wait for 20 ns;
        aresetn <= '1';
        wait for 20 ns;
    
        -- Primo dato con volume medio
        volume <= std_logic_vector(to_signed(200, VOLUME_WIDTH));
        
        
        wait until rising_edge(aclk);
        for i in 20 to 300 loop
            s_axis_tdata <= std_logic_vector(to_signed(-i, s_axis_tdata'length));
            s_axis_tlast <= not s_axis_tlast;
            volume <= std_logic_vector(signed(volume) + 10);
            wait until s_axis_tready = '1' and s_axis_tvalid = '1';
            
        end loop;

        wait for 100 ns;

        wait;
    end process;
    

end Behavioral;