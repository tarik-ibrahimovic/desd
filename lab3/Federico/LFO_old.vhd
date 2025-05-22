    library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.all;

entity LFO is
    generic(
        CHANNEL_LENGHT  : integer := 24;
        JOYSTICK_LENGHT  : integer := 10;
        CLK_PERIOD_NS   : integer := 10;
        TRIANGULAR_COUNTER_LENGHT    : integer := 10 -- Triangular wave period length
    );
    Port (
        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            lfo_period      : in std_logic_vector(JOYSTICK_LENGHT-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGHT-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

    constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000; -- Base period of the LFO counter in us (when the joystick is at the center)    
    constant ADJUSTMENT_FACTOR : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position   
    constant clk_us : integer := natural(ceil(real(1000/CLK_PERIOD_NS))); --number of clock cycles per us (100 for T = 10ns)
    constant LFO_COUNTER_BASE_PERIOD : integer := LFO_COUNTER_BASE_PERIOD_US * clk_us;
    constant LFO_COUNTER_LENGTH : integer :=natural(ceil(log2(real(LFO_COUNTER_BASE_PERIOD + (ADJUSTMENT_FACTOR * 512))))); -- number of bits necessary for lfo_period_int to not overflow

    
    -------------------------LFO signals--------------------------------------
    
    signal TRIANGULAR_COUNTER : unsigned(TRIANGULAR_COUNTER_LENGHT - 1 downto 0) := (others => '0'); 
    signal TRIANGULAR_COUNTER_LEFT : unsigned(TRIANGULAR_COUNTER_LENGHT - 1 downto 0) := (others => '0'); --used to scale both stereo channels by the same amount
    signal lfo_period_internal : unsigned(LFO_COUNTER_LENGTH - 1 downto 0) := to_unsigned(LFO_COUNTER_BASE_PERIOD_US, LFO_COUNTER_LENGTH);
    signal counter_clk_cycles : unsigned(LFO_COUNTER_LENGTH - 1 downto 0) := (others => '0'); 

    
    signal lfo_direction : std_logic := '0'; -- '0' = up   '1' = down
    
    type state_type is (RESET, WAITING_DATA, MULTIPLICATION, TRANSMISSION);
    signal state : state_type := WAITING_DATA;
    signal next_state : state_type := WAITING_DATA;
    
    signal mult_out : signed(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 1 downto 0) := (others => '0');
    signal mult_out_extendend : signed(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT downto 0) := (others => '0');


begin  

    LFO_generator: process(aclk, aresetn)
    begin
        if aresetn = '0' then
            TRIANGULAR_COUNTER <= (others => '0');
            counter_clk_cycles <= to_unsigned(1, LFO_COUNTER_LENGTH);
            lfo_period_internal <= to_unsigned(LFO_COUNTER_BASE_PERIOD, LFO_COUNTER_LENGTH); 
            lfo_direction <= '0';
        elsif rising_edge(aclk) then
            if counter_clk_cycles < lfo_period_internal then
                counter_clk_cycles <= counter_clk_cycles + 1;
            else
                counter_clk_cycles <= to_unsigned(1, LFO_COUNTER_LENGTH);
                if lfo_direction = '0' then
                    TRIANGULAR_COUNTER <= TRIANGULAR_COUNTER + 1;
                else
                    TRIANGULAR_COUNTER <= TRIANGULAR_COUNTER - 1;
                end if;
                if (TRIANGULAR_COUNTER = 1 and lfo_direction = '1') or  (TRIANGULAR_COUNTER = (2**TRIANGULAR_COUNTER_LENGHT) - 2 and lfo_direction = '0') then
                    lfo_direction <= not(lfo_direction);
                end if;
                lfo_period_internal <= to_unsigned(LFO_COUNTER_BASE_PERIOD - (ADJUSTMENT_FACTOR * TO_INTEGER(signed(lfo_period))), LFO_COUNTER_LENGTH);
            end if;
        end if;
    end process;
    
        
    stateLogic : process(state, s_axis_tvalid)
    begin
        next_state <= state;
        case state is
            when WAITING_DATA =>
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                if s_axis_tvalid = '1' then --data acquired at the end of the clock cycle
                    if lfo_enable = '1' then
                        next_state <= MULTIPLICATION;
                        if s_axis_tlast = '0' then
                            TRIANGULAR_COUNTER_LEFT <= TRIANGULAR_COUNTER; --updated only on the left channel to have coherent counter
						end if;
                    else
                        next_state <= TRANSMISSION;
                    end if;
                end if;
            when MULTIPLICATION =>
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
                next_state <= TRANSMISSION; 
            when TRANSMISSION =>
                s_axis_tready <= '0';
                m_axis_tvalid <= '1';  
                if m_axis_tready = '1' then --data transmitted at the end of the clock cycle
                    next_state <= WAITING_DATA;
                end if;
            when others => --RESET
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
                TRIANGULAR_COUNTER_LEFT <= TRIANGULAR_COUNTER;
                next_state <= WAITING_DATA;
        end case;
    end process;
    
    synchronousLogic : process(aclk, aresetn)
    begin
        if aresetn = '0' then
            state <= RESET;
        elsif rising_edge(aclk) then
            state <= next_state;
            
            case state is
                when WAITING_DATA =>
                    if s_axis_tvalid = '1' then --data acquisition
                        m_axis_tlast <= s_axis_tlast; 
                        if lfo_enable = '1' then
						  mult_out_extendend <= signed(s_axis_tdata) * signed('0' & TRIANGULAR_COUNTER_LEFT); --added 0 to triangular_counter to avoid considering it negative
						else
						  m_axis_tdata <= s_axis_tdata;
						end if;
                    end if;
                when MULTIPLICATION =>
                    m_axis_tdata <= std_logic_vector(mult_out(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 1 downto TRIANGULAR_COUNTER_LENGHT));
                when others =>
            end case;
        end if;
    end process;
    
    mult_out <= (mult_out_extendend(mult_out_extendend'LEFT) & mult_out_extendend(CHANNEL_LENGHT + TRIANGULAR_COUNTER_LENGHT - 2 downto 0)); --resize, the bit after the sign is removed
    
end architecture;