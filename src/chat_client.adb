with Ada.Text_IO;
use Ada.Text_IO;
with Ada.Float_Text_IO;
use Ada.Float_Text_IO;
with Ada.Calendar;
with Ada.Calendar.Formatting;
use Ada.Calendar;
with Ada.Numerics.Float_Random;
with Ada.Strings;
use Ada.Strings;
with Ada.Strings.Fixed;
use Ada.Strings.Fixed;
with Ada.Exceptions;
use Ada.Exceptions;
with Ada.Containers.Vectors;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Sockets;
use Sockets;

procedure chat_client is

-- zwraca podzielone separatorem nieograniczone stringi
-- KANAL/#$#/TYPE/#$#/NICK/#$#/MESSAGE
type arrayString is array(1..10) of Unbounded_String;
function splitString(str: String; separator: String) return arrayString is
	strRanges: array(1..10, 1..2) of Integer;
	i: Integer := 0;
	strLen: Integer := str'Size/8;
	separatorLen: Integer := separator'Size/8;
	tab: arrayString;
begin
	strRanges(1,1) := 1;
	for j in Integer range 1 .. strLen-separatorLen loop
		if str(j .. j+(separatorLen-1)) = separator then
			i := i+1;
			strRanges(i, 2) := j-1;
			strRanges(i+1, 1) := j+separatorLen;
		end if;
	end loop;
	strRanges(i+1, 2) := strLen;

	for j in Integer range 1 .. i+1 loop
		tab(j) := To_Unbounded_String(str( (strRanges(j,1)) .. (strRanges(j,2)) ));
	end loop;

	return tab;
end splitString;

-------------------------------------

	task type nasluchiwacz is
		entry Start (FD : Socket_FD; ch : String; nic : String);
	end nasluchiwacz;

	task body nasluchiwacz is
		Sock : Socket_FD;
		channel: Unbounded_String;
		nick: Unbounded_String;
		explode : arrayString;
		explode2 : arrayString;
	begin
		select
			accept Start (FD : Socket_FD; ch : String; nic : String) do
				Sock := FD;
				channel := To_Unbounded_String(ch);
				nick := To_Unbounded_String(nic);
			end Start;			
		or
			terminate;
		end select;

		loop
			begin
				explode := splitString(Get_Line(Sock), "/#$#/"); 
				explode2 := splitString(Ada.Calendar.Formatting.Image(Ada.Calendar.Clock), " ");

				if To_String(explode(1)) = To_String(channel) then

					if To_String(explode(2)) = "EXIT" and To_String(explode(3)) = nick then
						exit;
					elsif To_String(explode(2)) = "WRITE" then
						if To_String(explode(3)) /= nick then
							Put (ASCII.ESC & "[33m");
							Put_Line("[" & To_String(explode2(2)) & "] " & To_String(explode(4)));
							Put (ASCII.ESC & "[00m");
						end if;
					elsif To_String(explode(2)) = "MESSAGE" then
						if To_String(explode(3)) /= nick then
							Put_Line("[" & To_String(explode2(2)) & "] " & To_String(explode(4)));
						end if;
					elsif To_String(explode(2)) = "JOIN" then
						if To_String(explode(3)) /= nick then
							Put (ASCII.ESC & "[31m");
							Put_Line("[" & To_String(explode2(2)) & "] " & To_String(explode(4)));
							Put (ASCII.ESC & "[00m");
						end if;
					end if;

				end if;
			end;
		end loop;
	end nasluchiwacz;

	type nasluchiwaczType is access nasluchiwacz;
	NasluchiwaczZm: nasluchiwaczType;

-------------------------------------

	procedure clearScreen is
	begin
		Put(ASCII.ESC & "[2J");
	end clearScreen;

