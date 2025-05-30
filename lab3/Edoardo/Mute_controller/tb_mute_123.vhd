library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity tb_mute_123 is
    	Generic (
		TDATA_WIDTH		: positive := 24
	);
--  Port ( );
end tb_mute_123;

architecture Behavioral_123 of tb_mute_123 is




component mute_controller is



	Generic (
		TDATA_WIDTH		: positive := 24
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		mute			: in std_logic
	);
end component mute_controller;

	signal	aclk			:  std_logic := '0';
	signal	aresetn			:  std_logic := '1';

	signal	s_axis_tvalid	:  std_logic := '0';
	signal	s_axis_tdata	:  std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
	signal	s_axis_tlast	:  std_logic := '0';
	signal	s_axis_tready	:  std_logic;

	signal	m_axis_tvalid	:  std_logic;
	signal	m_axis_tdata	: std_logic_vector(TDATA_WIDTH-1 downto 0);
	signal	m_axis_tlast	:  std_logic;
	signal	m_axis_tready	:  std_logic := '1';

	signal	mute			: std_logic := '0';
	
	------------auxiliar signals------------
	
	signal flag : unsigned (4 downto 0) := (others => '0');


begin


    dut_123: mute_controller
	Generic Map(
		TDATA_WIDTH => 24
	)
	Port Map (
		aclk => aclk,
		aresetn	=> aresetn,

		s_axis_tvalid => s_axis_tvalid,
		s_axis_tdata => s_axis_tdata,
		s_axis_tlast =>	s_axis_tlast,
		s_axis_tready =>	s_axis_tready,

		m_axis_tvalid =>	m_axis_tvalid,
		m_axis_tdata =>	m_axis_tdata,
		m_axis_tlast =>	m_axis_tlast,
		m_axis_tready =>	m_axis_tready,

		mute => mute);
		
		-------------clk_gen------------------------------
		clk : process
		begin
		      wait for 10 ns;
		      aclk <= not aclk;
		
		end process;
		
	    --------------------s_axis_tdata_gen and s_axis_tvalid and tlast-------------
		due: process(aclk)
		begin  
		  if (rising_edge(aclk)) then 
		      
		      flag <= flag + to_unsigned (1, 5);
		      
		      if flag = to_unsigned (3, 5) then 
		      
                  s_axis_tdata(TDATA_WIDTH-1) <= '1';
                  s_axis_tdata(TDATA_WIDTH-2) <= '1';
                  s_axis_tdata(TDATA_WIDTH-3) <= '1';
                  s_axis_tdata(TDATA_WIDTH-4) <= '1';
                  s_axis_tvalid <= '1';
--                  mute <= '1';
              end if;
              
              if flag = to_unsigned (4, 5) then 
		      
                  s_axis_tdata(TDATA_WIDTH-1) <= '0';
                  s_axis_tdata(TDATA_WIDTH-2) <= '0';
                  s_axis_tdata(TDATA_WIDTH-3) <= '0';
                  s_axis_tdata(TDATA_WIDTH-4) <= '0';
                  s_axis_tdata(0) <= '1';
                  s_axis_tdata(1) <= '1';
                  s_axis_tdata(2) <= '1';
                  s_axis_tdata(3) <= '1';
                  s_axis_tlast <= '1';
--                  mute <= '0';
              end if;
              
             if flag = to_unsigned (5, 5) then 
		      
                  s_axis_tdata <= (others => '0');
                  s_axis_tvalid <= '0';
                  s_axis_tlast <= '0';
              end if;
                        
          end if;           
		  
		end process;
		
		---------------------------------------------------
		
		
		--------------------m_axis_tready gen----------------
		
--		paguro: process
--		begin 
		      
--		      wait for 1 ns;
--		      m_axis_tready <= '0';
		      
--		      wait for 17 ns;
		      
--		      m_axis_tready <= '1';
		      
--		      wait for 17 ns;
		      
--		      m_axis_tready <= '0';
		  
		
--		end process;
		
		--------------------------------------------------
		
		
		---------------aresetn gen--------------
		ci: process
		begin
		  wait for 3 ns;
		  aresetn <='0';
		  
		  wait for 5 ns;
		  
		  aresetn <='1';
		  wait for 37 ns;
		  
		  aresetn <='0';
		  
		  wait for 3 ns;
		  
		  aresetn <= '1';
		  
		  wait;
		
		end process;
		--------------------------------------
		

end Behavioral_123;

