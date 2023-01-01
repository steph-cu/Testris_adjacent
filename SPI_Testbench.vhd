library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPI_TB is 
end entity SPI_TB;

architecture behavioral of SPI_TB is 

	component SPI
		generic(
			word_size : integer;
			clk_div : integer;
			clk_div_size : integer
		);
		port(
			--Inputs
			transmit : in std_logic;
			tx_dat : in std_logic_vector (word_size-1 downto 0);
			sdi : in std_logic;
			
			clk : in std_logic;
			--Outputs
			cs : out std_logic;
			sdo : out std_logic;
			sclk : out std_logic;
			
			read_ack : out std_logic;
			tx_finished : out std_logic;
			rx_dat : out std_logic_vector (word_size-1 downto 0)
		);
	end component;
	
	signal clk, transmit, sdi, cs, sdo, sclk, read_ack, tx_finished : std_logic := '0';
	signal tx_dat, rx_dat : std_logic_vector (7 downto 0);
	
	constant clk_period : time := 20 ns;
	
begin
	uut : SPI
	generic map(
		word_size => 8,
		clk_div => 25,
		clk_div_size => 5
	)
	port map(
		transmit			=> transmit,
		tx_dat 			=> tx_dat,
		sdi 				=> sdi,
		clk 				=> clk,
		cs					=> cs,
		sdo				=> sdo,
		sclk				=> sclk,
		read_ack			=> read_ack,
		tx_finished		=> tx_finished,
		rx_dat			=> rx_dat
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
		wait for clk_period;
		tx_dat <= "10101010";
		wait for clk_period * 10;
		transmit <= '1';
		wait until read_ack = '1';
		tx_dat <= "00000000";
		wait until read_ack = '1';
		tx_dat <= "11111111";
		wait until read_ack = '1';
		transmit <= '0';
		wait until tx_finished = '1';
		wait for clk_period * 500;
		
	end process;
	
	slave_process : process
	begin
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0';	--0
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --1
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --2
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --3
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --4
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --5
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --6
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --7
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --0
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --1
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --2
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --3
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --4
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --5
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '1'; --6
		wait until sclk = '1';
		wait until sclk = '1';
		wait until sclk = '0';
		wait for 10 ns;
		sdi <= '0'; --7
		wait until sclk = '1';

	end process;


end architecture behavioral;