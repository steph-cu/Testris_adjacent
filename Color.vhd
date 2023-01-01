library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Color is 
	port(
		clk : in std_logic;
		a_color : in std_logic_vector (2 downto 0);
		red : out std_logic_vector (3 downto 0);
		blue : out std_logic_vector (3 downto 0);
		green : out std_logic_vector (3 downto 0)
	);
end entity Color;

architecture choose of Color is

begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			case a_color is 
				when "000" => -- black
					red <= "0000";
					blue <= "0000";
					green <= "0000";
				when "001" => -- white
					red <= "1111";
					blue <= "1111";
					green <= "1111";
				when "010" => -- red 
					red <= "1111";
					blue <= "0000";
					green <= "0000";
				when "011" => -- blue
					red <= "0000";
					blue <= "1111";
					green <= "0000";
				when "100" => -- green
					red <= "0000";
					blue <= "0000";
					green <= "1111";
				when "101" => -- yellow
					red <= "1111";
					blue <= "0000";
					green <= "1111";
				when others => -- in any other case do black
					red <= "0000";
					blue <= "0000";
					green <= "0000";
			end case;
		end if;
	end process;
end architecture choose;