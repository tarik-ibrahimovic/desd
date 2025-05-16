----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.05.2025 14:40:00
-- Design Name: 
-- Module Name: LFO_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LFO_tb is
--  Port ( );
end LFO_tb;

architecture testbench of LFO_tb is

    -- Constants for generics
    constant CHANNEL_LENGHT              : integer := 24;
    constant JOYSTICK_LENGTH             : integer := 10;
    constant CLK_PERIOD_NS               : integer := 10;
    constant TRIANGULAR_COUNTER_LENGTH   : integer := 10;

    -- Clock and reset
    signal clk        : std_logic := '1';
    signal resetn     : std_logic := '0';

    -- LFO control
    signal lfo_enable : std_logic := '0';
    signal lfo_period : std_logic_vector(JOYSTICK_LENGTH-1 downto 0) := (others => '0');

    -- AXIS Slave
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    signal s_axis_tlast  : std_logic := '0';
    signal s_axis_tready : std_logic;

    -- AXIS Master
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(CHANNEL_LENGHT-1 downto 0);
    signal m_axis_tlast  : std_logic;
    signal m_axis_tready : std_logic := '1';
    
    signal m_axis_tdata_old  : std_logic_vector(CHANNEL_LENGHT-1 downto 0) := (others => '0');
    
    component LFO is
--    generic(
--        CHANNEL_LENGHT  : integer := 24;
--        JOYSTICK_LENGHT  : integer := 10;
--        CLK_PERIOD_NS   : integer := 10;
--        TRIANGULAR_COUNTER_LENGHT    : integer := 10 -- Triangular wave period length
--    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            lfo_period      : in std_logic_vector(10-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(24-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(24-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
    end component;

begin

    -- DUT instance
    lfo_inst : LFO
--        generic map (
--            CHANNEL_LENGHT              => CHANNEL_LENGHT,
--            JOYSTICK_LENGHT             => JOYSTICK_LENGTH,
--            CLK_PERIOD_NS               => CLK_PERIOD_NS,
--            TRIANGULAR_COUNTER_LENGHT  => TRIANGULAR_COUNTER_LENGTH
--        )
        port map (
            aclk            => clk,
            aresetn         => resetn,
            lfo_period      => lfo_period,
            lfo_enable      => lfo_enable,
            s_axis_tvalid   => s_axis_tvalid,
            s_axis_tdata    => s_axis_tdata,
            s_axis_tlast    => s_axis_tlast,
            s_axis_tready   => s_axis_tready,
            m_axis_tvalid   => m_axis_tvalid,
            m_axis_tdata    => m_axis_tdata,
            m_axis_tlast    => m_axis_tlast,
            m_axis_tready   => m_axis_tready
        );
        
        clk <= not clk after 2.75 ns;
        
        process
        begin
            resetn <= '0';
            wait for 101 ns;
            resetn <= '1';
            wait;
        end process;
        
        process
        begin 
            wait for 101ns;
            lfo_enable <= '0';
            s_axis_tvalid <= '1';
            --s_axis_tdata <= "000000000000001111101000";
            s_axis_tdata <= "010000000000001111101000";
            --lfo_period <= "0000000100";
            m_axis_tready <= '1';
            wait for 50 ns;
            lfo_enable <= '1';   
            --m_axis_tready <= '0';    
--            wait for 2 ms;    
--            m_axis_tready <= '0';
--            lfo_enable <= '0';
--            wait for 2 ms;
--            m_axis_tready <= '1';
--            lfo_enable <= '1';     
            wait;
        end process;
        
        process
        begin
            while true loop
                wait until( s_axis_tready = '1' and rising_edge(clk) and s_axis_tvalid = '1');
                s_axis_tlast <= not s_axis_tlast;
            end loop;
        end process;
        
        process
        begin
            lfo_period <= "0000000000";
            for i in 0 to 1023 loop
                wait until(not(m_axis_tdata_old = m_axis_tdata));
                lfo_period <= std_logic_vector(to_unsigned(i,10));
                m_axis_tdata_old <= m_axis_tdata;
            end loop;
            wait;
        end process;
        
end testbench;
