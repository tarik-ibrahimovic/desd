---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
------------------------------------

entity KittCarPWM is
	Generic (

		CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100     := 10;	-- clk period in nanoseconds
		MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000    := 1;	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

		NUM_OF_SWS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of input switches
		NUM_OF_LEDS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of output LEDs

		TAIL_LENGTH				:	INTEGER	RANGE	1 TO 16	:= 4	-- Tail length
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
end KittCarPWM;

architecture Behavioral of KittCarPWM is

    component PulseWidthModulator is
    Generic(
							
			BIT_LENGTH	:	INTEGER	RANGE	1 TO 16 ;	-- Leds used  over the 16 in Basys3
			
			T_ON_INIT	:	POSITIVE ;					-- Init of Ton
			PERIOD_INIT	:	POSITIVE ;				    -- Init of Periof
			
			PWM_INIT	:	STD_LOGIC			       -- Init of PWM
		);
		Port ( 
		
			------- Reset/Clock --------
			reset	:	IN	STD_LOGIC;
			clk		:	IN	STD_LOGIC;
			----------------------------		

			-------- Duty Cycle ----------
			Ton		:	IN	STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0);	-- clk at PWM = '1'
			Period	:	IN	STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0);		-- clk per period of PWM
			
			PWM		:	OUT	STD_LOGIC		-- PWM signal
			----------------------------		
			
		);
    end component;
	
	signal PWM_out : std_logic_vector(TAIL_LENGTH - 1 downto 0);
	signal PWM_out_reversed : std_logic_vector(TAIL_LENGTH - 1 downto 0);
    signal count_sel : unsigned(3 downto 0) := TO_UNSIGNED(TAIL_LENGTH - 1, 4);

    signal direction : std_logic := '0';
        
    signal srst_0 : std_logic;
    signal srst_1 : std_logic;
    
    constant min_clk_per_period : unsigned(17 downto 0) := to_unsigned((MIN_KITT_CAR_STEP_MS*1000000)/(2*CLK_PERIOD_NS), 18);
    signal count : unsigned (28 downto 0);
    signal clk_ms: std_logic;
    
    signal speed : unsigned (33 downto 0);
    attribute use_dsp : string;
    attribute use_dsp of speed : signal is "no";
    
begin

    PWM_gen : for I in 1 to TAIL_LENGTH-1 generate
        PWM_INST : PulseWidthModulator
            Generic map(
							
			BIT_LENGTH	=>	 NUM_OF_LEDS,	-- Leds used  over the 16 in Basys3
			
			T_ON_INIT	=>	1,					-- Init of Ton
			PERIOD_INIT	=>	10,				    -- Init of Periof
			
			PWM_INIT	=>	'1'			       -- Init of PWM
		)
		Port map( 
		
			------- Reset/Clock --------
			reset    =>     reset,
			clk	     =>     clk,
			----------------------------		

			-------- Duty Cycle ----------
			Ton		    =>   std_logic_vector(to_unsigned(I, NUM_OF_LEDS)),
			Period      =>   std_logic_vector(to_unsigned(TAIL_LENGTH, NUM_OF_LEDS)),
			
			PWM		    =>   PWM_out(I - 1)
			----------------------------		
			
		);
    end generate;
    
    PWM_out(PWM_out'LEFT) <= '1';
    
    PWM_reversing : for I in 0 to TAIL_LENGTH - 1 generate
    pwm_out_reversed(I) <= pwm_out(TAIL_LENGTH - 1 -I);
    end generate;
    
    reset_sync : process (clk) begin
        if rising_edge(clk) then
            srst_0 <= reset;
            srst_1 <= srst_0;
        end if;
    end process;
    
    clkgen: process(clk) begin
        if rising_edge(clk) then
            if srst_1 = '1' then
                count <= (Others => '0');
                clk_ms <= '0';
          else
             count <= count + 1;
             speed <= min_clk_per_period * unsigned(sw); -- x * const x, const = 3, x*3 = x<1 +x 
             if count = speed then
                 clk_ms <= not clk_ms;
                 count <= (others => '0');
             end if;       
            end if;
        end if;
    end process;
    
    shifting : process (clk_ms) 
        variable leds_var : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0);
    begin
    
    if rising_edge(clk_ms) then
            count_sel <= count_sel + 1;
            if count_sel = "1111" then
                count_sel <= to_unsigned(1,4);
                direction <= not direction;
            end if;
    end if; 

    end process;
    demux: process (count_sel, PWM_out)
    begin
    leds <= (others => '0');
			if count_sel >= TAIL_LENGTH - 1 then

				if direction = '0' then
				    leds(to_integer(count_sel) downto to_integer(count_sel) - TAIL_LENGTH + 1) <= pwm_out;
				else
				    leds(NUM_OF_LEDS - 1 - to_integer(count_sel) + TAIL_LENGTH - 1 downto NUM_OF_LEDS - 1 - to_integer(count_sel)) <= pwm_out_reversed;

				end if;
            else
            
                if direction = '0' then
				    for I in TAIL_LENGTH - 1 downto 0 loop
				        if I - to_integer(count_sel) >= 0 then
                            leds(I - to_integer(count_sel)) <= pwm_out(TAIL_LENGTH - I - 1);
                         else
                            leds(-I + to_integer(count_sel)) <= pwm_out(TAIL_LENGTH - I - 1);
                         end if;
				    end loop;
				else
				
				    for I in TAIL_LENGTH - 1 downto 0 loop
				        if NUM_OF_LEDS - 1 - I + to_integer(count_sel) <=  NUM_OF_LEDS - 1 then
                            leds(NUM_OF_LEDS - 1 - I + to_integer(count_sel)) <= pwm_out(TAIL_LENGTH - I - 1);
                         else
                            leds(NUM_OF_LEDS - 1 + I - to_integer(count_sel)) <= pwm_out(TAIL_LENGTH - I - 1);
                         end if;
				    end loop;
				    
				end if;
				
            end if;
    end process;
    
    
    
end Behavioral;