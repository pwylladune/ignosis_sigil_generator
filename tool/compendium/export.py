"""Exports The Compendium for the app from the literature review in the vault.

    python3 tool/compendium/export.py [vault-folder]

Reads clr-data.json and clr-glossary.json from
Agent-Memory/Knowledge/Esoterica/chaos-magic-literature-review/ and writes
assets/compendium/compendium.json. Only quotations, citations and links go
into the app: the researchers' notes, the leads and the audit stay in the vault.
"""
import json
import os
import re
import sys
from datetime import date

VAULT = '/Users/pwyll/Documents/MCR/Agent-Memory/Knowledge/Esoterica/chaos-magic-literature-review'
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'compendium', 'compendium.json')
QUOTE_FIELDS = ('text', 'author', 'work', 'year', 'translator', 'locator', 'public_domain', 'source_url', 'learn_more_url')


def clean(q):
    out = {k: q.get(k) for k in QUOTE_FIELDS if q.get(k) not in (None, '')}
    out['text'] = q['text'].strip()
    return out


def main(vault):
    data = json.load(open(os.path.join(vault, 'clr-data.json')))
    glossary = json.load(open(os.path.join(vault, 'clr-glossary.json')))
    parts, by_text = [], {}
    for p in data['parts']:
        numeral, _, title = p['part'].partition('.')
        sections = []
        for s in p['sections']:
            quotes = [clean(q) for q in s['quotes']]
            if quotes:
                sections.append({'title': re.sub(r'^\d+\.\s*', '', s['title']), 'quotes': quotes})
        parts.append({'numeral': numeral.strip(), 'title': title.strip(), 'sections': sections})
        for si, s in enumerate(sections):
            for qi, q in enumerate(s['quotes']):
                by_text.setdefault(q['text'], (len(parts) - 1, si, qi))

    terms = []
    for t in glossary['terms']:
        refs = [list(by_text[g['text']]) for g in t['quotes'] if g['text'] in by_text]
        if refs:
            terms.append({'term': t['term'], 'refs': refs})

    # Study guide: each part's works, in the order they are first quoted.
    guide = []
    for p in parts:
        seen, works = set(), []
        for s in p['sections']:
            for q in s['quotes']:
                key = (q.get('author'), q.get('work'))
                if key in seen:
                    continue
                seen.add(key)
                works.append({k: q.get(k) for k in ('author', 'work', 'year', 'public_domain')}
                             | {'url': q.get('learn_more_url') or q.get('source_url')})
        guide.append({'numeral': p['numeral'], 'title': p['title'], 'works': works})

    seen, authors = set(), []
    for a in sorted(data.get('authors', []), key=lambda a: a.get('name', '').lower()):
        key = a.get('name', '').lower()
        if key and a.get('website') and key not in seen:
            seen.add(key)
            authors.append({'name': a['name'], 'website': a['website']})

    bibliography = [{'citation': b['citation'], 'url': b.get('url'), 'public_domain': bool(b.get('public_domain'))}
                    for b in data['bibliography']]

    out = {
        'generated': date.today().isoformat(),
        'parts': parts,
        'glossary': terms,
        'study_guide': guide,
        'bibliography': bibliography,
        'authors': authors,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, open(OUT, 'w'), ensure_ascii=False, separators=(',', ':'))
    n = sum(len(s['quotes']) for p in parts for s in p['sections'])
    print(f'{len(parts)} parts, {n} quotations, {len(terms)} glossary terms, {len(bibliography)} works, '
          f'{len(authors)} authors -> {os.path.normpath(OUT)} ({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else VAULT)
