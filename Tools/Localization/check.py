#!/usr/bin/env python3
"""Checks Shared/Localizable.xcstrings against the Swift source.

Run from the repo root: python3 Tools/Localization/check.py

Fails (exit 1) when
  * a localizable literal in the source has no catalog key,
  * a catalog key is missing a language, or
  * a translation's format specifiers do not match its key.

Literals count as localizable when they are the first argument of a SwiftUI
text API (Text, Button, Label, Section, navigationTitle, alert, ...) or of
String(localized:). Interpolations are compared loosely (%@ and %lld match
each other), because the type of an interpolated expression is not visible
without the compiler.

Also fails on a bare literal passed as copy to one of this app's own view
components (TriPlaceholder, TriChip, TriSectionHeader, ...). Those take a
plain String, so the call site must pass String(localized:). Code inside
`#if DEBUG` is skipped: it never ships.
"""
import json
import os
import re
import sys

ROOT = os.getcwd()
DIRS = ['IronSplits', 'Shared']
LANGS = ['de', 'es', 'fr', 'it', 'ja', 'nl', 'pl', 'pt-BR']
UI_FUNCS = {'Text', 'Button', 'Label', 'Section', 'Toggle', 'TextField', 'navigationTitle', 'accessibilityLabel',
            'alert', 'DatePicker', 'Stepper', 'Link', 'configurationDisplayName', 'description', 'eyebrow',
            'confirmationDialog', 'Picker', 'LocalizedStringKey', 'accessibilityHint', 'SecureField',
            'LabeledContent', 'accessibilityValue', 'Menu', 'ProgressView', 'ShareLink'}
IGNORED = {'0'}
# The app's own components that draw a String argument as copy, and the
# argument labels (or `0` for the first unlabeled one) that carry it.
COMPONENTS = {'TriPlaceholder', 'TriChip', 'TriBadge', 'StatTile', 'TriSectionHeader', 'TriPrimaryButton',
              'TriBarLabel', 'RaceBookActionLabel', 'LockedRow', 'AskPattieOptionRow', 'optionToggle',
              'noteField', 'block', 'selector', 'primaryButtonLabel', 'drawStat', 'drawMetric'}
COPY_LABELS = {'title', 'message', 'actionTitle', 'caption', 'subtitle', 'text', 'trailing', 'cta', 'detail',
               'label', 'source'}


def strip_debug(src):
    """Blanks `#if DEBUG` branches (keeping newlines) so they are not scanned."""
    out = []
    depth = 0       # nesting of #if blocks
    skip_at = None  # depth whose DEBUG branch is being skipped
    for line in src.split('\n'):
        t = line.strip()
        if t.startswith('#if'):
            depth += 1
            if skip_at is None and re.match(r'#if\s+DEBUG\b', t):
                skip_at = depth
            out.append('')
            continue
        if t.startswith('#else') or t.startswith('#elseif'):
            if skip_at == depth:
                skip_at = None
            out.append('')
            continue
        if t.startswith('#endif'):
            if skip_at == depth:
                skip_at = None
            depth -= 1
            out.append('')
            continue
        out.append('' if skip_at is not None else line)
    return '\n'.join(out)


def parse_literal(src, i):
    """src[i] == '"'. Returns (end_index_after, segments) where segments are ('lit', str) or ('interp', expr)."""
    assert src[i] == '"'
    if src.startswith('"""', i):
        j = src.index('"""', i + 3)
        return j + 3, None
    i += 1
    segs = []; buf = ''
    while True:
        c = src[i]
        if c == '"':
            if buf: segs.append(('lit', buf))
            return i + 1, segs
        if c == '\\':
            n = src[i + 1]
            if n == '(':
                if buf: segs.append(('lit', buf)); buf = ''
                depth = 1; j = i + 2; expr = ''
                while depth:
                    ch = src[j]
                    if ch == '"':
                        k, _ = parse_literal(src, j)
                        expr += src[j:k]; j = k; continue
                    if ch == '(': depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0: break
                    expr += ch; j += 1
                segs.append(('interp', expr.strip()))
                i = j + 1; continue
            if n == 'u':
                j = src.index('}', i)
                buf += chr(int(src[i + 3:j], 16)); i = j + 1; continue
            buf += {'n': '\n', 't': '\t', '"': '"', '\\': '\\', "'": "'", '0': '\0'}[n]
            i += 2; continue
        buf += c; i += 1

