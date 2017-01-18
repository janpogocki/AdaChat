with Ada.Containers.Vectors;
with Ada.Containers.Hashed_Maps;
use Ada.Containers;
with Ada.Strings.Hash;
with Ada.Command_Line;
use Ada.Command_Line;
with Ada.Exceptions;
use Ada.Exceptions;
with Ada.Text_IO;
use Ada.Text_IO;
with Ada.Strings.Fixed;
use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
use Ada.Strings.Unbounded;
with Sockets;
use Sockets;
 
procedure chat_server is
	 
	package Client_Vectors is new Ada.Containers.Vectors (Element_Type => Socket_FD, Index_Type => Positive);
	All_Clients: Client_Vectors.Vector;

	type arrayOfChannels is array(1..1000, 1..2) of Unbounded_String;

---------------------------------------------

	protected Globalne is
		procedure Update (zwr: Out Integer);
		procedure Update(nrPokoju: Integer; nrKolejny: Integer; wartosc: Unbounded_String);
		function PobierzNumer return Integer;
		function PobierzAll_Channels(nrPokoju: Integer; nrKolejny: Integer) return Unbounded_String;

		private
			numerChannel: Integer := 1;
			All_Channels: arrayOfChannels := (others => (To_Unbounded_String("NULL"), To_Unbounded_String("NULL")));
	end Globalne;

	protected body Globalne is
		procedure Update (zwr: Out Integer) is    
		begin
			numerChannel := numerChannel+1;
			zwr := numerChannel;
		end Update;

		procedure Update(nrPokoju: Integer; nrKolejny: Integer; wartosc: Unbounded_String) is    
		begin
			All_Channels(nrPokoju, nrKolejny) := wartosc;
		end Update;

		function PobierzNumer return Integer is (numerChannel);

		function PobierzAll_Channels(nrPokoju: Integer; nrKolejny: Integer) return Unbounded_String is (All_Channels(nrPokoju, nrKolejny));
	end Globalne;

