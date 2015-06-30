library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package b64_utils is
  constant B64      : string := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  function to_b64(S : std_logic_vector) return std_logic_vector;
end b64_utils;

package body b64_utils is
  function to_b64(S : std_logic_vector) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(B64(1+to_integer(unsigned(S)))), 8));
  end to_b64;
end b64_utils;



