library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tetris_game is
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
		GSENSOR_SDO : inout std_logic;
		-- Arduino Header
		ARDUINO_IO : inout std_logic_vector (15 downto 0);
		ARDUINO_RESET_N : inout std_logic
	);
end entity tetris_game;

architecture behavioral of tetris_game is


begin


end architecture behavioral;