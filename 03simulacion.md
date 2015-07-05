---
layout: page
title: Simulaciones
permalink: /simulation/
categories: doc
tags: doc vhdl
---

- TOC
{:toc}

El proyecto incluye varios *test benchs* de forma de poder asegurarse de que todo funciona normalmente.  Los mismos leen el archivo `pruebas.txt` que tiene una lista de cadenas a codificar junto con el resultado esperado.  Si alguna comprobación no es correcta, se informa el error y se aborta la ejecucióno del test, ejemplo:

{% highlight vhdl %}
  -- Comprobar que lo encodeado coincida con lo del archivo leido al comienzo.
  for i in 1 to counter loop
    exit when character'pos(comprobation(i)) = character'pos('.');
    assert comprobation(i) = result(i)
      report "No coincide la comprobación"
      severity failure;
  end loop;
{% endhighlight %}

Más allá de los tests mencionados, se ejecutaron algunos puntuales con el fin de obtener simulaciones para exponer el comportamiento interno del periférico.  Las mismas fueron hechas con cadenas de 12, 13, 14, 62, 63 y 64 bytes, cuyos valores fueron:

* ABCDEFGHIJKL (Valor codificado: QUJDREVGR0hJSktM)
* ABCDEFGHIJKLM (Valor codificado: QUJDREVGR0hJSktMTQ==)
* ABCDEFGHIJKLMN (Valor codificado: QUJDREVGR0hJSktMTU4=)
* 12345678901234567890123456789012345678901234567890123456789012 (Valor codificado: MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI=)
* 123456789012345678901234567890123456789012345678901234567890123 (Valor codificado: MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIz)
* 123456789012345678901234567890123456789012345678901234567890124 (Valor codificado: MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNA==)

## Simulaciones del primer caso

Como se mencionó antes, se corresponde a la cadena `ABCDEFGHIJKL`

### Primeros bytes

{% include image.html src="../assets/sim/12bytes_1.png" width="80%" %}

### Últimos bytes

{% include image.html src="../assets/sim/12bytes_2.png" width="80%" %}

### Memoria de datos de entrada

{% include image.html src="../assets/mem/12_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/12_result.png" width="80%" %}

## Simulaciones del segundo caso

Como se mencionó antes, se corresponde a la cadena `ABCDEFGHIJKLM`

### Primeros bytes

{% include image.html src="../assets/sim/13bytes_1.png" width="80%" %}

### Comienzo del procesamiento

Se puede ver que luego de indicarle la cantidad de bytes a (0x0d = 13'd), se empieza con el procesamiento propiamente dicho.

{% include image.html src="../assets/sim/13bytes_proc.png" width="80%" %}

### Últimos bytes

{% include image.html src="../assets/sim/13bytes_2.png" width="80%" %}

### Memoria de datos de entrada

{% include image.html src="../assets/mem/13_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/13_result.png" width="80%" %}


## Simulaciones del tercer caso

Como se mencionó antes, se corresponde a la cadena `ABCDEFGHIJKLMN`

### Primeros bytes

Ver la sección marcada en rojo, en donde se observa la transición de estados de la máquna de estado a medida que va procesando los bytes de entrada.  Hay una máquina de estados para el componente `b64_encoder` y otra para `encoder` (paramás información consultar el código fuente).

{% include image.html src="../assets/sim/14bytes_1.png" width="80%" %}

### Disparo de la señal de ready

Observar que luego de procesar los datos de entrada se dispara la señal de `ready` indicando que ya están disponibles los bytes codificados.

{% include image.html src="../assets/sim/14bytes_ready.png" width="80%" %}

### Últimos bytes

{% include image.html src="../assets/sim/14bytes_2.png" width="80%" %}

### Memoria de datos de entrada

{% include image.html src="../assets/mem/14_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/14_result.png" width="80%" %}

## Simulaciones del cuarto caso

### Memoria de datos de entrada

{% include image.html src="../assets/mem/62_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/62_result.png" width="80%" %}

## Simulaciones del quinto caso

### Memoria de datos de entrada

{% include image.html src="../assets/mem/63_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/63_result.png" width="80%" %}

## Simulaciones del sexto caso

### Memoria de datos de entrada

{% include image.html src="../assets/mem/64_buffer.png" width="80%" %}

### Memoria de datos de salida

{% include image.html src="../assets/mem/64_result.png" width="80%" %}

