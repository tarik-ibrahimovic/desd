library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity img_conv is
    generic(
        LOG2_N_COLS: POSITIVE :=8;
        LOG2_N_ROWS: POSITIVE :=8
    );
    port (

        clk   : in std_logic;
        aresetn : in std_logic;

        m_axis_tdata : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic; 
        m_axis_tlast : out std_logic;
        
        conv_addr: out std_logic_vector(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);
        conv_data: in std_logic_vector(6 downto 0);

        start_conv: in std_logic;
        done_conv: out std_logic
        
    );
end entity img_conv;

architecture rtl of img_conv is

    
    type conv_mat_type is array(0 to 2, 0 to 2) of integer;
    constant conv_mat : conv_mat_type := ((-1,-1,-1),(-1,8,-1),(-1,-1,-1)); 
    
    constant n_rows : integer := 2**LOG2_N_COLS;
    constant n_cols : integer := 2**LOG2_N_ROWS;
    
    type state_t is (IDLE, RECEIVING, CONV);
    
    signal state, next_state : state_t;
                                                    
    signal bram_addr  : unsigned(LOG2_N_COLS+LOG2_N_ROWS-1 downto 0);
    type window_t is array (0 to 8) of std_logic_vector(6 downto 0);
    signal window    : window_t;
    
    signal cnt        : unsigned(4 downto 0);

    signal row_cnt    : unsigned(LOG2_N_ROWS-1 downto 0);
    signal col_cnt    : unsigned(LOG2_N_COLS-1 downto 0);
    
    type mres_t is array(0 to 8) of signed(12 downto 0);
    signal mres : mres_t := (others => (others => '0'));
    signal sum_all   : signed(12 downto 0); -- -1424 < sum_all < 1424. at least 12 bit + 1 for the sign needed
    signal m_axis_tvalid_int : std_logic;
    signal m_axis_tdata_int : std_logic_vector(7 downto 0);
