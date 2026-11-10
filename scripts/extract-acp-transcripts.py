import sqlite3, os, glob, json, datetime, re

d = os.path.expandvars(r'%APPDATA%\devin\User\acp-messages')
outdir = r'D:\DevOptimizer\logs\acp-transcripts'
os.makedirs(outdir, exist_ok=True)

def texts(o, out):
    if isinstance(o, dict):
        if o.get('type') == 'text' and isinstance(o.get('text'), str):
            out.append(o['text'])
        for v in o.values():
            texts(v, out)
    elif isinstance(o, list):
        for v in o:
            texts(v, out)

def safe(s):
    return re.sub(r'[^\w\-]+', '_', s)[:60]

manifest = []
for f in sorted(glob.glob(os.path.join(d, '*.db')), key=os.path.getmtime, reverse=True):
    base = os.path.basename(f)
    try:
        con = sqlite3.connect('file:' + f.replace('\\','/') + '?mode=ro', uri=True)
        meta = {r[0]: r[1] for r in con.execute('select key, value from meta')}
        info = json.loads(meta.get('info','{}'))
        title = info.get('title') or 'untitled'
        n = con.execute('select count(*) from messages').fetchone()[0]
        if n < 5:
            con.close(); continue
        mt = datetime.datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
        fn = os.path.join(outdir, f'{mt.replace(":","-").replace(" ","_")}_{safe(title)}_{base[:8]}.md')
        with open(fn, 'w', encoding='utf-8') as w:
            w.write(f'# {title}\n\n- source: {base}\n- messages: {n}\n- last activity: {mt}\n\n---\n\n')
            for pos, kind, payload in con.execute('select position, kind, payload from messages order by position'):
                try:
                    p = json.loads(payload)
                except Exception:
                    continue
                ts = []
                texts(p, ts)
                body = '\n'.join(t for t in ts if t.strip())
                k = (p.get('kind') or kind or '').lower()
                if 'user' in k:
                    w.write(f'\n## USER\n\n{body}\n')
                elif 'thought' in k:
                    w.write(f'\n### thought\n\n{body}\n')
                elif 'tool' in k:
                    title_t = ''
                    c = p.get('content') or {}
                    if isinstance(c, dict):
                        title_t = c.get('title') or ''
                    w.write(f'\n> tool: {title_t or k} {("- " + body[:300]) if body else ""}\n')
                elif 'agent' in k or 'message' in k or 'text' in k:
                    w.write(f'\n## AGENT\n\n{body}\n')
                else:
                    if body:
                        w.write(f'\n[{k}] {body[:1000]}\n')
        manifest.append((mt, title, n, os.path.basename(fn)))
        con.close()
    except Exception as e:
        manifest.append(('ERR', base[:12], -1, str(e)[:80]))

for mt, t, n, fn in manifest:
    print(f'{mt}  msgs={n:<5}  {t[:55]:<55}  {fn}')
print(f'\n{len(manifest)} transcripts -> {outdir}')
