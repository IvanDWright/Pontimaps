#!/usr/bin/env python3
"""Genera lib/data/campus_osm_data.dart a partir de docs/javeriana_osm.geojson.

Uso (desde la raíz del proyecto):  python tool/generar_campus_osm.py

Qué hace
  1. Filtra del GeoJSON de OpenStreetMap solo lo que pertenece al campus de la
     Pontificia Universidad Javeriana (edificios numerados, edificios y servicios
     con nombre propio que se listan explícitamente abajo, y unas papelerías
     aliadas de la Calle 40C). Descarta vivienda, hoteles y otras universidades.
  2. Calcula el centroide (área ponderada) de cada polígono y toma `building:levels`
     como número de pisos.
  3. Construye el grafo peatonal con las geometrías `highway=footway|pedestrian|
     path|steps`: une las componentes sueltas, conecta la entrada de cada lugar al
     sendero más cercano (partiendo el tramo en el punto de unión), simplifica las
     curvas (Douglas-Peucker, 1,5 m) y calcula cada distancia con Haversine sobre
     la polilínea real. Los tramos `highway=steps` quedan marcados como escaleras.
  4. Escribe todo como tablas `const` de Dart. NO edites a mano el archivo
     generado: cambia este script (o el GeoJSON) y vuelve a ejecutarlo.
"""
import json
import math
import re
import sys
from collections import defaultdict, deque
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
FUENTE = RAIZ / 'docs' / 'javeriana_osm.geojson'
SALIDA = RAIZ / 'lib' / 'data' / 'campus_osm_data.dart'

RADIO = 6371008.8
REF_LAT, REF_LNG = 4.628, -74.064
TOLERANCIA_DP = 1.5          # m
UNION_COMPONENTES_MAX = 40   # m para unir fragmentos sueltos a la red principal
CONECTOR_AVISO = 60          # m: aviso si la entrada queda lejos del sendero


def hav(a, b):
    la1, la2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = la2 - la1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin(dl / 2) ** 2
    return 2 * RADIO * math.asin(math.sqrt(h))


def xy(p):
    return ((p[1] - REF_LNG) * math.cos(math.radians(REF_LAT)) * RADIO * math.pi / 180,
            (p[0] - REF_LAT) * RADIO * math.pi / 180)


def proyectar(p, a, b):
    """Punto más cercano de p sobre el segmento a-b. Devuelve (distancia_m, t)."""
    px, py = xy(p); ax, ay = xy(a); bx, by = xy(b)
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy)), t


def centroide(anillo):
    pts = [xy(p) for p in anillo]
    area = cx = cy = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % len(pts)]
        c = x0 * y1 - x1 * y0
        area += c; cx += (x0 + x1) * c; cy += (y0 + y1) * c
    if abs(area) < 1e-9:
        return (sum(p[0] for p in anillo) / len(anillo), sum(p[1] for p in anillo) / len(anillo))
    cx /= 3 * area; cy /= 3 * area
    return (REF_LAT + cy / (RADIO * math.pi / 180),
            REF_LNG + cx / (math.cos(math.radians(REF_LAT)) * RADIO * math.pi / 180))


def douglas_peucker(pts, tol):
    """Índices que se conservan de la polilínea pts (en lat/lng)."""
    if len(pts) <= 2:
        return list(range(len(pts)))
    conservar = {0, len(pts) - 1}
    pila = [(0, len(pts) - 1)]
    while pila:
        i, j = pila.pop()
        mejor, idx = -1.0, None
        for k in range(i + 1, j):
            d, _ = proyectar(pts[k], pts[i], pts[j])
            if d > mejor:
                mejor, idx = d, k
        if idx is not None and mejor > tol:
            conservar.add(idx); pila.append((i, idx)); pila.append((idx, j))
    return sorted(conservar)


# ----------------------------------------------------------------------------
# 1. Lectura y filtrado
# ----------------------------------------------------------------------------
datos = json.loads(FUENTE.read_text(encoding='utf-8'))
por_id = {f['properties']['@id']: f for f in datos['features']}


