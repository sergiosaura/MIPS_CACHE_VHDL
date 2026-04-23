----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:10:07 04/01/2026 
-- Design Name: 
-- Module Name:    ALU - Behavioral with support for vectorial MAC with internal accumulation
-- Additional Comments: by AOC2 Team Unizar 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;



entity ALU_Vector_MAC is
    Port ( DA : in  STD_LOGIC_VECTOR (31 downto 0); --input 1
           DB : in  STD_LOGIC_VECTOR (31 downto 0); --input 2
           valid_I_EX : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
		   ready : out STD_LOGIC; --initially is always '1', but if ALU supports multicycle ops, it will be cero when the output is not ready
           ALUctrl : in  STD_LOGIC_VECTOR (2 downto 0); -- Ops: "000" add, "001" sub, "010" AND, "011" OR, "100" MAC with internal acc, "101" MAC without previous acc.
           Dout : out  STD_LOGIC_VECTOR (31 downto 0)); -- Output
end ALU_Vector_MAC;

architecture Behavioral of ALU_Vector_MAC is

component reg is
    generic (size: natural := 32);  -- por defecto son de 32 bits, pero se puede usar cualquier tama�o
	Port ( Din : in  STD_LOGIC_VECTOR (size -1 downto 0);
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           load : in  STD_LOGIC;
           Dout : out  STD_LOGIC_VECTOR (size -1 downto 0));
end component;

signal Dout_internal: STD_LOGIC_VECTOR (31 downto 0);
-- Señal para la maquina de estados de la mac
signal next_state: STD_LOGIC_VECTOR (1 downto 0);
signal state: STD_LOGIC_VECTOR (1 downto 0);
signal ACC_out : STD_LOGIC_VECTOR (31 downto 0) := X"00000000";
signal ACC_input, sum_total_ext: Signed (31 downto 0);
signal sum_total_ext_out: STD_LOGIC_VECTOR (31 downto 0); -- Añadido para salida de los registros
signal prod0, prod1, prod2, prod3 : Signed(15 downto 0);
signal prod0_out, prod1_out, prod2_out, prod3_out : STD_LOGIC_VECTOR(15 downto 0); -- Añadido para salida de los registros
signal sum1, sum2 : Signed(16 downto 0);
signal sum_total : Signed(17 downto 0);
signal load_acc, load_mul, load_add, Acc_op, MAC_start : STD_LOGIC; -- Añadido load_mul y laod_add para cargar en los nuevos registros

