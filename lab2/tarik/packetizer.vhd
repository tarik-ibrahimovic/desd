library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity packetizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic 
        
    );
end entity packetizer;

architecture rtl of packetizer is
    type buf_array_t is array (0 to 1) of STD_LOGIC_VECTOR(7 downto 0);
    signal buf : buf_array_t := (0 => x"00", 1 => x"00");
    type state_t is (IDLE, PASS_THROUGH, ENDING);
    signal state        : state_t := IDLE;

    signal m_axis_tvalid_internal : std_logic;
    signal last_reg     : std_logic;
    signal sending_last : std_logic;
    signal next_state   : state_t;
    signal sent         : std_logic;

    signal buf_empty : std_logic;
begin
    process(aresetn, clk) begin
        if aresetn = '0' then
            state    <= IDLE;
            last_reg <= '0';
            sent     <= '0';
            buf_empty <= '0';
        elsif rising_edge(clk) then
            state   <= next_state;
            
            if m_axis_tvalid_internal = '1' and m_axis_tready = '1' then
                sent <= '1';
                if (state = ENDING and buf(1) /= std_logic_vector(to_unsigned(FOOTER,8))) then
                    sent <= '0';
                end if;
            end if;
            
            if next_state = PASS_THROUGH or next_state = ENDING then
                buf_empty <= '0';
            else 
                buf_empty <= '1';
            end if;

            if s_axis_tvalid = '1' and m_axis_tready = '1' then
                last_reg <= '0';
                sent     <= '0';
                if state = IDLE then
                    buf(0)   <= s_axis_tdata;
                    buf(1)   <= std_logic_vector(to_unsigned(HEADER,8));
                else
                    buf(0)   <= s_axis_tdata;
                    buf(1)   <= buf(0);
                end if;
            end if;

            if state = ENDING and m_axis_tready = '1' then
                buf(0)   <= std_logic_vector(to_unsigned(FOOTER,8));
                buf(1)   <= buf(0);
                last_reg <= '1';
            end if; 
        end if;
    end process;

    process (state, s_axis_tvalid, s_axis_tlast, sent) begin
        next_state <= state;
        case state is 
            when IDLE =>
                if s_axis_tvalid = '1' then
                    next_state <= PASS_THROUGH;
                end if;
            when PASS_THROUGH =>
                if s_axis_tlast = '1' then
                    next_state <= ENDING;
                end if;
            when ENDING =>
                if sent = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;

    m_axis_tdata  <= buf(1);
    s_axis_tready <= '1' when state /= ENDING and m_axis_tready = '1' else '0';
    
    m_axis_tvalid_internal <= '1' when not(state = IDLE) and sent = '0' else '0';
    m_axis_tvalid          <= m_axis_tvalid_internal;
end architecture;