import zipfile, xml.etree.ElementTree as ET, re, sys

xlsx = 'code Delta.xlsx'
with zipfile.ZipFile(xlsx) as z:
    ss = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        ns = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
        for si in root.findall(f'{ns}si'):
            t = ''.join(x.text or '' for x in si.iter(f'{ns}t'))
            ss.append(t)
    # sheet names
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    wbns = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
    names = {s.get('sheetId'): s.get('name') for s in wb.findall(f'.//{wbns}sheet')}
    sheets = sorted([f for f in z.namelist() if re.match(r'xl/worksheets/sheet\d+\.xml', f)])
    for sh in sheets:
        sid = re.search(r'sheet(\d+)', sh).group(1)
        sname = names.get(sid, sh)
        print(f'\n=== Sheet: {sname} ===')
        root2 = ET.fromstring(z.read(sh))
        nsm = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
        for row in root2.findall(f'.//{nsm}row'):
            cells = []
            for c in row.findall(f'{nsm}c'):
                t = c.get('t', '')
                v = c.find(f'{nsm}v')
                val = ''
                if v is not None and v.text:
                    val = ss[int(v.text)] if t == 's' else v.text
                cells.append(val)
            if any(cells):
                print('  | ' + ' | '.join(cells))
