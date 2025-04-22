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
        dividend    : in std_logic_vector(8 downto 0); -- 9 bits to match the dimension of color sum
        result      : out std_logic_vector(7 downto 0) -- division by 3 reduces the number of bits necessary to rapresent the number (tecnically 7 bits are enough)
      );
    end component;

    signal result_r2g   : std_logic_vector (BYTE_LENGTH - 1 downto 0) := (others => '0');
    signal color_selector : unsigned (1 downto 0) := (others => '0'); -- keeps track of the colors arrived
    signal color_sum : unsigned (BYTE_LENGTH downto 0); -- sum of colors referred on the same pixel
    
    type state_t is (IDLE, SENDING);
    signal state    : state_t;
    
    signal s_axis_tready_internal : std_logic :='1';
    signal next_state             : state_t;
    
    signal flag_division          : std_logic :='0'; --high if a division is complete and waiting to be passed on tdata
    signal flag_endOfImage          : std_logic :='0'; --used to trigger tlast

begin

    division_inst: division -- instance of the divider module
    port map(
        dividend    => std_logic_vector(color_sum),
        result      => result_r2g
    );
    
    
    synchronousLogic : process (clk, resetn) 
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                state    <= IDLE;
                color_selector <= (others => '0');
                color_sum <= (others => '0');
                flag_division <= '0';
                flag_endOfImage <= '0';
                s_axis_tready_internal   <= '1';
            else
                state      <= next_state;
                s_axis_tready_internal   <= '1';
                if state = IDLE then --if state is sending the previous data has not been transmitted
                    flag_division <= '0';
                    m_axis_tdata <= result_r2g;
                end if;
                if m_axis_tready = '1' then 
                    flag_endOfImage <= '0'; --last data transmitted
                end if;
                if m_axis_tready = '0' and s_axis_tready_internal = '0' then --previous data has not been transmitted
                    s_axis_tready_internal   <= '0';
                end if;
                if s_axis_tvalid = '1' and not(flag_division = '1' and state = SENDING) then -- data in valid and division is not full
                    color_selector <= color_selector + 1;
                    if color_selector = 0 then
                        color_sum <= '0' & unsigned(s_axis_tdata);
                    else
                        color_sum <=('0' & unsigned(s_axis_tdata)) + color_sum;
                    end if;
                    if color_selector = 2 then
                        color_selector <= (others => '0');
                        flag_division <= '1';
                        if state = SENDING then --previous data has not been transmitted
                            s_axis_tready_internal   <= '0';
                        end if;
                    end if;
                    if s_axis_tlast = '1' then
                        flag_endOfImage <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    nextStateLogic : process (state, flag_division, m_axis_tready)
    begin
        next_state        <= state;
        case state is 
            when IDLE  =>
                if flag_division = '1' then
                    next_state        <= SENDING;
                end if;
            when SENDING =>
                if m_axis_tready = '1' then
                    next_state <= IDLE;
                end if;
            when OTHERS =>
                next_state <= IDLE;
        end case;
    end process;
    
    outputLogic : process(state, flag_endOfImage)
    begin
        m_axis_tlast <= '0';
        case state is
            when IDLE       =>
                m_axis_tvalid <= '0';
            when SENDING    =>
                m_axis_tvalid <= '1';
                if flag_endOfImage = '1' then
                    m_axis_tlast <= '1';
                end if;
            when OTHERS     => 
                m_axis_tvalid <= '0';
        end case;
    end process;
    
    s_axis_tready <= s_axis_tready_internal;
    
end Behavioral;
