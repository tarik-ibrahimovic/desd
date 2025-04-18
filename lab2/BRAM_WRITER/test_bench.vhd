
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity test_bench_prova is

    generic(
        ADDR_WIDTH: POSITIVE :=16
    );
    
--  Port ( 
  
--  );
end test_bench_prova;

architecture Behavioral of test_bench_prova is

component bram_writer is
    generic(
        ADDR_WIDTH: POSITIVE :=16
    );
    port (
        clk   : in std_logic;
        aresetn : in std_logic;

        s_axis_tdata : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        s_axis_tlast : in std_logic;

        conv_addr: in std_logic_vector(ADDR_WIDTH-1 downto 0);
        conv_data: out std_logic_vector(6 downto 0);

        start_conv: out std_logic;
        done_conv: in std_logic;

        write_ok : out std_logic;
        overflow : out std_logic;
        underflow: out std_logic

    );
end component;



--------------------signals---------------

        signal clk   :  std_logic := '0';
        signal aresetn :  std_logic;

        signal s_axis_tdata :  std_logic_vector(7 downto 0);
        signal s_axis_tvalid :  std_logic := '0'; 
        signal s_axis_tready :  std_logic; 
        signal s_axis_tlast : std_logic;

        signal conv_addr: std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        signal conv_data:  std_logic_vector(6 downto 0);

        signal start_conv:  std_logic;
        signal done_conv: std_logic := '0';

        signal write_ok :  std_logic;
        signal overflow :  std_logic;
        signal underflow:  std_logic;
        
        
        type data_array is array (0 to 68535) of std_logic_vector(7 downto 0);
        signal data_to_send : data_array;
        signal cont : unsigned (16 downto 0) := to_unsigned(0, 17);
        
        type addr_array is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal addr_list : addr_array;
        signal count_2 : unsigned (16 downto 0) := to_unsigned (0, 17);
        signal cont_3 : unsigned (1 downto 0) := to_unsigned (0, 2) ;
        
        signal flag : std_logic := '0';
        signal start_conv_flag : std_logic :='0';
        

begin


 dut : bram_writer
     generic map (
        ADDR_WIDTH => 16
    )
    port map  (
        clk   => clk,
        aresetn => aresetn ,

        s_axis_tdata => s_axis_tdata,
        s_axis_tvalid => s_axis_tvalid, 
        s_axis_tready => s_axis_tready, 
        s_axis_tlast => s_axis_tlast,

        conv_addr => conv_addr,
        conv_data =>  conv_data,

        start_conv => start_conv,

        done_conv => done_conv,

        write_ok => write_ok,
        overflow => overflow,
        underflow => underflow

    );
    
    ----------random generation of data to send----------------------
    
    init_data: process
    begin
        for i in 0 to 65534 loop
            data_to_send(i) <= std_logic_vector(to_unsigned(i, 8));
        end loop;
        
        data_to_send(65535) <= std_logic_vector(to_unsigned(6, 8)); --random value
        wait;
    end process;
    
    ---------------------------------------------------------------------
    
        ----------random generation of address that conv requires----------------------
    
    init_addr: process
    begin
        for i in 0 to (2**ADDR_WIDTH)-1 loop
            addr_list(i) <= std_logic_vector(to_unsigned(i, 16));
        end loop;
        wait;
    end process;
    
    ---------------------------------------------------------------------
    
    --------------- clock generator------------
    clk_gen: process
    begin
        clk <= not clk;
        wait for  10ns;
    end process;
        
    -------------------------------------------
    
    --------------- s_axis_tvalid generator------------
    s_axis_tvalid_gen: process (clk)
    begin
    
        if rising_edge(clk)   then 
        
            cont_3 <= cont_3 + 1;
            if s_axis_tvalid = '1' then
                s_axis_tvalid <= '0';  
            elsif std_logic_vector(cont_3) = "11" then
                s_axis_tvalid <= not s_axis_tvalid;
            end if;
            
            
        end if;
        
    end process;
        
    -------------s_axis_tdata_and_tlast  generators -------------------------------------------------
    
    s_axis_tdata_and_tlast_gen: process(clk)
    begin


        
        if rising_edge(clk) then
        
            if s_axis_tvalid = '0' then 
                     s_axis_tdata <= data_to_send(to_integer(cont));
                     s_axis_tlast <= '0';
            end if;

            if s_axis_tready = '1' and s_axis_tvalid = '1' and cont /= to_unsigned(65536, 17) then
                
                if cont = to_unsigned(65534, 17) then
                    s_axis_tlast <= '1';
                    s_axis_tdata <= data_to_send(65535);
                    cont <= cont + 1;
                    
               
                elsif cont = to_unsigned(65535, 17) then
                    s_axis_tlast <= '0';
                    cont <= cont + 1;
                  
                else
                    s_axis_tlast <= '0';
                    cont <= cont + 1;
                    s_axis_tdata <= data_to_send(to_integer(cont+1));
                    
                end if;
                    

            end if;
           
                
        end if;
    end process;
        
    ---------------------------------------------------------------------------------------------------
    
    -------------conv_addr and done_conv generator -------------------------------------------------
    
    k: process (start_conv, start_conv_flag)
    begin
        if rising_edge (start_conv) then
            start_conv_flag <= '1';
        end if;
    end process;
    
    conv_addr_gen: process(clk)
    begin
       
        if rising_edge(clk) then
            if flag = '1' then
                done_conv <= '0';
--                start_conv_flag <= '0';
            end if;
            
                 
            if ( start_conv_flag = '1') and count_2 = to_unsigned(65535, 17 ) and flag /= '1' then
                done_conv <='1';
                flag <= '1' ;
            end if;
            
            if ( start_conv_flag = '1') and count_2 /= to_unsigned(65535, 17 )then
            
                conv_addr <= addr_list (TO_INTEGER(count_2+1));
                count_2 <= count_2 + 1;
                 
            end if;
        end if;
        
    end process;
        
    ---------------------------------------------------------------------------------------------------
    
    -------------aresetn generator -------------------------------------------------
    
    aresetn_gen: process
    begin
       
        aresetn <= '1';
        
--        wait for 2000000 ns;
      
--        aresetn <= '0';
        
--        wait for 17 ns;
        
--        aresetn <= '1';
        
        wait;
        
    end process;
        
    ---------------------------------------------------------------------------------------------------
    
    
    
end Behavioral;
