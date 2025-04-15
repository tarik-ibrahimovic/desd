---------- DEFAULT LIBRARIES -------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;	-- For LOG **FOR A CONSTANT!!**
------------------------------------

---------- OTHER LIBRARIES ---------
-- NONE
------------------------------------

entity rgb2gray is
	Port (
		clk				: in std_logic;
		resetn			: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(7 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(7 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic
	);
end rgb2gray;

architecture Behavioral of rgb2gray is
    
    constant BYTE_LENGTH : integer := 8;
    
    component division is
      Port ( 
        dividend : in std_logic_vector(8 downto 0); -- 9 bits to match the dimension of color sum
        result : out std_logic_vector(7 downto 0) -- division by 3 reduces the number of bits necessary to rapresent the number (tecnically 7 bits are enough)
      );
    end component;
    
    signal color_selector : unsigned (1 downto 0) := (others => '0'); -- keeps track of the colors arrived
    signal color_sum : unsigned (BYTE_LENGTH downto 0) := (others => '0'); -- sum of colors referred on the same pixel
    
    signal result_r2g : std_logic_vector (BYTE_LENGTH - 1 downto 0) := (others => '0');
    signal dividend_r2g : std_logic_vector (BYTE_LENGTH downto 0) := (others => '0');
    
    signal flag_division : std_logic := '0'; -- tracks when a complete pixel is recived and is ready to be transmitted
    signal flag_transmission : std_logic := '0'; --high if a pixel is waiting to be transitted (should have the same value as m_tvalid)
    signal flag_endOfImage : std_logic := '0';
        
    signal s_axis_tready_signal : std_logic := '1'; --used to read s_axis_tready
    signal m_axis_tlast_signal : std_logic := '0'; --used to read m_axis_tlast
    
begin
    
    division_inst: division -- instance of the divider module
    port map(
        dividend    => dividend_r2g,
        result      => result_r2g
    );
    
    s_axis_tready   <= s_axis_tready_signal;
    m_axis_tlast    <= m_axis_tlast_signal;
    
    color_conversion : process(clk)
    begin
    
        if rising_edge(clk) then
            ---------------------------- syncronous reset
            if resetn = '0' then 
                color_sum           <= (others => '0');
                color_selector      <= (others => '0');
                flag_division       <= '0';
                flag_endOfImage     <= '0';
                dividend_r2g        <= (others => '0');    
            else
            ------------------------------------------   
                flag_division <= '0';
                if s_axis_tvalid = '1' and s_axis_tready_signal = '1' and flag_endOfImage = '0' then
                    ------------------------------------------------color sum increase
                    if color_selector   <= to_unsigned(1,2) then              
                        color_sum       <= color_sum + unsigned(s_axis_tdata);
                        color_selector  <= color_selector + to_unsigned(1,2);
                    ---------------------------------------- 
                    else                                  
                    -------------------------------------pixel recived                      
                        dividend_r2g    <= std_logic_vector(color_sum + unsigned(s_axis_tdata));
                        color_sum       <= (others => '0');
                        color_selector  <= (others => '0');
                        flag_division   <= '1';
                    end if;
                    if s_axis_tlast = '1' then
                        flag_endOfImage <= '1';
                    end if;
                elsif m_axis_tready = '1' and flag_endOfImage = '1' then
                    flag_endOfImage         <= '0';
                end if;
            end if;
        end if;
    
    end process;
    
    Output_logic : process(clk)
    begin
    
        if rising_edge(clk) then
            if resetn = '0' then
                m_axis_tvalid           <= '0';
                s_axis_tready_signal    <= '1';
                m_axis_tlast_signal     <= '0';
                flag_transmission       <= '0';
            else
                if flag_division = '1' then --transmission to tdata
                    if flag_transmission = '0' or (flag_transmission = '1' and m_axis_tready = '1') then -- if previous value has been transimitted
                        m_axis_tdata        <= result_r2g;
                        m_axis_tvalid       <= '1';
                        flag_transmission   <= '1';
                        if flag_endOfImage = '1' then
                            m_axis_tlast_signal <= '1';
                        end if;
                    else -- previous value has not been transmitted, i have to stop accepting data
                        s_axis_tready_signal <= '0';
                    end if;
                elsif m_axis_tready = '1' and flag_transmission = '1' then -- transfer happened
                    m_axis_tvalid           <= '0';
                    flag_transmission       <= '0';
                    m_axis_tlast_signal     <= '0';
                    s_axis_tready_signal    <= '1';
                    if s_axis_tready_signal = '0' then -- stalled data transmission
                        m_axis_tdata        <= result_r2g;
                        m_axis_tvalid       <= '1';
                        flag_transmission   <= '1';
                        if flag_endOfImage = '1' then
                            m_axis_tlast_signal <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    
    end process;
    

end Behavioral;
