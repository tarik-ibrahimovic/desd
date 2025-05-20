library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_multiplier is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_multiplier;

architecture Behavioral of volume_multiplier is

    type state_type is (WAIT_D, SEND);
    signal state, next_state : state_type;

    signal N : integer range 0 to 2**(VOLUME_WIDTH-1-VOLUME_STEP_2); --
    signal vol_sig :  std_logic;
    
    
begin    
           
    process(aclk, aresetn)
        variable tdata_temp : std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
        
    begin
        if aresetn = '0' then
            state <= WAIT_D;
                                   
	    elsif rising_edge(aclk) then
	        state <= next_state;
	        
	        case state is
                when WAIT_D =>
	               if s_axis_tvalid = '1' then                    -- loading data
                         m_axis_tlast <= s_axis_tlast;
                         if s_axis_tlast = '1' then-------------------------------------------------------sampling volume
                             N <= to_integer(abs(signed(volume)) + (2**(VOLUME_STEP_2-1)) srl VOLUME_STEP_2);        --only when righ (last) channel's data detected    
                             vol_sig <= volume(volume'left);                                                         --for coherence: i do not want packets with differnt volume among channels 
                                                                                                                     --also sampling volume sign to know shift direction                                                                                
                         end if;
                         if vol_sig = '0' then ------------------------------------------------------------positive volume
                            tdata_temp := (others => s_axis_tdata(s_axis_tdata'left));                          -- filling with MSB
                            tdata_temp(TDATA_WIDTH-1+N downto N) :=  s_axis_tdata;                              --left shifting: multiplication by 2**N
                            tdata_temp(N-1 downto 0) :=  (others => '0');                                       -- manually to zero (to correctly mult. negative values)
                            m_axis_tdata <= tdata_temp;                                                         --!!note!! result truncated (2.5 => 2)
                            
                        else -----------------------------------------------------------------------------negative volume
                            tdata_temp := (others => s_axis_tdata(s_axis_tdata'left));                          -- filling with MSB  
                            tdata_temp(TDATA_WIDTH-N-1 downto 0) :=  s_axis_tdata(TDATA_WIDTH-1 downto N);      --right shifting: division by 2**N           
                            m_axis_tdata <= tdata_temp;                                                         --!!note!! if negative, result is rounded (2.5 => 3)
                                       										-- else truncated
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
