library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accel_tb is 
end entity accel_tb;

architecture behavioral of accel_tb is 
	component accelerometer is
		port(
			--Inputs
			clk : in std_logic;
			int : in std_logic_vector (2 downto 1);
			SDI : in std_logic;
			
			rst_l : in std_logic;
			--Outputs
			cs : out std_logic;
			sclk : out std_logic;
			SDO : out std_logic;
			
			lane : out std_logic_vector (3 downto 0);
			sample_output : out std_logic_vector (9 downto 0)
		);
	end component;
	
	signal rst_l, clk, SDI, cs, sclk, sdo : std_logic := '0';
	signal int : std_logic_vector (2 downto 1) := "00";
	signal lane : std_logic_vector (3 downto 0);
	signal sample_output : std_logic_vector (9 downto 0);
	
	constant clk_period : time := 20 ns;
	
begin
	accelerometer_module : accelerometer
		port map(
			clk	=> clk,
			int	=> int,
			SDI	=> sdi,
			rst_l => rst_l,
			
			CS		=> cs,
			sclk	=> sclk,
			SDO	=> sdo,
			
			lane	=> lane,
			sample_output => sample_output
		);
		
		
	clk_process : process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;
	
	stm_process : process
	begin
		wait for clk_period * 10;
		rst_l <= '1';
		sdi <= '1';
		wait for clk_period * 3000;
		int(1) <= '1';
		wait for clk_period * 10;
		int(1) <= '0';
		wait for clk_period * 3000;
		int(1) <= '1';
		wait for clk_period * 10;
		int(1) <= '0';
		wait;
		
	end process;

end architecture behavioral;