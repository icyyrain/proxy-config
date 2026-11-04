"""Exercise prefix grouping against the real converter using only synthetic nodes.

Requires requests, PyYAML and PowerShell. No private subscriptions or short links.
"""
import argparse
import base64
import concurrent.futures
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import requests
import yaml


ROOT = Path(__file__).resolve().parents[1]
NAMES = [
    'MochaKK-US-main', 'MochaKK-US-residential',
    'FriendVPS-JP-main', 'FriendVPS-US-Residential',
    'C++-US-main', 'C++-US-residential', 'Cxxxx-US-main',
    'Lab.(A)-US-main', 'Lab.(A)-US-residential', 'LabXA-US-residential',
    'Pipe|Home-US-main', 'Pipe|Home-US-residential', 'Pipe-US-main',
    'Back`Tick-US-main', 'Back`Tick-US-residential',
    '自建甲-JP-main', '自建甲-JP-residential',
    'Airport-HK-main', 'Airport-US-residential',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config-url')
    parser.add_argument('--powershell', default=os.environ.get('PWSH_EXE') or shutil.which('pwsh') or shutil.which('powershell'))
    args = parser.parse_args()
    if not args.powershell:
        raise SystemExit('PowerShell not found; use --powershell')
    fixture = {'proxies': [dict(name=n, type='ss', server='example.invalid', port=443,
                               cipher='aes-128-gcm', password='synthetic-test-only') for n in NAMES]}
    source = 'data:text/plain;base64,' + base64.b64encode(yaml.safe_dump(fixture, allow_unicode=True).encode()).decode()
    expected_dns = yaml.safe_load((ROOT / 'clash-base.yaml').read_text(encoding='utf-8'))['dns']
    command = r"""
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$ErrorActionPreference='Stop'
$spec=$env:PROXY_CONFIG_PREFIX_TEST | ConvertFrom-Json
$settings=@{ConfigPath='./tests/fixtures/subscription.test.psd1'}
if ($spec.config) { $settings.RemoteConfigUrl=$spec.config }
if ($spec.prefixes) { $settings.SelfHostedPrefixes=[string[]]@($spec.prefixes) }
(& './scripts/New-SubconverterLink.ps1' @settings).LongUrl
"""

    def probe(case):
        label, requested, expected = case
        env = dict(os.environ, PROXY_CONFIG_PREFIX_TEST=json.dumps({'prefixes': requested, 'config': args.config_url}))
        generated = subprocess.run([args.powershell, '-NoProfile', '-Command', command], cwd=ROOT,
                                   env=env, capture_output=True, encoding='utf-8-sig')
        if generated.returncode:
            raise RuntimeError(f'{label}: link generation failed (output suppressed)')
        url = urlsplit(generated.stdout.strip())
        query = dict(parse_qsl(url.query))
        query['url'] = source
        if label == 'legacy-no-parameter':
            query.pop('selfhost', None)
        request_url = urlunsplit((url.scheme, url.netloc, url.path, urlencode(query), ''))
        session = requests.Session()
        session.trust_env = False
        try:
            response = session.get(request_url, timeout=60)
        except requests.RequestException as error:
            raise RuntimeError(f'{label}: request failed ({type(error).__name__}; URL suppressed)') from None
        if response.status_code != 200:
            raise RuntimeError(f'{label}: conversion HTTP {response.status_code}')
        try:
            config = yaml.safe_load(response.text)
        except Exception:
            raise RuntimeError(f'{label}: invalid conversion output (suppressed)') from None
        if not isinstance(config, dict) or len(config.get('proxies', [])) != len(NAMES):
            raise RuntimeError(f'{label}: source nodes were removed or conversion failed')
        actual_names = [n['name'] for n in config['proxies']]
        members = [n for n in actual_names if any(p in n for p in expected)]
        residential = [n for n in members if any(
            p in n and re.search('[Rr]esidential', n[n.index(p) + len(p):]) for p in expected)]
        groups = {g['name']: g.get('proxies', []) for g in config.get('proxy-groups', [])}
        for group in ['🏠 自建节点', '🏠 自建备用']:
            if groups.get(group) != members:
                raise RuntimeError(f'{label}: incorrect membership in {group}')
        if groups.get('🏡 自建住宅IP') != residential:
            raise RuntimeError(f'{label}: incorrect residential membership')
        if config.get('dns') != expected_dns:
            raise RuntimeError(f'{label}: DNS was changed by prefix selection')
        return dict(case=label, source_nodes=len(actual_names), self_hosted=len(members), residential=len(residential))

    cases = [
        ('default', None, ['MochaKK']),
        ('legacy-no-parameter', None, ['MochaKK']),
        ('single-prefix', ['FriendVPS'], ['FriendVPS']),
        ('multiple-prefixes', ['MochaKK', 'FriendVPS'], ['MochaKK', 'FriendVPS']),
        ('literal-special-characters', ['C++', 'Lab.(A)', 'Pipe|Home', 'Back`Tick'],
         ['C++', 'Lab.(A)', 'Pipe|Home', 'Back`Tick']),
        ('unicode-prefix', ['自建甲'], ['自建甲']),
    ]
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            for result in pool.map(probe, cases):
                print(json.dumps(result, ensure_ascii=False), flush=True)
    except RuntimeError as error:
        raise SystemExit(str(error)) from None
    print('Real conversion validated for all three groups; default, legacy, custom, literal and Unicode prefixes passed')


if __name__ == '__main__':
    main()
