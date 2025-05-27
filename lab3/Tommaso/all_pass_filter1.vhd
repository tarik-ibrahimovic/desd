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
begin

    s_axis_tready <= m_axis_tready;
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tdata  <= s_axis_tdata;
    m_axis_tlast  <= s_axis_tlast;

end Behavioral;
