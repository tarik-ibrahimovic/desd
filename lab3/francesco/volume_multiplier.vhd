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

    signal tdata_temp, tdata_temp_reg : signed(TDATA_WIDTH-1 + 2**(VOLUME_WIDTH-VOLUME_STEP_2-1) downto 0);
    signal fill : std_logic_vector(2**(VOLUME_WIDTH-VOLUME_STEP_2-1)-1 downto 0);
    signal N : natural range 0 to 2**VOLUME_WIDTH-1;   
    signal volume_reg : std_logic_vector(VOLUME_WIDTH-1 downto 0);
 --   signal N : signed(VOLUME_WIDTH-1 downto 0);
    signal count : integer range 0 to 1;

	signal full_int	: std_logic;
	signal empty_int : std_logic;
    
    
begin
--espandi, shifta A MNAO
    
    fill            <= (others =>s_axis_tdata(TDATA_WIDTH-1));
    tdata_temp      <= signed(fill & s_axis_tdata);
    
    N               <= to_integer(shift_right(signed(volume_reg), VOLUME_STEP_2));
    m_axis_tdata    <= std_logic_vector(tdata_temp_reg sll N) when volume_reg(VOLUME_WIDTH-1) = '0' else std_logic_vector(tdata_temp_reg srl N);
    
    full_int		<= '1' when count = 1 else '0';
	empty_int		<= '1' when count = 0 else '0';

	s_axis_tready         <= not full_int;
	m_axis_tvalid	      <= not empty_int;
                       
    process(aclk, aresetn)
    	variable is_writing	: std_logic;
		variable is_reading	: std_logic;

    begin
       if aresetn = '0' then
            count <= 0;
                                   
	   elsif rising_edge(aclk) then
            tdata_temp_reg <= tdata_temp; 
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
