----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.04.2025 12:27:58
-- Design Name: 
-- Module Name: division_tb - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity division_tb is
--  Port ( );
end division_tb;

architecture Behavioral of division_tb is

    component division is
      Port ( 
        dividend : in std_logic_vector(8 downto 0); -- 9 bits to match the dimension of color sum
        result : out std_logic_vector(7 downto 0) -- division by 3 reduces the number of bits necessary to rapresent the number (tecnically 7 bits are enough)
      );
    end component;
    
     signal dividend_tb : std_logic_vector(8 downto 0) := std_logic_vector(TO_UNSIGNED(57,9));
     signal result_tb : std_logic_vector(7 downto 0);
     signal clk : std_logic := '0';
     
begin
    DUT : division
    port map(
    
        dividend => dividend_tb,
        result => result_tb
    );
    
    clk <= not clk after 5 ns;
    
    tb : process(clk)
    begin
        if rising_edge(clk) then
            dividend_tb <= std_logic_vector(unsigned(dividend_tb) + 1);
        end if;
    end process;

--    temp: process
--    begin
--    wait for 100 ns;
--    wait;
--    end process;
    
--    dividend_tb <= std_logic_vector(TO_UNSIGNED(57,9));
    

end Behavioral;