def scan(path):
    src = strip_debug(open(path).read())
    out = []
    stack = []  # (funcname, argtext_since_last_comma, argindex)
    i = 0; n = len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == '\n': line += 1
        if src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i):
            j = src.index('*/', i); line += src[i:j].count('\n'); i = j + 2; continue
        if c == '"':
            end, segs = parse_literal(src, i)
            if segs is not None and stack:
                fn, argtxt, idx = stack[-1]
                ctx = None
                if fn == 'String' and argtxt.strip().startswith('localized:'):
                    ctx = 'String'
                elif fn in UI_FUNCS and idx == 0 and not re.match(r'\s*[a-zA-Z_]+\s*:', argtxt):
                    ctx = fn
                elif fn in UI_FUNCS and idx == 0 and re.match(r'\s*titleKey\s*:', argtxt):
                    ctx = fn
                elif fn in COMPONENTS:
                    m = re.match(r'\s*([a-zA-Z_]+)\s*:', argtxt)
                    label = m.group(1) if m else (0 if idx == 0 else None)
                    copy = ''.join(v for kind, v in segs if kind == 'lit')
                    if (label in COPY_LABELS or label == 0) and re.search(r'[A-Za-z]', copy):
                        ctx = 'component'
                if ctx:
                    out.append((line, ctx, segs))
            line += src[i:end].count('\n')
            if stack:
                f, a, k = stack[-1]; stack[-1] = (f, a + src[i:end], k)
            i = end; continue
        if c == '(':
            m = re.search(r'([A-Za-z_][A-Za-z_0-9]*)\s*$', src[max(0, i - 60):i])
            stack.append((m.group(1) if m else '', '', 0)); i += 1; continue
        if c == ')':
            if stack: stack.pop()
            i += 1; continue
        if c == ',' and stack:
            f, a, k = stack[-1]; stack[-1] = (f, '', k + 1); i += 1; continue
        if stack:
            f, a, k = stack[-1]; stack[-1] = (f, a + c, k)
        i += 1
    return out


def loose(key):
    return re.sub(r'%(\d+\$)?(lld|@)', '%*', key)


def specs(value, subs=None):
    found = []
    auto = 0
    for m in re.finditer(r'%(?:(\d+)\$)?(lld|@|%)|%#@(\w+)@', value):
        if m.group(2) == '%':
            continue
        if m.group(3):
            found.append((subs[m.group(3)]['argNum'], 'lld'))
            continue
        if m.group(1):
            pos = int(m.group(1))
        else:
            auto += 1
            pos = auto
        found.append((pos, m.group(2)))
    return sorted(set(found))


def main():
    catalog = json.load(open(os.path.join(ROOT, 'Shared', 'Localizable.xcstrings')))['strings']
    by_loose = {loose(k): k for k in catalog}
    problems = []
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
            for name in files:
                if not name.endswith('.swift'):
                    continue
                path = os.path.join(dirpath, name)
                for line, ctx, segs in scan(path):
                    if ctx == 'component':
                        problems.append(f'{os.path.relpath(path, ROOT)}:{line}: bare literal passed to a component, '
                                        f'wrap it in String(localized:)')
                        continue
                    has_interp = any(kind == 'interp' for kind, _ in segs)
                    key = ''.join((v.replace('%', '%%') if has_interp else v) if kind == 'lit' else '%@'
                                  for kind, v in segs)
                    if key.strip() and key not in IGNORED and loose(key) not in by_loose:
                        problems.append(f'{os.path.relpath(path, ROOT)}:{line}: no catalog key for "{key}"')
    for key, entry in catalog.items():
        locs = entry.get('localizations', {})
        for lang in LANGS:
            loc = locs.get(lang)
            if loc is None:
                problems.append(f'"{key}": missing {lang}')
                continue
            want = specs(key)
            if 'variations' in loc:
                values = [u['stringUnit']['value'] for u in loc['variations']['plural'].values()]
                bad = [v for v in values if specs(v) and specs(v) != want]
            else:
                bad = [] if specs(loc['stringUnit']['value'], loc.get('substitutions')) == want else [loc['stringUnit']['value']]
            for v in bad:
                problems.append(f'"{key}" [{lang}]: format specifiers differ in "{v}"')
    for p in problems:
        print(p)
    print(f'{len(catalog)} keys, {len(LANGS)} languages, {len(problems)} problems')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
