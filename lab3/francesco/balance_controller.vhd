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

    type state_type is (WAIT_D, SEND);
    signal state, next_state : state_type;
    
    signal N : natural range 0 to 2**(BALANCE_WIDTH-1-BALANCE_STEP_2);   
    signal bal_sig : std_logic;

begin
    
    process(aclk, aresetn)
        variable tdata_temp : std_logic_vector(TDATA_WIDTH-1 downto 0);
                
    begin
        if aresetn = '0' then
            state <= WAIT_D;
                                   
        elsif rising_edge(aclk) then
            state <= next_state;
            
            case state is
                when WAIT_D =>
                   if s_axis_tvalid = '1' then                    -- loading data
                         m_axis_tlast <= s_axis_tlast;
                         if s_axis_tlast = '1' then
                            N <= to_integer(abs(signed(balance)) + (2**(BALANCE_STEP_2-1)) srl BALANCE_STEP_2);       
                            bal_sig <= balance(balance'left);                                                         
                                                                                                                                               
                         end if;
                         
                         if bal_sig = s_axis_tlast then----------------------------------------------------------- downshifting correct channel
                            tdata_temp := (others => s_axis_tdata(s_axis_tdata'left));                          -- filling with MSB  
                            tdata_temp(TDATA_WIDTH-N-1 downto 0) :=  s_axis_tdata(TDATA_WIDTH-1 downto N);      --right shifting: division by 2**N           
                            m_axis_tdata <= tdata_temp;                                                         --!!note!! result is rounded (2.5 => 3)
                             
                         else
                            m_axis_tdata <= s_axis_tdata;
                            
                         end if;      
                   end if;
                                     
                when SEND =>      
                       
                end case;                   
          end if;
    end process;           
    
    process(state, s_axis_tvalid, m_axis_tready)
    begin
        next_state <= state;
        case state is
            when WAIT_D =>
                m_axis_tvalid <= '0';
                s_axis_tready <= '1'; 
               
                if s_axis_tvalid = '1' then
                    next_state <= SEND;
    
                end if;
    
            when SEND =>
                m_axis_tvalid <= '1';
                s_axis_tready <= '0'; 
                
                if m_axis_tready = '1'then
                    next_state <= WAIT_D;
    
                end if;
        end case;
    end process;
    
end Behavioral;
