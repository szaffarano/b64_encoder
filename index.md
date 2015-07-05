---
layout: default
---

Este proyecto implementa un codificador Base64 en VHDL, embebiéndole un microcontrolador [picoblaze][picoblaze] para controlarlo.  Se desarrolló en el marco del trabajo práctico final del curso de Circuitos Lógico Programables.

Todas las pruebas de funcionalidad fueron validadas con una placa de desarrollo [Zybo][zybo].  Se puede ver la placa en funcionamiento, conectada a un conversor USB-RS232:

{% include image.html src="/assets/zybo.jpg" width="60%" %}

Referirse a la documentación dentro de esta página para conocer el funcionamiento del codificador, o bien descargar el código fuente del [repositorio git][repo].

A continuación un video que muestra el uso de la CLI desarrollada para PicoBlaze, codificando cadenas a Base64:

<center>
<iframe width="560" height="315" src="https://www.youtube.com/embed/gqvm2cqnHRU" frameborder="0" allowfullscreen></iframe>
</center>

[picoblaze]:      http://www.xilinx.com/products/intellectual-property/picoblaze.html
[zybo]:           https://www.digilentinc.com/Products/Detail.cfm?Prod=ZYBO
[repo]:           "{{ site.github.repository_url}}"