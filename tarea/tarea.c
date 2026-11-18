/*
 * Tarea de prueba del clúster.
 * Cada proceso MPI (uno por worker) obtiene:
 *   - nombre del servidor y su dirección IP
 *   - fecha y hora con segundos decimales (microsegundos)
 * y lo agrega a resultados.txt en el folder compartido (NFS).
 *
 * Compilar:  mpicc -O2 -Wall -o tarea tarea.c
 * Ejecutar:  mpirun --hostfile hostfile -np 2 ./tarea <id_corrida> [archivo]
 */
#define _GNU_SOURCE
#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>

/* Primera IPv4 que no sea loopback (en Azure: la IP privada de eth0). */
static void obtener_ip(char *buf, size_t n) {
    struct ifaddrs *ifs, *it;
    snprintf(buf, n, "desconocida");
    if (getifaddrs(&ifs) != 0) return;
    for (it = ifs; it; it = it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family != AF_INET) continue;
        if (it->ifa_flags & IFF_LOOPBACK) continue;
        inet_ntop(AF_INET, &((struct sockaddr_in *)it->ifa_addr)->sin_addr, buf, n);
        break;
    }
    freeifaddrs(ifs);
}

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    const char *corrida = argc > 1 ? argv[1] : "0";
    const char *archivo = argc > 2 ? argv[2] : "/home/ec1/compartido/resultados.txt";

    /* Tomar la hora lo primero, para medir cuándo arranca cada worker */
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);

    char host[256];
    gethostname(host, sizeof host);
    char ip[INET_ADDRSTRLEN];
    obtener_ip(ip, sizeof ip);

    struct tm tm;
    localtime_r(&ts.tv_sec, &tm);
    char fecha[32];
    strftime(fecha, sizeof fecha, "%Y-%m-%dT%H:%M:%S", &tm);

    char linea[512];
    int len = snprintf(linea, sizeof linea,
        "corrida=%s rank=%d/%d host=%s ip=%s fecha=%s.%06ld epoch=%ld.%09ld\n",
        corrida, rank, size, host, ip, fecha, ts.tv_nsec / 1000,
        (long)ts.tv_sec, ts.tv_nsec);

    /* Escritura concurrente sobre NFS: O_APPEND no es atómico en NFS,
       así que se bloquea el archivo mientras cada worker escribe. */
    int fd = open(archivo, O_WRONLY | O_CREAT | O_APPEND, 0664);
    if (fd < 0) { perror(archivo); MPI_Abort(MPI_COMM_WORLD, 1); }
    struct flock lk = { .l_type = F_WRLCK, .l_whence = SEEK_SET };
    fcntl(fd, F_SETLKW, &lk);
    if (write(fd, linea, len) != len) perror("write");
    fsync(fd);
    lk.l_type = F_UNLCK;
    fcntl(fd, F_SETLK, &lk);
    close(fd);

    printf("%s", linea);
    MPI_Finalize();
    return 0;
}
