library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.tetris_types.all;

entity Gameplay is 
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
end entity Gameplay;

architecture behavioral of Gameplay is
	type srs is (reset, startNewBrick, progressing, gameover); -- start/reset states ***** (not sure what to do for gameover and other)
	
	type state_mach is (waiting, checking, scoring, updating); -- checking state machine 
	
	constant stop : integer := 1000000; -- stops counting (how long to wait before updating falling 
	
	-- all of these are extensively used 
	signal staying_color : tetris_block_array := (others => (others => "000")); -- tells me what every block color is (starting and default should be black)
	
	signal stays : place := (others => (others => '0')); -- if the area is keeping a block in it
	signal about_to_disappear : place := (others => (others => '0')); -- during the checking stage, will tell me which block will disappear
	
	signal current_square_place_x : integer := 4; -- tells me where the block currently is 
	signal current_square_place_y : integer := 0; 
	
	signal current_color : unsigned (2 downto 0); -- tells me what the color of the current falling block is 
	
	signal gen : std_logic := '0'; -- used for generating a new color (happens in startNewBrick)
	
	signal sr_states : srs := reset; -- the start/reset state
	signal check : state_mach := waiting; -- the state machine when the game is in the progressing state 
	
	signal scored : unsigned (3 downto 0) := (others => '0'); -- will reset after checking state_mach
	signal score1 : unsigned (3 downto 0) := (others => '0'); -- keeps until reset is pressed. 
	signal score2 : unsigned (3 downto 0) := (others => '0');
	signal score3 : unsigned (3 downto 0) := (others => '0');
	signal score4 : unsigned (3 downto 0) := (others => '0');
	signal score5 : unsigned (3 downto 0) := (others => '0');
	signal score6 : unsigned (3 downto 0) := (others => '0');
	
	signal count :integer := 0; -- count for frame  sake 
	signal UDorLR : integer := 0;
	--signal falling : unsigned (5 downto 0) := (others => '0'); -- where we are in the falling animation 
	
	component LSR is 
	port 
	(
		clk : in std_logic; 
		gen : in std_logic;
		reset : in std_logic;
		seed : in unsigned (7 downto 0);
		reg : out unsigned (2 downto 0)
	);
	end component;
	
begin
	RNG : LSR 
	port map (
		clk => clk,  
		gen => gen,
		reset => rst_l,
		seed => "01101001",
		reg => current_color
	);
	
	process (current_color)
	begin 
		rng_color <= std_logic_vector(current_color); 
	end process;
	
	
	process(clk, rst_l)
	begin
		if rst_l = '0' then -- when the reset button is pressed (at any point) 
			sr_states <= reset; -- puts us in the reset state
			staying_color <= (others => (others => "000")); -- all colors are reset
			falling <= (others => (others => '0')); -- ^
			stays <= (others => (others => '0')); -- all blocks are emptied 
			about_to_disappear <= (others => (others => '0')); -- all status of disappearing are reset 
			current_square_place_x <= 4; -- put starting place at the middle of the top
			current_square_place_y <= 0;
			check <= waiting; -- check starts in waiting 
			scored <= (others => '0'); -- all of these are set to 0 
			score1 <= (others => '0');
			score2 <= (others => '0');
			score3 <= (others => '0');
			score4 <= (others => '0');
			score5 <= (others => '0');
			score6 <= (others => '0');
			count <= 0;
			start_reset_state <= "00";
			sound_trigger <= '0';
		elsif (rising_edge(clk)) then -- the game may start or is already going 
			case sr_states is  -- where we are in gameplay 
				when reset => -- reset: waiting to start the game 
					start_reset_state <= "00";
					sound_trigger <= '0';
					if start = '0' then -- if the start button is pressed then we go by putting in a new brick 
						sr_states <= startNewBrick;
						current_square_place_x <= 4;
						current_square_place_y <= 0;
					else
						sr_states <= reset;
					end if;
				when startNewBrick => 
					sound_trigger <= '0';
					start_reset_state <= "01";
					gen <= '1'; -- generate new color 
					sr_states <= progressing;
					falling(current_square_place_x, current_square_place_y) <= '1';
				when progressing => -- here we have game play 
					start_reset_state <= "11";
					gen <= '0';
					if check = waiting then -- no checking, the brick is falling and we wait until it lands on bottom or on another brick 
						count <= count + 1;
						if count = stop and UDorLR = 1 then-- when we update the falling animation 
							count <= 0;
							UDorLR <= 0;
							--falling <= (others => '0');
							if (current_square_place_y < 13 and stays(current_square_place_x, current_square_place_y + 1) = '0') then -- keeps going down  
								falling(current_square_place_x, current_square_place_y + 1) <= '1';
								falling(current_square_place_x, current_square_place_y) <= '0';
								current_square_place_y <= current_square_place_y + 1;
								sound_trigger <= '0';
							else														-- finds a spot to land, may or may not be a gameover 
								sound_trigger <= '1';
								stays(current_square_place_x, current_square_place_y) <= '1';
								falling(current_square_place_x, current_square_place_y) <= '0';
								if current_square_place_y <= 1 then -- if 2 from the top = gameover, else lets go check on stuff (i know there's some cases, but I don't think we need to worry about that little case)
									sr_states <= gameover;
									sound_type <= "10";
								else 
									check <= checking;
									sound_type <= "00";
								end if;
								staying_color(current_square_place_x, current_square_place_y) <= std_logic_vector(current_color);
								current_square_place_x <= 8;
								current_square_place_y <= 13;
							end if;
						elsif count = stop and UDorLR = 0 then 
							count <= 0;
							UDorLR <= 1;
							if signed(lane) < to_signed(-50,lane'length) then -- moving the falling brick right 
								if stays(current_square_place_x + 1, current_square_place_y) = '0' and not(current_square_place_x = 8) then 
									sound_trigger <= '1';
									sound_type <= "01";
									current_square_place_x <= current_square_place_x + 1;
									falling(current_square_place_x, current_square_place_y) <= '0';
									falling(current_square_place_x + 1, current_square_place_y) <= '1';
								end if;
							elsif signed(lane) > to_signed(50,lane'length) then -- moving the falling brick left 
								if stays(current_square_place_x - 1, current_square_place_y) = '0' and not(current_square_place_x = 0) then 
									sound_trigger <= '1';
									sound_type <= "01";
									current_square_place_x <= current_square_place_x - 1;
									falling(current_square_place_x, current_square_place_y) <= '0';
									falling(current_square_place_x - 1, current_square_place_y) <= '1';
								end if;
							end if;
						end if;
					elsif check = checking then -- where we check for patterns of matching blocks 
						sound_trigger <= '0';
						if (current_square_place_x > 0) then 
							current_square_place_x <= current_square_place_x - 1;
						elsif current_square_place_x = 0 and current_square_place_y > 0 then
							current_square_place_x <= 8;
							current_square_place_y <= current_square_place_y - 1;
						elsif current_square_place_x = 0 and current_square_place_y = 0 and scored > 0 then -- pattern found and needs to update the blocks' statuses
							check <= scoring; 
						elsif current_square_place_x = 0 and current_square_place_y = 0 and scored = 0 then -- can make a new block fall 
							check <= waiting;
							sr_states <= startNewBrick;
							current_square_place_x <= 4;
							current_square_place_y <= 0;
						end if;
						if stays(current_square_place_x, current_square_place_y) = '1' then -- only need to check blocks that are in position (don't want to score all those black areas)
							if current_square_place_x = 8 and current_square_place_y = 13 then -- these single ones are the 16 locations in the corners (each needs a seperate search parameter as seen in each if block 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 7 and current_square_place_y = 13 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y - 2)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 8 and current_square_place_y = 12 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 7 and current_square_place_y = 12 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 0 and current_square_place_y = 13 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 1 and current_square_place_y = 13 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 0 and current_square_place_y = 12 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 1 and current_square_place_y = 12 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right 
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 0 and current_square_place_y = 0 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 1 and current_square_place_y = 0 then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right 
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 0 and current_square_place_y = 1 then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 1 and current_square_place_y = 1 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right 
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 7 and current_square_place_y = 0 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right 
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 8 and current_square_place_y = 0 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 7 and current_square_place_y = 1 then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right 
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif current_square_place_x = 8 and current_square_place_y = 1 then -- the ones below are the 2 columns on the left and right 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_x = 0 and (current_square_place_y > 1 and current_square_place_y < 12)) then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_x = 1 and (current_square_place_y > 1 and current_square_place_y < 12)) then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_x = 7 and (current_square_place_y > 1 and current_square_place_y < 12)) then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_x = 8 and (current_square_place_y > 1 and current_square_place_y < 12)) then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then -- 2 to the left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_y = 13 and (current_square_place_x > 1 and current_square_place_x < 7)) then -- these are the rows on top and bottom 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then-- 2 left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_y = 12 and (current_square_place_x > 1 and current_square_place_x < 7)) then
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then-- 2 left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_y = 1 and (current_square_place_x > 1 and current_square_place_x < 7)) then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then-- 2 left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							elsif (current_square_place_y = 0 and (current_square_place_x > 1 and current_square_place_x < 7)) then 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then-- 2 left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							else -- all other blocks need every type of search 
								if (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 2, current_square_place_y)) then -- 2 to the right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 2, current_square_place_y)) then-- 2 left
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 2)) then-- 2 down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 2)) then-- 2 up
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y - 1) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x, current_square_place_y + 1)) then-- up and down
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								elsif (staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x - 1, current_square_place_y) and staying_color(current_square_place_x, current_square_place_y) = staying_color(current_square_place_x + 1, current_square_place_y)) then-- left and right
									about_to_disappear(current_square_place_x, current_square_place_y) <= '1';
									scored <= scored + 1;
								end if;
							end if;
						end if;
					elsif check = scoring then 
						score1 <= score1 + scored; -- takes the new points in 
						sound_trigger <= '1';
						sound_type <= "11";
						if (score1 + scored > "1001") then 
							case score1 + scored is
								when "1010" =>
									score1 <= "0000";
								when "1011" =>
									score1 <= "0001";
								when "1100" =>
									score1 <= "0010";
								when "1101" =>
									score1 <= "0011";
								when "1110" =>
									score1 <= "0100";
								when "1111" =>
									score1 <= "0101";
								when others =>
									score1 <= "0110";
							end case;
							score2 <= score2 + 1;
							if (score2 + 1 > "1001") then 
								score2 <= "0000";
								score3 <= score3 + 1;
								if (score3 + 1 > "1001") then 
									score3 <= "0000";
									score4 <= score4 + 1;
									if (score4 + 1 > "1001") then 
										score4 <= "0000";
										score5 <= score5 + 1;
										if (score5 + 1 > "1001") then 
											score5 <= "0000";
											score6 <= score6 + 1;
											if (score6 + 1 > "1001") then 
												score6 <= "0000";
											end if;
										end if;
									end if;
								end if;
							end if;
						end if;
						
						scored <= (others => '0'); -- resets for new patterns to score 
						check <= updating; -- 
						current_square_place_x <= 8; -- need to check for updates 
						current_square_place_y <= 13;
					elsif check = updating then 
						sound_trigger <= '0';
						if (current_square_place_x > 0) then 
							current_square_place_x <= current_square_place_x - 1;
						elsif current_square_place_x = 0 and current_square_place_y > 0 then
							current_square_place_x <= 8;
							current_square_place_y <= current_square_place_y - 1;
						elsif current_square_place_x = 0 and current_square_place_y = 0 then 
							check <= checking;
							current_square_place_x <= 8;
							current_square_place_y <= 13;
						end if;
						if about_to_disappear(current_square_place_x, current_square_place_y) = '1' then -- if the square is part of a pattern ( or will be affected soon after 
							about_to_disappear(current_square_place_x, current_square_place_y) <= '0';
							if current_square_place_y > 2 and about_to_disappear(current_square_place_x, current_square_place_y - 3) = '1' then  -- 4 squares up
								if (current_square_place_y - 3) = 0 then 
									staying_color(current_square_place_x, current_square_place_y) <= "000"; 
									stays(current_square_place_x, current_square_place_y) <= '0';
								else 
									staying_color(current_square_place_x, current_square_place_y) <= staying_color(current_square_place_x, current_square_place_y - 4); -- moves the color down 
									stays(current_square_place_x, current_square_place_y) <= stays(current_square_place_x, current_square_place_y - 4); -- moves the status down 
									about_to_disappear(current_square_place_x, current_square_place_y - 4) <= '1'; -- will change status above so whole column is affected similarly 
								end if;
							elsif current_square_place_y > 1 and about_to_disappear(current_square_place_x, current_square_place_y - 2) = '1' then  -- 3 squares
								if (current_square_place_y - 2) = 0 then 
									staying_color(current_square_place_x, current_square_place_y) <= "000"; 
									stays(current_square_place_x, current_square_place_y) <= '0';
								else 
									staying_color(current_square_place_x, current_square_place_y) <= staying_color(current_square_place_x, current_square_place_y - 3); -- moves the color down 
									stays(current_square_place_x, current_square_place_y) <= stays(current_square_place_x, current_square_place_y - 3); -- moves the status down 
									about_to_disappear(current_square_place_x, current_square_place_y - 3) <= '1'; -- will change status above so whole column is affected similarly 
								end if;
							else  -- 1 squares
								if (current_square_place_y) = 0 then 
									staying_color(current_square_place_x, current_square_place_y) <= "000"; 
									stays(current_square_place_x, current_square_place_y) <= '0';
								else 
									staying_color(current_square_place_x, current_square_place_y) <= staying_color(current_square_place_x, current_square_place_y - 1); -- moves the color down 
									stays(current_square_place_x, current_square_place_y) <= stays(current_square_place_x, current_square_place_y - 1); -- moves the status down 
									about_to_disappear(current_square_place_x, current_square_place_y - 1) <= '1'; -- will change status above so whole column is affected similarly 
								end if;
							end if;
						end if;
					end if;
				when gameover =>
					start_reset_state <= "10";
				when others =>
					start_reset_state <= "00";
			end case;
		end if;
		--falling_count <= std_logic_vector(falling);
		score_display1 <= std_logic_vector(score1);
		score_display2 <= std_logic_vector(score2);
		score_display3 <= std_logic_vector(score3);
		score_display4 <= std_logic_vector(score4);
		score_display5 <= std_logic_vector(score5);
		score_display6 <= std_logic_vector(score6);
		stays_out <= stays;
		staying_color_out <= staying_color;
		
	end process;
end architecture behavioral;