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
  type state is (idle, reading, processing, waiting, padding, ending);
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
  signal count_r : natural range 0 to 90;

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

  process(rst, clk)
  begin
    if rst = '1' then
      ready <= '0';
    elsif clk'event and clk = '1' then
      case current is
        when idle =>
          if start = '1' then
            result_we <= "0";
            b64_we    <= '1';
            b64_en    <= '1';
            b64_rst   <= '0';
            count_a   <= 0;
            current   <= reading;
          else
            result_we <= "0";
            b64_we    <= '0';
            b64_en    <= '0';
            b64_rst   <= '1';
            current   <= idle;
          end if;

        when reading =>
          if count_a = bytes_to_process then
            b64_we <= '1';
            result_we <= "1";
            current <= padding;
          else
            b64_rst    <= '0';
            b64_we     <= '0';
            result_we  <= "0";
            buff_addrb <= std_logic_vector(to_unsigned(count_a, buff_addrb'length));
            current    <= processing;
          end if;

        when processing =>
          result_we    <= "1";
          b64_we       <= '1';
          result_addra <= std_logic_vector(to_unsigned(count_r, result_addra'length));
          count_r      <= count_r + 1;
          current      <= waiting;

        when waiting =>
          b64_we <= '0';
          if b64_busy = '0' then
            count_a   <= count_a + 1;
            current   <= reading;
            result_we <= "0";
          else
            result_addra <= std_logic_vector(to_unsigned(count_r, result_addra'length));
            count_r      <= count_r + 1;
            result_we <= "1";
            current      <= waiting;
          end if;

        when padding =>
          b64_en       <= '0';
          if b64_ready = '1' then
            current <= ending;
          else
            result_we    <= "1";
            b64_we       <= '1';
            result_addra <= std_logic_vector(to_unsigned(count_r, result_addra'length));
            count_r      <= count_r + 1;
            current      <= padding;
          end if;
        when ending =>
          result_we       <= "0";
          processed_bytes <= count_r-1;
          ready           <= '1';
          current         <= idle;
      end case;

    end if;
  end process;

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

  b64_din     <= buff_doutb;
  result_dina <= b64_dout;

  buff_addra   <= ain;
  buff_dina    <= din;
  result_addrb <= aout;
  dout         <= result_doutb;
  buff_we      <= "1" when we = '1' else "0";
end architecture;
