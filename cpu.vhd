-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2018 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Ondøej Andrla
--					xandrl09
--					xandrl09@fit.vutbr.cz
--
--==========================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni z pameti (DATA_RDWR='1') / zapis do pameti (DATA_RDWR='0')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WE musi byt '0'
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

-- speï¿½l doï¿½asnï¿½ promï¿½nnï¿½
	signal docasna_promena_oza: std_logic_vector(7 downto 0);


	signal pomocny_stav4: std_logic;
	signal pomocny_stav5: std_logic;
	
--stavy konecneho automatu
	type stavy_stavoveho_automatu is (
		--0-9
		ceske_stavy_cislice,
		--A-F
		ceske_a_moravske_stavy_pismena,
		
		stav1_zacatek,
		stav2_cteni,
		stav3_inkrementace_ukazatele,
		stav4_dekrementace_ukazatele,
		
		stav5_inkrementace_bunky, stav52,
		stav6_dekrementace_bunky, stav62,
		stav7_nacteni_ze_vstupu, stav72,
		stav73_tisk_na_vystup,
		
		null_zastaveni_vykonavani_programu,
		vyjimka_jedeme_nanovo,
		
		komentar_numero_uno,
		komentar_numero_2,
		komenta_numero_tre,
		
		while_stav1_oza,
		while_stav2_oza,
		while_stav3,
		while_mezistav,
		while_stav4,
		
		konec_while_stavu1, konec_while_stavu2, 
		konec_while_stavu3, konec_while_stavu4, 
		konec_while_stavu5, konec_while_stavu6,
		konec_while_mezistav

	);
	
-- ukazatel do pameti a prace s nim
	signal ukazatel: std_logic_vector(9 downto 0);
	
	signal dekrementace_ukazatele: std_logic;
	signal inkrementace_ukazatele: std_logic;
	
-- programovi citaï¿½ a prï¿½ce s nï¿½m	
	signal programovi_citac_oza: std_logic_vector(11 downto 0);
	
	signal dekrementace_programoveho_citace: std_logic;
	signal inkrementaceprogramoveho_citace: std_logic;
	

-- adresa a prï¿½ce s nï¿½	
	signal adresa: std_logic_vector(7 downto 0);
	
	signal inkrementace_adresi: std_logic;
	
	signal dekrementace_adresi: std_logic;

--pomo
	signal pomocny_stav1: std_logic;
	signal pomocny_stav2: std_logic_vector(7 downto 0);
	signal pomocny_stav3: std_logic;

	
	
	-- aktuï¿½lnï¿½ a nï¿½sledujï¿½cï¿½ stav
-- deklarace
	signal aktualni_stav: stavy_stavoveho_automatu;
	signal nasledujici_stav: stavy_stavoveho_automatu;

--multiplexor pro rozhodovanï¿½
--co pustit do alu	
signal muj_uzasny_multiplexor: std_logic_vector(1 downto 0);

------------------------------------------------------------------------------
--proces
------------------------------------------------------------------------------

--incicializace


begin

