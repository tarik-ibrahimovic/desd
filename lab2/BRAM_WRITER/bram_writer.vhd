library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE :=16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic := '0'; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end entity bram_writer;

architecture rtl of bram_writer is

    ---------------------------------- COMPONENT: BRAM CONTROLLER----------------------------------------------
    
    component bram_controller is
        generic (
            ADDR_WIDTH: POSITIVE :=16
        );
        port (
            clk   : in std_logic;
            aresetn : in std_logic;
    
            addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
            dout: out std_logic_vector(7 downto 0);
            din: in std_logic_vector(7 downto 0);
            we: in std_logic
        );
    end component;
    
    -------------------------------------SIGNALS: ------------------------------------------------------------

    signal current_addr : std_logic_vector (ADDR_WIDTH-1 downto 0) := (others => '0'); -- This signal determines the current address during writing operation in the BRAM (see line 90 for more details)
    signal addr: std_logic_vector (ADDR_WIDTH-1 downto 0); -- this signal is connected to the addr input of the BRAM controller component (see line 90 for more details)
    signal address_control : std_logic := '0'; -- this signal selects if the address of the bram_controller is decided by the conv_addr input or the signal current_addr (see line 90 for more details) 
    signal write_enable : std_logic := '1'; -- this signal is connected to the we input of the BRAM controller component
    signal dout : std_logic_vector(7 downto 0); -- this signal is connected to the dout output of the BRAM controller component
    signal start_conv_internal : std_logic := '0'; -- this signal controls the start_conv output of the BRAM Writer
    signal too_many_packets : std_logic := '0'; -- this signal is set to '1' when too many packects arrive to the BRAM
    
    type led_state_t is (OFF, UNDER , OK, OVER);
    
    signal led_status : led_state_t := OFF; -- this signal is used to set the status of the leds connected to the BRAM Writer

  

begin


   ------------------------- creating bram component -------------------------------------------
    
    bram : bram_controller 
                generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk  => clk,
            aresetn => aresetn,
            addr => addr,
            dout => dout,
            din => s_axis_tdata,
            we => write_enable
        );
        
   
    s_axis_tready <= write_enable; 
    start_conv <= start_conv_internal;
    conv_data <= dout ( 6 downto 0);
    
    
    -- The following process is used to select which signal controls the addr input of the BRAM_controller component. The addr input of the BRAM_controller is always connected to the signal called addr.
    -- During the writing operation of the packets in the memory, the addr signal is set equal to the current_addr signal.
    -- When the writing operation is completed and the convolution module is reading the contents of the memory, instead, the addr signal is set equal to the conv_addr input.
    -- Another signal called address_control is used to distinguish between these two operations: when address_control is '0' the writing operation is happening, when address_control is '1' the convolution module
    -- is reading the contents of the memory.
    
    process(address_control, current_addr, conv_addr)
        begin
        case address_control is
            when '0' => addr <= current_addr;
            when '1' => addr <= conv_addr;
            when others => addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        end case;
    end process;

      
    
    bramWriter : process(clk)
        begin
        
            if rising_edge (clk) then 
            
            
            -- The following lines are used to save the data received via axis into the bram when s_axis_tvalid = '1' and write_enable = '1' (note that s_axis_tready <= write_enable).      
            -- The current_addr variable increases by one each time a valid data is saved into memory. The code also checks if current_addr reaches a too high value to detect if too many packets have been received. 
            --If too many packets have been received, the signal current_addr will overflow.
            
                if s_axis_tvalid = '1' and write_enable = '1' then
                    if s_axis_tlast = '0' then 
                        if unsigned(current_addr) = to_unsigned(2**ADDR_WIDTH - 1, ADDR_WIDTH) then
                            too_many_packets <= '1';
                        end if;
                        current_addr <= std_logic_vector(unsigned(current_addr) + 1);
                    end if;
                end if;

            
            
           --The following lines are used to: 
           --set write_enable to '0' after the tlast signal has been received,
           --send to the convolution module the start convolution signal,
           --set the value of the led_status variable depending on the number of packets that have been received (too few, the correct number or too many).
              
                if s_axis_tlast = '1' then
                    
                    write_enable <= '0';
                    start_conv_internal <= '1';--Note that, to speed up the comunication between the convolution module and the BRAM, the value of conv_addr input is set by the convolution module equal to the address of the first data that
                                               --it wants to receive, even before the start_conv is set to '1'
                                               
                    address_control <= '1'; -- the addr signal is set equal to the conv_addr input when address_control is '1'.
                    
                    if ( unsigned(current_addr) = to_unsigned(2**ADDR_WIDTH - 1, ADDR_WIDTH)) then 
                        led_status <= OK;
                    elsif ( too_many_packets = '1' ) then 
                        led_status <= OVER;
                    else
                        led_status <= UNDER;
                    end if;
                
                end if;
                

            
            --The following lines are used to turn on or off the leds 
            
                case led_status is 
            
                    when OFF =>
                    
                        underflow <= '0';
                        write_ok <= '0';
                        overflow <= '0'; 
                    
                    when OVER =>
                        underflow <= '0';
                        write_ok <= '0';
                        overflow <= '1';
                    when OK =>
                    
                        underflow <= '0';
                        write_ok <= '1';
                        overflow <= '0';
                    
                    when UNDER =>
                        underflow <= '1';
                        write_ok <= '0';
                        overflow <= '0';
                
                end case;
                
            --The following lines are used, after the done_conv signal is received, to modify the value of some signals and set to '0' the outputs to the leds            
                
                if done_conv = '1' then 
                    write_enable <= '1';
                    start_conv_internal <= '0';
                    led_status <= OFF;
                    too_many_packets <= '0';
                    address_control <= '0'; --the addr signal is set equal to the current_addr signal when address_control is '0'
                    current_addr <= (others => '0');
                end if;
                

            -- The following lines are used to set the start convolution signal back to '0' if it was set to '1'.
                
                if start_conv_internal  = '1' then 
                    start_conv_internal <= '0';
                end if;             
            
           --The following lines are used for the reset operation.
           
                  if aresetn = '0' then 
                
                    current_addr <= (others => '0');
                    address_control <= '0';
                    write_enable <= '1';
                    start_conv_internal <= '0';
                    led_status <= OFF;
                    too_many_packets <= '0';
                end if;
                        
            end if;

    end process;
  

end architecture;