def anillo_de(f):
    pts = [(c[1], c[0]) for c in f['geometry']['coordinates'][0]]
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    return pts


def niveles_de(f):
    v = f['properties'].get('building:levels')
    try:
        n = int(float(v)) if v is not None else None
    except ValueError:
        n = None
    return n if n and n >= 1 else None


def sotanos_de(f):
    v = f['properties'].get('building:levels:underground')
    try:
        n = int(float(v)) if v is not None else 0
    except ValueError:
        n = 0
    return n if n and n >= 0 else 0


CORRECCIONES_NOMBRE = {45: 'Capilla San Francisco Javier'}  # OSM la trae truncada

edificios = {}
for f in datos['features']:
    p = f['properties']
    if f['geometry']['type'] != 'Polygon':
        continue
    m = re.match(r'^(\d+)\.\s*(.+)$', p.get('name', ''))
    if not m or not p.get('building'):
        continue
    numero, nombre = int(m.group(1)), m.group(2).strip()
    nombre = CORRECCIONES_NOMBRE.get(numero, nombre)
    anillo = anillo_de(f)
    if numero in edificios:
        sys.exit(f'Número de edificio repetido en OSM: {numero}')
    edificios[f'ed{numero:02d}'] = dict(
        id=f'ed{numero:02d}', numero=numero, nombre=nombre,
        niveles=niveles_de(f), sotanos=sotanos_de(f),
        anillo=anillo, osm=p['@id'])

# Edificios con nombre propio y sin número oficial
SIN_NUMERO = [
    ('biblioteca', 'way/40156024', 'Biblioteca General Alfonso Borrero Cabal'),
    ('hospital', 'way/24368575', 'Hospital Universitario San Ignacio'),
    ('ciencias-puj', 'way/1200925544', 'Edificio Ciencias PUJ'),
    ('casa-navarro', 'way/40156030', 'Casa Navarro'),
    ('formacion-deportiva', 'way/24368577', 'Centro Javeriano de Formación Deportiva'),
    ('morfologia', 'way/40156905', 'Rafael Barrientos Conto - Morfología'),
    ('taller-diseno-industrial', 'way/830697558', 'Taller de Diseño Industrial'),
    ('vicerrectoria-extension', 'way/334969238', 'Vicerrectoría de Extensión y Relaciones Institucionales'),
]
for id_, osm, nombre in SIN_NUMERO:
    f = por_id[osm]
    edificios[id_] = dict(id=id_, numero=None, nombre=nombre,
                          niveles=niveles_de(f), sotanos=sotanos_de(f),
                          anillo=anillo_de(f), osm=osm)

# Ascensores y accesibilidad: docs/edificios_ascensores.json, cruzado por osmWayId
# con el GeoJSON. Los edificios que no aparecen allí quedan "sin confirmar"
# (accesibilidad desconocida, nunca "sin ascensor"). El ascensor privado de OSM
# (access=private) NO se usa.
ASCENSORES = RAIZ / 'docs' / 'edificios_ascensores.json'
for e in edificios.values():
    e.update(ascensor=False, multiples=False, movilidad=False, confirmada=False)
por_osm = {e['osm']: e for e in edificios.values()}
sin_cruce = []
if ASCENSORES.exists():
    for x in json.loads(ASCENSORES.read_text(encoding='utf-8'))['edificios']:
        e = por_osm.get(x['osmWayId'])
        if e is None:
            sin_cruce.append(x['id'])
            continue
        if e['niveles'] is not None and e['niveles'] != x['pisos']:
            print(f"  AVISO: {x['id']} pisos={x['pisos']} en el JSON y building:levels={e['niveles']} en OSM")
        e.update(ascensor=bool(x['tieneAscensor']), multiples=bool(x['tieneMultiplesAscensores']),
                 movilidad=bool(x['accesoMovilidadReducida']), confirmada=True,
                 sotanos=max(e['sotanos'], int(x.get('sotanos', 0))))
        # Nombre oficial del JSON sin el prefijo "Edificio N - ".
        e['nombre'] = re.sub(r'^Edificio\s+\d+\s*-\s*', '', x['nombreOficial']).strip() or e['nombre']
    print(f"Ascensores: {sum(1 for e in edificios.values() if e['confirmada'])} edificios cruzados; "
          f"sin edificio equivalente en el catálogo: {sin_cruce}")
