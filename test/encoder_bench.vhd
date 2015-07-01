library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.txt_util.all;

entity encoder_bench is
end entity;

architecture arch of encoder_bench is
  constant PERIOD : time := 10 ns;

  component encoder
    port (
      clk              : in  std_logic;
      rst              : in  std_logic;
      we               : in  std_logic;
      ain              : in  std_logic_vector(5 downto 0);
      din              : in  std_logic_vector(7 downto 0);
      aout             : in  std_logic_vector(6 downto 0);
      dout             : out std_logic_vector(7 downto 0);
      bytes_to_process : in  natural range 0 to 63;
      processed_bytes  : out natural range 0 to 90;
      ready            : out std_logic);
  end component;

  signal clk              : std_logic := '0';
  signal rst              : std_logic := '0';
  signal clk_en           : std_logic := '1';
  signal we               : std_logic;
  signal buff_addr        : std_logic_vector(5 downto 0);
  signal buff_data        : std_logic_vector(7 downto 0);
  signal result_addr      : std_logic_vector(6 downto 0);
  signal result_data      : std_logic_vector(7 downto 0);
  signal bytes_to_process : natural range 0 to 63;
  signal processed_bytes  : natural range 0 to 90;
  signal processed        : std_logic := '0';
begin
  buff : encoder
    port map (
      clk              => clk,
      rst              => rst,
      we               => we,
      ain              => buff_addr,
      din              => buff_data,
      aout             => result_addr,
      dout             => result_data,
      bytes_to_process => bytes_to_process,
      processed_bytes  => processed_bytes,
      ready            => processed);

  clock : process
  begin

    if clk_en = '1' then
      clk <= not clk;
      wait for PERIOD / 2;
    end if;
  end process clock;

  estimulo : process
    constant cadena : string := "01234";
  begin
    result_addr <= std_logic_vector(to_unsigned(89, result_addr'length));

    --
    -- Reset del device
    --
    wait until rising_edge(clk);
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';

    --
    -- Primer ciclo de escritura
    --
    we <= '1';
    for i in 1 to cadena'length loop
      buff_addr <= std_logic_vector(to_unsigned(i-1, buff_addr'length));
      buff_data <= std_logic_vector(to_unsigned(character'pos(cadena(i)), buff_data'length));
      wait until rising_edge(clk);
    end loop;

    buff_addr <= (others => '-');
    buff_data <= (others => '-');
    we        <= '0';

    --
    -- Indico que procese los bytes escritors
    --
    bytes_to_process <= cadena'length;

    --
    -- Espero a que se hayan procesado los datos
    --
    wait until processed'event and processed = '1';

    --
    -- Se leen los datos procesados
    --
    wait until clk'event and clk = '0';
    for i in 0 to 90 loop
      exit when i = processed_bytes;
      result_addr <= std_logic_vector(to_unsigned(i, result_addr'length));
      wait until rising_edge(clk);
      --assert false                      --to_char(result_data) = cadena(i+1)
      --  report "Comparando <" & cadena(i+1) & "> con <" & to_char(result_data) & ">"
      --  severity note;                  --failure;
    end loop;
    result_addr <= (others => '-');
    wait until rising_edge(clk);

    report "### Test finalizado exitosamente";
    -- Detengo la simulacin
    clk_en <= '0';
  end process estimulo;
end architecture;
