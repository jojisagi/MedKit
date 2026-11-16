"""Convierte la primera hoja de un .xlsx a CSV sin dependencias.
Uso: python3 tool/xlsx_to_csv.py archivo.xlsx --csv assets/catalog/medicamentos.csv"""
import sys, zipfile, re, csv
import xml.etree.ElementTree as ET
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}

def col_index(ref):
    letters = re.match(r'[A-Z]+', ref).group()
    n = 0
    for ch in letters:
        n = n * 26 + (ord(ch) - 64)
    return n - 1

def load(path):
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    target = {r.get('Id'): r.get('Target') for r in rels}
    sheets = []
    for s in wb.find('m:sheets', NS):
        rid = s.get('{%s}id' % NS['r'])
        t = target[rid].lstrip('/')
        t = t if t.startswith('xl/') else 'xl/' + t
        rows = []
        for row in ET.fromstring(z.read(t)).iter('{%s}row' % NS['m']):
            vals = {}
            for c in row.findall('m:c', NS):
                v = c.find('m:v', NS)
                typ = c.get('t')
                if typ == 'inlineStr':
                    val = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['m']))
                elif v is None:
                    continue
                elif typ == 's':
                    val = shared[int(v.text)]
                else:
                    val = v.text
                vals[col_index(c.get('r'))] = val
            if vals:
                rows.append([vals.get(i, '') for i in range(max(vals) + 1)])
        sheets.append((s.get('name'), rows))
    return sheets

if __name__ == '__main__':
    sheets = load(sys.argv[1])
    if '--csv' in sys.argv:
        out = sys.argv[sys.argv.index('--csv') + 1]
        with open(out, 'w', newline='') as f:
            csv.writer(f).writerows(sheets[0][1])
    for name, rows in sheets:
        print('HOJA', repr(name), 'filas', len(rows))
        for r in rows[:15]:
            print(r)