else:
    print('AVISO: no existe docs/edificios_ascensores.json; la accesibilidad queda sin confirmar')

# Servicios: (id, osm, nombre, categoría, piso, apertura, cierre, horario confirmado, dentro de edificio)
H_DEF = ('08:00', '18:00')
SERVICIOS = [
    ('biblioteca-general', 'way/40156024', 'Biblioteca General Alfonso Borrero Cabal', 'biblioteca', 1, '10:00', '00:00', True, True),
    ('hospital-san-ignacio', 'way/24368575', 'Hospital Universitario San Ignacio', 'salud', 1, '00:00', '00:00', False, True),
    ('cafeteria-la-central', 'way/409391089', 'Cafetería La Central', 'cafeteria', 1, '06:00', '21:00', True, False),
    ('la-pecera', 'way/48255427', 'La Pecera', 'cafeteria', 1, '07:00', '19:00', False, False),
    ('kiosko-urapanes', 'way/409392267', 'Kiosko Urapanes', 'cafeteria', 1, '07:00', '19:00', False, False),
    ('la-conejera', 'way/478119312', 'La Conejera', 'cafeteria', 1, '08:30', '20:00', True, False),
    ('el-italiano-express', 'way/1359775387', 'El Italiano Express', 'cafeteria', 1, '07:00', '19:00', False, False),
    ('la-frutera', 'way/1419891744', 'La Frutera', 'cafeteria', 1, '07:00', '19:00', False, False),
    ('papeleria-el-circulo', 'way/334774751', 'Papelería El Círculo', 'papeleria', 1, *H_DEF, False, False),
    ('papeleria-el-triangulo', 'way/334774752', 'Papelería El Triángulo', 'papeleria', 1, *H_DEF, False, False),
    ('papeleria-plotter', 'way/334780838', 'Plotter', 'papeleria', 1, *H_DEF, False, False),
    ('papeleria-compu-plotter', 'way/334774750', 'Compu Plotter', 'comercioAliado', 1, *H_DEF, False, False),
]
servicios = []
for id_, osm, nombre, cat, piso, ap, ci, conf, dentro in SERVICIOS:
    f = por_id[osm]
    anillo = anillo_de(f)
    servicios.append(dict(id=id_, osm=osm, nombre=nombre, categoria=cat, piso=piso,
                          apertura=ap, cierre=ci, confirmado=conf, dentro=dentro,
                          anillo=anillo, centro=centroide(anillo)))
for e in edificios.values():
    e['centro'] = centroide(e['anillo'])


def edificio_mas_cercano(punto, excluir=None):
    mejor = min((e for e in edificios.values() if e['id'] != excluir),
                key=lambda e: hav(punto, e['centro']))
    return mejor, hav(punto, mejor['centro'])


for s in servicios:
    if s['dentro']:
        s['edificio'] = next(e['id'] for e in edificios.values() if e['osm'] == s['osm'])
        s['distancia_edificio'] = 0.0
    else:
        e, d = edificio_mas_cercano(s['centro'])
        s['edificio'], s['distancia_edificio'] = e['id'], d

# Lugares que necesitan nodo de entrada propio
lugares = {e['id']: e for e in edificios.values()}
lugares.update({s['id']: s for s in servicios if not s['dentro']})

# ----------------------------------------------------------------------------
# 2. Red peatonal
# ----------------------------------------------------------------------------
latmin = min(l['centro'][0] for l in lugares.values()) - 0.0006
latmax = max(l['centro'][0] for l in lugares.values()) + 0.0006
lngmin = min(l['centro'][1] for l in lugares.values()) - 0.0006
lngmax = max(l['centro'][1] for l in lugares.values()) + 0.0006

verts, vidx = [], {}


def vertice(p):
    if p not in vidx:
        vidx[p] = len(verts); verts.append(p)
    return vidx[p]


