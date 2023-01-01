library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.tetris_types.all;

entity accelerometer_test_top is
	port(
		-- clock
		ADC_CLK_10 : in std_logic;
		MAX10_CLK1_50 : in std_logic;
		MAX10_CLK2_50 : in std_logic;
		-- 7 segment display
		HEX0 : out unsigned (7 downto 0);
		HEX1 : out unsigned (7 downto 0);
		HEX2 : out unsigned (7 downto 0);
		HEX3 : out unsigned (7 downto 0);
		HEX4 : out unsigned (7 downto 0);
		HEX5 : out unsigned (7 downto 0);
		-- buttons
		KEY : in std_logic_vector (1 downto 0);
		-- LEDs
		LEDR : out std_logic_vector (9 downto 0);
		-- Switches
		SW : in std_logic_vector (9 downto 0);
		-- VGA
		VGA_B : out std_logic_vector (3 downto 0);
		VGA_G : out std_logic_vector (3 downto 0);
		VGA_R : out std_logic_vector (3 downto 0);
		VGA_HS : out std_logic;
		VGA_VS : out std_logic;
		-- Accelerometer
		GSENSOR_CS_N : out std_logic;
		GSENSOR_INT : in std_logic_vector (2 downto 1);
		GSENSOR_SCLK : out std_logic;
		GSENSOR_SDI : inout std_logic;
		GSENSOR_SDO : in std_logic;
		-- Arduino Header
		ARDUINO_IO : inout std_logic_vector (15 downto 0);
		ARDUINO_RESET_N : inout std_logic
	);
end entity accelerometer_test_top;

architecture behavioral of accelerometer_test_top is
	
-- begin stephen top
	
	--signal falling : std_logic_vector (5 downto 0);
	signal end_falling : std_logic_vector (125 downto 0);
	signal start_falling : std_logic_vector (125 downto 0);
	--signal staying : std_logic_vector (125 downto 0);
	--signal changing_color : std_logic_vector (2 downto 0);
	signal changing_location : std_logic_vector (6 downto 0);
	
	signal rng_color : std_logic_vector (2 downto 0);
	signal sr_state : std_logic_vector (1 downto 0);
	signal falling : place;
	signal staying : place;
	signal changing_color : tetris_block_array;
	signal score1 : std_logic_vector (3 downto 0);
	signal score2 : std_logic_vector (3 downto 0);
	signal score3 : std_logic_vector (3 downto 0);
	signal score4 : std_logic_vector (3 downto 0);
	signal score5 : std_logic_vector (3 downto 0);
	signal score6 : std_logic_vector (3 downto 0);
	signal sound_trigger : std_logic;
	signal sound_type : std_logic_vector (1 downto 0);
	
	signal pretend_falling : place := (others => (others => '0'));
	signal x_loc : integer := 0;
	signal y_loc : integer := 0;
	signal count : integer := 0;
	signal stop : integer := 10000000;
	
	component Gameplay is 
	port(
		clk : in std_logic; -- main clk 
		lane : in std_logic_vector (9 downto 0); -- want something from accelorometer
		start : in std_logic; -- start button 
		rst_l : in std_logic; -- rst button 
		score_display1 : out std_logic_vector (3 downto 0);-- score, this needs to get to vga_tetris
		score_display2 : out std_logic_vector (3 downto 0);
		score_display3 : out std_logic_vector (3 downto 0);
		score_display4 : out std_logic_vector (3 downto 0);
		score_display5 : out std_logic_vector (3 downto 0);
		score_display6 : out std_logic_vector (3 downto 0);
		falling : out place;
		stays_out : out place;
		staying_color_out : out tetris_block_array;
		rng_color : out std_logic_vector (2 downto 0);
		start_reset_state : out std_logic_vector (1 downto 0); -- get to vga_tetris, needed to tell what state we are in (00 reset, 01 startNewBrick, 11 progressing, 10 gameover)
		sound_type : out std_logic_vector (1 downto 0); -- 00 is landing, 01 is left right, 11 is patterned, 10 is gameover
		sound_trigger : out std_logic
	);
	end component;
	component vga_tetris is 
	port(
		clk : in std_logic;
		rst_l : in std_logic;
		start : in std_logic;
		falling : in place;
		staying : in place;
		staying_color_in : in tetris_block_array; -- the stay location color change 
		rng_color : in std_logic_vector (2 downto 0); -- the random color that is the falling square
		vgab : out std_logic_vector (3 downto 0);
		vgag : out std_logic_vector (3 downto 0);
		vgar : out std_logic_vector (3 downto 0);
		vgahs : out std_logic;
		vgavs : out std_logic;
		sr_states : in std_logic_vector (1 downto 0);
		x1 : in std_logic_vector (3 downto 0);
		x2 : in std_logic_vector (3 downto 0);
		x3 : in std_logic_vector (3 downto 0);
		x4 : in std_logic_vector (3 downto 0);
		x5 : in std_logic_vector (3 downto 0);
		x6 : in std_logic_vector (3 downto 0)
	);
	end component;
	
