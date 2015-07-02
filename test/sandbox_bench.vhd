library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sandbox is
end entity;

architecture sandbox of sandbox is
  constant period : time := 10 ns;

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

  signal clk : std_logic := '0';

  signal b64_rst, b64_en, b64_we : std_logic;
  signal b64_busy                : std_logic;
  signal b64_din                 : std_logic_vector(7 downto 0);
  signal b64_ready               : std_logic;
  signal b64_dout                : std_logic_vector(7 downto 0);

  signal buff_addra : std_logic_vector(5 downto 0);
  signal buff_addrb : std_logic_vector(5 downto 0);
  signal buff_dina  : std_logic_vector(7 downto 0);
  signal buff_doutb : std_logic_vector(7 downto 0);
  signal buff_we    : std_logic_vector(0 downto 0);

  signal result_addra : std_logic_vector(6 downto 0);
  signal result_addrb : std_logic_vector(6 downto 0);
  signal result_dina  : std_logic_vector(7 downto 0);
  signal result_doutb : std_logic_vector(7 downto 0);
  signal result_we    : std_logic_vector(0 downto 0);

  signal clk_en : std_logic := '1';
begin
  enc : b64_encoder
    port map (
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

  clock : process
  begin

    if clk_en = '1' then
      clk <= not clk;
      wait for PERIOD / 2;
    end if;
  end process clock;

  process
    constant msg     : string                := "Hola mundo";
    variable counter : natural range 0 to 90 := 0;
  begin
    buff_we <= "1";

    b64_rst <= '1';
    wait until rising_edge(clk);
    b64_rst <= '0';

    buff_addra <= (others => '-');
    buff_addrb <= (others => '-');
    buff_dina  <= (others => '-');

    for i in 1 to msg'length loop
      buff_addra <= std_logic_vector(to_unsigned(i-1, buff_addra'length));
      buff_dina  <= std_logic_vector(to_unsigned(character'pos(msg(i)), buff_dina'length));
      wait until rising_edge(clk);
    end loop;

    --------------------------------------------------------------------------
    -- Lógica para leer del buffer y escribir en result
    --------------------------------------------------------------------------

    b64_we    <= '0';
    b64_en    <= '0';
    result_we <= "0";
    b64_rst   <= '1';
    wait until rising_edge(clk);

    buff_addra <= (others => '-');
    buff_dina  <= (others => '-');
    buff_we    <= "0";
    result_we  <= "1";
    b64_en     <= '1';
    b64_we     <= '1';
    b64_rst    <= '0';
    wait until rising_edge(clk);


    -- recorre todos los bytes de "msg"
    for i in 1 to msg'length loop
      b64_rst    <= '0';
      b64_we     <= '0';
      result_we  <= "0";
      buff_addrb <= std_logic_vector(to_unsigned(i-1, buff_addrb'length));
      wait until rising_edge(clk);

      -- procesa un byte
      result_we    <= "1";
      b64_we       <= '1';
      result_addra <= std_logic_vector(to_unsigned(counter, result_addra'length));
      counter      := counter +1;
      wait until rising_edge(clk);

      -- espera a que no este busy para procesar el siguiente byte
      for j in 0 to 1 loop
        exit when b64_busy = '0';

        result_addra <= std_logic_vector(to_unsigned(counter, result_addra'length));
        counter      := counter +1;
        wait until clk'event and clk = '1';
      end loop;
    end loop;

    -- espera hasta que encoder haya terminado de procesar
    for j in 0 to 3 loop
      exit when b64_ready = '1';

      b64_en       <= '0';
      b64_we       <= '1';
      result_addra <= std_logic_vector(to_unsigned(counter, result_addra'length));
      counter      := counter + 1;
      wait until clk'event and clk = '1';
    end loop;

    result_we <= "0";

    --------------------------------------------------------------------------
    -- Fin de la lógica para leer del buffer y escribir en result
    --------------------------------------------------------------------------

    wait until rising_edge(clk);
    for i in 0 to counter-2 loop
      result_addrb <= std_logic_vector(to_unsigned(i, result_addrb'length));
      wait until rising_edge(clk);
    end loop;

    clk_en <= '0';
  end process;

  b64_din     <= buff_doutb;
  result_dina <= b64_dout;
end architecture;
