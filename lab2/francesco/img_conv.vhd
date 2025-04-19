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
    
    constant n_rows : integer := 2**LOG2_N_ROWS;
    constant n_cols : integer := 2**LOG2_N_COLS;    

     
    signal conv_on : std_logic := '0'; -- 1 on 0 off  
    signal conv_on_delay : std_logic := '0';
    signal conv_on_2delay : std_logic := '0';
    signal conv_on_3delay : std_logic := '0';
    
    signal conv_off : std_logic := '0'; 
    signal conv_off_delay : std_logic := '0';
    
    signal count_rows : unsigned (LOG2_N_ROWS-1 downto 0) := (others => '0') ;
    signal count_cols : unsigned (LOG2_N_COLS-1 downto 0) := (others => '0') ; 
    
    signal adress : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0 ):= (others => '0') ;

    signal adrs_1clk_delay : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0 ):= (others => '0') ;
    signal adrs_2clk_delay : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0 ):= (others => '0') ;
    signal adrs_3clk_delay : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0 ):= (others => '0') ;
    signal adrs_4clk_delay : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0 ):= (others => '0') ;   
    
    signal rows_idx : integer range 0 to 2;  
    signal cols_idx : integer range 0 to 2;  --idx's for cmat 
    
    constant cnv_mat_adrs : conv_mat_type :=   ((-n_cols-1, -n_cols,-n_cols+1),  -- maps adresses from conv_mat to bram storage
                                                (       -1,       0,       +1),  
                                                ( n_cols-1,  n_cols, n_cols+1));
                                                
    signal conv : unsigned (6 downto 0) := (others => '0') ;
    signal px_conv_temp : integer range -1424 to 1424 := 0;
    signal sum_temp : integer range -1424 to 1424 := 0;
    
    signal i_delayed : integer range 0 to 2;
    signal j_delayed : integer range 0 to 2;  
    
    signal i_conv_mat : integer range 0 to 2;
    signal j_conv_mat : integer range 0 to 2; 
    
    signal m_axis_tvalid_int : std_logic := '0'; 
    signal int_fifo_tready: std_logic := '0';
    signal write_tdata : std_logic_vector(7 downto 0) := (others => '0');
    signal int_axis_tlast : std_logic := '0';
    
    --signal conv_on_delay : std_logic := '0';                                       
    
    procedure sweep_idxs (                    -- uptades the idxs to step through cnv_mat_adrs and image's pixels
        i_dim : in integer range 2 to n_rows; --
        j_dim : in integer range 2 to n_cols; -- variable dimensions for zero padding: steps through a submatrix of cnv_mat_adrs
        
        i_conv : inout integer range 0 to 2; --row idx 
        j_conv : inout integer range 0 to 2; --column idx
        
        i_img : inout integer range 0 to n_rows - 1; --row idx 
        j_img : inout integer range 0 to n_cols - 1;
        
        adress : inout unsigned(LOG2_N_ROWS+LOG2_N_COLS-1 downto 0) --adress
        
    ) is
    begin
        if j_conv = j_dim-1 and i_conv = i_dim-1 then
            adress := adress + 1;
            i_conv := 0;
            j_conv := 0;
            
            if j_img =  n_cols - 1 and i_img =  n_rows - 1 then
                i_img := 0;
                j_img := 0;
            
            elsif j_img  = n_cols - 1  then
                j_img  := 0;
                i_img  := i_img  + 1;
        
            else
                j_img  := j_img  + 1;
                
            end if;
            
        elsif j_conv  = j_dim-1 then
            j_conv  := 0;
            i_conv  := i_conv  + 1;
    
        else
            j_conv  := j_conv  + 1;
            
        end if;
    end procedure;                                           



    
begin


