----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.04.2025 17:39:35
-- Design Name: 
-- Module Name: c2g_tb - Behavioral
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

entity c2g_tb is
--  Port ( );
end c2g_tb;

architecture Behavioral of c2g_tb is
    component rgb2gray is
	Port (
		clk				: in std_logic;
		resetn			: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(7 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(7 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic
	);
	end component;
	
	signal clk				:  std_logic := '1';
	signal	resetn			:  std_logic;

	signal	m_axis_tvalid	:  std_logic;
	signal	m_axis_tdata	:  std_logic_vector(7 downto 0);
	signal	m_axis_tready	:  std_logic;
	signal	m_axis_tlast	:  std_logic;

	signal	s_axis_tvalid	:  std_logic;
	signal	s_axis_tdata	:  std_logic_vector(7 downto 0);
	signal	s_axis_tready	:  std_logic;
	signal	s_axis_tlast	:  std_logic;

begin

    DUT: rgb2gray
	Port map(
		clk				=> clk,
		resetn			=> resetn,

		m_axis_tvalid	=> m_axis_tvalid,
		m_axis_tdata	=> m_axis_tdata,
		m_axis_tready	=> m_axis_tready,
		m_axis_tlast	=> m_axis_tlast,

		s_axis_tvalid	=> s_axis_tvalid,
		s_axis_tdata	=> s_axis_tdata,
		s_axis_tready	=> s_axis_tready,
		s_axis_tlast	=> s_axis_tlast
	);
	
    clk <= not clk after 5 ns;
    
     reset: process
     begin
        resetn <= '0';
        wait for 100 ns;
        resetn <= '1';
        wait;
     end process;
     
     data : process
     begin
        s_axis_tvalid <= '0';
        m_axis_tready <= '0';
        s_axis_tlast <= '0';
        wait for 101 ns;
        m_axis_tready <= '0';
        s_axis_tlast <= '0';
        s_axis_tvalid <= '1';
        s_axis_tdata <= "00001110";
        wait for 30 ns;
        s_axis_tdata <= "01111000";
        wait for 30 ns;
        m_axis_tready <= '1';
        wait for 0 ns;
        s_axis_tdata <= "00111110";
        wait for 90 ns;
        m_axis_tready <= '1';
        s_axis_tvalid <= '0';
        wait for 30 ns;
        s_axis_tvalid <= '1';
        s_axis_tdata <= "01111000";
        wait for 20 ns;
        s_axis_tlast <= '1';
        wait for 10 ns;
        s_axis_tlast <= '0';
        s_axis_tvalid <= '0';
        m_axis_tready <= '0';
        --wait until rising_edge(clk) and s_axis_tready = '1';
--        s_axis_tdata <= "01111100";
        wait for 10 ns;
--        s_axis_tdata <= "01111010";
        wait for 10 ns;
--        s_axis_tdata <= "01111001";
        wait for 10 ns;
        s_axis_tvalid <= '0';
        m_axis_tready <= '1';
        wait;
     end process;
     
end Behavioral;