---------------------------------------------

	procedure Write (S : String) is
		procedure Output (Position : Client_Vectors.Cursor) is
			Sock : Socket_FD := Client_Vectors.Element (Position);
		begin
			Put_Line (Sock, S);
		end Output;
	begin
		All_Clients.Iterate (Output'Access);
	end Write;

---------------------------------------------

	task type Client_Task is
		entry Start (FD : Socket_FD);
	end Client_Task;
 
	task body Client_Task is
		Sock : Socket_FD;
		Sock_ID : Positive;
		Name, typCzatu, typCzatu2, nickRozmowcy : Unbounded_String;
		numerPokoju: Integer;
		tmpNumerPokoju, tmpNumerChannel: Integer;
		znalezionyPokoj: Boolean;
		TmpAll_Channels: array(1..1000, 1..2) of Unbounded_String;
	begin
		select
			accept Start (FD : Socket_FD) do
				Sock := FD;
			end Start;
		or
			terminate;
		end select;

		-- 1: ogolny, 2: grupowy, 3: prywatny
		Put_Line(Sock, "WPROWADZ_NICK");
		Name := To_Unbounded_String (Get_Line (Sock));
		Put_Line(Sock, "WPROWADZ_TYP_CZATU");
		typCzatu := To_Unbounded_String (Get_Line (Sock));

		if To_String(typCzatu) = "2" then
			Put_Line(Sock, "WPROWADZ_TYP_CZATU_GRUPOWEGO");
			typCzatu2 := To_Unbounded_String (Get_Line (Sock));

				-- 1: nowy pokoj, 2: istniejacy pokoj
				if To_String(typCzatu2) = "1" then
					Globalne.Update(tmpNumerPokoju);
					Globalne.Update(tmpNumerPokoju,1,To_Unbounded_String("GROUP"));
					Globalne.Update(tmpNumerPokoju,2,To_Unbounded_String("GROUP"));
					Put_Line(Sock, Ada.Strings.Fixed.Trim(Integer'Image(tmpNumerPokoju), Ada.Strings.Left));
				elsif To_String(typCzatu2) = "2" then
					-- sprawdzenie, czy pokój jest typu GROUP
					loop
						Put_Line(Sock, "WPROWADZ_NUMER_POKOJU");
						numerPokoju := Integer'Value(Ada.Strings.Fixed.Trim(Get_Line (Sock), Ada.Strings.Both));
						TmpAll_Channels(numerPokoju,1) := Globalne.PobierzAll_Channels(numerPokoju,1);
						TmpAll_Channels(numerPokoju,2) := Globalne.PobierzAll_Channels(numerPokoju,2);
						if To_String(TmpAll_Channels(numerPokoju,1)) = "GROUP" and To_String(TmpAll_Channels(numerPokoju,2)) = "GROUP" then
							Put_Line(Sock, "OK");
							Put_Line(Sock, Ada.Strings.Fixed.Trim(Integer'Image(numerPokoju), Ada.Strings.Left));
							exit;
						else
							Put_Line(Sock, "DOSTEP_ZABRONIONY");
							Put_Line(Sock, "DOSTEP_ZABRONIONY");
						end if;
					end loop;
				end if;

		elsif To_String(typCzatu) = "3" then
			znalezionyPokoj := false;
			Put_Line(Sock, "WPROWADZ_NICK_ROZMOWCY");
			nickRozmowcy := To_Unbounded_String (Get_Line (Sock));

			-- przeszukanie rozmowcow; jesli istnieje, to bierzemy jego nr pokoju, jezeli nie, to przydzielamy nowy
			tmpNumerChannel := Globalne.PobierzNumer;
			for i in Integer range 1..tmpNumerChannel loop
				TmpAll_Channels(i,1) := Globalne.PobierzAll_Channels(i,1);
				TmpAll_Channels(i,2) := Globalne.PobierzAll_Channels(i,2);

				if (Ada.Strings.Unbounded.Trim(TmpAll_Channels(i,1), Ada.Strings.Both) = Ada.Strings.Unbounded.Trim(Name, Ada.Strings.Both) and Ada.Strings.Unbounded.Trim(TmpAll_Channels(i,2), Ada.Strings.Both) = Ada.Strings.Unbounded.Trim(nickRozmowcy, Ada.Strings.Both)) then
					numerPokoju := i;
					znalezionyPokoj := true;
					exit;
				end if;

			end loop;

			if (not znalezionyPokoj) then
				Globalne.Update(numerPokoju);	
				Globalne.Update(numerPokoju,1,nickRozmowcy);
				Globalne.Update(numerPokoju,2,Name);
			end if;

			Put_Line(Sock, Ada.Strings.Fixed.Trim(Integer'Image(numerPokoju), Ada.Strings.Left));

			if znalezionyPokoj then
				Put_Line(Sock, "TRUE/#$#/" & To_String(nickRozmowcy));
			else
				Put_Line(Sock, "FALSE/#$#/" & To_String(nickRozmowcy));
			end if;

		end if;

		All_Clients.Append (Sock);
		Sock_ID := All_Clients.Find_Index (Sock);

		loop
			declare
				Input : String := Get_Line (Sock);
			begin
				Write (Input);
			end;
		end loop;

		exception
			when Connection_Closed =>
				Put_Line ("Połączenie zakończone");
				Shutdown (Sock, Both);
				All_Clients.Delete (Sock_ID);

	end Client_Task;
 
	Accepting_Socket : Socket_FD;
	Incoming_Socket  : Socket_FD;
 
	type Client_Access is access Client_Task;
	Klient : Client_Access;
begin
	Put_Line("==== AdaChat Server ====");
	
	Socket (Accepting_Socket, PF_INET, SOCK_STREAM);
	Setsockopt (Accepting_Socket, SOL_SOCKET, SO_REUSEADDR, 1);
	Bind (Accepting_Socket, 6000);
	Listen (Accepting_Socket);

	Globalne.Update(1,1,To_Unbounded_String("MAIN"));
	Globalne.Update(1,2,To_Unbounded_String("MAIN"));

	loop
		Put_Line ("Oczekiwanie na połączenie...");
		Accept_Socket (Accepting_Socket, Incoming_Socket);
		Put_Line ("Połączenie nawiązane");
 
		Klient := new Client_Task;
		Klient.Start (Incoming_Socket);
	end loop;
end chat_server;
