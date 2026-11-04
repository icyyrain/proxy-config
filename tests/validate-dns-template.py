"""Validate DNS routing and the emitted subscription without printing credentials.

Requires Python 3 and PyYAML. --converted additionally checks an actual conversion.
"""
import argparse
import ipaddress
from pathlib import Path
from urllib.parse import urlsplit

import yaml


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--converted', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    ini = (root / 'subconverter.ini').read_text(encoding='utf-8')
    lines = ini.splitlines()
    require([x for x in lines if x.startswith('clash_rule_base=')] == [
        'clash_rule_base=https://raw.githubusercontent.com/icyyrain/proxy-config/main/clash-base.yaml'
    ], 'The active INI must reference this repository DNS base template')
    groups = {x.split('=', 1)[1].split('`', 1)[0]
              for x in lines if x.startswith('custom_proxy_group=')}
    base = yaml.safe_load((root / 'clash-base.yaml').read_text(encoding='utf-8'))
    dns = base['dns']
    require(dns.get('enable') is True, 'DNS must be enabled')
    require(dns.get('enhanced-mode') == 'redir-host', 'Keep the validated DNS mode')
    require(bool(dns.get('nameserver')), 'Default DNS must not be empty')
    for endpoint in dns['nameserver']:
        url = urlsplit(endpoint)
        require(url.scheme == 'https' and url.path == '/dns-query', 'Default DNS must use DoH')
        require(url.fragment in groups, 'Default DNS must explicitly reference an existing proxy group')
        require(url.fragment == '🚀 节点选择', 'Default DNS must use the main proxy group')
    require(not dns.get('fallback'), 'Do not send unclassified domains to a domestic fallback')
    filters = dns.get('fallback-filter', {})
    require(not filters.get('geoip') and not any(filters.get(k) for k in ['geosite', 'ipcidr', 'domain']),
            'Old fallback filters must be cleared')
    policy = dns.get('nameserver-policy', {})
    require('geosite:cn' in policy and '+.cn' in policy, 'Domestic DNS policies must cover the CN set and TLD')
    require('+.weixin.qq.com' in policy and '+.qpic.cn' in policy, 'Preserve WeChat DNS compatibility')
    require(all(k in {'geosite:cn', '+.cn'} or k.startswith('+.') for k in policy),
            'Unexpected catch-all DNS policy')
    for endpoint in list(policy.values()) + dns.get('proxy-server-nameserver', []):
        require(isinstance(endpoint, str), 'Use string policy values for older FlClash versions')
        url = urlsplit(endpoint)
        require(url.scheme == 'https' and url.path == '/dns-query' and url.fragment == 'DIRECT',
                'Domestic and node DNS must use direct DoH')
    require(bool(dns.get('proxy-server-nameserver')), 'Node DNS must be independent of the proxy')
    for endpoint in dns.get('default-nameserver', []):
        url = urlsplit(endpoint)
        require(url.scheme == 'https' and not url.fragment, 'Bootstrap DNS must use independent DoH')
        try:
            ipaddress.ip_address(url.hostname)
        except ValueError:
            raise SystemExit('Bootstrap DNS must use an IP literal to avoid resolution loops')
    require(bool(dns.get('default-nameserver')), 'Bootstrap DNS is required')
    require(not any(k in base for k in ['tun', 'secret', 'authentication']),
            'Do not distribute device routing or credentials in the public base')
    require(all(base.get(k) == [] for k in ['proxies', 'proxy-groups', 'rules']),
            'The public template must not contain actual subscription nodes or routing data')
    if args.converted:
        # Never print data or parser exceptions from a credential-bearing subscription.
        try:
            actual = yaml.safe_load(args.converted.read_text(encoding='utf-8'))
        except Exception:
            raise SystemExit('Could not read converted configuration; details suppressed')
        require(isinstance(actual, dict), 'Conversion must return a Clash configuration')
        require(actual.get('dns') == dns, 'The actual conversion changed or omitted DNS fields')
        require(bool(actual.get('proxies')) and bool(actual.get('rules')), 'The conversion must preserve nodes and rules')
        emitted = {g['name'] for g in actual.get('proxy-groups', [])}
        require('🚀 节点选择' in emitted, 'The emitted subscription is missing the DNS proxy group')
        print('Actual converted DNS, nodes, groups and rules validated (contents suppressed)')
    print(f'DNS template validated: {len(policy)} domestic policies; proxy DoH and independent node/bootstrap DNS')


if __name__ == '__main__':
    main()
