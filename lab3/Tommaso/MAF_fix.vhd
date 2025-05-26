library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity moving_average_filter is
    generic (
        FILTER_ORDER_POWER : integer := 5; -- filtro su 2^5 = 32 campioni
        TDATA_WIDTH        : positive := 24
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
        m_axis_tready  : in  std_logic;

        
    );
end moving_average_filter;

architecture rtl of moving_average_filter is

    constant FILTER_LEN      : integer := 2 ** FILTER_ORDER_POWER;
    constant ACC_WIDTH       : integer := TDATA_WIDTH + FILTER_ORDER_POWER;

    type buffer_type is array (0 to FILTER_LEN-1) of signed(TDATA_WIDTH-1 downto 0);

    signal buffer_L : buffer_type := (others => (others => '0'));
    signal buffer_R : buffer_type := (others => (others => '0'));
    signal wr_ptr_L : integer range 0 to FILTER_LEN-1 := 0;
    signal wr_ptr_R : integer range 0 to FILTER_LEN-1 := 0;

    signal sum_L : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal sum_R : signed(ACC_WIDTH-1 downto 0) := (others => '0');

    signal sample_in  : signed(TDATA_WIDTH-1 downto 0);
    signal sample_out : signed(TDATA_WIDTH-1 downto 0);
    signal tlast_reg  : std_logic := '0';
    signal valid_reg  : std_logic := '0';

begin

    process(aclk)
    variable v_sum_L : signed(ACC_WIDTH-1 downto 0);
    variable v_sum_R : signed(ACC_WIDTH-1 downto 0);
    variable v_sample_in : signed(TDATA_WIDTH-1 downto 0);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            wr_ptr_L   <= 0;
            wr_ptr_R   <= 0;
            sum_L      <= (others => '0');
            sum_R      <= (others => '0');
            valid_reg  <= '0';
            tlast_reg  <= '0';
            sample_out <= (others => '0');
        elsif s_axis_tvalid = '1'  then
            v_sample_in := signed(s_axis_tdata);

            
                if s_axis_tlast = '0' then -- Canale sinistro
                    v_sum_L := sum_L - resize(buffer_L(wr_ptr_L), ACC_WIDTH) + resize(v_sample_in, ACC_WIDTH);
                    buffer_L(wr_ptr_L) <= v_sample_in;
                    wr_ptr_L <= (wr_ptr_L + 1) mod FILTER_LEN;
                    sample_out <= resize(shift_right(v_sum_L, FILTER_ORDER_POWER), TDATA_WIDTH);
                    sum_L <= v_sum_L;
                    tlast_reg <= '0';
                else -- Canale destro
                    v_sum_R := sum_R - resize(buffer_R(wr_ptr_R), ACC_WIDTH) + resize(v_sample_in, ACC_WIDTH);
                    buffer_R(wr_ptr_R) <= v_sample_in;
                    wr_ptr_R <= (wr_ptr_R + 1) mod FILTER_LEN;
                    sample_out <= resize(shift_right(v_sum_R, FILTER_ORDER_POWER), TDATA_WIDTH);
                    sum_R <= v_sum_R;
                    tlast_reg <= '1';
                end if;
            
            valid_reg <= '1';
        elsif m_axis_tready = '1' then
            valid_reg <= '0';
        end if;
    end if;
end process;
    s_axis_tready <= '1'; -- sempre pronto a ricevere
    m_axis_tvalid <= valid_reg;
    m_axis_tdata  <= std_logic_vector(sample_out);
    m_axis_tlast  <= tlast_reg;

end rtl;
