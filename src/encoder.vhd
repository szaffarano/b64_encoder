library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- El periférico propiamente dicho.  Utiliza la entidad
-- b64_encoder que es quien recibe los bytes como entrada
-- y devuelve bytes codificados en base 64 como salida.
--  clk: clock
--  rst: reset
--  we: cuando está en uno habilita la escritura en la 
--      memoria buffer
--  ain: dirección de la memoria buffer en donde se va a escribir 
--  din: dato a escribir en la memoria buffer
--  aout: dirección desde donde se va a leer en la memoria
--        resultado
--  dout: dato leido de la memoria resultado
--  bytes_to_process: registro mediante el cual se le indica
--                    al periférico cuántos bytes se desea
--                    codificar.  Ni bien se escribe en este
--                    puerto se comienza a codificar
--  processed_bytes: el periférico indica en este registro
--                   cuántos bytes ocupa el resultado de la
--                   codificación.  Sólo tendrá un valor válido
--                   una vez disparada la señal ready que indica
--                   que se finalizó de codificar
--  ready: se pone a uno por un ciclo de reloj, indicando que
--         se termino de codificar
--
entity encoder is
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
end entity;

--
-- Arquitectura con la implementación del encoder
--
architecture arch of encoder is
  component b64_encoder is
    port (
      clk, rst, en, we : in  std_logic;
      din              : in  std_logic_vector(7 downto 0);
      busy             : out std_logic;
      ready            : out std_logic;
      dout             : out std_logic_vector(7 downto 0));
  end component;

  -- 
  -- Memoria RAM para que el usuario escriba los datos a procesar
  component ram_buffer
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(5 downto 0);
      dina  : in  std_logic_vector(7 downto 0);
      clkb  : in  std_logic;
      addrb : in  std_logic_vector(5 downto 0);
      doutb : out std_logic_vector(7 downto 0));
  end component;

  --
  -- Memoria RAM donde se guardan los datos procesados y desde 
  -- donde el usuario puede leerlos
  --
  component ram_result
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(6 downto 0);
      dina  : in  std_logic_vector(7 downto 0);
      clkb  : in  std_logic;
      addrb : in  std_logic_vector(6 downto 0);
      doutb : out std_logic_vector(7 downto 0));
  end component;

  --
  -- Estados de la FSM
  --
  type state is (idle, reading, encoding, padding, ending);
  signal current : state;

  --
  -- Señales del encoder
  --
  signal b64_rst, b64_en, b64_we : std_logic;
  signal b64_busy                : std_logic;
  signal b64_din                 : std_logic_vector(7 downto 0);
  signal b64_ready               : std_logic;
  signal b64_dout                : std_logic_vector(7 downto 0);

  --
  -- Señales del buffer de entrada
  --
  signal buff_addra : std_logic_vector(5 downto 0);
  signal buff_addrb : std_logic_vector(5 downto 0);
  signal buff_dina  : std_logic_vector(7 downto 0);
  signal buff_doutb : std_logic_vector(7 downto 0);
  signal buff_we    : std_logic_vector(0 downto 0);

  --
  -- Señales del buffer de salida
  --
  signal result_addra : std_logic_vector(6 downto 0);
  signal result_addrb : std_logic_vector(6 downto 0);
  signal result_dina  : std_logic_vector(7 downto 0);
  signal result_doutb : std_logic_vector(7 downto 0);
  signal result_we    : std_logic_vector(0 downto 0);

  -- Señales internas al encoder
  signal start   : std_logic;
  signal count_a : natural range 0 to 63;
  signal count_r : natural range 0 to 89;
  signal prev_value : std_logic_vector(6 downto 0);

begin
  -- Instanciar b64_encoder
  enc : b64_encoder port map (
    clk   => clk,
    rst   => b64_rst,
    en    => b64_en,
    we    => b64_we,
    din   => b64_din,
    busy  => b64_busy,
    ready => b64_ready,
    dout  => b64_dout);

  -- Instanciar memorias
  buff : ram_buffer port map (
    clka  => clk,
    clkb  => clk,
    wea   => buff_we,
    addra => buff_addra,
    dina  => buff_dina,
    addrb => buff_addrb,
    doutb => buff_doutb);
  result : ram_result port map (
    clka  => clk,
    clkb  => clk,
    wea   => result_we,
    addra => result_addra,
    dina  => result_dina,
    addrb => result_addrb,
    doutb => result_doutb);

  --
  -- Máquina de estados con la lógica de procesamiento.
  -- Lee de la memoria buffer, habilita al encoder para
  -- que procese y escribe en la memoria de resultado.
  -- Cada 3 bytes procesados devuelve 4 y demora 6 ciclos
  --
  process(rst, clk)
  begin
    if rst = '1' then
      ready      <= '0';
      b64_we     <= '0';
      b64_en     <= '0';
      b64_rst    <= '1';
      buff_addrb <= (others => '-');
      current    <= idle;

    elsif clk'event and clk = '1' then
      case current is
        when idle =>
          if start = '1' then
            b64_we  <= '0';
            b64_en  <= '1';
            b64_rst <= '0';
            count_a <= 0;
            count_r <= 0;
            current <= reading;
          else
            b64_we     <= '0';
            b64_en     <= '0';
            b64_rst    <= '1';
            buff_addrb <= (others => '-');
            current    <= idle;
          end if;
          ready <= '0';
        when reading =>
          b64_rst <= '0';
          b64_we  <= '1';

          if count_a < to_integer(unsigned(bytes_to_process)) then
            if b64_busy = '0' then
              buff_addrb <= std_logic_vector(to_unsigned(count_a, buff_addrb'length));
              count_a    <= count_a + 1;
              b64_we     <= '1';
            end if;
            result_we <= "0";
            current   <= encoding;
          else
            current <= padding;
          end if;

        when encoding =>
          b64_we       <= '0';
          result_we    <= "1";
          result_addra <= std_logic_vector(to_unsigned(count_r, result_addra'length));
          count_r      <= count_r+1;
          current      <= reading;

        when padding =>
          b64_en <= '0';
          if b64_ready = '1' then
            current <= ending;
          else
            result_we    <= "1";
            result_addra <= std_logic_vector(to_unsigned(count_r, result_addra'length));
            count_r      <= count_r+1;
            current      <= padding;
          end if;

        when ending =>
          processed_bytes <= std_logic_vector(to_unsigned(count_r-1, processed_bytes'length));
          ready           <= '1';
          current         <= idle;

        when others =>
      end case;

    end if;
  end process;

  --
  -- Proceso para mantener el estado del registro
  -- de bytes a procesar, utilizado como flag para
  -- comenzar con el procesamiento
  process (clk, rst)
  begin
    if rst = '1' then
      start <= '0';
    elsif clk'event and clk = '1' then
      if prev_value /= bytes_to_process and to_integer(unsigned(bytes_to_process)) > 0 then
        start <= '1';
      else
        start <= '0';
      end if;
      prev_value <= bytes_to_process;
    end if;
  end process;

  b64_din     <= buff_doutb;
  result_dina <= b64_dout;

  buff_addra   <= ain;
  buff_dina    <= din;
  result_addrb <= aout;
  dout         <= result_doutb;
  buff_we      <= "1" when we = '1' else "0";
end architecture;
