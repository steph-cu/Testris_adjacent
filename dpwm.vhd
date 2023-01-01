library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpwm is 
	generic(
		div : integer := 256;
		div_size : integer := 8
	);
	
	port(
		-- inputs
		clk : std_logic;
		D : unsigned (div_size-1 downto 0);
		
		-- Outputs
		output : std_logic
	);
end entity dpwm;

architecture behavioral of dpwm is
	signal counter : unsigned (div_size-1 downto 0);
begin 
	process(clk)
	begin
		if rising_edge(clk) then
			if counter = div-1 then
				counter <= 0;
				output <= '0';
			else
				counter <= counter + 1;
--				output = output;		--uncomment if latch inferred for output
			end if;
			
			if counter = D  then
				output <= '1';
--			else
--				output = output;		--uncomment if latch inferred for output
			end if;
		end if;
	end process;
end architecture behavioral;