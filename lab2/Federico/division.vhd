----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.03.2025 15:57:06
-- Design Name: 
-- Module Name: division - Behavioral
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

entity division is
  Port ( 
    dividend : in std_logic_vector(8 downto 0); -- 9 bits to match the dimension of color sum 
    result : out std_logic_vector(7 downto 0) -- division by 3 reduces the number of bits necessary to rapresent the number (tecnically 7 bits are enough)
  );
end division;


    
architecture Behavioral of division is

    signal mult32 : unsigned(13 downto 0) := (others => '0');
    signal mult8 : unsigned(11 downto 0) := (others => '0');
    signal mult2 : unsigned(9 downto 0) := (others => '0');
    signal mult43 : unsigned(14 downto 0) := (others => '0');

begin

    mult32(mult32'LEFT downto mult32'LEFT - dividend'LENGTH + 1) <= unsigned(dividend); -- dividend << 5 = dividend*32
    mult8(mult8'LEFT downto mult8'LEFT - dividend'LENGTH + 1) <= unsigned(dividend); -- dividend << 3 = dividend*8
    mult2(mult2'LEFT downto mult2'LEFT - dividend'LENGTH + 1) <= unsigned(dividend); -- dividend << 1 = dividend*2
    
    mult43 <= TO_UNSIGNED(TO_INTEGER(mult32) + TO_INTEGER(mult8) + TO_INTEGER(mult2) + TO_INTEGER(unsigned(dividend)), mult43'length); -- dividend*(32+8+2+1)   
    
    result <= std_logic_vector(mult43(mult43'LEFT downto mult43'LEFT - result'LENGTH + 1)); -- mult43 >> 7 = mult43/128 = dividend*0.335 (approximated by default) it is a bit higher than .333, in this way the average of 3 equal number is right

end Behavioral;
