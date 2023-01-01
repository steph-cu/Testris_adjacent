library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;




entity accelerometer is
	port(
		--Inputs
		clk : in std_logic;
		int : in std_logic_vector (2 downto 1);
		SDI : in std_logic;
		rst_l : in std_logic;
		
		--Outputs
		cs : out std_logic;
		sclk : out std_logic;
		SDO : out std_logic;
		
		lane : out std_logic_vector (3 downto 0);
		sample_output : out std_logic_vector (9 downto 0)
	);
end entity accelerometer;


architecture behavioral of accelerometer is
	component SPI
		generic(
			word_size : integer;
			clk_div : integer;
			clk_div_size : integer
		);
		port(
			--Inputs
			transmit : in std_logic;
			tx_dat : in std_logic_vector (word_size-1 downto 0);
			sdi : in std_logic;
			
			clk : in std_logic;
			--Outputs
			cs : out std_logic;
			sdo : out std_logic;
			sclk : out std_logic;
			
			read_ack : out std_logic;
			tx_finished : out std_logic;
			rx_dat : out std_logic_vector (word_size-1 downto 0)
		);
	end component;
	
	constant word_size : integer := 8;
	constant clk_div : integer := 25;
	constant clk_div_size : integer := 5;
	
	type state_type is (reset, initalize, wait_for_int, read_sample, process_sample);
	
	signal cstate, nstate : state_type := reset;
	
	signal tx_dat, ntx_dat : std_logic_vector (word_size-1 downto 0);
	signal sample, nsample : signed (9 downto 0) := to_signed(0,10);
	signal int_sample, nint_sample : integer range -512 to 512 := 0;
	signal count, ncount : integer;
	signal transmit, otransmit, ntransmit, ocs : std_logic;
	signal olane, nlane : std_logic_vector (3 downto 0) := "0000";
	signal read_ack, tx_finished : std_logic;
	signal rx_dat : std_logic_vector (word_size-1 downto 0);
	signal nsample_high, sample_high : signed (1 downto 0) := to_signed(0,2);
	signal nsample_low, sample_low : signed (7 downto 0) := to_signed(0,8);

-- -128 , -99, -71, -42, -14, 14, 42, 71, 99, 128
	constant val_1  : integer := -128;
	constant val_2  : integer := -99;
	constant val_3  : integer := -71;
	constant val_4  : integer := -42;
	constant val_5  : integer := -14;
	constant val_6  : integer := 14;
	constant val_7  : integer := 42;
	constant val_8  : integer := 71;
	constant val_9  : integer := 99;
	constant val_10 : integer := 128;

	

	
begin
	spi_module : SPI
	generic map(
		word_size => word_size,
		clk_div => clk_div,
		clk_div_size => clk_div_size
	)
	port map(
		transmit			=> transmit,
		tx_dat 			=> tx_dat,
		sdi 				=> SDI,
		clk 				=> clk,
		cs					=> ocs,
		sdo				=> SDO,
		sclk				=> sclk,
		read_ack			=> read_ack,
		tx_finished		=> tx_finished,
		rx_dat			=> rx_dat
	);
	
	process(clk)
	begin
		if rising_edge(clk) then
			cstate <= nstate;
			tx_dat <= ntx_dat;
			count <= ncount;
			otransmit <= ntransmit;
			sample <= nsample;
			olane <= nlane;
			int_sample <= nint_sample;
			sample_low <= nsample_low;
			sample_high <= nsample_high;
		end if;		
	end process;
	
