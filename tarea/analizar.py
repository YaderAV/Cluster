#!/usr/bin/env python3
"""Analiza resultados.txt: orden de llegada de los workers, desfase entre
ellos en cada corrida y tiempo entre corridas.

Uso: python3 analizar.py [ruta/a/resultados.txt]
"""
import re
import statistics
import sys
from collections import Counter, defaultdict

PAT = re.compile(r"(\w+)=(\S+)")


def resumen(nombre, datos, unidad="ms"):
    if not datos:
        return
    print(f"  {nombre}: media={statistics.mean(datos):.3f} {unidad}  "
          f"min={min(datos):.3f}  max={max(datos):.3f}  "
          f"desv={statistics.pstdev(datos):.3f}  (n={len(datos)})")


def main():
    ruta = sys.argv[1] if len(sys.argv) > 1 else "/home/ec1/compartido/resultados.txt"
    corridas = defaultdict(list)
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            d = dict(PAT.findall(linea))
            if "corrida" in d and "epoch" in d:
                d["t"] = float(d["epoch"])
                corridas[d["corrida"]].append(d)

    if not corridas:
        print("No hay datos en", ruta)
        return

    orden = sorted(corridas, key=lambda c: min(r["t"] for r in corridas[c]))
    print(f"{'corrida':<16}{'host':<10}{'ip':<12}{'fecha y hora':<28}{'desfase (ms)'}")
    print("-" * 78)

    desfases, primeros, inicios = [], Counter(), []
    for c in orden:
        regs = sorted(corridas[c], key=lambda r: r["t"])
        t0 = regs[0]["t"]
        inicios.append(t0)
        primeros[regs[0]["host"]] += 1
        for r in regs:
            print(f"{c:<16}{r['host']:<10}{r['ip']:<12}{r['fecha']:<28}{(r['t'] - t0) * 1000:>10.3f}")
        if len(regs) >= 2:
            desfases.append((regs[-1]["t"] - t0) * 1000)
        print()

    entre = [(b - a) * 1000 for a, b in zip(inicios, inicios[1:])]
    print("RESUMEN")
    print(f"  Corridas: {len(orden)}   Registros: {sum(len(v) for v in corridas.values())}")
    resumen("Desfase entre workers en una misma corrida", desfases)
    resumen("Tiempo entre corridas consecutivas", entre)
    print("  Worker que llegó primero:", ", ".join(f"{h}: {n} veces" for h, n in primeros.most_common()))


if __name__ == "__main__":
    main()
