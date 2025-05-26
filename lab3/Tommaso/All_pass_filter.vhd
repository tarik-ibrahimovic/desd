library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity all_pass_filter is
    generic (
        TDATA_WIDTH : positive := 24
    );
    port (
        aclk           : in  std_logic;
        aresetn        : in  std_logic;
        s_axis_tvalid  : in  std_logic;
        s_axis_tdata   : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tlast   : in  std_logic;
        s_axis_tready  : out std_logic;
        m_axis_tvalid  : out std_logic;
        m_axis_tdata   : out std_logic_vector(TDATA_WIDTH-1 downto 0);
        m_axis_tlast   : out std_logic;
        m_axis_tready  : in  std_logic
    );
end all_pass_filter;

architecture Behavioral of all_pass_filter is

    signal tvalid_reg : std_logic := '0';
    signal tdata_reg  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal tlast_reg  : std_logic := '0';
    signal ready_now  : std_logic;

begin

    ready_now <= not tvalid_reg or m_axis_tready;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                tvalid_reg <= '0';
                tdata_reg  <= (others => '0');
                tlast_reg  <= '0';
            elsif s_axis_tvalid = '1' and ready_now = '1' then
                tvalid_reg <= '1';
                tdata_reg  <= s_axis_tdata;
                tlast_reg  <= s_axis_tlast;
            elsif m_axis_tready = '1' then
                tvalid_reg <= '0';
            end if;
        end if;
    end process;

    s_axis_tready <= ready_now;
    m_axis_tvalid <= tvalid_reg;
    m_axis_tdata  <= tdata_reg;
    m_axis_tlast  <= tlast_reg;

end Behavioral;