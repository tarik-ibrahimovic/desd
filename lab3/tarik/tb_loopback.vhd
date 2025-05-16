----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/16/2025 10:17:25 AM
-- Design Name: 
-- Module Name: tb_loopback - Behavioral
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

entity tb_loopback is
--  Port ( );
end tb_loopback;

architecture Behavioral of tb_loopback is

component top_bd_wrapper is
  port (
    SPI_M_0_io0_io : inout STD_LOGIC;
    SPI_M_0_io1_io : inout STD_LOGIC;
    SPI_M_0_sck_io : inout STD_LOGIC;
    SPI_M_0_ss_io : inout STD_LOGIC;
    UART_0_rxd : in STD_LOGIC;
    UART_0_txd : out STD_LOGIC;
    reset : in STD_LOGIC;
    sys_clock : in STD_LOGIC
  );
end component top_bd_wrapper;

signal sys_clock : std_logic := '0';
signal reset  : std_logic := '0';
signal UART_0_txd : std_logic;
signal UART_0_rxd : std_logic := '0';

signal SPI_M_0_io0_io : std_logic;
signal SPI_M_0_io1_io : std_logic;
signal SPI_M_0_sck_io : std_logic;
signal SPI_M_0_ss_io : std_logic; 
    
-- UART baud rate constants
constant BAUD_RATE   : integer := 115200;
-- Bit period = 1/BAUD_RATE; here approximate to 8680 ns
constant BIT_PERIOD  : time := 8680 ns;
begin
sys_clock <= not sys_clock after 5 ns;

process begin
    reset <= '1';
    wait for 10 us;
    reset <= '0';
    wait;
end process;
   uart_tx_process : process
        -- Procedure to send one byte over the UART line, LSB first
        procedure send_byte(b : in std_logic_vector(7 downto 0)) is
        begin
            -- Start bit: drive line low
            UART_0_rxd <= '0';
            wait for BIT_PERIOD;
            
            -- Send 8 data bits (LSB first)
            for i in 0 to 7 loop
                UART_0_rxd <= b(i);
                wait for BIT_PERIOD;
            end loop;
            
            -- Stop bit: drive line high (idle state)
            UART_0_rxd <= '1';
            wait for BIT_PERIOD;
        end procedure;
    begin
        wait for 11 us;
        send_byte(x"C0");
        send_byte(x"11");
        send_byte(x"2F");
        send_byte(x"5A");
    end process;

dut : component top_bd_wrapper 
    port map(
        sys_clock => sys_clock,
        reset => reset,
        UART_0_txd => UART_0_txd,
        UART_0_rxd => UART_0_rxd,
        SPI_M_0_io0_io => SPI_M_0_io0_io,
        SPI_M_0_io1_io => SPI_M_0_io1_io,
        SPI_M_0_sck_io => SPI_M_0_sck_io,
        SPI_M_0_ss_io => SPI_M_0_ss_io
    );
end Behavioral;