-- end stephen top
	
	component reset_delay is
		port(
			iRSTN : in std_logic;
			iCLK : in std_logic;
			oRST : out std_logic
		);
	end component;
	
	component spi_pll is
		port(
			areset : in std_logic;
			inclk0 : in std_logic;
			c0 : out std_logic;
			c1 : out std_logic
		);
	end component;
	
	component spi_ee_config is
		port(
			iRSTN : in std_logic;
			iSPI_CLK : in std_logic;
			iSPI_CLK_OUT : in std_logic;
			iG_INT2 : in std_logic;
			oDATA_L : out std_logic_vector (7 downto 0);
			oDATA_H : out std_logic_vector (7 downto 0);
			SPI_SDIO : inout std_logic;
			oSPI_CSN : out std_logic;
			oSPI_CLK : out std_logic
		);
	end component;
	
	component led_driver is
		port(
			iRSTN : in std_logic;
			iCLK : in std_logic;
			iDIG : in std_logic_vector (9 downto 0);
			iG_INT2 : in std_logic;
			oLED : out std_logic_vector
		);
	end component;
	
	signal dly_rst, spi_clk, spi_clk_out : std_logic;
	signal data_x : std_logic_vector (15 downto 0);
begin


	VISUAL : vga_tetris
	port map(
		clk => MAX10_CLK1_50,
		rst_l => KEY(0),
		start =>KEY(1),
		falling => falling,
		staying => staying,
		staying_color_in => changing_color, -- the stay location color change 
		rng_color => rng_color, -- the random color that is the falling square
		vgab => VGA_B,
		vgag => VGA_G,
		vgar => VGA_R,
		vgahs => VGA_HS,
		vgavs => VGA_VS,
		sr_states => sr_state,
		x1 => score1,
		x2 => score2,
		x3 => score3,
		x4 => score4,
		x5 => score5,
		x6 => score6
	);
	
	GAME : Gameplay
	port map(
		clk => ADC_CLK_10, -- main clk 
		lane => data_x(9 downto 0), -- want something from accelorometer
		start => KEY(1), -- start button 
		rst_l => KEY(0), -- rst button 
		score_display1 => score1,-- score, this needs to get to vga_tetris
		score_display2 => score2,
		score_display3 => score3,
		score_display4 => score4,
		score_display5 => score5,
		score_display6 => score6,
		falling => falling,
		stays_out => staying, 
		staying_color_out => changing_color, -- same but for staying 
		rng_color => rng_color,
		start_reset_state => sr_state,
		sound_type => sound_type,
		sound_trigger => sound_trigger
	);

	rst_del : reset_delay
	port map(
		iRSTN 	=> KEY(0),
		iCLK 		=> max10_CLK1_50,
		oRST 		=> dly_rst
	);
	
	spipll : spi_pll
	port map(
		areset	=> dly_rst,
		inclk0 	=> max10_CLK1_50,
		c0 		=> spi_clk,
		c1 		=> spi_clk_out
	);
	
	spithing : spi_ee_config
	port map(
		iRSTN 			=> not dly_rst,
		iSPI_CLK 		=> spi_clk,
		iSPI_CLK_OUT 	=> spi_clk_out,
		iG_INT2 			=> GSENSOR_INT(1),
		oDATA_L 			=> data_x(7 downto 0),
		oDATA_H 			=> data_x(15 downto 8),
		SPI_SDIO 		=> GSENSOR_SDI,
		oSPI_CSN 		=> GSENSOR_CS_N,
		oSPI_CLK 		=> GSENSOR_SCLK
	);
--	LEDR <= data_x(9 downto 0);
	
	led_driver_u : led_driver
	port map(
		iRSTN		=> not dly_rst,
		iCLK		=> MAX10_CLK1_50,
		iDIG 		=> data_x(9 downto 0),
		iG_INT2 	=> GSENSOR_INT(1),
		oLED		=> LEDR
	);

end architecture behavioral;