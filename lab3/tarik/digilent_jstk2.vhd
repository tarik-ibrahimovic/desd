library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

entity digilent_jstk2 is
   generic (
      DELAY_US		: integer := 25;    -- Delay (in us) between two packets
      CLKFREQ		: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz)
      SPI_SCLKFREQ 	: integer := 5000 -- Frequency of the SPI SCLK clock signal (in Hz)
   );
   Port ( 
      aclk 			: in  STD_LOGIC;
      aresetn			: in  STD_LOGIC;

      -- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
      m_axis_tvalid	: out STD_LOGIC;
      m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
      m_axis_tready	: in STD_LOGIC;

      -- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
      -- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
      s_axis_tvalid	: in STD_LOGIC;
      s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

      -- Joystick and button values read from the module
      jstk_x			: out std_logic_vector(9 downto 0);
      jstk_y			: out std_logic_vector(9 downto 0);
      btn_jstk		: out std_logic;
      btn_trigger		: out std_logic;

      -- LED color to send to the module
      led_r			: in std_logic_vector(7 downto 0);
      led_g			: in std_logic_vector(7 downto 0);
      led_b			: in std_logic_vector(7 downto 0)
   );
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is

   -- Code for the SetLEDRGB command, see the JSTK2 datasheet.
   constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";
   constant DUMMY             : std_logic_vector(7 downto 0) := x"00";
   -- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
   ------------------------------------------------------------

   signal m_axis_tvalid_internal : std_logic;
   signal tick_25us     : std_logic := '0';
   constant CNT_TICK_25US_WIDTH : integer := 23;
   signal cnt_tick_25us : unsigned(CNT_TICK_25US_WIDTH - 1 downto 0);
   signal byte_sent     : std_logic;
   signal waiting       : std_logic := '1';
   constant NUM_25US_CLKS : positive := CLKFREQ/1_000_000*25 + 8*CLKFREQ/SPI_SCLKFREQ; -- minus 2 since sequential logic

   -- read led buffer for command
   signal spi_command_buffer : std_logic_vector(7 downto 0);
   signal spi_sending_state : unsigned (2 downto 0) := "101";
begin
   -- generate 25 us ticks for delays and handle master rdy/vld
   gen_tick : process(aclk) begin
      if rising_edge (aclk) then
          if aresetn = '0' then
             tick_25us     <= '0';
             cnt_tick_25us <= (others => '0');
             waiting       <= '1';
             m_axis_tvalid_internal <= '0';
          else
             if spi_sending_state = "100" and byte_sent = '1' then
                waiting <= '1';
             end if;
             
             if waiting = '1' then
                cnt_tick_25us <= cnt_tick_25us + 1;
             end if;
             
             if cnt_tick_25us = NUM_25US_CLKS then
                tick_25us <= '1';
                cnt_tick_25us <= (others => '0');
                waiting <= '0';
             else
                tick_25us <= '0';
             end if;
             
             if byte_sent = '0' and waiting = '0' then
                m_axis_tvalid_internal <= '1';
             else 
                m_axis_tvalid_internal <= '0';
             end if;
          end if;
      end if;
   end process;
   -- assign byte sending
   byte_sent <= '1' when m_axis_tvalid_internal = '1' and m_axis_tready = '1' else '0';
   
   m_axis_tdata  <= spi_command_buffer;
   m_axis_tvalid <= m_axis_tvalid_internal;
   -- ...
   -- command sending and color acquiring FSM
   -- input mux to the buffer 
   process (aclk) begin
      if rising_edge(aclk) then
          if aresetn ='0' then
             spi_command_buffer <= CMDSETLEDRGB;
             spi_sending_state <= "101";
          else
             if byte_sent = '1' or tick_25us = '1' then
                for i in 3 downto 0 loop
                   spi_command_buffer(i+1) <= spi_command_buffer(i);
                end loop;
                
                if spi_sending_state = "101" and tick_25us =  '1' then -- 101 is waiting
                   spi_sending_state <= "000";
                else
                   spi_sending_state <= spi_sending_state + 1;
                end if;
    
                case spi_sending_state is
                   when "000" =>
                      spi_command_buffer <= led_r;
                   when "001" =>
                      spi_command_buffer <= led_g;
                   when "010" =>
                      spi_command_buffer <= led_b;
                   when "011" =>
                      spi_command_buffer <= (others => '0');
                   when "100" =>
                      spi_command_buffer <= CMDSETLEDRGB; --entering waiting state                   
                   when "101" =>
                      spi_command_buffer <= CMDSETLEDRGB; --entering waiting state  
                   when others =>
                      spi_command_buffer <= (others => '0');
                end case;
             end if;
          end if;
       end if;
   end process;
   
   -- receiving data back
   process(aclk) begin
      if rising_edge(aclk) then
          if aresetn = '0' then
             jstk_x <= (others => '0');
             jstk_y <= (others => '0');
             btn_jstk    <= '0';
             btn_trigger <= '0';
          else 
             if s_axis_tvalid = '1' then
                case spi_sending_state is
                   when "000" =>
                      jstk_x(7 downto 0) <= s_axis_tdata;
                   when "001" =>
                      jstk_x(9 downto 8) <= s_axis_tdata(1 downto 0);
                   when "010" =>
                      jstk_y(7 downto 0) <= s_axis_tdata;
                   when "011" =>
                      jstk_y(9 downto 8) <= s_axis_tdata(1 downto 0);
                   when "100" =>
                      btn_jstk    <= s_axis_tdata(0);
                      btn_trigger <= s_axis_tdata(1);
                   when others =>
                end case;
             end if;
          end if;
      end if;
   end process;
end architecture;
