library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.tetris_types.all;

entity vga_tetris is 
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
end entity vga_tetris;

architecture behavioral of vga_tetris is 
	-- types/constants
	constant notASignal : std_logic := '0';
	--type std_logic_aoa is array (natural range <>) of std_logic_vector;
	type sc is array (natural range <>) of std_logic_vector (2 downto 0);
	type srs is (reset, startNewBrick, progressing, gameover);
	
	-- for top module stuff
	signal clk25 : std_logic := '0';
	signal pllLocked : std_logic := '0';
	
	-- for COLOR
	signal a_color : std_logic_vector (2 downto 0) := "000";
	
	--for GAMEPLAY
	--signal rng_color : std_logic_vector (2 downto 0) := "000";
	--signal falling : std_logic_vector (5 downto 0) := "000000";
	--signal in_end_falling : std_logic_vector (125 downto 0) := (others => '0');
	--signal in_start_falling : std_logic_vector (125 downto 0) := (others => '0');
	--signal staying : std_logic_vector (125 downto 0) := (others => '0');
	
	--signal staying_color : sc (0 to 125)(2 downto 0) := (others => "000");
	signal start_reset_states : srs := reset;-- start in reset
	
	-- units tracked in this module
	
	signal countV : unsigned (9 downto 0):= (others => '0'); -- (used for porches)
	signal countH : unsigned (9 downto 0) := (others => '0'); 
	signal location_x : integer := 0;
	signal location_y : integer := 0;
	signal count_for_x : integer := 0;
	
	-- connect these into gamplay 
	
	component VGA_PLL IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0				: OUT STD_LOGIC;
		locked		: OUT STD_LOGIC 
	);
	END component;
	component Color is 
	port(
		clk : in std_logic;
		a_color : in std_logic_vector (2 downto 0);
		red : out std_logic_vector (3 downto 0);
		blue : out std_logic_vector (3 downto 0);
		green : out std_logic_vector (3 downto 0)
	);
	end component;
	
