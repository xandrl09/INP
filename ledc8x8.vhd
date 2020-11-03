--------------------------------------------------------------------------------
-- Autor: Ondøej Andrla                          --
--        xandrl09                               --
-- Datum: 2018                                   --
-- Název: Øízení maticového displeje pomocí FPGA --
--        Návrh poèítaèových systémù             --
--        Projekt è. 1                           --
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- KNIHOVNY
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;


--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------

entity ledc8x8 is
port ( 

  RESET : IN std_logic;
  SMCLK : IN std_logic;
  ROW : OUT std_logic_vector(0 to 7);
  LED : OUT std_logic_vector(7 downto 0)  

);
end ledc8x8;


--------------------------------------------------------------------------------
-- ARCHITEKTURA
--------------------------------------------------------------------------------

architecture main of ledc8x8 is

-- 7372800/256/8 = 3600 = 111000010000
-- zde 11 hodnot proto 11 downto 0
signal PoCtAr : std_logic_vector(11 downto 0) := (others => '0');

-- 7372800/4 = 1843200 = 111000010000000000000
-- zde 20 hodnot proto 20 downto 0
signal MeNiTeLsTaVu : std_logic_vector (20 downto 0) := (others => '0');

signal StaV : std_logic_vector (1 downto 0) := "00";

signal Vystup_ledek : std_logic_vector(7 downto 0) := (others => '0');
signal Vystup_sloupcu : std_logic_vector(7 downto 0) := (others => '0');

signal cer : std_logic := '0';
--------------------------------------------------------------------------------
begin

--   --------------------------------------
-- dìlièka SCMLK
---------------------------------------------
delicka_CE: process(SMCLK, RESET) 
    begin
    --asynchronní reset
		if RESET = '1' then 
			PoCtAr <= (others => '0');
        -- nastupní hrana
		elsif rising_edge(SMCLK) then 
            PoCtAr <= PoCtAr + 1;
				if PoCtAr = "111000010000" then
					cer <= '1';
					PoCtAr <= (others => '0');
				else
					cer <= '0';
				end if;
      end if;
    end process delicka_CE;
   


--   --------------------------------------
-- mìniè stavù
---------------------------------------------
meneni_stavu: process(SMCLK, RESET) 
    begin
    --asynchronní reset
		if RESET = '1' then 
			MeNiTeLsTaVu <= (others => '0');
        -- nastupní hrana
		elsif rising_edge(SMCLK) then
			MeNiTeLsTaVu <= MeNiTeLsTaVu + 1;
			if MeNiTeLsTaVu = "111000010000000000000" then
              StaV <= StaV + 1;
              MeNiTeLsTaVu <= (others => '0');
			end if;
		end if;
    end process meneni_stavu;
       

 	---------------------------------
	--Rotace øádkù 
	---------------------------------
rotace_radku: process(RESET, StaV, SMCLK)
	begin	
		if RESET = '1' then 
			Vystup_sloupcu <= "10000000"; 
		elsif (SMCLK'event and SMCLK = '1' and cer = '1') then
			Vystup_sloupcu <= Vystup_sloupcu(0) & Vystup_sloupcu(7 downto 1); 
		end if;
	end process rotace_radku;


  --------------------------------- -----------------------------------------
	--Dekoder øádkù
	---------------------------------   -------------------------------------------
dekoder: process(Vystup_sloupcu)
	begin
		if StaV = "00" then
			case Vystup_sloupcu is
				when "10000000" => Vystup_ledek <= "11100111";
				when "01000000" => Vystup_ledek <= "11011011";
				when "00100000" => Vystup_ledek <= "10111101";
				when "00010000" => Vystup_ledek <= "10111101";
				when "00001000" => Vystup_ledek <= "10111101";
				when "00000100" => Vystup_ledek <= "10111101";
				when "00000010" => Vystup_ledek <= "11011011";
				when "00000001" => Vystup_ledek <= "11100111";
				when others =>     Vystup_ledek <= "11111111";
			end case;
		end if;
		 if StaV = "01" then
			case Vystup_sloupcu is
				when "10000000" => Vystup_ledek <= "11111111";
				when "01000000" => Vystup_ledek <= "11111111";
				when "00100000" => Vystup_ledek <= "11111111";
				when "00010000" => Vystup_ledek <= "11111111";
				when "00001000" => Vystup_ledek <= "11111111";
				when "00000100" => Vystup_ledek <= "11111111";
				when "00000010" => Vystup_ledek <= "11111111";
				when "00000001" => Vystup_ledek <= "11111111";
				when others =>     Vystup_ledek <= "11111111";
			end case;
		end if;
		 if StaV = "10" then
			case Vystup_sloupcu is
				when "10000000" => Vystup_ledek <= "11111111";
				when "01000000" => Vystup_ledek <= "11100111";
				when "00100000" => Vystup_ledek <= "11011011";
				when "00010000" => Vystup_ledek <= "10111101";
				when "00001000" => Vystup_ledek <= "10111101";
				when "00000100" => Vystup_ledek <= "10000001";
				when "00000010" => Vystup_ledek <= "10111101";
				when "00000001" => Vystup_ledek <= "10111101";
				when others =>     Vystup_ledek <= "11111111";
			end case;
		end if;
		 if StaV = "11" then
			case Vystup_sloupcu is
				when "10000000" => Vystup_ledek <= "11111111";
				when "01000000" => Vystup_ledek <= "11111111";
				when "00100000" => Vystup_ledek <= "11111111";
				when "00010000" => Vystup_ledek <= "11111111";
				when "00001000" => Vystup_ledek <= "11111111";
				when "00000100" => Vystup_ledek <= "11111111";
				when "00000010" => Vystup_ledek <= "11111111";
				when "00000001" => Vystup_ledek <= "11111111";
				when others =>     Vystup_ledek <= "11111111";
			end case;
		end if;

	end process dekoder;

	---------------------------------
	--Svícení ledek------
	---------------------------------
ROW <= Vystup_sloupcu;
LED <= Vystup_ledek;	

end main;

-- 7372800/256/8 = 3600 = 111000010000
-- 7372800/4 = 1843200 = 111000010000000000000