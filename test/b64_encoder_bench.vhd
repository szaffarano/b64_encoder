library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;

entity b64_encoder_bench is
end entity;

--
-- Benchmark de la máquina de estados que codifica en base64
-- una secuencia de bytes.
--
architecture bench of b64_encoder_bench is
  constant period : time := 10 ns;

  component b64_encoder is
    port (
      clk, rst, en, we : in  std_logic;
      din              : in  std_logic_vector(7 downto 0);
      busy             : out std_logic;
      ready            : out std_logic;
      dout             : out std_logic_vector(7 downto 0));
  end component;


  signal clk, rst, en, we : std_logic;
  signal busy             : std_logic;
  signal din              : std_logic_vector(7 downto 0);
  signal ready            : std_logic;
  signal dout             : std_logic_vector(7 downto 0);

  signal stop_bench : boolean := false;
begin

  enc : b64_encoder
    port map (
      clk   => clk,
      rst   => rst,
      en    => en,
      we    => we,
      din   => din,
      busy  => busy,
      ready => ready,
      dout  => dout);

  clock : process
  begin
    if not stop_bench then
      clk <= '1';
      wait for period / 2;
      clk <= '0';
      wait for period / 2;
    end if;
  end process;


  estimulo : process
    -- Al dejar todo lo generado en ${project}/build tengo que poner
    -- el path del archivo de datos relativo a dicho directorio.
    file f                : text open read_mode is "../test/pruebas.txt";
    variable to_encode    : string(1 to 65);
    variable result       : string(1 to 129);
    variable comprobation : string(1 to 128);
    variable counter      : natural range 1 to 128 := 1;
  begin

    --
    -- Reseteo y deshabilito la escritura.  Espero un rising edge del clk
    --
    rst <= '1';
    en  <= '0';
    wait until clk'event and clk = '1';
    rst <= '0';

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

      -- informar cadena a codificar
      report "####### Codificando en base64: <" & to_encode & ">";

      -- Habilitar encoder
      en <= '1';
      we <= '1';
      wait until clk'event and clk = '1';

      -- Se va escribiendo cada byte de la línea a encodear
      for i in 1 to to_encode'length loop
        -- workaround por el tamaño fijo de las líneas.  Siempre se traen los 64
        -- caracteres pero se lee hasta el "."
        exit when character'pos(to_encode(i)) = character'pos('.');

        -- conversión de character a std_logic_vector
        din <= std_logic_vector(to_unsigned(character'pos(to_encode(i)), 8));

        -- como voy un ciclo atrás, no almaceno el primer "dout" que será basura
        if i > 1 then
          result(counter) := character'val(to_integer(unsigned(dout)));
          counter         := counter + 1;
        end if;

        -- deshabilito la escritura intencionalmente
        -- para probar que no siga procesando mientras no
        -- se le escribe.
        we <= '0';
        wait for 2*period;
        we <= '1';

        -- siempre que se escribe hay que esperar que el encoder no esté
        -- busy, esto es porque cada 3 ciclos el cuarto no espera que le
        -- escriban al tener que procesar mas bytes de los que lee.
        wait until clk'event and clk = '1';
        for j in 0 to 1 loop
          exit when busy = '0';
          result(counter) := character'val(to_integer(unsigned(dout)));
          counter         := counter + 1;
          wait until clk'event and clk = '1';
        end loop;
      end loop;

      -- Terminado el ciclo de escritura se deshabilita para indicarle
      -- al encoder que ya no se va a escribir más.
      en <= '0';
      for j in 0 to 3 loop
        result(counter) := character'val(to_integer(unsigned(dout)));
        counter         := counter + 1;
        exit when ready = '1';
        wait until clk'event and clk = '1';
      end loop;

      -- Informar datos del procesamiento
      assert false
        report "### Datos de comprobacion: " & comprobation
        severity note;
      assert false
        report "### Datos encodeados     : " & result
        severity note;

      -- Comprobar que lo encodeado coincida con lo del archivo leido al comienzo.
      for i in 1 to counter loop
        exit when character'pos(comprobation(i)) = character'pos('.');
        assert comprobation(i) = result(i)
          -- @TODO informar más detalles...
          report "No coincide la comprobación"
          severity failure;
      end loop;
      counter := 1;
    end loop;

    -- Mensaje informativo ;-)
    assert false
      report "####### Benchmark finalizado exitosamente #######"
      severity note;

    -- Se detiene el reloj
    stop_bench <= true;
    wait;
  end process estimulo;
end architecture;
