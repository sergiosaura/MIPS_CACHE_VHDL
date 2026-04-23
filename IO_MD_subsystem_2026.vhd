----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:12:11 04/04/2014 
-- Design Name: 
-- Module Name:    memoriaRAM - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
-- Memoria RAM de 128 oalabras de 32 bits
entity IO_Data_Memory_Subsystem is port (
	  CLK : in std_logic;
	  reset: in std_logic; 		
	  -- READ/Write ports with the MIPS core
	  ADDR : in std_logic_vector (31 downto 0); --Dir solicitada por el Mips
     Din : in std_logic_vector (31 downto 0);--entrada de datos desde el Mips
	  WE : in std_logic;		-- write enable	del MIPS
	  RE : in std_logic;		-- read enable del MIPS			  
	  IO_MEM_ready: out std_logic; -- indica si puede hacer la operación solicitada en el ciclo actual
	  Data_abort: out std_logic; --indica que el último acceso a memoria ha sido un error
	  Dout : out std_logic_vector (31 downto 0); --dato que se envía al Mips
	  -- SoC Input/Output ports
	  Ext_IRQ	: 	in  STD_LOGIC;   --External interrupt signal
	  INT_ACK	: 	out  STD_LOGIC;  --Signal to acknowledge the interrupt
	  MIPS_IRQ	: 	out  STD_LOGIC;  -- IRQ signal for the MIPS core. It may combine several IRQ signals from different sources 
	  IO_input: in std_logic_vector (31 downto 0); --dato que viene de una entrada del sistema
	  IO_output : out  STD_LOGIC_VECTOR (31 downto 0) -- 32 bits de salida para el MIPS para IO
		  ); 
end IO_Data_Memory_Subsystem;

-- En este proyecto el IO_Data_Memory_Subsystem está compuesto por una MD de 128 palabras con acceso alineado, y dos registros mapeados en memoria, uno de entrada y otro de salida
-- En el P2 esta parte será más complicada

architecture Behavioral of IO_Data_Memory_Subsystem is

component reg is
    generic (size: natural := 32);  -- por defecto son de 32 bits, pero se puede usar cualquier tamaño
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
	   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;	

component counter is
 	generic (   size : integer := 10);
	Port ( 	clk : in  STD_LOGIC;
       		reset : in  STD_LOGIC;
       		count_enable : in  STD_LOGIC;
       		count : out  STD_LOGIC_VECTOR (size-1 downto 0));
end component;

component RAM_128_32 is port (
		CLK : in std_logic;
		Reset : in std_logic;
		ADDR : in std_logic_vector (31 downto 0); --Dir 
        Din : in std_logic_vector (31 downto 0);
        enable: in std_logic; -- If enable is 0 WE and RE are ignored
        WE : in std_logic;		-- write enable	
		RE : in std_logic;		-- read enable		
		Mem_ready: out std_logic; -- 1 if the requested operation can be done in the current cycle
		Dout : out std_logic_vector (31 downto 0));
end component;

signal dir_7:  std_logic_vector(6 downto 0); 
signal unaligned, out_of_range, load_output, Mem_addr, IO_addr, addr_input, addr_output, addr_ack, ack_input, ready, Mem_ready, Data_abort_internal:  std_logic;
signal Input_data, Output_data, RAM_Dout: std_logic_vector (31 downto 0);
signal ack_input_vector, INT_ACK_vector : std_logic_vector (0 downto 0);
begin
 
--------------------------------------------------------------------------------------------------
-- Decodificador para detectar si la señal pertenece a memoria o a los registros mapeados en memoria
-- Direcciones de MEM válidas: desde x"00000000" al x"000001FC"
	Mem_addr <= '1' when (ADDR(31 downto 9)= "00000000000000000000000") else '0'; 
-- Direcciones de IO válidas:  x"00007000" y x"0000700C" Hay 4 registros direccionables, aunque sólo se usan 3
	IO_addr <= '1' when (ADDR(31 downto 4) = x"0000700") else '0'; 
	addr_input <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "0000")) else '0'; --x"00007000"
	addr_output <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "0100")) else '0';--x"00007004"
	addr_ack <= '1' when ((IO_addr='1') and (ADDR(3 downto 0)= "1000")) else '0';--x"00007008"

