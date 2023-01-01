library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tetris_types is

	type tetris_block_array is array(0 to 8, 0 to 13) of std_logic_vector(2 downto 0);
	type place is array(0 to 8, 0 to 13) of std_logic;

end package;