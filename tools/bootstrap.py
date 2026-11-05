"""Extract immutable requirements and the original RTL allocation; no RTL generation."""
from pathlib import Path
import hashlib, json, zipfile
import openpyxl

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT.parent
(ROOT / 'docs').mkdir(parents=True, exist_ok=True)
(ROOT / 'verification').mkdir(exist_ok=True)
sources = {}
for p in INPUT.iterdir():
    if p.suffix.lower() in ('.pdf', '.xlsx', '.zip'):
        sources[p.name] = {'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}
tables = {}
for p in sorted(INPUT.glob('*.xlsx')):
    book = openpyxl.load_workbook(p, data_only=False)
    values = openpyxl.load_workbook(p, data_only=True)
    tables[p.name] = {sheet.title: [
        {'row': i, 'cells': {openpyxl.utils.get_column_letter(j): v for j, v in enumerate(row, 1) if v is not None}}
        for i, row in enumerate(sheet.values, 1) if any(v is not None for v in row)
    ] for sheet in book}
    for sheet in book:
        for row in sheet:
            for cell in row:
                if cell.data_type == 'f':
                    tables[p.name].setdefault('_formula_cache', {})[sheet.title + '!' + cell.coordinate] = values[sheet.title][cell.coordinate].value
with zipfile.ZipFile(INPUT / 'BLE.zip') as archive:
    allocation = []
    for name in archive.namelist():
        if name.startswith('BLE/') and '/rtl/' in name and name.endswith('.v'):
            relative = name.removeprefix('BLE/')
            (ROOT / relative).parent.mkdir(parents=True, exist_ok=True)
            allocation.append({'source': name, 'target': relative, 'module': Path(name).stem,
                               'source_sha256': hashlib.sha256(archive.read(name)).hexdigest()})
assert len(allocation) == 43
for name, data in [('source_manifest.json', sources), ('resource_contract.json', tables), ('module_allocation.json', allocation)]:
    (ROOT / 'docs' / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Extracted 6 source hashes, 3 workbooks, and 43 RTL allocations.')
