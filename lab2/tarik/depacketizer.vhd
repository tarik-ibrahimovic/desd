library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity depacketizer is
    generic (
        HEADER: INTEGER :=16#FF#;
        FOOTER: INTEGER :=16#F1#
    );
    port (
        clk     : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata  : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 

        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic; 
        m_axis_tlast  : out std_logic
      );
end entity depacketizer;

architecture rtl of depacketizer is
    -- Declare signals or types here
    type state_t is (IDLE, PASS_THROUGH);
    
    signal state : state_t;
    type buf_array_t is array (0 to 1) of STD_LOGIC_VECTOR(7 downto 0);
    signal buf : buf_array_t;
    signal sent : std_logic; --output is valid until the send req gets turned off

    signal m_axis_tvalid_internal : std_logic;
    signal m_axis_tlast_internal  : std_logic :='0';
    signal next_m_axis_tlast      : std_logic;
    signal next_state             : state_t;
begin
    process (clk, aresetn) begin
        if aresetn = '0' then
            state    <= IDLE;
            buf      <= (others => (others => '0'));
            sent <= '0';
        elsif rising_edge(clk) then
            state      <= next_state;
            m_axis_tlast_internal <= next_m_axis_tlast;
            if s_axis_tvalid = '1' and m_axis_tready = '1' then
                buf(0) <= s_axis_tdata;
                buf(1) <= buf(0);
                sent   <= '0';
            elsif m_axis_tready = '1' and m_axis_tvalid_internal = '1' then
                sent   <= '1';
            end if;
        end if;
    end process;

    process (state, s_axis_tdata, s_axis_tvalid, buf(0), m_axis_tready)
    begin
        next_state        <= state;
        next_m_axis_tlast <= m_axis_tlast_internal;
        case state is 
            when IDLE  =>
                if s_axis_tvalid = '1' and s_axis_tdata = std_logic_vector(to_unsigned(HEADER, 8)) and m_axis_tready = '1' then
                    next_state        <= PASS_THROUGH;
                    next_m_axis_tlast <= '0';
                end if;
            when PASS_THROUGH =>
                if buf(0) = std_logic_vector(to_unsigned(FOOTER,8)) then 
                    next_state   <= IDLE;
                end if;
                if s_axis_tdata = std_logic_vector(to_unsigned(FOOTER,8)) then
                    next_m_axis_tlast <= '1';
                end if;
        end case;
    end process;

    s_axis_tready <= m_axis_tready;
    m_axis_tvalid_internal <= '1' when (buf(0) /= std_logic_vector(to_unsigned(HEADER,8)) and buf(1) /= std_logic_vector(to_unsigned(HEADER,8))  and buf(1) /= std_logic_vector(to_unsigned(FOOTER,8))) and state = PASS_THROUGH and sent = '0' else '0';
    m_axis_tvalid <= m_axis_tvalid_internal;
    m_axis_tlast  <= m_axis_tlast_internal;
    m_axis_tdata  <= buf(1);
    
end architecture;
