---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:38:18 05/15/2014 
-- Design Name: 
-- Module Name:    UC_slave - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: la UC incluye un contador de 2 bits para llevar la cuenta de las transferencias de bloque y una m�quina de estados
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UC_MC_CB is
    Port ( 	clk : in  STD_LOGIC;
			reset : in  STD_LOGIC;
			-- �rdenes del MIPS
			RE : in  STD_LOGIC; 
			WE : in  STD_LOGIC;
			-- Respuesta al MIPS
			ready : out  STD_LOGIC; -- indica si podemos procesar la orden actual del MIPS en este ciclo. En caso contrario habr� que detener el MIPs
			-- Se�ales de la MC
			hit0 : in  STD_LOGIC; --se activa si hay acierto en la via 0
			hit1 : in  STD_LOGIC; --se activa si hay acierto en la via 1
			via_2_rpl :  in  STD_LOGIC; --indica que via se va a reemplazar
			addr_non_cacheable: in STD_LOGIC; --indica que la direcci�n no debe almacenarse en MC. En este caso porque pertenece a la scratch
			internal_addr: in STD_LOGIC; -- indica que la direcci�n solicitada es de un registro de MC
			MC_WE0 : out  STD_LOGIC;
            MC_WE1 : out  STD_LOGIC;
           	-- Se�ales para indicar la operaci�n que se quiere hacer en el bus
       		MC_bus_Read : out  STD_LOGIC; -- para pedir el bus en acceso de lectura
			MC_bus_Write : out  STD_LOGIC; --  para pedir el bus en acceso de escritura
			MC_tags_WE : out  STD_LOGIC; -- para escribir la etiqueta en la memoria de etiquetas
            palabra : out  STD_LOGIC_VECTOR (1 downto 0);--indica la palabra actual dentro de una transferencia de bloque (1�, 2�...). HABRA QUE USAR COUNT_ENABLE
            mux_origen: out STD_LOGIC; -- Se utiliza para elegir si el origen de la direcci�n de la palabra y el dato es el Mips (cuando vale 0) o la UC y el bus (cuando vale 1)
			block_addr : out  STD_LOGIC; -- indica si la direcci�n a enviar es la de bloque (rm) o la de palabra (w)
			mux_output: out  std_logic_vector(1 downto 0); -- para elegir si le mandamos al procesador la salida de MC (valor 0),los datos que hay en el bus (valor 1), o un registro interno( valor 2)
			-- se�ales para los contadores de rendimiento de la MC
			inc_m : out STD_LOGIC; -- indica que ha habido un fallo en MC
			inc_w : out STD_LOGIC; -- indica que ha habido una escritura en MC
			inc_r : out STD_LOGIC; -- indica que ha habido una lectura en MC
			inc_cb :out STD_LOGIC; -- indica que ha habido un reemplazo sucio en MC
			-- Gesti�n de errores
			unaligned: in STD_LOGIC; --indica que la direcci�n solicitada por el MIPS no est� alineada
			Mem_ERROR: out std_logic; -- Se activa si en la ultima transferencia el esclavo no respondi� a su direcci�n
			load_addr_error: out std_logic; --para controlar el registro que guarda la direcci�n que caus� error
			-- Gesti�n de los bloques sucios
			send_dirty: out std_logic;-- Indica que hay que enviar la @ del bloque sucio
			Update_dirty	: out  STD_LOGIC; --indica que hay que actualizar los bits dirty tanto por que se ha realizado una escritura, como porque se ha enviado el bloque sucio a memoria
			dirty_bit_rpl : in  STD_LOGIC; --indica si el bloque a reemplazar es sucio
			Block_copied_back	: out  STD_LOGIC; -- indica que se ha enviado a memoria un bloque que estaba sucio. Se usa para elegir la m�scara que quita el bit de sucio
			-- Para gestionar las transferencias a trav�s del bus
			bus_TRDY : in  STD_LOGIC; --indica que la memoria puede realizar la operaci�n solicitada en este ciclo
			Bus_DevSel: in  STD_LOGIC; --indica que la memoria ha reconocido que la direcci�n est� dentro de su rango
			Bus_grant :  in  STD_LOGIC; --indica la concesi�n del uso del bus
			MC_send_addr_ctrl : out  STD_LOGIC; --ordena que se env�en la direcci�n y las se�ales de control al bus
            MC_send_data : out  STD_LOGIC; --ordena que se env�en los datos
            Frame : out  STD_LOGIC; --indica que la operaci�n no ha terminado
            last_word : out  STD_LOGIC; --indica que es el �ltimo dato de la transferencia
            Bus_req :  out  STD_LOGIC --indica la petici�n al �rbitro del uso del bus
			);
