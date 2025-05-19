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
    
    signal s_ready : std_logic;
	signal m_valid, m_axis_valid_reg : std_logic;
	
	signal tdata_reg : std_logic_vector(TDATA_WIDTH-1 downto 0);
    signal s_axis_tlast_reg : std_logic;
    
    signal count : integer range 0 to 1;

	signal full_int	: std_logic;
	signal empty_int : std_logic;
	
begin

 process(s_axis_tdata)--combinaroty logic, manages overflow
    begin
        if signed(s_axis_tdata) <= HIGHER_BOUND and signed(s_axis_tdata) >= LOWER_BOUND then
            tdata_reg <= s_axis_tdata(s_axis_tdata'left) & s_axis_tdata(TDATA_WIDTH-2 downto 0);
            
        elsif signed(s_axis_tdata) <= 0 then
            tdata_reg <= std_logic_vector(to_signed(HIGHER_BOUND, TDATA_WIDTH));
            
        else
             tdata_reg <= std_logic_vector(to_signed(LOWER_BOUND, TDATA_WIDTH));
            
        end if;
 end process;
 
    full_int		<= '1' when count = 1 else '0';
	empty_int		<= '1' when count = 0 else '0';

	s_axis_tready         <= not full_int;
	m_axis_tvalid	        <= not empty_int;
                       
    process(aclk, aresetn)
    	variable is_writing	: std_logic;
		variable is_reading	: std_logic;

    begin
       if aresetn = '0' then
            count <= 0;
                                   
	   elsif rising_edge(aclk) then
            m_axis_tdata <= tdata_reg; 
            m_axis_tlast <= s_axis_tlast;          
    
            is_writing	:= s_axis_tvalid and not full_int; 
            is_reading	:= m_axis_tready and not empty_int; 
                       
            if is_writing = '1' and is_reading = '0' then
                count <= count + 1;
                
            elsif is_writing = '0' and is_reading = '1' then
                count <= count - 1;
                
            end if;
            
        end if;
	end process;           

 
end Behavioral;
