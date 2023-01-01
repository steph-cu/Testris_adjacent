library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LSR is 
	port (
		clk : in std_logic; 
		gen : in std_logic;
		reset : in std_logic;
		seed : in unsigned (7 downto 0);
		reg : out unsigned (2 downto 0)
	);
end entity LSR;

architecture behavioral of LSR is 
	signal shift_in : std_logic := '0';
	signal output : unsigned (7 downto 0) := "00000001";
	signal ready : unsigned (1 downto 0) := "00";
begin
	process (clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '0') then
				output <= seed;
			elsif (gen = '1')then 
				shift_in <= output(3) xor output(4) xor output(6) xor output(7);
				output <= output(6 downto 0) & shift_in; -- shift_left(unsigned(shift_in), 1);
			end if;
		end if;
		ready <= output(2 downto 1);
	end process;
	
	process (ready)
	begin
		case ready is 
			when "00" =>
				reg <= "010";
			when "01" =>
				reg <= "011";
			when "10" =>
				reg <= "100";
			when "11" =>
				reg <= "101";
			when others =>
				reg <= "000"; -- white is big mess up
		end case;
	end process;
end architecture behavioral;