--    signal conv_data_d : std_logic_vector;

    
begin
    -----parallel multiplier + summer
    mres(0) <= signed('0' & window(0)) * to_signed(conv_mat(0, 0), 5);
    mres(1) <= signed('0' & window(1)) * to_signed(conv_mat(0, 1), 5);
    mres(2) <= signed('0' & window(2)) * to_signed(conv_mat(0, 2), 5);
    mres(3) <= signed('0' & window(3)) * to_signed(conv_mat(1, 0), 5);
    mres(4) <= signed('0' & window(4)) * to_signed(conv_mat(1, 1), 5);
    mres(5) <= signed('0' & window(5)) * to_signed(conv_mat(1, 2), 5);
    mres(6) <= signed('0' & window(6)) * to_signed(conv_mat(2, 0), 5);
    mres(7) <= signed('0' & window(7)) * to_signed(conv_mat(2, 1), 5);
    mres(8) <= signed('0' & window(8)) * to_signed(conv_mat(2, 2), 5);
     
    sum_all <= resize(mres(0), 13) + resize(mres(1), 13) + resize(mres(2), 13)
             + resize(mres(3), 13) + resize(mres(4), 13) + resize(mres(5), 13)
             + resize(mres(6), 13) + resize(mres(7), 13) + resize(mres(8), 13);
             
    
 process(sum_all)--manages overflow
    begin
        if sum_all < to_signed(0, sum_all'length) then
            m_axis_tdata_int <= x"00";
            
        elsif sum_all > to_signed(127, sum_all'length) then
            m_axis_tdata_int <= x"7F";
            
        else
            m_axis_tdata_int <= std_logic_vector(resize(sum_all, 8));
            
        end if;
 end process;
 
  m_axis_tvalid <= m_axis_tvalid_int;
                        
  process(clk, aresetn)
        -- used to manage zero padding
        variable nr, nr_prev : integer range 0 to n_rows - 1; --row indexes  for pixels of conv_mat inside image
        variable nc, nc_prev : integer range 0 to n_cols - 1; --cols indexes  "     "   "       "      "     "
                                                              -- they map where is the desired px inside the image  
        variable drow, dcol : integer range -1 to 1;   --  
        variable idx : integer range 0 to n_rows*n_cols-1;
    begin
        if aresetn = '0' then
            state         <= IDLE;
            conv_addr     <= (others => '0');
            cnt           <= (others => '0');
            row_cnt       <= (others => '0');
            col_cnt       <= (others => '0');
            bram_addr     <= (others => '0');
            m_axis_tvalid_int <= '0';
            m_axis_tdata  <= (others => '0');
            window <= (others => (others => '0'));
            m_axis_tlast <= '0';
            done_conv <= '0';
            
        elsif rising_edge(clk) then
            state <= next_state;

            case state is
                when IDLE =>
                    cnt <= (others => '0');
                    m_axis_tlast <= '0'; 
                    if start_conv = '1' then 
                        done_conv <= '0';
                    end if;
                when RECEIVING =>
                    drow := to_integer(((cnt sll 5) + (cnt sll 3) + (cnt sll 1) + cnt) srl 7); -- drow := to_integer(cnt)/3 - 1;  --technically should not occupy a lot of resources, since 3 is constant and cnt just 5 bits
                    dcol := to_integer(cnt) mod 3 - 1;
                    nr   := to_integer(row_cnt) + drow;
                    nc   := to_integer(col_cnt) + dcol;
                    
                    nr_prev   := to_integer(row_cnt) + to_integer(cnt - 2)/3 - 1;
                    nc_prev   := to_integer(col_cnt) + to_integer(cnt - 2) mod 3 - 1;
                    
                    if not (nr < 0 or nr > n_rows-1 or nc < 0 or nc > n_cols-1) and cnt <= to_unsigned(8, cnt'length) then
                        idx := nr*n_cols + nc;
                        conv_addr <= std_logic_vector(to_unsigned(idx, LOG2_N_COLS+LOG2_N_ROWS));
                    end if;
                    
                    if cnt > to_unsigned(1, cnt'length) then
                        if (nr_prev < 0 or nr_prev > n_rows-1 or nc_prev < 0 or nc_prev > n_cols-1) then
                            window(to_integer(cnt) - 2) <= (others => '0');
                        
                        else
                            window(to_integer(cnt) - 2) <= conv_data;
                                                            
                        end if;    
                    end if;
                    
                    cnt <= cnt + 1;

                when CONV =>
                    m_axis_tvalid_int <= '1';
                    m_axis_tdata  <= m_axis_tdata_int;
                    cnt <= (others => '0');
                    
                    if m_axis_tready = '1' and m_axis_tvalid_int = '1' then
                        m_axis_tvalid_int <= '0';
                        -- advance address and coords
                        if bram_addr < to_unsigned(n_rows*n_cols-1, bram_addr'length) then
                            bram_addr <= bram_addr + 1;
                            if col_cnt = to_unsigned(n_cols-1, col_cnt'length) then
                                col_cnt <= (others=>'0');
                                row_cnt <= row_cnt + 1;
                           
                            else
                                col_cnt <= col_cnt + 1;
                                m_axis_tlast <= '1';
                                
                            end if;
                        else
                            conv_addr <= (others=>'0');
                            row_cnt   <= (others=>'0');
                            col_cnt   <= (others=>'0');
                            done_conv <= '1';
                            
                        end if;
                    end if;
            end case;
        end if;
    end process;

    process(state, start_conv, cnt, bram_addr, m_axis_tready, m_axis_tvalid_int)
    begin
        next_state <= state;
        case state is
            when IDLE =>                 
                if start_conv = '1' then 
                    next_state <= RECEIVING;
                    
                end if;
            when RECEIVING => 
                if cnt = to_unsigned(10, cnt'length) then 
                    next_state <= CONV; 
                    
                end if;
            when CONV =>
                if m_axis_tvalid_int = '1' and m_axis_tready = '1' then
                    if bram_addr < to_unsigned(n_cols*n_rows-1, bram_addr'length) then
                        next_state <= RECEIVING;
                        
                    else
                        next_state <= IDLE;
   
                    end if;
                end if;
        end case;
    end process;
    
    
end architecture;