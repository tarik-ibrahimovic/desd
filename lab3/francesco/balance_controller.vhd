library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**VOLUME_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is
   signal busy : std_logic;
   signal m_axis_tvalid_internal : std_logic;
   signal balance_internal : std_logic_vector(BALANCE_WIDTH-1 downto 0);
   signal balance_internal_signed : signed(BALANCE_WIDTH-1 downto 0);
   signal balance_internal_unsigned : unsigned(BALANCE_WIDTH-1 downto 0);
   signal N : natural;
   signal selector : std_logic_vector(1 downto 0);
   signal balance_sign : std_logic;
begin
   balance_internal  <= balance;
   balance_internal_signed   <= signed(balance) - 512;
   balance_internal_unsigned <= unsigned(balance_internal_signed);
   N <= to_integer(
        (unsigned(balance_internal) + to_unsigned(2**(BALANCE_WIDTH-1), BALANCE_WIDTH))
        srl BALANCE_STEP_2
     );
   balance_sign <= balance_internal_signed(balance_internal'left);
   selector <= balance_sign & s_axis_tlast;    
   s_axis_tready <= '1' when (busy = '1' and m_axis_tready = '1') or busy ='0' else '0';
   m_axis_tvalid <= m_axis_tvalid_internal;
   
   process(aclk)
      variable tdata_temp : std_logic_vector(TDATA_WIDTH-1 downto 0); 
   begin      
      if rising_edge(aclk) then
         if aresetn = '0' then
            busy <= '0';
            m_axis_tvalid_internal <= '0';
         else
            if busy = '1' and m_axis_tready = '1' then
               m_axis_tvalid_internal <= '0';
               busy <= '0';
            end if;

            if s_axis_tvalid = '1' and (busy = '0' or m_axis_tready = '1') then
               m_axis_tlast  <= s_axis_tlast;
               m_axis_tvalid_internal <= '1';
               busy <= '1';
               case selector is
                  when "00" => --left channel to be decreased
                     tdata_temp := (others => s_axis_tdata(s_axis_tdata'left));                          -- filling with MSB  
                     tdata_temp(TDATA_WIDTH-N-1 downto 0) :=  s_axis_tdata(TDATA_WIDTH-1 downto N);      --right shifting: division by 2**N           
                     m_axis_tdata <= tdata_temp;                               
                  when "01" => --right channel intact
                     m_axis_tdata  <= s_axis_tdata;
                  when "10" => --left channel intact
                     m_axis_tdata  <= s_axis_tdata;
                  when "11" => -- right channel to be decreased
                     tdata_temp := (others => s_axis_tdata(s_axis_tdata'left));                          -- filling with MSB  
                     tdata_temp(TDATA_WIDTH-N-1 downto 0) :=  s_axis_tdata(TDATA_WIDTH-1 downto N);      --right shifting: division by 2**N           
                     m_axis_tdata <= tdata_temp;       
                  when others =>                     
                  end case;
            end if;
         end if;
      end if;
   end process;
end Behavioral;