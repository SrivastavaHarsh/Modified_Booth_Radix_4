-- Code for twos_comp; to be used as component in booth_decoder --
library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity twos_comp is
	generic (N: INTEGER);
 	port(inp: in std_logic_vector(N-1 downto 0);
		outp: out std_logic_vector(N-1 downto 0));
end twos_comp; 

architecture structure of twos_comp is
begin
	process(inp)
		variable flag: std_logic := '0';
	begin 
		outp <= not(inp);
		for i in 0 to N-1 loop
			if inp(i) = '1' then
				outp(i) <= '1';
				flag := '1';
			end if;
			exit when flag = '1';
		end loop; 
	end process;
end structure;

----------------------------------------------------------------------------------------
-- Code for CLAdder: Carry-look-ahead Adder (modified as per needs); to be used as component in modified_booth_multiplier --
library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity CLAdder is
	generic (N: INTEGER);
 	port(X,Y: in std_logic_vector(N-1 downto 0);
		sum: out std_logic_vector(N-1 downto 0));
end CLAdder; 

architecture structure of CLAdder is
	signal P,G: std_logic_vector(N-1 downto 0);
	signal C: std_logic_vector(N-1 downto 0);
begin 
	gen_pg: for i in 1 to N-1 generate 
		P(i) <= X(i) xor Y(i);
		G(i) <= X(i) and Y(i);
		C(i) <= G(i-1) or (P(i-1) and C(i-1));
		sum(i) <= P(i) xor C(i);
	end generate;
	C(0) <= '0';
	P(0) <= X(0) xor Y(0);
	G(0) <= X(0) and Y(0);
	sum(0) <= P(0);		-- Since, Cin = 0, the expression (P(0) xor Cin) reduces to P(0)	
end structure;

----------------------------------------------------------------------------------------
-- Code for booth_decoder; to be used as component in modified_booth_multiplier --
library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity booth_decoder is
	generic (N: INTEGER);
 	port( control: in std_logic_vector(2 downto 0);
	 	 	inp: in std_logic_vector(N-1 downto 0);
			outp: out std_logic_vector(N downto 0));
end booth_decoder; 

architecture structure of booth_decoder is
	component twos_comp is
		generic (N: INTEGER);
 		port(inp: in std_logic_vector(N-1 downto 0);
			outp: out std_logic_vector(N-1 downto 0));
	end component;
	signal inp_comp: std_logic_vector(N-1 downto 0);
begin
	comp1: twos_comp generic map(N) port map(inp => inp, outp => inp_comp);
 	with control select
		outp <= inp(N-1) & inp when "001",
		 		inp(N-1) & inp when "010",
				inp & '0' when "011",
				inp_comp & '0' when "100",
				inp_comp(N-1) & inp_comp when "101",
				inp_comp(N-1) & inp_comp when "110",
				(others =>'0') when others;
end structure;
----------------------------------------------------------------------------------------
-- Code for modified_booth_multiplier: Radix 4 --
library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity modified_booth_multiplier is
	generic (N: INTEGER:= 31); 	-- Since rollno. ends with 71 (2017uee0071) 
								-- the implementation is generic for all odd values of N > 1 
	port (A,B: in std_logic_vector (N-1 downto 0); 	-- Numbers to be multiplied
	 		mode: in std_logic;						-- Mode of operation: mode = '0' for unsigned,
													--                    mode = '1' for signed
 			P: out std_logic_vector (2*N-1 downto 0)); -- Product
end modified_booth_multiplier;

architecture structure of modified_booth_multiplier is 
	component booth_decoder is
		generic (N: INTEGER);
 		port( control: in std_logic_vector(2 downto 0);
	 	 	inp: in std_logic_vector(N-1 downto 0);
			outp: out std_logic_vector(N downto 0));
	end component; 
	component CLAdder is
		generic (N: INTEGER);
 		port(X,Y: in std_logic_vector(N-1 downto 0);
			sum: out std_logic_vector(N-1 downto 0));
	end component; 

	type arr1 is array(0 to (N-1)/2) of std_logic_vector(2 downto 0);
	type arr2 is array(0 to (N-1)/2) of std_logic_vector(N+1 downto 0);
	type arr3 is array(0 to (N-1)/2) of std_logic_vector((2*N)+1 downto 0);
	signal A_ext: std_logic_vector(N downto 0);
	signal B_ext: std_logic_vector(N+1 downto 0);
	signal ctrl: arr1;
	signal pp: arr2;
	signal pp_ext, S: arr3;

begin

	A_ext <= A(N-1) & A when mode = '1' else
			'0' & A when mode = '0' else
			(others => '0');   
											 
	B_ext <= B(N-1) & B & '0' when mode = '1' else
			'0' & B & '0' when mode = '0' else
			(others => '0');		
		
	gen_dec: for i in 0 to (N-1)/2 generate
		ctrl(i) <= B_ext((i*2)+2 downto (i*2));
		bd_i: booth_decoder generic map(N+1) port map(control => ctrl(i), inp => A_ext, outp => pp(i));
		pp_ext(i)((N+1+(i*2)) downto (i*2)) <= pp(i);
		epp_j: for j in (N+2+(i*2)) to (2*N)+1 generate
			pp_ext(i)(j) <= pp(i)(N+1);
		end generate;
		lb1:if i>0 generate
			epp_k: for k in 0 to (i*2)-1 generate
				pp_ext(i)(k) <= '0';
			end generate;
		end generate;
	end generate;
	
	S(0) <= pp_ext(0);
	gen_add: for i in 1 to (N-1)/2 generate
		cla: CLAdder generic map(2*(N+1)) port map(X => S(i-1), Y => pp_ext(i), sum => S(i));
	end generate;
	
	P <= S((N-1)/2)((2*N)-1 downto 0);

end structure;