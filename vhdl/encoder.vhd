library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder is
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
end entity;

architecture arch of encoder is
  component b64_encoder is
    port (
      clk, rst, en, we : in  std_logic;
      din              : in  std_logic_vector(7 downto 0);
      busy             : out std_logic;
      ready            : out std_logic;
      dout             : out std_logic_vector(7 downto 0));
  end component;

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
  type state is (idle, reading, processing, waiting, padding);
  signal pr_state, nx_state : state;

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
  signal start : std_logic;
  signal buffer_address: natural range 0 to 64;
  signal result_address: natural range 0 to 89;

begin
  enc : b64_encoder port map (
      clk   => clk,
      rst   => b64_rst,
      en    => b64_en,
      we    => b64_we,
      din   => b64_din,
      busy  => b64_busy,
      ready => b64_ready,
      dout  => b64_dout);

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
  -- Parte secuencial / "lower section" de la FSM (ver [Pedroni 2010])
  --
  process(rst, clk)
  begin
    if rst = '1' then
      --pr_state <= idle;
    elsif clk'event and clk = '1' then
      pr_state <= nx_state;
    end if;
  end process;

  --
  -- Parte combinacional  / "upper section" de la FSM (ver [Pedroni 2010])
  --
  process(pr_state, start, buffer_address, result_address, b64_busy, b64_ready, bytes_to_process)
  begin
    case pr_state is
      when idle =>
        ready <= '1';

        b64_rst <= '1';
        b64_we <= '0';
        b64_en <= '0';

        buff_addrb <= (others => '-');

        result_we <= "0";
        result_addra <= (others => '0');

        if start = '1' then
          nx_state <= reading;
        else
          nx_state <= idle;
        end if;

      when reading =>
        ready <= '0';
        
        b64_rst <= '0';
        b64_we <= '0';
        b64_en <= '1';

        result_we <= "0";
        result_addra <= (others => '0');

        if buffer_address < bytes_to_process then
          buff_addrb <= std_logic_vector(to_unsigned(buffer_address, buff_addrb'length));
          nx_state <= processing;
        else
          -- termino de procesar los bytes, continuar hasta b64_ready = '1'
          nx_state <= padding;
          buff_addrb <= (others => '-');
        end if;

      when processing =>
        ready <= '0';

        b64_we <= '1';
        b64_rst <= '0';
        b64_en <= '1';

        buff_addrb <= (others => '-');

        result_we <= "1";
        result_addra <= std_logic_vector(to_unsigned(result_address, result_addra'length));

        nx_state <= waiting;

      when waiting =>
        ready <= '0';

        b64_we <= '1';
        b64_rst <= '0';
        b64_en <= '1';

        buff_addrb <= (others => '-');

        if b64_busy = '1' then
          result_we <= "1";
          result_addra <= std_logic_vector(to_unsigned(result_address, result_addra'length));
          nx_state <= waiting;
        elsif buffer_address < bytes_to_process then
          result_we <= "1";
          result_addra <= (others => '0');
          nx_state <= reading;
        else
          result_we <= "1";
          result_addra <= (others => '0');
          nx_state <= padding;
        end if;

      when padding =>
        ready <= '0';

        b64_we <= '1';
        b64_rst <= '0';
        b64_en <= '0';
        
        buff_addrb <= (others => '-');

        if b64_ready = '0' then
          result_we <= "1";
          result_addra <= std_logic_vector(to_unsigned(result_address, result_addra'length));
          nx_state <= padding;
        else
          result_we <= "0";
          result_addra <= (others => '0');
          nx_state <= idle;
        end if;
    end case;
  end process;

  --
  -- Monitorea el cambio de estado del registro de bytes a procesar
  -- para activar el flag que inicia a la FSM.
  --
  process (clk, rst)
    variable prev_value : natural range 0 to 63 := 0;
  begin
    if rst = '1' then
      start <= '0';
    elsif clk'event and clk = '1' then
      if prev_value /= bytes_to_process then
        start <= '1';
      else
        start <= '0';
      end if;
      prev_value := bytes_to_process;
    end if;
  end process;

  --
  -- Mantiene actualizado el contador que se usa para escribir en el
  -- buffer de salida, se pone a cero en el reset y se incrementa sólo
  -- en el estado writing de la fsm.
  --
  process (clk, rst)
  begin
    if rst = '1' then
    -- poner contador en cero
      result_address <= 0;
      buffer_address <= 0;
    elsif clk'event and clk = '1' then
      if pr_state = reading then
      -- incrementar contador de buffer address
        buffer_address <= buffer_address + 1;
      elsif pr_state = processing or pr_state = waiting or pr_state = padding then
        result_address <= result_address + 1;
      end if;
    end if;
  end process;

  b64_din     <= buff_doutb;
  result_dina <= b64_dout;

  buff_addra <= ain;
  buff_dina <= din;
  result_addrb <= aout;
  dout <= result_doutb;
  buff_we <= "1" when we = '1' else "0";
  processed_bytes <= result_address;
end architecture;
