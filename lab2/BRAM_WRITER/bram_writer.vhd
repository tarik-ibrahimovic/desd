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

    -- current address for writing
    signal current_addr : std_logic_vector (ADDR_WIDTH-1 downto 0) := (others => '0');
    signal addr: std_logic_vector (ADDR_WIDTH-1 downto 0);
    
    signal write_enable : std_logic := '1'; -- write_enable of bram controller
    signal dout : std_logic_vector(7 downto 0);
    signal start_conv_internal : std_logic := '0' ;
    signal too_many_packets : std_logic := '0';
    signal address_control : std_logic := '0'; -- selct if the address of the bram is decided by the convolution module or the writing module
    
    
    ---------------------------------- COMPONENT BRAM CONTROLLER----------------------------------------------
    
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
    
    ------------------------------------------------------------------------------------------------------------
    
    --for leds
    
    type led_state_t is (OFF, UNDER , OK, OVER);
    
    signal led_status : led_state_t := OFF;

  

begin

    s_axis_tready <= write_enable;
    start_conv <= start_conv_internal;
    
     conv_data <= dout ( 6 downto 0);
    
    process(address_control, current_addr, conv_addr)
        begin
        case address_control is
            when '0' => addr <= current_addr;
            when '1' => addr <= conv_addr;
            when others => addr <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        end case;
    end process;

   ------------------------- creating bram component -------------------------------------------
    
    bram : bram_controller 
                generic map (
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map(
            clk  => clk,
            aresetn => aresetn,
            addr => addr,
            dout => dout, ----------------spero sia giusto----------
            din => s_axis_tdata,
            we => write_enable
        );
        
   --------------------------------------------------------------------------------------------------  

      
   ------------------this process is used to save the data received via axis into the bram-----------
    
    bramWriter : process(clk)
        begin
        
            if rising_edge (clk) then 
            
            
            -----------------save the data received via axis into the bram---------------------------------------------------------
            
                if s_axis_tvalid = '1' and write_enable = '1' then
                    if s_axis_tlast = '0' then 
                        if unsigned(current_addr) = to_unsigned(2**ADDR_WIDTH - 1, ADDR_WIDTH) then
                            too_many_packets <= '1';
                        end if;
                        current_addr <= std_logic_vector(unsigned(current_addr) + 1);
                    end if;
                end if;
    
            ------------------------------------------------------------------------------------------------------- ----------------
            
            
            -----------enable or disable the memory write operation and check if the number of packets received is correct; it also manages the s_axis_tready signal for the AXIS-----------    
                if s_axis_tlast = '1' then
                    
                    write_enable <= '0';
                    start_conv_internal <= '1';
                    address_control <= '1';
                    
                    
                    if ( unsigned(current_addr) = to_unsigned(2**ADDR_WIDTH - 1, ADDR_WIDTH)) then 
                        led_status <= OK;
                    elsif ( too_many_packets = '1' ) then 
                        led_status <= OVER;
                    else
                        led_status <= UNDER;
                    end if;
                
                end if;
                
            ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            
            
            --------------------------------turn on or off the leds ----------------------------------------------------------------------------------------------------------------------------
            
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
                
            --------------------------------------------------------------------------comunication with the convolution module-----------------------------------------------------------------
            
                
                if done_conv = '1' then 
                    write_enable <= '1';
                    start_conv_internal <= '0';
                    led_status <= OFF;
                    address_control <= '0';
                    current_addr <= (others => '0');
                end if;
                
                if start_conv_internal  = '1' then 
                    start_conv_internal <= '0';
                end if; 
            
            
            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            
            
            
           ------------------reset operation--------------------------------------------------------------------------------------------------------------------
           
                  if aresetn = '0' then 
                
                    current_addr <= (others => '0');
                    address_control <= '0';
                    write_enable <= '1';
                    start_conv_internal <= '0';
                    led_status <= OFF;
                    too_many_packets <= '0';
                end if;
                    
             
            ----------------------------------------------------------------------------------------------------------------------------------------------------
            
            
            end if;

    end process;
  

end architecture;