-------------------------------------

	procedure startChat(host: String; nick: String; wyborCzatu: Character) is
		Sock : Socket_FD;
		explode2, explode3 : arrayString;
		wybor_czatu2 : Character;
		wyborCzatuStr, wybor_czatu3, tmp : Unbounded_String; 
	begin
		Socket (Sock, PF_INET, SOCK_STREAM);
		Setsockopt (Sock, SOL_SOCKET, SO_REUSEADDR, 1);
		Connect (Sock, host, 6000);

		explode2 := splitString(Ada.Calendar.Formatting.Image(Ada.Calendar.Clock), " ");

		tmp := To_Unbounded_String(Get_Line(Sock));  --WPROWADZ_NICK
		Put_Line (Sock, nick);

		tmp := To_Unbounded_String(Get_Line(Sock)); --WPROWADZ_TYP_CZATU

		if wyborCzatu = '1' then
			wyborCzatuStr := To_Unbounded_String("1");
			Put_Line (Sock, "1");
		elsif wyborCzatu = '2' then
			Put_Line (Sock, "2");

			tmp := To_Unbounded_String(Get_Line(Sock)); --WPROWADZ_TYP_CZATU_GRUPOWEGO

			Put_Line("");
			Put_Line("1. Utwórz nowy pokój rozmowy grupowej");
			Put_Line("2. Dołącz do pokoju");
			Put_Line("");

			loop
				Get_Immediate(wybor_czatu2);

				if (wybor_czatu2 = '1' or wybor_czatu2 = '2') then exit; end if;
			end loop;

			Put_Line("");

			if wybor_czatu2 = '1' then
				Put_Line(Sock, "1");
				wyborCzatuStr := To_Unbounded_String(Trim(Get_Line(Sock),Both)); --np. 2
			elsif wybor_czatu2 = '2' then
				Put_Line(Sock, "2");
				loop
					tmp := To_Unbounded_String(Get_Line(Sock)); --WPROWADZ_NUMER_POKOJU
					Put("Wprowadź numer pokoju: ");
					Put_Line(Sock, Get_Line);			
					tmp := To_Unbounded_String(Trim(Get_Line(Sock),Both)); --np. OK

					if tmp = To_Unbounded_String("OK") then
						wyborCzatuStr := To_Unbounded_String(Get_Line(Sock));
						exit;
					else
						tmp := To_Unbounded_String(Get_Line(Sock)); --DOSTEP_ZABRONIONY
						Put_Line("Nie masz uprawnień do wejścia na ten kanał. Wybierz inny.");
						Put_Line("");
					end if;
				end loop;
			end if;
		elsif wyborCzatu = '3' then
			Put_Line (Sock, "3");

			tmp := To_Unbounded_String(Get_Line(Sock)); --WPROWADZ_NICK_ROZMOWCY

			Put_Line("");
			Put("Podaj nick adwersarza: ");
			Put_Line(Sock, Get_Line);

			wyborCzatuStr := To_Unbounded_String(Trim(Get_Line(Sock), Both)); --np. 3
			tmp := To_Unbounded_String(Get_Line(Sock)); --TRUE lub nick_adwersarza - czy jest adwersarz czy nie
		end if;

		clearScreen;

		Put (ASCII.ESC & "[01m");
		Put_Line ("[" & To_String(explode2(2)) & "] " & "INFO: Połączenie nawiązane. Aby zakończyć, wpisz: !exit");

		if wyborCzatu = '2' then
			Put_Line ("[" & To_String(explode2(2)) & "] " & "INFO: Numer pokoju: " & To_String(wyborCzatuStr));
		end if;

		explode3 := splitString(To_String(tmp), "/#$#/");

		if wyborCzatu = '3' and explode3(1) = To_Unbounded_String("FALSE") then
			Put_Line ("[" & To_String(explode2(2)) & "] " & "INFO: Trwa oczekiwanie na " & To_String(explode3(2)) & "...");
		elsif wyborCzatu = '3' and explode3(1) = To_Unbounded_String("TRUE") then
			Put_Line ("[" & To_String(explode2(2)) & "] " & "INFO: Użytkownik " & To_String(explode3(2)) & " już na Ciebie czeka. Miłej rozmowy!");
		end if;

		Put (ASCII.ESC & "[00m");

		-- info o dolaczeniu
		Put_Line(Sock, To_String(wyborCzatuStr) & "/#$#/JOIN/#$#/" & nick & "/#$#/INFO: " & nick & " dołączył właśnie do czatu");

		NasluchiwaczZm := new nasluchiwacz;
		NasluchiwaczZm.Start(Sock, To_String(wyborCzatuStr), nick);

		loop
			declare
				wiadomosc: Unbounded_String;
				wiadomosc10000: String(1..10000) := (others => ' ');
				wiadomosc_int: Integer;
				Ch: Character;
				ChStr: String(1..1);
				Available: Boolean;
			begin
				Available := false;

				loop
					Get_Immediate(Ch, Available);
					if Available then exit; end if;
				end loop;

				explode2 := splitString(Ada.Calendar.Formatting.Image(Ada.Calendar.Clock), " ");

				Put (ASCII.ESC & "[32m");
				Put("[" & To_String(explode2(2)) & "] " & nick & ": ");
				Put(Ch);
				ChStr(1) := Ch;
				Put (ASCII.ESC & "[00m");

				if Ch /= '!' then
					Put_Line(Sock, To_String(wyborCzatuStr) & "/#$#/WRITE/#$#/" & nick & "/#$#/INFO: " & nick & " pisze...");
				end if;

				Put (ASCII.ESC & "[32m");
				Get_Line(wiadomosc10000, wiadomosc_int);
				Put (ASCII.ESC & "[00m");

				Append(wiadomosc, To_Unbounded_String(Trim(ChStr,Both)));
				Append(wiadomosc, To_Unbounded_String(Trim(wiadomosc10000,Both)));

				if wiadomosc = "!exit" then	
					Put_Line("");				
					Put_Line(Sock, To_String(wyborCzatuStr) & "/#$#/JOIN/#$#/" & nick & "/#$#/INFO: " & nick & " rozłączył się");			
					Put_Line(Sock, To_String(wyborCzatuStr) & "/#$#/EXIT/#$#/" & nick & "/#$#/EXIT");			
					Shutdown (Sock, Both);
				end if;

				Put_Line(Sock, To_String(wyborCzatuStr) & "/#$#/MESSAGE/#$#/" & nick & "/#$#/" & nick & ": " & To_String(wiadomosc));
			end;
		end loop;

		exception
				when Connection_Closed =>
					Put_Line ("Do zobaczenia!");
	end startChat;