--------------------------------------------------------------------------------------------
-- Data Memory:    
	MD: RAM_128_32 port map ( 	clk => clk, reset => reset, ADDR => ADDR, Din => Din, enable => Mem_addr, WE => WE, RE => RE, 
										Mem_ready => Mem_ready, Dout => RAM_Dout);
--------------------------------------------------------------------------------------------------
-- Registros Entrada/salida
-- 
-- Input_Reg: Permite leer los 32 bits de entrada del sistema. Su dirección asociada es "01000000"
-- Output_Reg: Permite escribir en los 32 bits de entrada del sistema. Su dirección asociada es "01000004"
--------------------------------------------------------------------------------------------------
	Input_Reg: reg generic map (size => 32)
					port map (	Din => IO_input, clk => clk, reset => reset, load => '1', Dout => Input_data);
	-- El contenido del Output_Reg es visible desde el exterior			
	load_output <= '1' when (addr_output='1') and (WE = '1') else '0';
	-- 
	Output_Reg: reg generic map (size => 32)
					port map (	Din => Din, clk => clk, reset => reset, load => load_output, Dout => Output_data);
	IO_output <= Output_data	;
	-- ACK_Reg para informar que se ha atendido a la INT externa
	-- Sólo tiene un bit, y se pone a 0 automáticamente después de cada escritura. Lo hace para que la RTI sea más ligera (así no hay que poner un '1', y luego un '0' para evitar que la siguiente INT crea que ya la han atendido)
	-- y también para evitar dar el ACK a dos interrupciones que vayan muy seguidas, cuando sólo se ha tratado la primera
	-- Si se indica la @ del Ack y se da la orden de escribir se cargará en el registro el bit 0 de los datos de entrada. En caso contrario se pondrá un 0
	ACK_input <= Din(0) and addr_ack and WE; 
	ACK_input_vector <= (0 => ACK_input);-- El componente registro usa vectores para la entrada y salida (en este caso de 1 bit). Esta línea asigna una señal al bit 0 del vector. Es una forma de pasar de std_logic a STD_logic_vector
	ACK_Reg: reg generic map (size => 1)
					port map (	Din => ACK_input_vector, clk => clk, reset => reset, load => '1', Dout => INT_ACK_vector);
	INT_ACK <= INT_ACK_vector(0);
------------------------
-- DATA ABORT
--------------------------------------------------------------------------------------------------------------------
    -- out_of_range se activa si la dirección está fuera del rango. 
    -- Se activa si la dirección no pertenece a MD ni a los registros IO
    out_of_range <= '0' when ((Mem_addr = '1') OR (IO_addr = '1')) else '1';
    -- Sólo vamos a permitir direcciones alineadas. Como leemos palabras de 4 bytes estas deben estar en direcciones múltiplos de 4. Es decir, acaban en "00"
    unaligned <= '0' when (ADDR(1 downto 0)= "00") else '1';
    -- Hay un data abort cuando se accede a una dirección que no existe, o se realiza un acceso no alineado.
    -- ¡Pero sólo si se está haciendo un acceso a memoria! Si WE y RE valen cero no se está accediendo a memoria, por tanto da igual el valor de la dirección
    Data_abort_internal <= (out_of_range or unaligned) and (WE or RE);
    Data_abort <= Data_abort_internal; 

--------------------------------------------------------------------------------------------------
----------- Salidas para el Mips
-------------------------------------------------------------------------------------------------- 
Dout <= x"000BAD00" when ready = '0' else -- Valor para depuración, si aparece en vuestros registros estáis leyendo datos cuando la memoria no está preparada
		x"BAD0ADD0" when Data_abort_internal = '1' else -- Valor para depuración, si aparece en vuestros registros estáis leyendo datos cuando la @ no es correcta
		RAM_Dout 	when Mem_addr = '1' else -- la memoria comprueba internamente que RE valga '1'
		Input_data 	when ((addr_input = '1') and (RE='1')) else -- se usa para mandar el dato del registro de entrada
		Output_data when ((addr_output = '1') and (RE='1')) else -- se usa para mandar el dato del registro de salida
		x"00000000"; -- Cuando no se pide nada

--Interrupts: There may be many interrupt sources. But currently we only have the external one

MIPS_IRQ <= Ext_IRQ;
-- if the @ is from Data memory, and Data memory is not ready, the processor has to wait		
ready <= '0' when (Mem_ready = '0') and (Mem_addr = '1') else '1';
IO_MEM_ready <= ready;
end Behavioral;

