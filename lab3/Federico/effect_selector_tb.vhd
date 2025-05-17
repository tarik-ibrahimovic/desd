----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.05.2025 15:08:57
-- Design Name: 
-- Module Name: effect_selector_tb - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity effect_selector_tb is
--  Port ( );
end effect_selector_tb;

architecture Behavioral of effect_selector_tb is
    constant JOYSTICK_LENGHT  : integer := 10;
    component effect_selector is
--    generic(
--        JOYSTICK_LENGHT  : integer := 10
--    );
    Port (
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        effect : in STD_LOGIC;
        jstck_x : in STD_LOGIC_VECTOR(10-1 downto 0) := (others => '0');
        jstck_y : in STD_LOGIC_VECTOR(10-1 downto 0) := (others => '0');
        volume : out STD_LOGIC_VECTOR(10-1 downto 0):= (others => '0');
        balance : out STD_LOGIC_VECTOR(10-1 downto 0):= (others => '0');
        lfo_period : out STD_LOGIC_VECTOR(10-1 downto 0) := (others => '0')
    );
    end component;
    
        signal aclk : STD_LOGIC := '1';
        signal aresetn : STD_LOGIC := '1';
        signal effect : STD_LOGIC;
        signal jstck_x : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        signal jstck_y : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        signal volume : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        signal balance : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        signal lfo_period : STD_LOGIC_VECTOR(JOYSTICK_LENGHT-1 downto 0);
        
begin

    DUT: effect_selector
--    generic map(
--        JOYSTICK_LENGHT => 10
--    )
    Port map(
        aclk => aclk,
        aresetn => aresetn,
        effect => effect,
        jstck_x => jstck_x,
        jstck_y => jstck_y,
        volume => volume,
        balance => balance,
        lfo_period => lfo_period
    );
    
    
    aclk <= not aclk after 2.5 ns;
    
    process
    begin
        aresetn <= '0';
        wait for 100 ns;
        aresetn <= '1';
--        wait for 35 ns;
--        aresetn <= '0';
        wait;
    end process;
    
    
    process
    begin
        jstck_x <= (others => '0');
        wait for 101 ns;
        jstck_y <= "0000010000";
        wait for 10ns;
        effect <= '1';
        wait for 20 ns;
        jstck_y <= "0000110000";
        jstck_x <= "0000110000";
        wait for 20 ns;
        effect <= '0';
        wait for 20 ns;
        jstck_y <= "0000010000";
        wait for 5ns;
        jstck_x <= "0000110000";
        wait;
    end process;
end Behavioral;