segs = {}  # (u, v) con u<v -> es_escalera
for f in datos['features']:
    p = f['properties']
    if f['geometry']['type'] != 'LineString' or p.get('highway') not in ('footway', 'pedestrian', 'path', 'steps'):
        continue
    # Los senderos internos del campus suelen venir como access=private (privados
    # para el público, no para la comunidad); solo se excluyen los vetados al peatón.
    if p.get('foot') in ('no', 'private') or p.get('access') == 'no':
        continue
    pts = [(c[1], c[0]) for c in f['geometry']['coordinates']]
    if not any(latmin <= q[0] <= latmax and lngmin <= q[1] <= lngmax for q in pts):
        continue
    esc = p.get('highway') == 'steps'
    for a, b in zip(pts, pts[1:]):
        u, v = vertice(a), vertice(b)
        if u == v:
            continue
        k = (min(u, v), max(u, v))
        segs[k] = segs.get(k, False) or esc


def componentes(segmentos):
    vecinos = defaultdict(set)
    for u, v in segmentos:
        vecinos[u].add(v); vecinos[v].add(u)
    vistos, comps = set(), []
    for s in vecinos:
        if s in vistos:
            continue
        comp, cola = {s}, deque([s]); vistos.add(s)
        while cola:
            x = cola.popleft()
            for y in vecinos[x]:
                if y not in vistos:
                    vistos.add(y); comp.add(y); cola.append(y)
        comps.append(comp)
    return sorted(comps, key=len, reverse=True)


comps = componentes(segs)
principal = comps[0]
print(f'Red OSM: {len(verts)} vértices, {len(segs)} segmentos, {len(comps)} componentes {[len(c) for c in comps]}')

# unir fragmentos sueltos a la red principal (o descartarlos)
descartados = 0
for comp in comps[1:]:
    mejor = min(((hav(verts[a], verts[b]), a, b) for a in comp for b in principal), key=lambda t: t[0])
    if mejor[0] <= UNION_COMPONENTES_MAX:
        segs[(min(mejor[1], mejor[2]), max(mejor[1], mejor[2]))] = False
        principal |= comp
        print(f'  fragmento de {len(comp)} vértices unido a la red con un enlace de {mejor[0]:.1f} m')
    else:
        descartados += 1
        for k in [k for k in segs if k[0] in comp]:
            del segs[k]
        print(f'  fragmento de {len(comp)} vértices DESCARTADO (a {mejor[0]:.0f} m de la red)')

# ----------------------------------------------------------------------------
# 3. Conectar la entrada de cada lugar al sendero más cercano
# ----------------------------------------------------------------------------
divisiones = defaultdict(list)  # segmento -> [(t, vértice nuevo)]
entradas = {}                    # id de lugar -> vértice
conectores = []                  # (vértice entrada, vértice de unión)
distancia_conector = {}
reclamados = set()


def agregar_vertice(p):
    verts.append(p); return len(verts) - 1


