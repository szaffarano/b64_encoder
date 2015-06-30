library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.b64_utils.all;

--
-- Máquina de estados que codifica una secuencia de bytes (sin límite) 
-- a Base64.  El funcionamiento es:
-- 1. Debe tener "we" (Write Enabled) en "1" para que la FSM funcione
-- 2. Recibe bytes en "din" (Data INput)
-- 3. Solo recibe bytes cuando "busy" está en cero.
-- 4. Deja los datos ya procesados (a medida que los procesa) en dout (Data
--    OUT).
-- 5. Cuando finaliza de procesar pone en "1" el puerto "ready"
--
entity b64_encoder is
  port (
    clk, rst, en, we : in  std_logic;
    din              : in  std_logic_vector(7 downto 0);
    busy             : out std_logic;
    ready            : out std_logic;
    dout             : out std_logic_vector(7 downto 0));
end entity;


architecture b64_encoder of b64_encoder is
  type state is (idle, read1, read2, read3, read4, pad_one_equal, pad_two_equals);
  signal pr_state, nx_state : state;
  signal prev               : std_logic_vector(5 downto 0);
begin

  --
  -- Parte secuencial / "lower section" de la FSM (ver [Pedroni 2010])
  --
  process(rst, clk, we)
  begin
    if rst = '1' then
      pr_state <= idle;
    elsif clk'event and clk = '1' and we = '1' then
      pr_state <= nx_state;
    end if;
  end process;

  --
  -- Parte combinacional  / "upper section" de la FSM (ver [Pedroni 2010])
  --
  process(pr_state, din, en, prev)
  begin
    case pr_state is
      when idle =>
        ready <= '1';
        dout  <= (others => '-');
        busy  <= '0';
        if en = '1' then
          nx_state <= read1;
        else
          nx_state <= idle;
        end if;
      when read1 =>
        if en = '0' then
          ready    <= '1';
          nx_state <= idle;
          dout     <= (others => '-');
        else
          ready    <= '0';
          nx_state <= read2;
          dout     <= to_b64(din(7 downto 2));
        end if;
        busy <= '0';
      when read2 =>
        if en = '0' then
          ready    <= '0';
          nx_state <= pad_two_equals;
          dout     <= to_b64(prev(1 downto 0) & "0000");
          busy     <= '1';
        else
          ready    <= '0';
          nx_state <= read3;
          dout     <= to_b64(prev(1 downto 0) & din(7 downto 4));
          busy     <= '0';
        end if;
      when read3 =>
        if en = '0' then
          ready    <= '0';
          dout     <= to_b64(prev(3 downto 0) & "00");
          nx_state <= pad_one_equal;
          busy     <= '1';
        else
          ready    <= '0';
          dout     <= to_b64(prev(3 downto 0) & din(7 downto 6));
          nx_state <= read4;
          busy     <= '0';
        end if;
      when read4 =>
        if en = '0' then
          ready    <= '1';
          nx_state <= idle;
        else
          ready    <= '0';
          nx_state <= read1;
        end if;
        dout <= to_b64(prev(5 downto 0));
        busy <= '1';
      when pad_two_equals =>
        dout     <= std_logic_vector(to_unsigned(character'pos('='), 8));
        ready    <= '0';
        busy     <= '1';
        nx_state <= pad_one_equal;
      when pad_one_equal =>
        dout     <= std_logic_vector(to_unsigned(character'pos('='), 8));
        ready    <= '0';
        busy     <= '0';
        nx_state <= idle;
    end case;
  end process;

  --
  -- Mantiene buffer de estado para compensar la asimetría entre
  -- lectura y escritura-
  --
  process(clk, din, we)
  begin
    if clk'event and clk = '1' and we = '1' then
      if en = '1' then
        prev <= din (5 downto 0);
      end if;
    end if;
  end process;
end architecture;
