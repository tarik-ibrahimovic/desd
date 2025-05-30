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
    
    -- The following process is in charge of the s_axis_tready signal.
    -- The mute controller is ready to receive new data (which means s_axis_tready is one) in two cases :
    -- if it doesn't have any valid data to send yet(m_axis_tvalid_internal = '0') and so it needs to receive new data
    -- or if it has valid data to send (m_axis_tvalid = '1') AND it is sending the old away data to then next module (m_axis_tready = '1').
    -- If, instead, the mute_controller has valid data to send (m_axis_tvalid = '1'), but it is NOT sending it then next module (m_axis_tready = '0'), then it isn't ready to receive new data (s_axis_tready is zero).

    process(m_axis_tvalid_internal, m_axis_tready )
    begin
    
        if m_axis_tvalid_internal = '0' then
            s_axis_tready_internal <= '1';
        else
            s_axis_tready_internal <= m_axis_tready;
        end if;
        
    end process;
   
   
    -- The following process is in charge of receiving the data from the slave axis interface and to send it away from the master axis interface.
    -- If mute = '1' then the data sent is composed only of zeros.
    -- The process manages also the reset.
   
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