--nstate
--ntx_dat	
--ncount
--ntransmit
--nsample
--nlane
--nint_sample
--nsample_high
--nsample_low
	
	process(cstate, tx_dat, read_ack, tx_finished, rx_dat, ocs, sample, olane, rst_l, int_sample, count, int, otransmit, sample_high, sample_low)
	begin
		case cstate is
			when reset =>
				if rst_l = '1' then
					nstate <= initalize;
				else
					nstate <= reset;
				end if;
				ntx_dat <= (others => '0');
				ncount <= 0;
				ntransmit <= '0';
				nsample <= sample;
				nlane <= olane;
				nint_sample <= int_sample;
				nsample_high <= sample_high;
				nsample_low <= sample_low;
			
			when initalize =>
				--registers to set:
					--power saving features control register
						--address: 0x2D		0
						--"00001000"			1
					--interrupt mapping control
						--address: 0x2F		20
						--"01111111"			21
					--interrupt enable control register
						--address: 0x2E		40
						--"10000000"			41
				nsample <= sample;
				nlane <= olane;
				nint_sample <= int_sample;
				nsample_high <= sample_high;
				nsample_low <= sample_low;
				case count is
					when 0 =>
						ntransmit <= '1';
						nstate <= initalize;
						ntx_dat <= std_logic_vector(to_unsigned(16#2D#,ntx_dat'length));
						if read_ack = '1' then
							ncount <= 1;
						else
							ncount <= count;
						end if;
					when 1 => 
						nstate <= initalize;
						ntransmit <= '1';
						ntx_dat <= "00001000";
						if tx_finished = '1' then
							ncount <= 2;
						else
							ncount <= count;
						end if;
					when 2 to 99 =>
						nstate <= initalize;	
						ntransmit <= '0';
						ntx_dat <= tx_dat;
						if ocs = '1' then
							ncount <= count + 1;
						else
							ncount <= count;
						end if;
						
					when 100 => 
						nstate <= initalize;
						ntransmit <= '1';
						ntx_dat <= std_logic_vector(to_unsigned(16#2F#,ntx_dat'length));
						if read_ack = '1' then
							ncount <= count + 1;
						else
							ncount <= count;
						end if;
					when 101 =>
						nstate <= initalize;
						ntx_dat <= "01111111";
						ntransmit <= '1';
						if tx_finished = '1' then
							ncount <= count + 1;
						else
							ncount <= count;
						end if;
					when 102 to 199 =>
						nstate <= initalize;
						ntx_dat <= tx_dat;
						ntransmit <= '0';
						if ocs = '1' then
							ncount <= count + 1;
						else
							ncount <= count;
						end if;
					when 200 =>
						nstate <= initalize; 
						ntransmit <= '1';
						ntx_dat <= std_logic_vector(to_unsigned(16#2E#,ntx_dat'length));
						if read_ack = '1' then
							ncount <= count + 1;
						else
							ncount <= count;
						end if;
					when 201 =>
						if tx_finished = '1' then
							nstate <= initalize;
							ntransmit <= '0';
							ntx_dat <= (others => '0');
							ncount <= 202;
						elsif read_ack = '1' then
							ntransmit <= '0';
							ntx_dat <= (others => '0');
							ncount <= count;
							nstate <= initalize;
						else
							ntx_dat <= "10000000";
							ntransmit <= '1';
							ncount <= count;
							nstate <= initalize;
						end if;
					when 202 =>
						nstate <= initalize;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						ncount <= 203;
						
					when 203 to 3000 => 
						if count = 2999 then
							nstate <= wait_for_int;
							ncount <= 0;
						else
							nstate <= initalize;
							ncount <= count + 1;
						end if;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						
						
					when others =>
						nstate <= reset;
						ntx_dat <= (others => '0');
						ncount <= 0;
						ntransmit <= '0';
				end case;
			
			
			when wait_for_int =>
				nlane <= olane;
				nsample <= sample;
				nint_sample <= int_sample;
				nsample_high <= sample_high;
				nsample_low <= sample_low;
				
				ntx_dat <= "11110010"; -- read, multi byte, address: 0x32
				if int(1) = '1' or int(2) = '1' or count = 100000 then
					nstate <= read_sample;
					ntransmit <= '1';
					ncount <= 0;
				else 
					nstate <= wait_for_int;
					ntransmit <= '0';
					ncount <= count + 1;
				end if;
			
			when read_sample =>
				nlane <= olane;
				case count is
					when 0 =>
						if read_ack = '1' then	--First word read, load second word
							nstate <= read_sample;
							ncount <= 1;
							ntransmit <= '1';
							ntx_dat <= (others => '0');
						else
							nstate <= read_sample; --Wait for word to be read
							ncount <= count;
							ntransmit <= otransmit;
							ntx_dat <= tx_dat;
						end if;
						nsample <= sample;
						nint_sample <= int_sample;
						nsample_high <= sample_high;
						nsample_low <= sample_low;
					when 1 =>
						if tx_finished = '1' then	--Second word read, load third word
							nstate <= read_sample;
							ncount <= 2;
							ntransmit <= '1';
							ntx_dat <= (others => '0');
						else
							nstate <= read_sample;	--Wait for word to be read
							ncount <= 1;
							ntransmit <= '1';
							ntx_dat <= tx_dat;
						end if;
						nsample <= sample;
						nint_sample <= int_sample;
						nsample_high <= sample_high;
						nsample_low <= sample_low;
					when 2 => 
						--read output from spi module
						nsample_high <= signed(rx_dat(1 downto 0));
						nsample <= sample;
						nsample_low <= sample_low;
						nstate <= read_sample;
						ncount <= 3;
						ntransmit <= '1';
						ntx_dat <= tx_dat;
						nint_sample <= int_sample;
						
					when 3 =>
						if tx_finished = '1' then
							ncount <= 4;
						else
							ncount <= 3;
						end if;
						nsample_high <= sample_high;
						nsample <= sample;
						nsample_low <= sample_low;
						nstate <= read_sample;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						nint_sample <= int_sample;
					when 4 =>
						if tx_finished = '1' then
							nsample_low <= signed(rx_dat);
							nstate <= read_sample;
							ncount <= 5;
							nsample_high <= sample_high;
							nsample <= sample;
						else
							nsample <= sample;
							nstate <= read_sample;
							ncount <= count;
							nsample_high <= sample_high;
							nsample_low <= sample_low;
							nsample <= sample;
						end if;
						ntransmit <= '0';
						ntx_dat <= tx_dat;
						nint_sample <= int_sample;
						
					when 5 =>
						nsample <= sample_high&sample_low;
						nint_sample <= int_sample;
						nstate <= cstate;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						ncount <= 6;
						nsample_low <= sample_low;
						nsample_high <= sample_high;
					when 6 =>
						nint_sample <= to_integer(sample);
						nsample <= sample;
						nstate <= process_sample;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						ncount <= 0;
						nsample_low <= sample_low;
						nsample_high <= sample_high;
					when others =>
						nstate <= wait_for_int;
						nsample <= sample;
						ntransmit <= otransmit;
						ntx_dat <= tx_dat;
						ncount <= count;
						nint_sample <= int_sample;
						nsample_low <= sample_low;
						nsample_high <= sample_high;
				end case;
			
			when process_sample =>
				nstate <= wait_for_int;
				nsample <= sample;
				ntransmit <= otransmit;
				ntx_dat <= tx_dat;
				ncount <= count;
				nint_sample <= int_sample;
				nsample_low <= sample_low;
				nsample_high <= sample_high;
				
				case int_sample is
					when -512 to val_1 - 1 =>
						nlane <= "0000";
					when val_1 to val_2 - 1 => -- lane 0
						nlane <= "0000";
					when val_2 to val_3 - 1 => -- lane 1
						nlane <= "0001";
					when val_3 to val_4 - 1 => -- lane 2
						nlane <= "0010";
					when val_4 to val_5 - 1 => -- lane 3
						nlane <= "0011";
					when val_5 to val_6 - 1 => -- lane 4
						nlane <= "0100";
					when val_6 to val_7 - 1 => -- lane 5
						nlane <= "0101";
					when val_7 to val_8 - 1 => -- lane 6
						nlane <= "0110";
					when val_8 to val_9 - 1 => -- lane 7
						nlane <= "0111";
					when val_9 to val_10 - 1 => -- lane 8
						nlane <= "1000";
					when val_10 to 511 =>
						nlane <= "1000";
					when others =>
						nlane <= "0100";
				end case;
			
		end case;
	end process;
	
	transmit <= otransmit;
	cs <= ocs;
	lane <= olane;
	sample_output <= std_logic_vector(sample);
end architecture behavioral;