ESTRUCTURA DEL COMPUTADOR I – EXAMEN FINAL

PROFESOR: EDUARDO ZUREK, PH.D. DEPARTAMENTO DE INGENIERÍA DE SISTEMAS             

Temas: Proyecto integrador y Arquitectura en la Nube

Valor de la evaluación: 100 puntos

                                                                                                                                                                     

El reto de esta actividad es crear un clúster con tres componentes computacionales: un servidor que se encargue de la administración, al que se puede denominar *main*, y dos servidores que se encarguen de realizar las tareas, a los que se puede denominar *workers*. Para la realización de esta actividad pueden usar los recursos de su preferencia: recursos en la nube obtenidos a través de sus cuentas estudiantiles en Azure o GitHub (Codespaces), los portátiles del Laboratorio de Ciencias de la Computación, o sus propios equipos computacionales.

Para la construcción del clúster, se sugiere seguir estos pasos:

- Crear un usuario, se sugiere llamarlo ec1, con privilegios de administrador en cada uno de los servidores.

- Garantizar que haya passwordless login (logueo sin contraseña) entre todas las máquinas que forman su clúster.

- Lo siguiente es definir una máquina como *main* **y las otras dos como *workers* **(worker1, worker2).

- Luego, crear un folder en main que debe ser compartido con todos los workers. Todas las máquinas deben poder leer, escribir y ejecutar archivos en el folder compartido. Para compartir el folder puede usar NFS (Network File System).

- Posteriormente, se debe instalar un MPI (Message Passing Library) que permita administrar la ejecución de tareas desde el main hacia los workers.

- Finalmente, pruebe que el clúster funciona, diseñe e implemente una tarea que se ejecute en cada uno de los workers:

  - Obtenga el nombre del servidor y su dirección IP.

  - Obtenga la fecha, hora, minutos y segundos (con decimales) de la máquina donde se está ejecutando la prueba.

  - En un archivo guardado en el folder compartido y llamado “resultados.txt” escriba la información obtenida.

  - Desde el main, mande a ejecutar varias veces la tarea en los servidores y analice los resultados.

  - Todos los archivos relacionados con este proyecto deben almacenarse en el directorio compartido para que todas las máquinas tengan acceso a ellos.

Cada grupo debe generar un video con una duración exacta de 15 minutos donde explique el proceso realizado y los resultados obtenidos. El video debe basarse en diapositivas con pistas de audio. El video será presentado en la fecha, hora y salón correspondiente al examen final. La asistencia es obligatoria. 

Este taller debe ser resuelto en grupos de máximo 6 personas.

                                                                                                                                            ¡ÉXITOS!
