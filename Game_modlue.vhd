library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity game_module is 
	port(
		-- inputs
		pixel_x : in unsigned (8 downto 0);
		pixel_y : in unsigned (8 downto 0);
		
		accelerometer : in unsigned (9 downto 0);
		
		start : in std_logic;
		reset : in std_logic;
		
		clk : in std_logic;
		
		RNG_val : in std_logic_vector (1 downto 0);
		
		
		-- outputs
		pixel_color : out std_logic_vector (1 downto 0);
		game_updating : out std_logic;
		score : out unsigned (19 downto 0);
		rng_read : out std_logic
	);
end entity game_module;

architecture behavioral of game_module is


begin


end architecture behavioral;