end UC_MC_CB;

architecture Behavioral of UC_MC_CB is
 
component counter is 
	generic (
	   size : integer := 10
	);
	Port ( clk : in  STD_LOGIC;
	       reset : in  STD_LOGIC;
	       count_enable : in  STD_LOGIC;
	       count : out  STD_LOGIC_VECTOR (size-1 downto 0)
					  );
end component;		           
-- Ejemplos de nombres de estado. No hay que usar estos. Nombrad a vuestros estados con nombres descriptivos. As� se facilita la depuraci�n
type state_type is (Inicio, Arbitro, ADDR, Scratch, Fetch, WriteAround, single_word_transfer_addr, read_block, write_dirty_block, single_word_transfer_data, block_transfer_addr, block_transfer_data, Send_Addr, Send_ADDR_CB, fallo, CopyBack, bajar_Frame); 
type error_type is (memory_error, No_error); 
signal state, next_state : state_type; 
signal error_state, next_error_state : error_type; 
signal last_word_block: STD_LOGIC; --se activa cuando se est� pidiendo la �ltima palabra de un bloque
signal one_word: STD_LOGIC; --se activa cuando s�lo se quiere transferir una palabra
signal count_enable: STD_LOGIC; -- se activa si se ha recibido una palabra de un bloque para que se incremente el contador de palabras
signal hit: std_logic;
signal palabra_UC : STD_LOGIC_VECTOR (1 downto 0);
begin

hit <= hit0 or hit1;	
 
--el contador nos dice cuantas palabras hemos recibido. Se usa para saber cuando se termina la transferencia del bloque y para direccionar la palabra en la que se escribe el dato leido del bus en la MC
word_counter: counter 	generic map (size => 2)
						port map (clk, reset, count_enable, palabra_UC); --indica la palabra actual dentro de una transferencia de bloque (1�, 2�...)

last_word_block <= '1' when palabra_UC="11" else '0';--se activa cuando estamos pidiendo la �ltima palabra

palabra <= palabra_UC;

   State_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            state <= Inicio;
         else
            state <= next_state;
         end if;        
      end if;
   end process;
 
   ---------------------------------------------------------------------------
-- 2023
-- M�quina de estados para el bit de error
---------------------------------------------------------------------------

error_reg: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then           
            error_state <= No_error;
        else
            error_state <= next_error_state;
         end if;   
      end if;
   end process;
   
--Salida Mem Error
Mem_ERROR <= '1' when (error_state = memory_error) else '0';

   
   --MEALY State-Machine - Outputs based on state and inputs
   --Sensitivity list: check that all the combinational inputs used are included
   OUTPUT_DECODE: process (state, hit, last_word_block, bus_TRDY, RE, WE, Bus_DevSel, Bus_grant, via_2_rpl, hit0, hit1, dirty_bit_rpl, addr_non_cacheable, internal_addr, unaligned)
   begin