-------------------------------------

	procedure chatStartScreen is
		host: Unbounded_String;
		host50: String(1..50) := (others => ' ');
		host_int: Integer;

		nick: Unbounded_String;
		nick50: String(1..50) := (others => ' ');
		nick_int: Integer;

		wybor_czatu: Character;
	begin
		clearScreen;
		Put_Line("==== AdaChat Client ====");
		Put_Line("");
		Put_Line("Podaj host lub zostaw puste, aby wybrać localhost:");
		Put("> ");
		Get_Line (host50, host_int);
		host := To_Unbounded_String(Trim(host50,Both));

		if host = Null_Unbounded_String then
			Put("> localhost");
			host := To_Unbounded_String("localhost");
			Put_Line("");
		end if;		

		Put_Line("");
		Put_Line("Podaj swój nick:");

		while nick = Null_Unbounded_String or nick = To_Unbounded_String("MAIN") or nick = To_Unbounded_String("GROUP") or nick = To_Unbounded_String("INFO") loop
			Put("> ");
			Get_Line (nick50, nick_int);
			nick := To_Unbounded_String(Trim(nick50,Both));
			
			if nick = Null_Unbounded_String or nick = To_Unbounded_String("MAIN") or nick = To_Unbounded_String("GROUP") or nick = To_Unbounded_String("INFO") then
				Put_Line("Niepoprawny nick. Spróbuj ponownie");
				Put_Line("");
				nick50(5) := ' ';
			end if;
		end loop;

		Put_Line("");
		Put_Line("1. Chat ogólny");
		Put_Line("2. Chat grupowy");
		Put_Line("3. Chat prywatny");
		Put_Line("");
		Get_Immediate(wybor_czatu);

		if (wybor_czatu = '1' or wybor_czatu = '2' or wybor_czatu = '3') then
			startChat(To_String(host), To_String(nick), wybor_czatu);
		end if;
	end chatStartScreen;

begin
	chatStartScreen;
end chat_client;    
