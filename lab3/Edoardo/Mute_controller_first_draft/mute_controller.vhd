library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		mute			: in std_logic
	);
end mute_controller;

architecture Behavioral of mute_controller is

    signal m_axis_tvalid_internal : std_logic;
    signal s_axis_tready_internal : std_logic;

begin

    m_axis_tvalid <= m_axis_tvalid_internal;
    
    process(m_axis_tvalid_internal, m_axis_tready )
    begin
    
        if m_axis_tvalid_internal = '0' then
            s_axis_tready_internal <= '1';
        else
            s_axis_tready_internal <= m_axis_tready;
        end if;
        
    end process;
   
   
   
    process( aclk, aresetn, s_axis_tready_internal )
    begin
        if (aresetn = '0') then
        
            s_axis_tready <= '0';
            
        else
            s_axis_tready <= s_axis_tready_internal;
            
            if rising_edge(aclk) then
                     
                if (s_axis_tvalid = '1' and s_axis_tready_internal = '1') then 
                    
                    m_axis_tdata <= s_axis_tdata;
                    m_axis_tvalid_internal <= '1';
                    m_axis_tlast <= s_axis_tlast;
                    
                    if mute = '1' then
                        m_axis_tdata <= (others => '0');
                    end if;
                
                end if;
                
                if (m_axis_tready = '1' and s_axis_tvalid /= '1') then
                    
                    m_axis_tvalid_internal <= '0';
                
                end if; 
                    
            end if; 
            
        end if;
    
    end process;







end Behavioral;


