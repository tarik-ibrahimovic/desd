library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH		: positive := 24;
		VOLUME_WIDTH	: positive := 10;
		VOLUME_STEP_2	: positive := 6;		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND	: integer := 2**23-1;	-- Inclusive
		LOWER_BOUND		: integer := -2**23		-- Inclusive
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

		volume			: in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_controller;

architecture Behavioral of volume_controller is

    signal tvalid_int, tlast_int, tready_int : std_logic; 
    signal tdata_int : std_logic_vector(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0); 
begin

    ist_1 : entity work.volume_multiplier
        generic map (
          TDATA_WIDTH		=> TDATA_WIDTH,
          VOLUME_WIDTH	    => VOLUME_WIDTH,
          VOLUME_STEP_2	    => VOLUME_STEP_2		-- i.e., volume_values_per_step = 2**VOLUME_STEP_2
        )
        port map (
        
            aclk			=> aclk,
            aresetn			=> aresetn,
    
            s_axis_tvalid	=> s_axis_tvalid,
            s_axis_tdata	=> s_axis_tdata,
            s_axis_tlast	=> s_axis_tlast,
            s_axis_tready	=> s_axis_tready, 	
    
            m_axis_tvalid	=> tvalid_int,
            m_axis_tdata	=> tdata_int,
            m_axis_tlast	=> tlast_int,
            m_axis_tready	=> tready_int,
    
            volume			=> volume
        );
        
        
        ist_2 : entity work.volume_saturator
        generic map (
          TDATA_WIDTH		=> TDATA_WIDTH,
          VOLUME_WIDTH	    => VOLUME_WIDTH,
          VOLUME_STEP_2	    => VOLUME_STEP_2,		
          HIGHER_BOUND	    =>  HIGHER_BOUND,	
		  LOWER_BOUND		=> LOWER_BOUND     --!!!!!!!!!!!!!!!!!!!!!!!!!!nota!!!!!!!!!!!!!!!!!!!! hai messo quelli di default dal modulo saturator
        )
        port map (
        
            aclk			=> aclk,
            aresetn			=> aresetn,
    
            s_axis_tvalid	=> tvalid_int,
            s_axis_tdata	=> tdata_int,
            s_axis_tlast	=> tlast_int,
            s_axis_tready	=> tready_int,
    
            m_axis_tvalid	=> m_axis_tvalid,
            m_axis_tdata	=> m_axis_tdata,
            m_axis_tlast	=> m_axis_tlast,
            m_axis_tready	=> m_axis_tready
    

        );

end Behavioral;
