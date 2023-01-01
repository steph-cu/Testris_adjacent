library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SPI is 
	generic(
		word_size : integer := 8;
		clk_div : integer := 25;
		clk_div_size : integer := 5
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
end entity SPI;

architecture behavioral of SPI is
signal count : unsigned (clk_div_size-1 downto 0) := to_unsigned(0,clk_div_size);
signal nrx_bit_count, rx_bit_count, ntx_bit_count, tx_bit_count : integer range -1 to word_size;
signal nstored_tx_dat, stored_tx_dat, nstored_rx_dat, stored_rx_dat, nout_rx_dat, out_rx_dat : unsigned (word_size-1 downto 0) := to_unsigned(0,word_size);
signal nsdo, osdo, sclk_enable, nsclk_enable, ntx_finished, ncs, ocs, nread_ack, oread_ack, sclk_output : std_logic := '0';
signal nfed, fed : std_logic := '0';
signal nred, red : std_logic := '1';

type state_type is (idle, start_transmit, transmit_state, end_transmit);

signal cstate, nstate : state_type;

begin
	process(clk)	--generate sclk
	begin
		if rising_edge(clk) then
			if count >= clk_div-1 then
				count <= to_unsigned(0,count'length);
				sclk_output <= not sclk_output;
			else
				count <= count + 1;
				sclk_output <= sclk_output;
			end if;
		end if;
	end process;

	process(clk)	--update state machine
	begin
		if rising_edge(clk) then
			cstate <= nstate;
			osdo <= nsdo;
			sclk_enable <= nsclk_enable;
			tx_finished <= ntx_finished;
			tx_bit_count <= ntx_bit_count;
			rx_bit_count <= nrx_bit_count;
			stored_tx_dat <= nstored_tx_dat;
			stored_rx_dat <= nstored_rx_dat;
			out_rx_dat <= nout_rx_dat;
			ocs <= ncs;
			oread_ack <= nread_ack;
			red <= nred;
			fed <= nfed;
		end if;
	end process;
	
	
--Used signals:

--nstate
--nsdo
--nsclk_enable
--ntx_finished
--nrx_bit_count
--ntx_bit_count
--nstored_rx_dat
--nstored_tx_dat
--nout_rx_dat
--ncs
--nread_ack
--nred
--nfed
	
	process(cstate, tx_dat, transmit, rx_bit_count, tx_bit_count, sclk_output, sclk_enable, stored_tx_dat, fed, stored_rx_dat, out_rx_dat, red, sdi, oread_ack, osdo, ocs)
	begin
		case cstate is
			when idle =>
				--Transition logic, leave idle when transmit asserts
				if transmit = '1' then
					nstate <= start_transmit;
				else
					nstate <= idle;
				end if;
				
				--Things to do in this state
				nsdo <= '0';		--Clear SDO
				ncs <= '1';			--Ensure CS is deasserted;
				
				--Prevent inferring of latches
				nsclk_enable <= sclk_enable;
				ntx_finished <= '0';
				ntx_bit_count <= 0;
				nrx_bit_count <= 0;
				nstored_tx_dat <= stored_tx_dat;
				nstored_rx_dat <= stored_rx_dat;
				nout_rx_dat <= out_rx_dat;
				nread_ack <= '0';
				nred <= '1';
				nfed <= '0';
				
				
			when start_transmit =>
				--Transition logic, 
				if sclk_output = '1' and sclk_enable = '0' and red = '1' then  --enable sclk, assert cs, 
					nstate <= start_transmit;	--Stay in this state
					nsclk_enable <= '1';			--Enable sclk
					ncs <= '0';						--Assert chip select (low)
					nsdo <= '0';					--Prevent latch
					nread_ack <= oread_ack;		--Prevent latch
					nred <= '0';
					nfed <= '1';
					nstored_tx_dat <= stored_tx_dat;
					
				elsif sclk_output = '0' and sclk_enable = '1' and fed = '1' then --load msb of transmission data, transition to transmission state, initialize transmission variables
					nstate <= transmit_state;	--Go to transmission state
					nsdo <= stored_tx_dat(word_size-1); --load MSB
					nsclk_enable <= '1';			--Prevent latch
					ncs <= '0';						--Prevent latch
					nread_ack <= '0';				--Clear read acknowledge
					nfed <= '0';
					nred <= '1';
					nstored_tx_dat <= stored_tx_dat;
					
					
				else
					nstate <= start_transmit;	--Prevent latch
					nsdo <= '0';
					ncs <= ocs;
					nred <= red;
					nfed <= fed;
					nsclk_enable <= sclk_enable;
					
					if oread_ack = '0' then
						nstored_tx_dat <= unsigned(tx_dat);	--Store tx data to local
						nread_ack <= '1';
					else 
						nstored_tx_dat <= stored_tx_dat;
						nread_ack <= oread_ack;
					end if;
				end if;
				
				--Prevent inferring of latches
				ntx_finished <= '0';
				ntx_bit_count <= word_size-2;
				nrx_bit_count <= word_size-1;
				nstored_rx_dat <= to_unsigned(0, nstored_rx_dat'length);
				nout_rx_dat <= out_rx_dat;
				
				
			when transmit_state =>		
				nsclk_enable <= sclk_enable;
				ncs <= ocs;
				
				if sclk_output = '0' and fed = '1' then
					nstate <= transmit_state;
					nsdo <= std_logic(stored_tx_dat(tx_bit_count));
					ntx_bit_count <= tx_bit_count - 1;
					nread_ack <= '0';
					nstored_tx_dat <= stored_tx_dat;
					
					ntx_finished <= '0';
					nrx_bit_count <= rx_bit_count;
					nstored_rx_dat <= stored_rx_dat;
					nout_rx_dat <= out_rx_dat;
					nred <= '1';
					nfed <= '0';
					
				elsif sclk_output = '1' and red = '1' then
					nstate <= transmit_state;
					nstored_rx_dat <= stored_rx_dat(word_size-2 downto 0) & sdi;
					nrx_bit_count <= rx_bit_count - 1;
					nstored_tx_dat <= stored_tx_dat;
					nread_ack <= oread_ack;
					
					ntx_finished <= '0';
					ntx_bit_count <= tx_bit_count;
					nsdo <= osdo;
					nout_rx_dat <= out_rx_dat;
					nred <= '0';
					nfed <= '1';
					
				else
					nsdo <= osdo;
					nstored_rx_dat <= stored_rx_dat;
					nred <= red;
					nfed <= fed;
					if transmit = '1' and rx_bit_count = -1 then
						nstate <= transmit_state;
						nrx_bit_count <= word_size-1; --Continue transmitting
						ntx_bit_count <= word_size-1;
						nstored_tx_dat <= unsigned(tx_dat);
						nread_ack <= '1';
						ntx_finished <= '1';
						nout_rx_dat <= stored_rx_dat;
					elsif transmit = '0' and rx_bit_count = -1 then
						nstate <= end_transmit; 
						ntx_finished <= '1';
						nout_rx_dat <= stored_rx_dat;
						
						nread_ack <= '0';
						nstored_tx_dat <= stored_tx_dat;
						nrx_bit_count <= rx_bit_count;
						ntx_bit_count <= tx_bit_count;
					else
						nstate <= transmit_state;
						ntx_finished <= '0';
						nread_ack <= '0';
						nstored_tx_dat <= stored_tx_dat;
						nrx_bit_count <= rx_bit_count;
						ntx_bit_count <= tx_bit_count;
						nout_rx_dat <= out_rx_dat;
					end if;
				end if; 
				
				
			when end_transmit =>
				nstate <= idle;
				
				nsdo <= '0';
				nsclk_enable <= '0';
				ntx_finished <= '0';
				nrx_bit_count <= 0;
				ntx_bit_count <= 0;
				nstored_rx_dat <= stored_rx_dat;
				nstored_tx_dat <= stored_tx_dat;
				nout_rx_dat <= out_rx_dat;
				ncs <= '1';
				nread_ack <= '0';
				nred <= red;
				nfed <= fed;
			
			when others =>
				nstate <= idle;
				nsdo <= osdo;
				nsclk_enable <= sclk_enable;
				ntx_finished <= '0';
				nrx_bit_count <= rx_bit_count;
				ntx_bit_count <= tx_bit_count;
				nstored_rx_dat <= stored_rx_dat;
				nstored_tx_dat <= stored_tx_dat;
				nout_rx_dat <= out_rx_dat;
				ncs <= ocs;
				nread_ack <= oread_ack;
				nred <= red;
				nfed <= fed;
		end case;
	end process;
	
	
	sclk <= 	sclk_output when sclk_enable = '1' else
				'1';
	rx_dat <= std_logic_vector(out_rx_dat);
	read_ack <= oread_ack;
	cs <= ocs;
	sdo <= osdo;
end architecture behavioral;