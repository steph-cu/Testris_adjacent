library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_module is 
	port(
		-- inputs
		pixel_color : in std_logic_vector (1 downto 0);
		game_updating : in std_logic;
		
		clk : in std_logic;
		
		-- outputs
		pixel_x : out unsigned (8 downto 0);
		pixel_y : out unsigned (8 downto 0);
		display_vs : out std_logic;
		display_hs : out std_logic;
		display_r : out std_logic_vector (3 downto 0);
		display_g : out std_logic_vector (3 downto 0);
		display_b : out std_logic_vector (3 downto 0)
	);
end entity display_module;

architecture behavioral of display_module is

	signal countV : integer := 0;
	signal countH : integer := 0;
	signal color : std_logic_vector (2 downto 0);
	
	signal x_pos : integer;
	signal y_pos : integer;
	type color_type is record
		r : std_logic_vector (3 downto 0);
		g : std_logic_vector (3 downto 0);
		b : std_logic_vector (3 downto 0);
	end record color_type;
	
	type color_array_t is array (0 to 5) of color_type;
	
	constant red_color : color_type := (r =>"1111",g=>"0000",b=>"0000");
	constant green_color : color_type := (r =>"0000",g=>"1111",b=>"0000");
	constant blue_color : color_type := (r =>"0000",g=>"0000",b=>"1111");
	constant yellow_color : color_type := (r =>"1111",g=>"1111",b=>"0000");
	constant black_color : color_type := (r =>"0000",g=>"0000",b=>"0000");
	constant white_color : color_type := (r =>"1111",g=>"1111",b=>"1111");
	
	constant color_array : color_array_t := (red_color,blue_color,green_color,yellow_color,black_color,white_color);
	constant black : std_logic_vector := "100";
	constant white : std_logic_vector := "101";
	
begin

	process(clk)
	begin
		if rising_edge(clk) then
			--timing
			countH <= countH + 1;
			if countH = 15 then --set horizontal sync
				display_hs <= '1';
			end if;
			if countH = 111 then --clear horizonatl sync
				display_hs <= '0';
			end if;
			if countH = 799 then --end of line
				countH <= 0;
				countV <= countV + 1;
			end if;
			if countV = 524 then --end of frame
				countV <= 0;
			end if;
			if countV = 10 or countV = 11 then --set vertical sync
				display_vs <= '1';
			else 
				display_vs <= '0'; --clear vertical sync
			end if;
			
			--active display area:
			if countH >= 159 and countV >= 45 then
				x_pos <= x_pos + 1;		--Generate x/y postion on display area
				if x_pos = 639 then
					x_pos <= 0;
					if y_pos = 479 then
						y_pos <= 0;
					else
						y_pos <= y_pos + 1;
					end if;
				end if;
				
				--generate white frame
				if x_pos = 176 or x_pos = 465 then
					color <= white;
				end if;
				if y_pos = 471 then
					if x_pos >= 176 and x_pos <= 465 then
						color <= white;
					else
						color <= black;
					end if;
				end if;
				
				if x_pos > 176 and x_pos < 465 and y_pos > 21 and y_pos < 471 then
					-- main play area
				
				elsif x_pos >= 471 and x_pos <= 631 and y_pos >= 294 and y_pos <= 344 then
					-- digits (25 px by 50 px, 1 px kerning)
					if x_pos >= 471 and x_pos <= 496 then
						--Hundred thousnads place
					elsif	x_pos >= 498 and x_pos <= 523 then
						--Ten thousands place
					elsif x_pos >= 525 and x_pos <= 550 then
						--Thousands place
					elsif x_pos >= 552 and x_pos <= 577 then
						--Hundreds place
					elsif x_pos >= 579 and x_pos <= 604 then
						--Tens place
					elsif x_pos >= 606 and x_pos <= 631 then
						--Ones place
					end if;
				else
					color <= black;
				end if;
			end if;
		end if;
	end process;
	
	process(color)
	begin
		display_r <= color_array(color).r;
		display_g <= color_array(color).g;
		display_b <= color_array(color).b;
	end process;

end architecture behavioral;