begin
	PLL : VGA_PLL
	port map(
		areset	=> notASignal,
		inclk0	=> clk,
		c0			=> clk25,
		locked	=> pllLocked
	);
	Choosen_Color : Color 
	port map(
		clk => clk,
		a_color => a_color,
		red => vgar,
		blue => vgab,
		green => vgag
	);
	
	process(sr_states)
	begin
		case sr_states is 
			when "00" =>
				start_reset_states <= reset;
			when "01" =>
				start_reset_states <= startNewBrick;
			when "11" =>
				start_reset_states <= progressing;
			when "10" =>
				start_reset_states <= gameover;
			when others =>
				start_reset_states <= reset;
		end case;
	end process;
	
	--process(stay_l)
	--begin 
	--	staying_color(to_integer(unsigned(stay_l))) <= stay_change;
	--end process;
	
	-- might need one for updating as well
	
	process(clk25)
	begin
		if (rising_edge(clk25)) then
			countH <= countH + 1;-- horizontal count
			if countV = 10 or countV = 11 then-- VSync
				vgavs <= '1';
			else 
				vgavs <= '0';
			end if;
			if countH >=16 and countH <= 111 then -- HSync
				vgahs <= '1';
			else
				vgahs <= '0';
			end if;
			if countH = 799 then-- vertical count 
				countH <= (others => '0');
				countV <= countV + 1;
				a_color <= "000";
			end if;
			if (countV = 524) then 
					countV <= (others => '0');
					location_y <= 0;
			end if;
			if countH <= 111 or countV < 77 then -- left and up side black
				a_color <= "000";
			elsif ((countH = 335 or countH = 624) and countV >= 77 and countV < 524) or (countV = 523 and (countH >= 335 and countH <= 624)) then -- the white border (all sides)
				a_color <= "001";
			elsif (countH >= 336 and countH <= 623) and (countV >= 76 and countV <= 523) then-- The area
				if countH = 367 or countH = 399 or countH = 431 or countH = 463 or countH = 495 or countH = 527 or countH = 559 or countH = 591  then 
					location_x <= location_x + 1; -- get to the end a block 
					--location_y <= location_y;
				elsif countH = 623 then
					location_x <= 0;
				end if;
				
				if countH = 623 and (countV = 107 or countV = 139 or countV = 171 or countV = 203 or countV = 235 or countV = 267 or countV = 299 or countV = 331 or countV = 363 or countV = 203 or countV = 395 or countV = 427 or countV = 459 or countV = 491) then 
					location_y <= location_y + 1;
				else
					location_y <= location_y;
				end if;
				
				case start_reset_states is 
					when reset => -- The reset here needs to be black
						a_color <= "000";
					when startNewBrick =>
						--a_color <= staying_color_in(location_x, location_y);
						-- continue or remove
					when progressing =>
						if staying(location_x, location_y) = '1' then 
							a_color <= staying_color_in(location_x, location_y);
						elsif falling(location_x, location_y) = '1' then 
							a_color <= rng_color;
						else 
							a_color <= "000";
						end if;
					when gameover =>
						--a_color <= staying_color_in(location_x, location_y);
					when others =>
						a_color <= "000";
				end case;
			elsif (countH >= 640 and countH <= 647) and (countV >= 332 and countV <= 347) then -- MSD
				case x6 is
					when "0000" => -- 0
						if countH = 640 or countH = 647 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 647 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 640 and countV > 339) or (countH = 647 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 647 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 640 and countV < 339) or countV = 339 or countH = 647 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 640 and countV < 339) or (countH = 647 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 647) or countH = 640 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 647 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 640 or countH = 647 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 640) or countH = 647 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			elsif (countH >= 649 and countH <= 656) and (countV >= 332 and countV <= 347) then -- 5th
				case x5 is
					when "0000" => -- 0
						if countH = 649 or countH = 656 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 656 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 649 and countV > 339) or (countH = 656 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 656 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 649 and countV < 339) or countV = 339 or countH = 656 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 649 and countV < 339) or (countH = 656 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 656) or countH = 649 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 656 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 649 or countH = 656 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 649) or countH = 656 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			elsif (countH >= 658 and countH <= 665) and (countV >= 332 and countV <= 347) then -- 4th
				case x4 is
					when "0000" => -- 0
						if countH = 658 or countH = 665 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 665 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 658 and countV > 339) or (countH = 665 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 665 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 658 and countV < 339) or countV = 339 or countH = 665 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 658 and countV < 339) or (countH = 665 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 665) or countH = 658 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 665 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 658 or countH = 665 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 658) or countH = 665 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			elsif (countH >= 667 and countH <= 674) and (countV >= 332 and countV <= 347) then -- 3rd
				case x3 is
					when "0000" => -- 0
						if countH = 667 or countH = 674 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 674 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 667 and countV > 339) or (countH = 674 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 674 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 667 and countV < 339) or countV = 339 or countH = 674 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 667 and countV < 339) or (countH = 674 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 674) or countH = 667 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 674 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 667 or countH = 674 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 667) or countH = 674 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			elsif (countH >= 676 and countH <= 683) and (countV >= 332 and countV <= 347) then -- 2nd 
				case x2 is
					when "0000" => -- 0
						if countH = 676 or countH = 683 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 683 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 676 and countV > 339) or (countH = 683 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 683 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 676 and countV < 339) or countV = 339 or countH = 683 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 676 and countV < 339) or (countH = 683 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 683) or countH = 676 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 683 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 676 or countH = 683 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 676) or countH = 683 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			elsif (countH >= 685 and countH <= 692) and (countV >= 332 and countV <= 347) then -- LSD
				case x1 is
					when "0000" => -- 0
						if countH = 685 or countH = 692 or countV = 332 or countV = 347 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0001" => -- 1
						if countH = 692 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0010" => -- 2
						if countV = 332 or countV = 347 or countV = 339 or (countH = 685 and countV > 339) or (countH = 692 and countV < 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0011" => -- 3
						if countV = 332 or countV = 347 or countV = 339 or countH = 692 then
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0100" => -- 4
						if (countH = 685 and countV < 339) or countV = 339 or countH = 692 then 
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0101" => --5
						if countV = 332 or countV = 347 or countV = 339 or (countH = 685 and countV < 339) or (countH = 692 and countV > 339) then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "0110" => --6
						if countV = 332 or countV = 347 or countV = 339 or (countV > 339 and countH = 692) or countH = 685 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when "0111" => -- 7
						if countV = 332 or countH = 692 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1000" => --8
						if countV = 332 or countV = 347 or countV = 339 or countH = 685 or countH = 692 then 
							a_color <= "001";
						else 
							a_color <= "000";
						end if;
					when "1001" => -- 9
						if countV = 332 or countV = 347 or countV = 339 or (countV < 339 and countH = 685) or countH = 692 then	
							a_color <= "001";
						else
							a_color <= "000";
						end if;
					when others => 
						a_color <= "001";
				end case;
			else 
				a_color <= "000";
			end if;
		end if;
	end process;
end architecture behavioral;
