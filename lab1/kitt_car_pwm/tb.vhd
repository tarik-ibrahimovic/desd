library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb is
end entity tb;

architecture test of tb is
   component KittCarPWM is
      Generic (

     CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100     := 10;	-- clk period in nanoseconds
     MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000    := 1;	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

     PERIOD_INIT      :	INTEGER	RANGE	1 TO 1000000 := 1000;	-- period in num of clk cycles
     NUM_OF_SWS		:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of input switches
     NUM_OF_LEDS		:	INTEGER	RANGE	1 TO 16 := 16	-- Number of output LEDs

  );
  Port (

     ------- Reset/Clock --------
     reset	:	IN	STD_LOGIC;
     clk		:	IN	STD_LOGIC;
     ----------------------------

     -------- LEDs/SWs ----------
     sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);	-- Switches avaiable on Basys3
     leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)	-- LEDs avaiable on Basys3
     ----------------------------

  );
   end component;

   constant CLK_PERIOD_NS      :	POSITIVE	:= 10;	-- clk period in nanoseconds
   constant MIN_KITT_CAR_STEP_MS	:	POSITIVE	:= 1;	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)
   constant NUM_OF_SWS      :	INTEGER	:= 16;	-- Number of input switches
   constant NUM_OF_LEDS      :	INTEGER	:= 16;	-- Number of output LEDs
   constant PWM_PERIOD : INTEGER := 1000; -- period in num of clk cycles
   
   signal reset : STD_LOGIC := '0';
   signal clk : STD_LOGIC := '0';
   signal sw : STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0) := "0000000000000001";
   signal leds : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0);

   signal leds_0 : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0) := (others => '0');
   signal leds_1 : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0) := (others => '0');
   signal leds_2 : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0) := (others => '0');
   signal leds_3 : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0) := (others => '0');

   type real_array is array (natural range <>) of real;
   signal values_vector : real_array(0 to NUM_OF_LEDS-1);
   signal pwm_quarter_tick : std_logic := '0';
   signal pwm_counter : unsigned (10 downto 0) := (others => '0');
begin

   UUT: KittCarPWM
   Generic Map (

     CLK_PERIOD_NS			=> CLK_PERIOD_NS,	-- clk period in nanoseconds
     MIN_KITT_CAR_STEP_MS	=> MIN_KITT_CAR_STEP_MS,	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

     PERIOD_INIT      => PWM_PERIOD,	-- period in num of clk cycles
     NUM_OF_SWS		=> 16,	-- Number of input switches
     NUM_OF_LEDS		=> 16	-- Number of output LEDs

  )
  Port Map (
     ------- Reset/Clock --------
     reset	=> reset,
     clk		=> clk,
     ----------------------------

     -------- LEDs/SWs ----------
     sw		=> sw,	-- Switches avaiable on Basys3
     leds	=> leds	-- LEDs avaiable on Basys3
     ----------------------------
  );
   clk <= not clk after 5 ns;
   resetting : process
   begin
      wait for 100 ns;
      reset <= '1';
      wait for 100 ns;
      reset <= '0';
      wait;
   end process;

   pwm_clock : process(clk, reset)
   begin
      if reset = '1' then
         pwm_counter <= (others => '0');
         pwm_quarter_tick <= '0';
      elsif rising_edge(clk) then
         pwm_counter <= pwm_counter + 1;
         if pwm_counter = PWM_PERIOD/4 then
            pwm_counter <= (others => '0');
            pwm_quarter_tick <= '1';
         else
            pwm_quarter_tick <= '0';
         end if;
      end if;
   end process;

   shifting : process (clk, reset) begin
      if reset = '1' then
         leds_0 <= (others => '0');
         leds_1 <= (others => '0');
         leds_2 <= (others => '0');
         leds_3 <= (others => '0');
      elsif rising_edge(clk) then
         if(pwm_quarter_tick = '1') then
            leds_0 <= leds_1;
            leds_1 <= leds_2;
            leds_2 <= leds_3;
            leds_3 <= leds;
         end if;
      end if;
   end process;

   averaging: process (leds_0, leds_1, leds_2, leds_3)
   variable sum : real := 0.0;
begin
   for i in 0 to NUM_OF_LEDS-1 loop
      sum := real(to_integer(unsigned(std_logic_vector'('0' & leds_0(i))))) +
             real(to_integer(unsigned(std_logic_vector'('0' & leds_1(i))))) +
             real(to_integer(unsigned(std_logic_vector'('0' & leds_2(i))))) +
             real(to_integer(unsigned(std_logic_vector'('0' & leds_3(i)))));
      values_vector(i) <= sum / 4.0;
   end loop;
end process;
end test;