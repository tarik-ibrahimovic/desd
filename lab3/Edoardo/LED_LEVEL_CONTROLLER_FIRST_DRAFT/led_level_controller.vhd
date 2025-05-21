
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

constant refresh_clock_cycles : positive := (refresh_time_ms * 1000000) / clock_period_ns;

signal abs_value : unsigned(CHANNEL_LENGHT-1 downto 0);
signal sum : signed(CHANNEL_LENGHT downto 0);
signal average : signed(CHANNEL_LENGHT-1 downto 0);
signal left_ch : signed(CHANNEL_LENGHT-1 downto 0);
signal right_ch : signed(CHANNEL_LENGHT-1 downto 0);
signal cont : unsigned(26 downto 0) := (others => '0') ; ----27 bits to reach 100 000 000


begin

    s_axis_tready <= '1';
    
    Absulute_value : process(average)
    begin
    
        if average < 0 then 
            
            abs_value <= unsigned(-average);
            
        else
            
            abs_value <= unsigned(average);
            
        end if;
        
    end process;
    

    process(aclk, aresetn, abs_value)
    begin
        if aresetn = '0' then
        
            led <= (others => '0');
            cont <= to_unsigned(0, cont'length);
            
        else
    
            if rising_edge(aclk) then
                
                if s_axis_tvalid ='1' then
                    
                        if s_axis_tlast = '1' then 
                            
                            right_ch <= signed(s_axis_tdata);
                            
                        else
                            
                            left_ch <= signed (s_axis_tdata);
                            
                        end if;
                    
                 end if;
                 
                 sum <= (right_ch(right_ch'left) & right_ch) + (left_ch(left_ch'left) & left_ch);
                 average <= sum(CHANNEL_LENGHT downto 1);
        
                        

                 
                 cont <= cont + 1;
                         
                 if cont = to_unsigned(refresh_clock_cycles, cont'length) then
                 
                     cont <= (others => '0');
                 
                     for i in 0 to NUM_LEDS - 1 loop
                    
                         if abs_value > ((2**(CHANNEL_LENGHT-1))/NUM_LEDS) * i then
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