fifo_inst : entity work.AXIS_FIFO
        generic map (
            FIFO_WIDTH => 8,
            FIFO_DEPTH => n_rows*n_cols
        )
        port map (
            clk           => clk,
            srst          => aresetn,

            write_tdata   =>  write_tdata,
            write_tvalid  => m_axis_tvalid_int,
            write_tready  => int_fifo_tready,
            write_tlast   => int_axis_tlast,

            read_tdata    => m_axis_tdata,
            read_tvalid   => m_axis_tvalid,
            read_tready   => m_axis_tready,
            read_tlast    => m_axis_tlast
        );


adress_generator: process(clk, aresetn)                -- for each clock cicle generates an address for the bram. 
    variable rows_temp : integer range 0 to 2 := 0;    -- zero padding obtained by not asking adresses to bram *
    variable cols_temp : integer range 0 to 2 := 0;
    
    variable count_rows_temp : integer range 0 to n_rows - 1 := 0;
    variable count_cols_temp : integer range 0 to n_cols - 1 := 0;
    
    variable adress_temp : unsigned (LOG2_N_ROWS+LOG2_N_COLS-1 downto 0) := (others => '0');
    
begin
    if aresetn = '0' then
        conv_addr <= (others => '0');
        rows_idx <= 0;
        cols_idx <= 0;
        adress <= (others => '0');
        rows_temp := 0;
        cols_temp := 0;
        count_rows_temp := 0;
        count_cols_temp := 0;
        adress_temp := (others => '0');
        count_rows <= (others => '0');
        count_cols <= (others => '0');
        i_conv_mat <= 0;
        j_conv_mat <= 0;
        
    elsif rising_edge (clk) then
        if conv_on = '1'and conv_off_delay = '0' then                    
            if count_rows = 0 then 
                if count_cols = 0 then --top-left corner
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx + 1, cols_idx + 1));
                    
                    sweep_idxs(2, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);
                    adress <= adress_temp;     
                    
                    i_conv_mat <= rows_idx + 1;
                    j_conv_mat <= cols_idx + 1;
                  
                elsif count_cols = n_cols-1 then --top right corner
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx + 1, cols_idx));
                        
                    sweep_idxs(2, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);
                    adress <= adress_temp;    
                    
                    i_conv_mat <= rows_idx + 1;
                    j_conv_mat <= cols_idx;
                    
                else --top edge
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx + 1, cols_idx));                                
                    
                    sweep_idxs(2, 3, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    adress <= adress_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);
                    
                    i_conv_mat <= rows_idx + 1;
                    j_conv_mat <= cols_idx;
                    
                end if;
                
            elsif count_rows = n_rows - 1 then
                if count_cols = 0 then --bottom left corner
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx + 1));
                    
                    sweep_idxs(2, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    adress <= adress_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);     
                    
                    i_conv_mat <= rows_idx;
                    j_conv_mat <= cols_idx + 1;
                  
                elsif count_cols = n_cols-1 then --bottoom right corner
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx));
                
                    sweep_idxs(2, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    adress <= adress_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);    
                    
                    i_conv_mat <= rows_idx;
                    j_conv_mat <= cols_idx;
                    
                else --bottom edge
                    conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx));                                
                    
                    sweep_idxs(2, 3, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                    rows_idx <= rows_temp;
                    cols_idx <= cols_temp;
                    adress <= adress_temp;
                    count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                    count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS); 
                    
                    i_conv_mat <= rows_idx;
                    j_conv_mat <= cols_idx;
                                       
                end if;
                
            elsif count_cols = 0 then -- left edge
                conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx + 1));                                
                    
                sweep_idxs(3, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                rows_idx <= rows_temp;
                cols_idx <= cols_temp;
                adress <= adress_temp;
                count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);    
                
                i_conv_mat <= rows_idx;
                j_conv_mat <= cols_idx + 1;
                
            elsif count_cols = n_cols - 1 then -- right edge
                conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx));                                
                    
                sweep_idxs(3, 2, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                rows_idx <= rows_temp;
                cols_idx <= cols_temp;
                adress <= adress_temp;
                count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);
                
                i_conv_mat <= rows_idx;
                j_conv_mat <= cols_idx;
                    
           else  -- not on the edges 
                conv_addr <= std_logic_vector(adress + cnv_mat_adrs(rows_idx, cols_idx)); -- asks bram desired index
                    
                sweep_idxs(3, 3, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
                rows_idx <= rows_temp;
                cols_idx <= cols_temp;
                adress <= adress_temp;
                count_rows <= to_unsigned(count_rows_temp, LOG2_N_ROWS);
                count_cols <= to_unsigned(count_cols_temp, LOG2_N_COLS);         
                
                i_conv_mat <= rows_idx;
                j_conv_mat <= cols_idx;
                                    
           end if;
           
        elsif conv_on = '1'and conv_off_delay = '1' then
            sweep_idxs(3, 3, rows_temp, cols_temp, count_rows_temp, count_cols_temp, adress_temp);
            adress <= adress_temp;
            
        end if;
    
    end if;             
end process;
    
data_stream_manager : process(clk, aresetn) begin
    if aresetn = '0' then
        conv_on <= '0';
        int_axis_tlast <= '0'; 
        conv_off <= '0';
        
    elsif rising_edge(clk) then
        if start_conv = '1' then
            conv_on <= '1'; 
        
        elsif conv_on = '1' and conv_off_delay = '0' then
            if adrs_4clk_delay /= adrs_3clk_delay then  -- here conv triggers to next convolved pixel
                m_axis_tvalid_int <= '1';
                
            elsif  m_axis_tvalid_int = '1' and int_fifo_tready = '1' then --data transfered, tvalid low to avoid transfering same px for two times
                m_axis_tvalid_int <= '0'; 
                
            end if;
             
            if adrs_4clk_delay = to_unsigned(n_rows*n_cols-1,LOG2_N_ROWS+LOG2_N_COLS) then
                int_axis_tlast <= '1';
           
            else
                 int_axis_tlast <= '0';                                            
           
            end if;         
    
            if (count_cols = n_cols - 1 and count_rows = n_rows-1) and (cols_idx = 1 and rows_idx = 1) then --very very last one
                    conv_off <= '1'; 
                    
            end if;
        end if;          
    end if;
end process;   
        
delayer : process(clk) begin
    if rising_edge(clk) then
            i_delayed <= i_conv_mat;
            j_delayed <= j_conv_mat;
              
            conv_off_delay <= conv_off;
            done_conv <= conv_off_delay;
            
            conv_on_delay <= conv_on;
            conv_on_2delay <= conv_on_delay;
            conv_on_3delay <= conv_on_2delay;
            
            adrs_1clk_delay <= adress;
            adrs_2clk_delay <= adrs_1clk_delay;
            adrs_3clk_delay <= adrs_2clk_delay;
            adrs_4clk_delay <= adrs_3clk_delay;
                   
    end if;    
end process;    
         
multiplier : process(clk, aresetn) 
begin
    if aresetn = '0' then
        px_conv_temp <= 0;
    
    elsif rising_edge(clk) then
        if conv_on_2delay = '1' then
            px_conv_temp <= to_integer(unsigned(conv_data)) * conv_mat(i_delayed, j_delayed);   -- rename, for better understanding
                        
        end if;    
    end if;     
end process; 

sum_temp_sampler : process(clk, aresetn) 
begin
    if aresetn = '0' then
        conv <= (others => '0');
        sum_temp <= 0;
        
    elsif rising_edge(clk) then
        if conv_on_3delay = '1' then
            if adrs_4clk_delay /= adrs_3clk_delay then   --  send and overwrite 
                if sum_temp < 0 then
                    conv <= (others => '0');
                    
                elsif sum_temp >= 128 then
                    conv <= to_unsigned(127, conv'length);
                    
                else
                    conv <= to_unsigned(sum_temp, conv'length);
                    
                end if;
                sum_temp <= px_conv_temp;
            
            else                                        --cumulate
                sum_temp <= sum_temp + px_conv_temp;
                --conv <= (others => '0');
                
            end if; 
        end if;               
    end if;

end process;

write_tdata <= '0' & std_logic_vector(conv);

end architecture;