------------------------------------------------------------------------------
-- instrukï¿½nï¿½ adresovi registr
------------------------------------------------------------------------------

	instruction_address_register: process(CLK, RESET, inkrementace_adresi, dekrementace_adresi)
	begin 
		if(RESET = '1') then
			adresa <= "00000000";
		elsif(CLK'event and CLK = '1') then
			if(inkrementace_adresi = '1') then
				adresa <= adresa + 1;
			elsif(dekrementace_adresi = '1') then
				adresa <= adresa - 1;
			end if;
		end if;	
	end process;

------------------------------------------------------------------------------
-- instrukcni registr
------------------------------------------------------------------------------

	instruction_reg_register: process(CLK, RESET, ukazatel, inkrementace_ukazatele, dekrementace_ukazatele)
	begin

		if(RESET = '1') then
			ukazatel <= "0000000000";
		elsif(CLK'event and CLK = '1') then
			if(inkrementace_ukazatele = '1') then
				ukazatel <= ukazatel + 1;
			elsif(dekrementace_ukazatele = '1') then
				ukazatel <= ukazatel - 1;
			end if;
		end if;

		DATA_ADDR <= ukazatel;

	end process;

-----------------------------------------------------------------------------

	pomo : process(CLK, RESET, pomocny_stav1, pomocny_stav2)
	begin
	
		if(RESET = '1')then
			pomocny_stav1 <= '1';
		end if;
		
		if(CLK'event and CLK = '1') then
			if(pomocny_stav1 = '1')then
				pomocny_stav2 <= pomocny_stav2 + 1;
				pomocny_stav3 <= '0';  
			end if;
		end if;
		
	end process;

------------------------------------------------------------------------------
-- programovï¿½ ï¿½ï¿½taï¿½
------------------------------------------------------------------------------

	pc_program_counter: process(CLK, RESET, programovi_citac_oza, inkrementaceprogramoveho_citace, dekrementace_programoveho_citace)
	begin
		if(RESET = '1') then
			programovi_citac_oza <= "000000000000";
		elsif(CLK'event and CLK = '1') then
			if(dekrementace_programoveho_citace = '1') then
				programovi_citac_oza <= programovi_citac_oza - 1;
			elsif(inkrementaceprogramoveho_citace = '1') then
				programovi_citac_oza <= programovi_citac_oza + 1;
			end if;
		end if;
		
		CODE_ADDR <= programovi_citac_oza;
		
	end process;


------------------------------------------------------------------------------
--pocatek_stavoveho_automatu acumulator
------------------------------------------------------------------------------

	pocatek_stavoveho_automatu_acumulator: process(CLK, RESET)
	begin
		if(RESET = '1') then
			aktualni_stav <= stav1_zacatek;
		elsif(CLK'event and CLK = '1') then
			if(EN = '1') then
				aktualni_stav <= nasledujici_stav;
			end if;
		end if;
	end process;


------------------------------------------------------------------------------
-- multiplexor
------------------------------------------------------------------------------

	multi_multi_multiplexor: process(IN_DATA, DATA_RDATA, muj_uzasny_multiplexor)
	begin
		case(muj_uzasny_multiplexor) is
			when "00" => DATA_WDATA <= docasna_promena_oza;
			when "01" => DATA_WDATA <= DATA_RDATA - 1;
			when "10" => DATA_WDATA <= DATA_RDATA + 1;
			when "11" => DATA_WDATA <= IN_DATA;
			when others =>
		end case;
	end process;



------------------------------------------------------------------------------
--stavovi automat
------------------------------------------------------------------------------

	somotny_stavovy_automat_co_vsechno_ridi: process(CODE_DATA, IN_VLD, OUT_BUSY, DATA_RDATA, adresa, aktualni_stav) 
	begin

-- inkrementaceprogramoveho_citace vseho, aby to dobre fungovalo
		inkrementaceprogramoveho_citace <= '0';
		dekrementace_programoveho_citace <= '0';
		
		CODE_EN <= '1';
		DATA_EN <= '0';
		OUT_WE <= '0';
		IN_REQ <= '0';
		DATA_RDWR <= '0';
		
		inkrementace_ukazatele <= '0';
		dekrementace_ukazatele <= '0';
		dekrementace_adresi <= '0';
		inkrementace_adresi <= '0';
		muj_uzasny_multiplexor <= "11";
 
--velky case
		
		case aktualni_stav is
		
			when stav1_zacatek =>
				CODE_EN <= '1';
				nasledujici_stav <= stav2_cteni;
				
			when stav2_cteni =>
			--dekodace vstupu
				case(CODE_DATA) is
					when X"2B" => nasledujici_stav <= stav5_inkrementace_bunky;
					when X"2D" => nasledujici_stav <= stav6_dekrementace_bunky;
					when X"3C" => nasledujici_stav <= stav4_dekrementace_ukazatele;
					when X"3E" => nasledujici_stav <= stav3_inkrementace_ukazatele;
					
					when X"5B" => nasledujici_stav <= while_stav1_oza;
					when X"5D" => nasledujici_stav <= konec_while_stavu1;
					when X"2E" => nasledujici_stav <= stav7_nacteni_ze_vstupu;
					when X"2C" => nasledujici_stav <= stav73_tisk_na_vystup;
					when X"23" => nasledujici_stav <= komentar_numero_uno;
					
					-- znaky 0-9
					when X"30" | X"31" | X"32" | X"33" | X"34" | X"35" | X"36" | X"37"  | X"38" | X"39"  => nasledujici_stav <= ceske_stavy_cislice;
				
					-- znaky A-F
     				when X"41" | X"42" | X"43" | X"44" | X"45" | X"46" => nasledujici_stav <= ceske_a_moravske_stavy_pismena;
	
					
					when X"00" => nasledujici_stav <= null_zastaveni_vykonavani_programu;
					when others => nasledujici_stav <= vyjimka_jedeme_nanovo;
				end case;

--jednotlive stavy
			
			--	inkrementaceprogramoveho_citace bunky
			when stav5_inkrementace_bunky =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				nasledujici_stav <= stav52;
			when stav52 =>
				muj_uzasny_multiplexor <= "10";
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= stav1_zacatek;
				
				--dekrementace_programoveho_citace bunky
			when stav6_dekrementace_bunky =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				nasledujici_stav <= stav62;
			when stav62 =>
				muj_uzasny_multiplexor <= "01";
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= stav1_zacatek;
				
			
			--necteni
			when stav7_nacteni_ze_vstupu =>
				if(OUT_BUSY = '1') then
					nasledujici_stav <= stav7_nacteni_ze_vstupu;
				
					case(CODE_DATA) is
					when X"2B" => pomocny_stav4 <= pomocny_stav3 ;
					when X"2D" => pomocny_stav4 <= pomocny_stav5 ;
					when others => 
				end case;
					
				else
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					nasledujici_stav <= stav72;
				end if;
			when stav72 =>
				OUT_DATA <= DATA_RDATA;
				OUT_WE <= '1';
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= stav1_zacatek;
				--tisk
			when stav73_tisk_na_vystup =>
				IN_REQ <= '1';
				if(IN_VLD = '0') then
					nasledujici_stav <= stav73_tisk_na_vystup;
				else
					muj_uzasny_multiplexor <= "11";
					DATA_RDWR <= '0';
					DATA_EN <= '1';
					inkrementaceprogramoveho_citace <= '1';
					nasledujici_stav <= stav1_zacatek;
				end if;
				
				
				--inkrementaceprogramoveho_citace ukazatele
			when stav3_inkrementace_ukazatele =>
				inkrementaceprogramoveho_citace <= '1';
				inkrementace_ukazatele <= '1';
				nasledujici_stav <= stav1_zacatek;
				
				--dekrementace_programoveho_citace ukazatele
			when stav4_dekrementace_ukazatele =>
				inkrementaceprogramoveho_citace <= '1';
				dekrementace_ukazatele <= '1';
				nasledujici_stav <= stav1_zacatek;
				
				-- while stavy
				
			when while_stav1_oza =>
				DATA_RDWR <= '1';
				inkrementaceprogramoveho_citace <= '1';
				DATA_EN <= '1';
				nasledujici_stav <= while_stav2_oza;
				
			when while_stav2_oza =>
				if(DATA_RDATA = "00000000") then
					inkrementace_adresi <= '1';
					nasledujici_stav <= while_stav3;
				else
					nasledujici_stav <= stav1_zacatek;
				end if;
				
			when while_stav3 =>
				if(adresa = "00000000") then
					nasledujici_stav <= stav1_zacatek;
				else
					CODE_EN <= '1';
					nasledujici_stav <= while_mezistav;
				end if;

			when while_mezistav =>
			if(DATA_RDATA = "00000000") then
					pomocny_stav2 <= pomocny_stav2 + 1;
			end if;
			
			if(adresa = "00000000")then
				pomocny_stav2 <= pomocny_stav2 + 2;
			end if;
			
				nasledujici_stav <= while_stav4;
		

			when while_stav4 =>
				if(CODE_DATA = X"5B") then
					inkrementace_adresi <= '1';
				elsif(CODE_DATA = X"5D") then
					dekrementace_adresi <= '1';
				end if;
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= while_stav3;

				--konce vhile
				
			when konec_while_stavu1 =>
				DATA_RDWR <= '1';
				DATA_EN <= '1';
				nasledujici_stav <= konec_while_stavu2;
				
			when konec_while_stavu2 =>
				if(DATA_RDATA = "00000000") then
					inkrementaceprogramoveho_citace <= '1';
					nasledujici_stav <= stav1_zacatek;
				else
					nasledujici_stav <= konec_while_stavu3;
				end if;
				
			when konec_while_stavu3 =>
				dekrementace_programoveho_citace <= '1';
				inkrementace_adresi <= '1';
				nasledujici_stav <= konec_while_mezistav;
				

			when konec_while_mezistav =>
			if(DATA_RDATA = "00000000") then
					pomocny_stav2 <= pomocny_stav2 + 1;
			end if;
			
			if(adresa = "00000000")then
				pomocny_stav2 <= pomocny_stav2 + 2;
			end if;
			
			
				nasledujici_stav <= konec_while_stavu4;

				
			when konec_while_stavu4 =>
				if(adresa = "00000000") then
					nasledujici_stav <= stav1_zacatek;
				else
					CODE_EN <= '1';
					nasledujici_stav <= konec_while_stavu5;
				end if;
				
			when konec_while_stavu5 =>
				if(CODE_DATA = X"5D") then
					inkrementace_adresi <= '1';
				elsif(CODE_DATA = X"5B") then
					dekrementace_adresi <= '1';
				end if;
				nasledujici_stav <= konec_while_stavu6;
				
			when konec_while_stavu6 =>
				if(adresa = "00000000") then
					inkrementaceprogramoveho_citace <= '1';
				else
					dekrementace_programoveho_citace <= '1';
				end if;
				nasledujici_stav <= konec_while_stavu4;

		--0-9
			when ceske_stavy_cislice =>
				DATA_EN <= '1';
				inkrementaceprogramoveho_citace <= '1';
				muj_uzasny_multiplexor <= "00";
				docasna_promena_oza <= CODE_DATA(3 downto 0) & "0000";
				nasledujici_stav <= stav1_zacatek;
				
			--A-F
			when ceske_a_moravske_stavy_pismena =>
				DATA_EN <= '1';
				inkrementaceprogramoveho_citace <= '1';
				muj_uzasny_multiplexor <= "00";
				docasna_promena_oza <= (CODE_DATA(3 downto 0) + std_logic_vector(conv_unsigned(9, docasna_promena_oza'LENGTH)(3 downto 0))) & "0000";
				nasledujici_stav <= stav1_zacatek;


			--zacatek komentare #
			when komentar_numero_uno =>
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= komentar_numero_2;
				--stred komentare
			when komentar_numero_2 =>
				CODE_EN <= '1';
				nasledujici_stav <= komenta_numero_tre;
				-- konec komentare #
			when komenta_numero_tre =>
				if CODE_DATA = X"23" then
					inkrementaceprogramoveho_citace <= '1';
					nasledujici_stav <= stav1_zacatek;
				else
					nasledujici_stav <= komentar_numero_uno;
				end if;

			--vyjmka
			when vyjimka_jedeme_nanovo =>
				inkrementaceprogramoveho_citace <= '1';
				nasledujici_stav <= stav1_zacatek;
				
			--	null
			when null_zastaveni_vykonavani_programu =>
				nasledujici_stav <= null_zastaveni_vykonavani_programu;

				
			when others =>
		end case;
	end process;
end behavioral;
 
