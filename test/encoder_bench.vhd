library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;

entity encoder_bench is
end entity;

--
-- Se lee el archivo pruebas.txt en donde la primera línea
-- tiene un valor a encodear y la segunda el resultado para
-- comprobarlo.  Falla si no matchea alguna comprobación
--
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
      bytes_to_process : in  std_logic_vector(6 downto 0);
      processed_bytes  : out std_logic_vector(6 downto 0);
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
  signal bytes_to_process : std_logic_vector(6 downto 0);
  signal processed_bytes  : std_logic_vector(6 downto 0);
  signal processed        : std_logic := '0';
begin
  enc : encoder
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
    -- Al dejar todo lo generado en ${project}/build tengo que poner
    -- el path del archivo de datos relativo a dicho directorio.
    file f                : text open read_mode is "../test/pruebas.txt";
    variable to_encode    : string(1 to 65);
    variable comprobation : string(1 to 128);
    variable counter      : natural range 0 to 128 := 0;
  begin
    --
    -- Itero todo el contenido del archivo
    -- @TODO: soportar comentarios a lo bash, con "#"
    -- 
    -- Espera que el archivo tenga pares de línea, una con el contenido a encodear
    -- y otra con el base64 para comprobar.  Como tiene que ser de ancho fijo
    -- delimito la cadena con un ".", que pasa a ser caracter no permitido para
    -- hacer pruebas...
    --
    while not endfile(f) loop
      str_read(f, to_encode);
      str_read(f, comprobation);

      --
      -- Reset del device
      --
      wait until rising_edge(clk);
      bytes_to_process <= "0000000";
      rst <= '1';
      wait until rising_edge(clk);
      rst <= '0';

      -- informar cadena a codificar
      assert false
        report "####### Codificando en base64: <" & to_encode & ">"
        severity note;

      we      <= '1';
      counter := 0;
      for i in 1 to to_encode'length loop
        exit when character'pos(to_encode(i)) = character'pos('.');

        buff_addr <= std_logic_vector(to_unsigned(i-1, buff_addr'length));
        buff_data <= std_logic_vector(to_unsigned(character'pos(to_encode(i)), 8));
        counter   := counter + 1;
        wait until rising_edge(clk);
      end loop;

      buff_addr        <= (others => '-');
      buff_data        <= (others => '-');
      we               <= '0';
      bytes_to_process <= std_logic_vector(to_unsigned(counter, bytes_to_process'length));
      wait until processed'event and processed = '1';

      wait until clk'event and clk = '0';
      for j in 0 to 90 loop
        exit when j = unsigned(processed_bytes);
        result_addr <= std_logic_vector(to_unsigned(j, result_addr'length));
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert to_char(result_data) = comprobation(j+1)
          report "##Error al comparar <" & comprobation(j+1) & "> con <" & to_char(result_data) & ">"
          severity failure;
      end loop;
      result_addr <= (others => '-');
      wait until rising_edge(clk);

    end loop;

    report "### Test finalizado exitosamente";
    -- Detengo la simulacin
    clk_en <= '0';
    wait;
  end process estimulo;
end architecture;
