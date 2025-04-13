library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- try to include dpi c
entity tb is
end tb;

architecture testbench of tb is
   component depacketizer is
      generic (
         HEADER: INTEGER :=16#FF#;
         FOOTER: INTEGER :=16#F1#
      );
      port(
         clk   : in std_logic;
         aresetn : in std_logic;

         s_axis_tdata : in std_logic_vector(7 downto 0);
         s_axis_tvalid : in std_logic; 
         s_axis_tready : out std_logic; 

         m_axis_tdata : out std_logic_vector(7 downto 0);
         m_axis_tvalid : out std_logic; 
         m_axis_tready : in std_logic; 
         m_axis_tlast : out std_logic
      );
   end component depacketizer;


   component packetizer is
      generic (
         HEADER: INTEGER :=16#FF#;
         FOOTER: INTEGER :=16#F1#
      );
      port(
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
   end component packetizer;

   signal clk     : std_logic;
   signal aresetn : std_logic;

   signal s_axis_tdata  : std_logic_vector (7 downto 0);
   signal s_axis_tvalid : std_logic;
   signal s_axis_tready : std_logic;
   
   signal m_axis_tdata  : std_logic_vector (7 downto 0);
   signal m_axis_tvalid : std_logic;
   signal m_axis_tready : std_logic;
   signal m_axis_tlast  : std_logic;

   constant HEADER : integer := 16#FF#;
   constant FOOTER : integer := 16#F1#;
   type send_axis_t is array (5 downto 0) of std_logic_vector(7 downto 0);
   signal send_axis : send_axis_t := (
      0 => x"FF",
      1 => x"04",
      2 => x"03",
      3 => x"02",
      4 => x"01",
      5 => x"F1"
   );
   signal send_count : integer;
   
begin
   clk <= not clk after 5 ns;

   process begin
      aresetn <= '0';
      wait for 100 ns;
      aresetn <= '1';
      wait for 100 ns;
      wait;
   end process;

   depacketizer_inst: entity work.depacketizer
    generic map(
       HEADER => HEADER,
       FOOTER => FOOTER
   )
    port map(
       clk           => clk,
       aresetn       => aresetn,
       s_axis_tdata  => s_axis_tdata,
       s_axis_tvalid => s_axis_tvalid,
       s_axis_tready => s_axis_tready,
       m_axis_tdata  => m_axis_tdata,
       m_axis_tvalid => m_axis_tvalid,
       m_axis_tready => m_axis_tready,
       m_axis_tlast  => m_axis_tlast
   );

   process (clk, aresetn) begin
      --axis simulation
      if aresetn = '0' then
         send_count <= 0;
      elsif aresetn = '1' then
         if rising_edge(clk) then
            if send_count /= 6 then
               send_count <= send_count + 1;
               s_axis_tdata <= send_axis(send_count);
            end if;
         end if;
      end if;
   end process;


   end testbench;