-- Default values
	MC_WE0 <= '0';
	MC_WE1 <= '0';
	MC_bus_Read <= '0';
	MC_bus_Write <= '0';
	MC_tags_WE <= '0';
    ready <= '0';
    mux_origen <= '0';
    MC_send_addr_ctrl <= '0';
    MC_send_data <= '0';
    next_state <= state;  
	count_enable <= '0';
	Frame <= '0';
	block_addr <= '0';
	inc_m <= '0';
	inc_w <= '0';
	inc_r <= '0';
	inc_cb <= '0';
	Bus_req <= '0';
	one_word <= '0';
	mux_output <= "00";
	last_word <= '0';
	next_error_state <= error_state; 
	load_addr_error <= '0';
	send_dirty <= '0';
	Update_dirty <= '0';
	Block_copied_back <= '0';
	
	    -- Inicio state          
    CASE state is 
		when Inicio => 			
        -- Estado Inicio          
		    if (RE = '0' and WE = '0') then -- si no piden nada no hacemos nada
				next_state <= Inicio;
				ready <= '1';
			elsif ((RE = '1') or (WE = '1')) and (unaligned ='1') then -- si el procesador quiere leer una direcci�n no alineada
				-- Se procesa el error y se ignora la solicitud
				next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --�ltima direcci�n incorrecta (no alineada)
				load_addr_error <= '1';
		    elsif (RE= '1' and  internal_addr ='1') then -- si quieren leer un registro de la MC se lo mandamos
		    	next_state <= Inicio;
				ready <= '1';
				inc_r <= '1'; -- se lee la MC ¿se pone?
				mux_output <= "10"; -- La salida es un registro interno de la MC
				next_error_state <= No_error; --Cuando se lee el registro interno el controlador quita la se�al de error
			elsif (WE = '1'  and  internal_addr ='1') then -- si quieren escribir en el registro interno de la MC se genera un error porque es s�lo de lectura
		    	next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --�ltima direcci�n incorrecta (intento de escritura en registro de lectura)
				load_addr_error <= '1';
			elsif (((RE= '1') or (WE= '1')) and (addr_non_cacheable='1')) then  --fallo de lectura y escritura o no cacheable
				next_state <= Arbitro;
			elsif (RE= '1' and  hit='1') then -- si piden y es acierto de lectura mandamos el dato
		        next_state <= Inicio;
				ready <= '1';
				inc_r <= '1'; -- se lee la MC
				mux_output <= "00"; --Es el valor por defecto. No hace falta ponerlo. La salida es un dato almacenado en la MC
			elsif ( WE= '1' and  hit='1') then -- si piden y es acierto de escritura 
		        next_state <= Inicio;
				ready <= '1';
				inc_w <= '1';
				-- Ponemos sucio el bloque en memoria cache, comprobando cual de las vias se ha usado
				Update_dirty <= '1';
				if hit0 = '1' then
					MC_WE0 <= '1';
				else
					MC_WE1 <= '1';
				end if;
			elsif (((RE= '1') or (WE= '1')) and (hit='0')) then  --fallo de lectura y escritura o no cacheable
				inc_m <= '1';
				next_state <= Arbitro;
				
			end if;

        when Arbitro =>
		-- Estado arbitro
		    Bus_req <= '1'; -- Solicitar entrar al bus, asi el grant dara un valor

		    if Bus_grant = '0' then -- Si bus no libre -> Bucle
				next_state <= Arbitro;
			else
				next_state <= ADDR;
			end if;

		when ADDR => -- Estado para derivar segun la operación que sea, prepara el bus para enviar lo que sea necesario
			Frame <= '1'; -- Ocupo el bus, digo que estoy "trabajando"
			MC_send_addr_ctrl <= '1'; -- Poner la dirección para acceder en el bus
			MC_bus_Read <= RE; -- Para saber si estoy leyendo
			MC_bus_Write <= WE; -- Para saber si estoy escribiendo

		    if Bus_DevSel = '0' then -- Nadie encontro la dirección en su memoria
				next_state <= Inicio;
				ready <= '1';
				next_error_state <= memory_error; --�ltima direcci�n incorrecta (no alineada)
				load_addr_error <= '1';
				
			elsif (addr_non_cacheable = '1') then -- Scratch: Direccion de datos no cacheable
				next_state <= Scratch; 
				-- Es una palabra block_addr <= '0';

			elsif (RE = '1' and dirty_bit_rpl = '0') then -- FETCH: Fallo de lectura, cacheable y bloque no esta sucio, faltaria pero ya se tiene en cuenta: addr_non_cacheable = '0', hit='0', internal_addr = '0' y unaligned = '0'
				next_state <= Fetch;
				block_addr <= '1'; -- Se lee bloque (solo se activa una vez recortando el send_addr, poniendo a 0 los 2 bits que indentifican la palabra)

			elsif (RE = '1' and dirty_bit_rpl = '1') then -- CopyBack: Fallo de lectura, cacheable y bloque esta sucio, faltaria pero ya se tiene en cuenta: addr_non_cacheable = '0', hit='0', internal_addr = '0' y unaligned = '0'
				send_dirty <= '1';
				MC_bus_Read <= '0'; -- Para saber si estoy leyendo
				MC_bus_Write <= '1'; -- Para saber si estoy escribiendo
				block_addr <= '1'; -- Se lee bloque (solo se activa una vez recortando el send_addr, poniendo a 0 los 2 bits que indentifican la palabra)
				next_state <= CopyBack;

			elsif (WE = '1') then -- WriteAround: Escribir en MD (Memoria principal), faltaria pero ya se tiene en cuenta: addr_non_cacheable = '0', hit='0', internal_addr = '0' y unaligned = '0'
				next_state <= WriteAround;
				-- Es una palabra block_addr <= '0'; En este caso porque al escribir en memoria principal no se escribe todo el bloque, solo hay que escribir una palabra directamente en MD (MP).
			end if;

		when Fetch =>	    
			Frame <= '1'; -- Ocupo el bus, digo que estoy "trabajando"
			MC_bus_Read <= '1';
			mux_origen <= '1'; -- Indexamos la palabra a escribir por el contador para el bloque de cache

			if bus_TRDY = '0' then -- Si la palabra de la memoria no esta lista en el bus -> Bucle 
				next_state <= Fetch;

			elsif last_word_block = '0' then -- Sacara 0 hasta que lea todo el bloque (debe dar 0 3 veces por las 3 palabras y a la cuarta palabra dara acierto)
				next_state <= Fetch;
				count_enable <= '1'; -- Aumentar contador de palabra, se reinicia por un overflow que hace que de 11 cambie a 00

				-- Politica FIFO: Mirar en que via escribo la palabra en MC
				if via_2_rpl = '0' then
					MC_WE0 <= '1'; -- Escribir en MC via 0
				else
					MC_WE1 <= '1'; -- Escribir en MC via 1
				end if;

			else -- Traer el bloque
			    count_enable <= '1'; -- Reiniciar contador
				last_word <= '1'; -- Decir que es la ultima palabra
				MC_tags_WE <= '1'; -- Escribo el TAG del bloque y actualizo el registro de la politica FIFO

				-- Politica FIFO: Mirar en que via escribo la palabra en MC
				if via_2_rpl = '0' then
					MC_WE0 <= '1'; -- Escribir en MC via 0
				else
					MC_WE1 <= '1'; -- Escribir en MC via 1
				end if;

				next_state <= Inicio; -- El Frame se pondra a 0 en inicio
			end if;

		when CopyBack =>
		    Frame <= '1'; -- Ocupo el bus, digo que estoy "trabajando"
			MC_bus_Write <= '1'; -- Le paso palabra a palabra al bus el bloque sucio
			MC_send_data <= '1'; -- Se indica a la MC que tiene que pasar el dato
			mux_origen <= '1'; -- Enviar la palabra indexada por el contador a memoria principal

			if bus_TRDY = '0' then -- Si la palabra de la memoria no esta lista en el bus -> Bucle 
				next_state <= CopyBack;

			elsif last_word_block = '0' then -- Sacara 0 hasta que lea todo el bloque (debe dar 0 3 veces por las 3 palabras y a la cuarta palabra dara acierto)
				next_state <= CopyBack;
				count_enable <= '1'; -- Aumentar contador de palabra, se reinicia por un overflow que hace que de 11 cambie a 00

			else -- Traer el bloque
			    count_enable <= '1'; -- Reiniciar contador
				last_word <= '1'; -- Decir que es la ultima palabra
				Update_dirty <= '1'; -- Se limpia el bit sucio del bloque
				-- Como update_dirty esta habilitado poner el bit de dirty a 0, lo hace en esta linea de la via: 
				-- dirty_bits_in 	<= set_clean_mask when (Block_copied_back ='1'), usa un mas máscara para limpiar ese bit
				Block_copied_back <= '1'; 
				inc_cb <= '1'; -- Contador copy back
				next_state <= ADDR; -- El Frame se pondra a 0 en inicio
			end if;

		when WriteAround =>
			Frame <= '1'; -- Ocupo el bus, digo que estoy "trabajando"
			MC_bus_Write <= '1'; -- Le paso palabra a palabra al bus el bloque sucio
			MC_send_data <= '1'; -- Se indica a la MC que tiene que pasar el dato

			if bus_TRDY = '0' then -- Si la palabra de la memoria no esta lista en el bus -> Bucle 
				next_state <= WriteAround;
			else -- Traer el bloque
				-- Aunque sea solo una palabra se pone porque last_word porque la maquina de estados de MD necesita esa condicion
				-- para terminar el proceso de escritura en ella
				last_word <= '1'; -- Decir que es la ultima palabra 
				ready <= '1'; -- Se pone ready a uno ya que no hara hit en cache cuando pase a Inicio
				next_state <= Inicio; -- El Frame se pondra a 0 en inicio
			end if;

		when Scratch =>
		    -- El devSel se pone a 1 para scratch ya que esta dentro del rango que eso se hace con su señal addr_in_range y el frame esta a 1
			Frame <= '1'; -- Ocupo el bus, digo que estoy "trabajando"
			MC_bus_Read <= RE; -- Para saber si estoy leyendo
			MC_bus_Write <= WE; -- Para saber si estoy escribiendo
			MC_send_data <= WE;

			if bus_TRDY = '0' then -- Si la palabra de la memoria no esta lista en el bus -> Bucle 
				next_state <= Scratch;
			else -- Traer el bloque
				
				if RE = '1' then
					mux_output <= "01"; -- La salida es un registro interno de la MC
				end if;

				last_word <= '1'; -- Decir que es la ultima palabra 
				ready <= '1';
				next_state <= Inicio; -- El Frame se pondra a 0 en inicio
			end if;

		WHEN others => 	
	end CASE;    
	
		
   end process;
 
   
end Behavioral;

