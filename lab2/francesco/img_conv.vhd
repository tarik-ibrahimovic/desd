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
    
    signal cnt        : unsigned(3 downto 0);   -- 0<=cnt<=9+2 where 9 is total number of cells in conv_mat, 
                                                -- +2 is some delay i need in order to assign conv_data to the window 
    signal row_cnt    : unsigned(LOG2_N_ROWS-1 downto 0);  --counts the rows of the image
    signal col_cnt    : unsigned(LOG2_N_COLS-1 downto 0);  -- count the columns of the image
    
    type mres_t is array(0 to 8) of signed(12 downto 0);   -- multiplication result, 13 bits (8+5 : 7 of window + 1 for sign, 5 for conv_mat values)
    signal mres, mres_reg : mres_t := (others => (others => '0')); -- mres_reg: registered mres to split the convolution operation in 2 stages: 
                                                                                                        -- (add) + (multiply and compare)
    signal sum_all   : signed(10 downto 0);                                                 
    signal m_axis_tvalid_int : std_logic;
    signal m_axis_tdata_int : std_logic_vector(7 downto 0);
--    signal conv_data_d : std_logic_vector;

    
begin
    ----------------------------------------------parallel multiplier 
    mres(0) <= signed('0' & window(0)) * to_signed(conv_mat(0, 0), 5);
    mres(1) <= signed('0' & window(1)) * to_signed(conv_mat(0, 1), 5);
    mres(2) <= signed('0' & window(2)) * to_signed(conv_mat(0, 2), 5);
    mres(3) <= signed('0' & window(3)) * to_signed(conv_mat(1, 0), 5);
    mres(4) <= signed('0' & window(4)) * to_signed(conv_mat(1, 1), 5);
    mres(5) <= signed('0' & window(5)) * to_signed(conv_mat(1, 2), 5);
    mres(6) <= signed('0' & window(6)) * to_signed(conv_mat(2, 0), 5);
    mres(7) <= signed('0' & window(7)) * to_signed(conv_mat(2, 1), 5);
    mres(8) <= signed('0' & window(8)) * to_signed(conv_mat(2, 2), 5);
    
    process(clk) begin --registers the multplication result, to split conv operation in two stages:
        if rising_edge(clk) then                            -- 1) multiply
            mres_reg <= mres;                               -- 2) add and manage overflow
            
        end if;
    end process;
    ----------------------------------------------------------------------parallel summer 
    sum_all <= resize(mres_reg(0), 11) + resize(mres_reg(1), 11) + resize(mres_reg(2), 11)
             + resize(mres_reg(3), 11) + resize(mres_reg(4), 11) + resize(mres_reg(5), 11)
             + resize(mres_reg(6), 11) + resize(mres_reg(7), 11) + resize(mres_reg(8), 11);
             
    
 process(sum_all)--combinaroty logic that manages overflow
    begin
        if sum_all(10) = '1'  then
            m_axis_tdata_int <= x"00";
            
        elsif sum_all(9 downto 8) /= "00" then
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
        variable drow, dcol, drow_prev, dcol_prev : integer range -1 to 1;  --row and columns distance in pixel from center of conv_mat to desired pixel:  
        
        variable idx : integer range 0 to n_rows*n_cols-1;  --bram adress of the desired px
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
                    -- this two muxes are used to select the distance in rows as a function of cnt
                    -- cnt counts the pixels asked for convolution  
                    if cnt <= 2 then -- if cnt is {0, 2}, we are in the first row: -1 distance from center row
                        drow := -1;
                    elsif cnt <= 5 then -- center row: cnt is {3, 5}
                        drow := 0;      -- 0 distance
                    else  -- cnt in {6, 8}, last row, distance +1
                        drow := 1;
                    end if;
                    
                    if cnt-2 <= 2 then     -- same for drow_prev, but as a function of cnt-2: 
                        drow_prev := -1;   -- -2 :needed to correctly assign conv_data to the correct window position
                    elsif cnt-2 <= 5 then  -- since idx is assigned 2 clk cicles before conv_data arrives:
                        drow_prev := 0;    -- variable is uptated instantly, at clk pulse i
                    else                   -- conv_addr is committed at clock pulse i, but assigned at i+1
                        drow_prev := 1;    -- conv_data arrives with 1 clk latency from bram, hence at i + 2
                    end if;
                                        
                    dcol := to_integer(cnt) mod 3 - 1;        --mod gives back the remainder of a /3 division
                    dcol_prev := to_integer(cnt-2) mod 3 - 1; --seems heavy as hardware, but it is implemented as a selector too
                    
                    nr   := to_integer(row_cnt) + drow;  --actual row of the desired pixel  |
                    nc   := to_integer(col_cnt) + dcol;  --actual column of the desired px  | => both for the pixel to ask to bram
                    
                    nr_prev   := to_integer(row_cnt) + drow_prev;
                    nc_prev   := to_integer(col_cnt) + dcol_prev;  --same of before, but for the uncoming pixel from bram. note! for the uncoming px
                    
                    if not (nr < 0 or nr > n_rows-1 or nc < 0 or nc > n_cols-1) and cnt <= to_unsigned(8, cnt'length) then -- this means: if desired pixel is not out of the image's borders
                        idx := nr*n_cols + nc;             --actual adress calculation                                        i.e. if the adress exists/is coherent with the actual pixel convolution
                        conv_addr <= std_logic_vector(to_unsigned(idx, LOG2_N_COLS+LOG2_N_ROWS));   --adress sending
                    
                    end if;                    
                    if cnt > "00001" and cnt < "01011" then -- if con > 1 or < 11: i'm assigning conv_data to window with 2 clk cicles delay
                        if (nr_prev < 0 or nr_prev > n_rows-1 or nc_prev < 0 or nc_prev > n_cols-1) then --same condition as before: if out of image borders or not coherent
                            window(to_integer(cnt) - 2) <= (others => '0');                              --zero padding
                        
                        else
                            window(to_integer(cnt) - 2) <= conv_data;         --assigning conv data to the correct window cell
                                                            
                        end if;    
                    end if;
                    
                    cnt <= cnt + 1;

                when CONV =>
                    m_axis_tvalid_int <= '1';              --ready to transfer
                    m_axis_tdata  <= m_axis_tdata_int;     --loading data on the bus
                    cnt <= (others => '0');                     --resetting counter
                    if bram_addr = to_unsigned(n_rows*n_cols-1, bram_addr'length) then
                       m_axis_tlast <= '1';
                       
                    end if;    
                    if m_axis_tready = '1' and m_axis_tvalid_int = '1' then   -- if data transfered
                        m_axis_tvalid_int <= '0';                                      
                        if bram_addr < to_unsigned(n_rows*n_cols-1, bram_addr'length) then   -- advance address and coords
                            bram_addr <= bram_addr + 1;
                            if col_cnt = to_unsigned(n_cols-1, col_cnt'length) then
                                col_cnt <= (others=>'0');
                                row_cnt <= row_cnt + 1;
                           
                            else
                                col_cnt <= col_cnt + 1;                               
                                
                            end if;
                        else --or reset signals when convolution ends
                            conv_addr <= (others=>'0');
                            row_cnt   <= (others=>'0');
                            col_cnt   <= (others=>'0');
                            done_conv <= '1';                           
                            
                        end if;
                    end if;
            end case;
        end if;
    end process;

    process(state, start_conv, cnt, bram_addr, m_axis_tready, m_axis_tvalid_int)  --FSM logic:
    begin                                                       -- 3 states: IDLE: waits for start signal
        next_state <= state;                                    --           RECEIVING: sends adresses and receives data
        case state is                                           --           CONV: charges output bus with one px convolution, waits until data is transfered
            when IDLE =>                 
                if start_conv = '1' then -- starting convolution
                    next_state <= RECEIVING;
                    
                end if;
            when RECEIVING => 
                if cnt = "01011" then --11: 9 conv_mat cells + 2 clk pulses delay: waits for all uncoming pixels to be assigned
                    next_state <= CONV; 
                    
                end if;
            when CONV =>
                if m_axis_tvalid_int = '1' and m_axis_tready = '1' then      --if data transfered
                    if bram_addr < to_unsigned(n_cols*n_rows-1, bram_addr'length) then  -- and if there are still pixels to convolv
                        next_state <= RECEIVING;   --back to receiving
                        
                    else
                        next_state <= IDLE;   --otherwise idle
   
                    end if;
                end if;
        end case;
    end process;
    
    
end architecture;













