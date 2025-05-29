
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity led_level_controller is
    generic(
        NUM_LEDS : positive := 16;
        CHANNEL_LENGHT  : positive := 24;
        refresh_time_ms: positive := 1;
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
end led_level_controller;

architecture Behavioral of led_level_controller is

constant refresh_clock_cycles : positive := (refresh_time_ms * 1000000) / clock_period_ns; --number of clock cycles needed to have the correct refresh time

signal left_ch : signed(CHANNEL_LENGHT-1 downto 0);
signal right_ch : signed(CHANNEL_LENGHT-1 downto 0);
signal abs_value_right_ch : unsigned(CHANNEL_LENGHT downto 0); -- absolute value of left channel data
signal abs_value_left_ch : unsigned(CHANNEL_LENGHT downto 0); -- absolute value of right channel data
signal sum : unsigned(CHANNEL_LENGHT downto 0); -- sum signal is one bit longer than left_ch and right_ch to avoid overflow, for example in the worst case when both left_ch and_right_ch are equal to a one folowed by CHANNEL_LENGHT-1 zeros  
signal average : unsigned(CHANNEL_LENGHT-1 downto 0);
signal cont : unsigned(26 downto 0) := (others => '0') ; -- this signal is used to count the number of clock cycles needed to have the selected refresh time.
--The signal length of 27 bits allows it to reach a maximum value of about 134 000 000 which is enough to have, for example, a 1 second refresh time with a 10 ns clock period 


begin

    s_axis_tready <= '1';
    
    
    -- the following process computes the absolute value of left_ch and right_ch which is used for the average.
    -- The absolute values are resized because they will be summed and the sum variable is longer than right_ch and left_ch to avoid overflow
    
    Absulute_value_calculation : process(left_ch, right_ch)
    begin
    

        if left_ch < 0 then
        
            abs_value_left_ch <= resize(unsigned(-left_ch), abs_value_left_ch'length); 
                        
        else
        
            abs_value_left_ch <= resize(unsigned(left_ch), abs_value_left_ch'length);
            
        end if;
    
        if right_ch < 0 then
        
            abs_value_right_ch <= resize(unsigned(-right_ch), abs_value_right_ch'length);
            
        else
        
            abs_value_right_ch <= resize(unsigned(right_ch), abs_value_right_ch'length);
            
        end if;
    
           
    end process;
    
    --This process is used to receive the data from the slave axis interface, then it computes the average of the absolute values of the data from left and right channel and turns on a number of leds proportional to the average value.
    --The process takes care of the reset operation, too.
    
    process(aclk, aresetn, abs_value_right_ch, abs_value_left_ch)
    begin
        if aresetn = '0' then --reset operation
        
            led <= (others => '0');
            cont <= to_unsigned(0, cont'length);
            
        else
    
            if rising_edge(aclk) then
                
                --this part of the porcess takes care to receive the data when it is valid and stores it in the right_ch and left_ch signals
                
                if s_axis_tvalid ='1' then
                    
                        if s_axis_tlast = '1' then 
                            
                            right_ch <= signed(s_axis_tdata);
                            
                        else
                            
                            left_ch <= signed (s_axis_tdata);
                            
                        end if;
                    
                 end if;
                 
                 --this part of the porcess computes the average of the absolute values of the data from left and right channel
                 
                 sum <= abs_value_right_ch +  abs_value_left_ch;
                 average <= sum(CHANNEL_LENGHT downto 1);
                                   
                 cont <= cont + 1; -- counter of clock cycles for refresh time is increased by one
                 
                 --this part of the porcess turns on a number of leds proportional to the value of the average signal and refreshes the leds every refresh_time_ms.
                         
                 if cont = to_unsigned(refresh_clock_cycles, cont'length) then
                 
                     cont <= (others => '0');
                 
                     for i in 0 to NUM_LEDS - 1 loop
                    
                         if average > ((2**(CHANNEL_LENGHT-1))/NUM_LEDS) * i then
                             led(i) <= '1';
                         else
                             led(i) <= '0';
                         end if;
                        
                     end loop;
                           
                 end if;

                   
            end if;
        
        end if;
    
    end process;
    
    


end Behavioral;