-- to improve readability
CONSTANT MAC_MUL 	 : STD_LOGIC_VECTOR (1 downto 0) 	:= "00";
CONSTANT MAC_ADD 	 : STD_LOGIC_VECTOR (1 downto 0) 	:= "01";
CONSTANT MAC_ACC_ADD : STD_LOGIC_VECTOR (1 downto 0) 	:= "10";
begin	
-- IMPORTANT
-- VHDL is strongly typed.
-- In VHDL, types do not just describe the size of a signal, they describe its meaning. 
-- A std_logic_vector means �a bundle of bits,� nothing more. 
-- A signed signal means �a two's complement number.� Because the language is strongly typed, VHDL won�t let you accidentally treat raw bits as a number or mix numeric and non-numeric types without being explicit.
-- In VHDL, you need to use the signed type for C2 (two�s-complement) arithmetic because arithmetic operators like +, -, and comparisons are only numerically defined for the signed and unsigned types in numeric_std, not for std_logic_vector. 
-- A std_logic_vector is just a collection of bits with no inherent numerical meaning, so the compiler has no way to know whether those bits represent a positive or negative number or how to interpret the sign bit.
-- By converting the operands to signed, you explicitly tell VHDL to interpret the MSB as the sign bit and to perform proper two�s-complement arithmetic. 
-- After the calculation, the result is typically converted back to std_logic_vector to store it in a register because registers and ports are often defined as std_logic_vector for generality and compatibility with other logic, interfaces, and synthesis tools. 
-- This separation keeps arithmetic correct and unambiguous while still allowing flexible storage and data movement.
-- NOTE: If you add additional registers you will have to adjust types
-- See the ACC_register for an example: 
-- 1) To use ACC_input as input, first it is transformed to std_logic_vector with: std_logic_vector(ACC_input)
-- 2) To use the output for signed arithmetic operations, first it is transformed to signed: else sum_total_ext + signed(ACC_out);

	prod0 <= signed(DA(7 downto 0))   * signed(DB(7 downto 0));
	prod1 <= signed(DA(15 downto 8))  * signed(DB(15 downto 8));
	prod2 <= signed(DA(23 downto 16)) * signed(DB(23 downto 16));
	prod3 <= signed(DA(31 downto 24)) * signed(DB(31 downto 24));

	sum1 <= signed(prod0_out(15) & prod0_out) + signed(prod1_out(15) & prod1_out);
	sum2 <= signed(prod2_out(15) & prod2_out) + signed(prod3_out(15) & prod3_out);
	sum_total <= (sum1(16) & sum1) + (sum2(16) & sum2);
	sum_total_ext(17 downto 0) <= sum_total;
	sum_total_ext(31 downto 18) <= "00000000000000" when sum_total(17)='0' else "11111111111111";
	
	--It is important not to update the ACC register with invalid instructions
	-- (Señal para saber si es una MAC/MAC_ini o no)
	Acc_op <= '1' when (ALUctrl(2 downto 1) = "10") else '0'; --Acc operations: "100" and "101"  

	-- load_acc <= Acc_op and valid_I_EX; 
	-- (Señal para saber si es MAC o MAC_ini)
	MAC_start <=   '1' when (ALUctrl(0) = '1') else '0'; -- If ALUCtrl = "101" the accumulation register is restarted
	
	-- (Entrada del registro y salida de la ALU para MAC)
	-- Es una MUX del final de la ALU para elegir la salida
	-- Si es MAC_ini usará la salida del resultado de la suma donde luego se transformará en std_logic_vector en el switch de abajo para la salida de la ALU y para cargar en ACC_register
	-- Si es MAC cogerá la salida del registro que guarda la suma de los productos y lo sumará con ACC ya que tarda 3 ciclos y no 2 como MAC_ini
	ACC_input <= sum_total_ext when (MAC_start = '1')
				 else signed(sum_total_ext_out) + signed(ACC_out);

	--reset is currentlly unused in the ALU, but it will be needed if it becomes multicycle
	-- Registro acumulador ACC
	ACC_register: reg 	generic map (size => 32)
						port map (	Din => std_logic_vector(ACC_input), clk => clk, reset => '0', load => load_acc, Dout => ACC_out);
					
	-- NUEVOS REGISTROS PARA LA ALU MULTICICLO
	--Registros de multiplicación						
	MUL_register_1: reg generic map (size => 16)
						port map (	Din => std_logic_vector(prod0), clk => clk, reset => '0', load => load_mul, Dout => prod0_out);
	MUL_register_2: reg generic map (size => 16)
						port map (	Din => std_logic_vector(prod1), clk => clk, reset => '0', load => load_mul, Dout => prod1_out);
	MUL_register_3: reg generic map (size => 16)
						port map (	Din => std_logic_vector(prod2), clk => clk, reset => '0', load => load_mul, Dout => prod2_out);
	MUL_register_4: reg generic map (size => 16)
						port map (	Din => std_logic_vector(prod3), clk => clk, reset => '0', load => load_mul, Dout => prod3_out);

	--Registro de la suma del la mac
	ADD_register: reg generic map (size => 32)
						port map (	Din => std_logic_vector(sum_total_ext), clk => clk, reset => '0', load => load_add, Dout => sum_total_ext_out);

	MAC_state_register: process (clk)
	   begin
	      if (clk'event and clk = '1') then
	         if (reset = '1') then
	            state <= MAC_MUL;
	         else
	            state <= next_state;
	         end if;        
	      end if;
	   end process;
	   
	-- FSM (Finite State Machine)
	-- Maquina de estados finitas para ir controlando los estados de la MAC
	UC_outputs : process(state, Acc_op, MAC_start, valid_I_EX)
	begin
		-- Poner valores por defecto de ciertas señales cada vez que se active
		load_mul <= '0';
		load_add <= '0';
		ready    <= '0';
		load_acc <= '0';

		CASE state IS
			WHEN MAC_MUL =>
				IF (valid_I_EX = '1' and Acc_op = '1') THEN	-- si es mac cargamos en los registros de multiplicación y saltamos al siguiente estado
					load_mul <= '1';
					next_state <= MAC_ADD;
				ELSE -- otra operación que se hará en un ciclo, ready a 1 y volvemos al estado inicial
					ready <= '1';
					next_state <= MAC_MUL;
				END IF;

			WHEN MAC_ADD => -- Se han sumado las multiplicaciones 
				load_acc <= MAC_start; -- Si es mac_ini se cargará directamente en el registro ACC
				ready    <= MAC_start; -- Si es mac_ini ya habrá terminado la ALU y ready será 1

				IF (MAC_start = '1') THEN -- Si es mac_ini se vuelve al estado inicial
					next_state <= MAC_MUL;
				ELSE -- Si es mac normal lo cargamos en el registro de suma de los productos y se pasa al tercer estado
					load_add <= '1';
					next_state <= MAC_ACC_ADD;
				END IF;

			WHEN MAC_ACC_ADD => -- Sumar con el acumulador (ACC), poner ready a 1 (ya terminó), guardar en el acumulador y volver al estado inicial
				load_acc <= '1';
				ready    <= '1';
				next_state <= MAC_MUL;

			WHEN OTHERS =>
				next_state <= MAC_MUL;
				ready <= '1';
		END CASE;
	end process;
				
	
	Dout_internal <= DA + DB when (ALUctrl="000") 
				else DA - DB when (ALUctrl="001") 
				else DA AND DB when (ALUctrl="010")
				else DA OR DB when (ALUctrl="011")
				else std_logic_vector(ACC_input) when (ALUctrl(2 downto 1) = "10") 
				else "00000000000000000000000000000000";
	Dout <= Dout_internal;
	-- to be updated:
	-- ready <= load_acc or ALUctrl(2) = '0'; -- Contemplado en la FSM
end Behavioral;