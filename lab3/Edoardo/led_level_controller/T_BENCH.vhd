
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity LED_TB is
GENERIC(
        NUM_LEDS : positive := 16;
        CHANNEL_LENGHT  : positive := 24;
        refresh_time_ms: positive :=1;
        clock_period_ns: positive :=10

);
--  Port ( );
end LED_TB;

architecture Behavioral of LED_TB is

COMPONENT led_level_controller is
    generic(
        NUM_LEDS : positive := 16;
        CHANNEL_LENGHT  : positive := 24;
        refresh_time_ms: positive :=1;
        clock_period_ns: positive :=10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led    : out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic

    );
end component;

 signal     aclk			:  std_logic := '0';
  signal       aresetn			: std_logic := '1' ;
        
  signal       led    : std_logic_vector(NUM_LEDS-1 downto 0);

   signal      s_axis_tvalid	:  std_logic;
   signal      s_axis_tdata	: std_logic_vector(CHANNEL_LENGHT-1 downto 0);
   signal      s_axis_tlast    : std_logic;
    signal     s_axis_tready	:  std_logic;


begin

dut123 : led_level_controller
    generic map (
        NUM_LEDS  => 16,
        CHANNEL_LENGHT   => 24,
        refresh_time_ms =>1,
        clock_period_ns =>10
    )
    Port map(
        
        aclk => aclk,
        aresetn	=>	aresetn	,
        
        led  =>  led,

        s_axis_tvalid =>s_axis_tvalid	,
        s_axis_tdata  => s_axis_tdata,
        s_axis_tlast => s_axis_tlast ,
        s_axis_tready=>	s_axis_tready
    );

-----clk gen-----

process
begin

    wait for 10 ns; 
    aclk <= not aclk;

end process;

----s_axis_gen-----------

process
begin
    s_axis_tdata <= (others => '1');
    s_axis_tvalid <= '0';
    s_axis_tlast <= '0';
    wait for 1899944.5 ns;
    s_axis_tdata <= "100000000000000000000000";--"101001111111111111111111";
    s_axis_tvalid<= '1';
    wait for 20 ns;
    s_axis_tdata <= "000000000000000000000001";--"101001111111111111111111";
    --"100000000000000000000000";
     s_axis_tlast <= '1';
    wait for 20 ns;
    s_axis_tdata <= (others => '1');
    s_axis_tvalid <= '0';
     s_axis_tlast <= '0';
     wait for 2 ms;
    s_axis_tdata <= std_logic_vector(to_unsigned(0, CHANNEL_LENGHT ));
    s_axis_tvalid <= '0';
    s_axis_tlast <= '0';
    wait for 12 ns;
    s_axis_tdata <= (others => '1');
    s_axis_tvalid <= '1';
    wait for 20 ns;
    s_axis_tdata <= (others => '1');
     s_axis_tlast <= '1';
    wait for 20 ns;
    s_axis_tdata <= std_logic_vector(to_unsigned(0, CHANNEL_LENGHT ));
    s_axis_tvalid <= '0';
     s_axis_tlast <= '0';
    wait;
end process;

--process
--begin

--    wait for 1ms;
--    wait for 16 ns;
    
--    aresetn <= '0';
--    wait for 1 ms;
    
--    aresetn <= '1';
    
--    wait;

--end process;

end Behavioral;