for id_, lugar in sorted(lugares.items()):
    mejor = None
    for punto in lugar['anillo']:
        for k in segs:
            d, t = proyectar(punto, verts[k[0]], verts[k[1]])
            if mejor is None or d < mejor[0]:
                mejor = (d, punto, k, t)
    d, punto, k, t = mejor
    a, b = verts[k[0]], verts[k[1]]
    largo = hav(a, b)
    if t * largo < 1.0:
        union = k[0]
    elif (1 - t) * largo < 1.0:
        union = k[1]
    else:
        existente = next((v for (tt, v) in divisiones[k] if abs(tt - t) * largo < 1.0), None)
        if existente is None:
            existente = agregar_vertice((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
            divisiones[k].append((t, existente))
        union = existente
    if d < 0.5 and union not in reclamados:
        entrada = union
    else:
        entrada = agregar_vertice(punto)
        conectores.append((entrada, union))
    reclamados.add(entrada)
    entradas[id_] = entrada
    distancia_conector[id_] = d

# reconstruir segmentos con las divisiones
aristas_brutas = []  # (u, v, escalera)
for k, esc in segs.items():
    cadena = [k[0]] + [v for (_, v) in sorted(divisiones.get(k, []))] + [k[1]]
    for u, v in zip(cadena, cadena[1:]):
        aristas_brutas.append((u, v, esc))
for u, v in conectores:
    aristas_brutas.append((u, v, False))

# ----------------------------------------------------------------------------
# 4. Simplificar cadenas de grado 2
# ----------------------------------------------------------------------------
ady = defaultdict(list)
for i, (u, v, esc) in enumerate(aristas_brutas):
    ady[u].append((v, esc, i)); ady[v].append((u, esc, i))

lugar_de = {v: id_ for id_, v in entradas.items()}
requeridos = set()
for v, vecinos in ady.items():
    if len(vecinos) != 2 or v in lugar_de or vecinos[0][1] != vecinos[1][1]:
        requeridos.add(v)

usadas = set()
tramos = []  # (lista de vértices, escalera)
for r in sorted(requeridos):
    for (w, esc, i) in ady[r]:
        if i in usadas:
            continue
        camino, actual, previa = [r], w, i
        usadas.add(i); camino.append(actual)
        while actual not in requeridos:
            siguiente = next((x for x in ady[actual] if x[2] != previa), None)
            if siguiente is None:
                break
            w2, _, i2 = siguiente
            usadas.add(i2); previa = i2; actual = w2; camino.append(actual)
        tramos.append((camino, esc))

nodos_finales = {}  # vértice -> id
aristas = []        # (origen_v, destino_v, metros, escalera)
for camino, esc in tramos:
    pts = [verts[v] for v in camino]
    conservar = douglas_peucker(pts, TOLERANCIA_DP)
    if camino[0] == camino[-1] and len(camino) > 2 and len(conservar) == 2:
        conservar = sorted(set(conservar) | {len(camino) // 2})
    for i, j in zip(conservar, conservar[1:]):
        metros = sum(hav(pts[k], pts[k + 1]) for k in range(i, j))
        if camino[i] == camino[j]:
            continue
        aristas.append((camino[i], camino[j], max(round(metros, 1), 0.1), esc))

usados = {v for a in aristas for v in a[:2]} | set(entradas.values())
orden = sorted(usados, key=lambda v: (-verts[v][0], verts[v][1]))
contador = 0
for v in orden:
    if v in lugar_de:
        nodos_finales[v] = f'n_{lugar_de[v]}'
    else:
        contador += 1
        nodos_finales[v] = f'n{contador:03d}'

# ----------------------------------------------------------------------------
# 5. Verificaciones
# ----------------------------------------------------------------------------
def alcanzables(origen, sin_escaleras):
    vecinos = defaultdict(list)
    for u, v, _, esc in aristas:
        if sin_escaleras and esc:
            continue
        vecinos[u].append(v); vecinos[v].append(u)
    vistos, cola = {origen}, deque([origen])
    while cola:
        x = cola.popleft()
        for y in vecinos[x]:
            if y not in vistos:
                vistos.add(y); cola.append(y)
    return vistos


raiz = entradas['ed67']
todos = alcanzables(raiz, False)
conexo = all(v in todos for v in usados)

# Componentes de la red accesible (sin escaleras): agrupan las entradas que se
# pueden unir sin subir ni bajar escalones.
pendientes_acc = set(entradas.values())
grupos_acc = []
while pendientes_acc:
    semilla = next(iter(pendientes_acc))
    alcance = alcanzables(semilla, True)
    grupos_acc.append(sorted(lugar_de[v] for v in pendientes_acc if v in alcance))
    pendientes_acc -= alcance
grupos_acc.sort(key=len, reverse=True)
sin_esc = alcanzables(entradas[grupos_acc[0][0]], True)
inaccesibles = sorted(i for i, v in entradas.items() if v not in sin_esc)
print('Grupos accesibles (sin escaleras):', [(len(g), g if len(g) < 6 else g[:3] + ['…']) for g in grupos_acc])
lejos = sorted((round(distancia_conector[i], 1), i) for i in entradas if distancia_conector[i] > CONECTOR_AVISO)
print(f'Grafo: {len(nodos_finales)} nodos, {len(aristas)} tramos, {sum(1 for a in aristas if a[3])} con escaleras, '
      f'{len(entradas)} entradas, conexo={conexo}')
print(f'Entradas que solo se alcanzan por escaleras ({len(inaccesibles)}): {inaccesibles}')
print(f'Entradas a más de {CONECTOR_AVISO} m del sendero: {lejos}')
print('Servicios independientes lejos de un edificio (>80 m):',
      [(s['id'], round(s['distancia_edificio'])) for s in servicios if s['distancia_edificio'] > 80])
if not conexo:
    sys.exit('ERROR: el grafo no es conexo')

# ----------------------------------------------------------------------------
# 6. Escritura del archivo Dart
# ----------------------------------------------------------------------------
def d(x):
    return repr(round(x, 6))


def cad(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


L = []
L.append('// GENERADO por tool/generar_campus_osm.py a partir de docs/javeriana_osm.geojson.')
L.append('// NO EDITAR A MANO: cambia el script o el GeoJSON y vuelve a ejecutarlo.')
L.append('//')
L.append('// Datos © colaboradores de OpenStreetMap (licencia ODbL).')
L.append('// ignore_for_file: lines_longer_than_80_chars')
L.append('')
L.append('/// Edificio del campus tal como viene de OpenStreetMap.')
L.append('class OsmEdificio {')
L.append('  const OsmEdificio({')
L.append('    required this.id,')
L.append('    required this.osm,')
L.append('    required this.numero,')
L.append('    required this.nombre,')
L.append('    required this.niveles,')
L.append('    this.sotanos = 0,')
L.append('    required this.lat,')
L.append('    required this.lng,')
L.append('    required this.perimetro,')
L.append('    required this.tieneAscensor,')
L.append('    required this.tieneMultiplesAscensores,')
L.append('    required this.accesoMovilidadReducida,')
L.append('    required this.accesibilidadConfirmada,')
L.append('  });')
L.append('')
L.append('  final String id;')
L.append('  final String osm;')
L.append('  final int? numero;')
L.append('  final String nombre;')
L.append('  final int? niveles;')
L.append('  final int sotanos;')
L.append('  final double lat;')
L.append('  final double lng;')
L.append('  final List<(double, double)> perimetro;')
L.append('')
L.append('  /// Ascensores y accesibilidad (docs/edificios_ascensores.json). Si')
L.append('  /// [accesibilidadConfirmada] es false, los tres indicadores son false y')
L.append('  /// significan "no se sabe".')
L.append('  final bool tieneAscensor;')
L.append('  final bool tieneMultiplesAscensores;')
L.append('  final bool accesoMovilidadReducida;')
L.append('  final bool accesibilidadConfirmada;')
L.append('}')
L.append('')
L.append('/// Servicio (cafetería, papelería, biblioteca…) tal como viene de OpenStreetMap.')
L.append('class OsmServicio {')
L.append('  const OsmServicio({')
L.append('    required this.id,')
L.append('    required this.osm,')
L.append('    required this.nombre,')
L.append('    required this.categoria,')
L.append('    required this.idEdificio,')
L.append('    required this.piso,')
L.append('    required this.dentroDeEdificio,')
L.append('    required this.apertura,')
L.append('    required this.cierre,')
L.append('    required this.horarioConfirmado,')
L.append('    required this.lat,')
L.append('    required this.lng,')
L.append('  });')
L.append('')
L.append('  final String id;')
L.append('  final String osm;')
L.append('  final String nombre;')
L.append('  final String categoria;')
L.append('  final String idEdificio;')
L.append('  final int piso;')
L.append('  final bool dentroDeEdificio;')
L.append('  final String apertura;')
L.append('  final String cierre;')
L.append('  final bool horarioConfirmado;')
L.append('  final double lat;')
L.append('  final double lng;')
L.append('}')
L.append('')
L.append(f'/// {len(edificios)} edificios del campus.')
L.append('const List<OsmEdificio> osmEdificios = <OsmEdificio>[')
for e in sorted(edificios.values(), key=lambda e: (e['numero'] is None, e['numero'] or 0, e['id'])):
    per = douglas_peucker(e['anillo'] + [e['anillo'][0]], 1.0)
    anillo = [e['anillo'][i % len(e['anillo'])] for i in per][:-1] if len(per) > 3 else e['anillo']
    if len(anillo) < 3:
        anillo = e['anillo']
    L.append('  OsmEdificio(')
    L.append(f"    id: {cad(e['id'])},")
    L.append(f"    osm: {cad(e['osm'])},")
    L.append(f"    numero: {e['numero'] if e['numero'] is not None else 'null'},")
    L.append(f"    nombre: {cad(e['nombre'])},")
    L.append(f"    niveles: {e['niveles'] if e['niveles'] is not None else 'null'},")
    if e['sotanos']:
        L.append(f"    sotanos: {e['sotanos']},")
    L.append(f"    lat: {d(e['centro'][0])},")
    L.append(f"    lng: {d(e['centro'][1])},")
    L.append('    perimetro: <(double, double)>[' + ', '.join(f'({d(a)}, {d(b)})' for a, b in anillo) + '],')
    L.append(f"    tieneAscensor: {'true' if e['ascensor'] else 'false'},")
    L.append(f"    tieneMultiplesAscensores: {'true' if e['multiples'] else 'false'},")
    L.append(f"    accesoMovilidadReducida: {'true' if e['movilidad'] else 'false'},")
    L.append(f"    accesibilidadConfirmada: {'true' if e['confirmada'] else 'false'},")
    L.append('  ),')
L.append('];')
L.append('')
L.append(f'/// {len(servicios)} servicios.')
L.append('const List<OsmServicio> osmServicios = <OsmServicio>[')
for s in servicios:
    L.append('  OsmServicio(')
    L.append(f"    id: {cad(s['id'])},")
    L.append(f"    osm: {cad(s['osm'])},")
    L.append(f"    nombre: {cad(s['nombre'])},")
    L.append(f"    categoria: {cad(s['categoria'])},")
    L.append(f"    idEdificio: {cad(s['edificio'])},")
    L.append(f"    piso: {s['piso']},")
    L.append(f"    dentroDeEdificio: {'true' if s['dentro'] else 'false'},")
    L.append(f"    apertura: {cad(s['apertura'])},")
    L.append(f"    cierre: {cad(s['cierre'])},")
    L.append(f"    horarioConfirmado: {'true' if s['confirmado'] else 'false'},")
    L.append(f"    lat: {d(s['centro'][0])},")
    L.append(f"    lng: {d(s['centro'][1])},")
    L.append('  ),')
L.append('];')
L.append('')
L.append('/// Nodos del grafo peatonal: (id, lat, lng, id del lugar si es una entrada).')
L.append(f'/// {len(nodos_finales)} nodos.')
L.append('const List<(String, double, double, String?)> osmNodos = <(String, double, double, String?)>[')
for v in orden:
    lug = cad(lugar_de[v]) if v in lugar_de else 'null'
    L.append(f"  ({cad(nodos_finales[v])}, {d(verts[v][0])}, {d(verts[v][1])}, {lug}),")
L.append('];')
L.append('')
L.append('/// Senderos: (origen, destino, metros por Haversine sobre la polilínea real, es escalera).')
L.append(f'/// {len(aristas)} tramos, {sum(1 for a in aristas if a[3])} de ellos con escaleras.')
L.append('const List<(String, String, double, bool)> osmSenderos = <(String, String, double, bool)>[')
for u, v, m, esc in sorted(aristas, key=lambda a: (nodos_finales[a[0]], nodos_finales[a[1]], a[2])):
    L.append(f"  ({cad(nodos_finales[u])}, {cad(nodos_finales[v])}, {m}, {'true' if esc else 'false'}),")
L.append('];')
L.append('')
SALIDA.write_text('\n'.join(L), encoding='utf-8', newline='\n')
print('escrito', SALIDA, f'({SALIDA.stat().st_size / 1024:.0f} KB)')
