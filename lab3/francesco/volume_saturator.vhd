library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_saturator is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., number_of_steps = 2**(VOLUME_STEP_2)
		HIGHER_BOUND	: integer := 2**15-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**15		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic
	);
end volume_saturator;

architecture Behavioral of volume_saturator is

    type state_type is (WAIT_D, SEND);
    signal state, next_state : state_type;


	
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
                         --------------------------------------------------------------------------------------managing overflow
                         if signed(s_axis_tdata) <= HIGHER_BOUND and signed(s_axis_tdata) >= LOWER_BOUND then
                            m_axis_tdata <= s_axis_tdata(s_axis_tdata'left) & s_axis_tdata(TDATA_WIDTH-2 downto 0);
                            
                         else
                            if signed(s_axis_tdata) > 0 then
                                m_axis_tdata <= std_logic_vector(to_signed(HIGHER_BOUND, TDATA_WIDTH));
                                
                            else
                                 m_axis_tdata <= std_logic_vector(to_signed(LOWER_BOUND, TDATA_WIDTH));
                                
                            end if;
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
