#!/usr/bin/env python3
import argparse
import time
import shutil
from pathlib import Path

# ================= 配置区 =================
HEADER_TEMPLATE = """# 标题: {name}
# 更新时间: {c_time}
# 策略: 精品化 / 高性能转换 / 自动合并
# 来源: MetaCubeX/meta-rules-dat (洋山芋定制)
"""
# ==========================================

class RuleRefiner:
    def __init__(self, site_dir, ip_dir, out_dir):
        self.site_dir = Path(site_dir)
        self.ip_dir = Path(ip_dir)
        self.out_dir = Path(out_dir)
        self.domainset_dir = self.out_dir / "domainset"
        self.ruleset_dir = self.out_dir / "ruleset"
        
        if self.out_dir.exists():
            print(f"🧹 清理旧目录: {self.out_dir}")
            shutil.rmtree(self.out_dir)
        
        for d in [self.domainset_dir, self.ruleset_dir]:
            d.mkdir(parents=True, exist_ok=True)
        
        self.registry = {}

    def parse_domain(self, line):
        line = line.strip()
        if not line or line.startswith(('#', '//', 'PROCESS-NAME', 'USER-AGENT')):
            return None
        if 'DOMAIN-SUFFIX,' in line: return ('SUFFIX', line.split(',')[1].lower())
        if 'DOMAIN,' in line: return ('DOMAIN', line.split(',')[1].lower())
        if line.startswith('+.'): return ('SUFFIX', line[2:].lower())
        if line.startswith('.'): return ('SUFFIX', line[1:].lower())
        if line.startswith('+'): return ('SUFFIX', line[1:].lower())
        return ('DOMAIN', line.lower())

    def optimize_domains(self, tuples):
        """
        高性能去重逻辑：
        使用长度排序 + 集合查找，避免万级数据下的 O(n^2) 崩溃
        """
        raw_count = len(tuples)
        if raw_count == 0: return [], [], 0, 0

        # 分离并去重
        raw_suffixes = sorted({d for t, d in tuples if t == 'SUFFIX'}, key=len)
        raw_domains = {d for t, d in tuples if t == 'DOMAIN'}
        
        # 1. 后缀嵌套去重 (如 google.com 包含 sub.google.com)
        final_suffixes = []
        for s in raw_suffixes:
            is_redundant = False
            parts = s.split('.')
            # 向上查找所有可能的父级后缀
            for i in range(1, len(parts)):
                parent = ".".join(parts[i:])
                if parent in final_suffixes:
                    is_redundant = True
                    break
            if not is_redundant:
                final_suffixes.append(s)
        
        suffix_set = set(final_suffixes)
        
        # 2. 域名去重 (如果域名已被后缀覆盖)
        final_domains = []
        for d in raw_domains:
            is_covered = False
            parts = d.split('.')
            # 向上查找，例如 d=a.b.com, 查找 b.com 和 com
            for i in range(1, len(parts)):
                parent = ".".join(parts[i:])
                if parent in suffix_set:
                    is_covered = True
                    break
            if not is_covered and d not in suffix_set:
                final_domains.append(d)
        
        return final_suffixes, sorted(final_domains), raw_count, len(final_suffixes) + len(final_domains)

    def process(self):
        c_time = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"🚀 RuleRefiner 正在运行...")
        
        # 扫描域名
        site_files = list(self.site_dir.glob("*.list"))
        for site_file in site_files:
            name = site_file.stem
            print(f"  > 正在精炼域名: {name}...", end="", flush=True) # 实时打印，不换行
            
            raw_tuples = []
            with site_file.open('r', encoding='utf-8') as f:
                for line in f:
                    res = self.parse_domain(line)
                    if res: raw_tuples.append(res)
            
            suffixes, domains, r_cnt, o_cnt = self.optimize_domains(raw_tuples)
            self.registry[name] = {"dom_raw": r_cnt, "dom_opt": o_cnt, "suffixes": suffixes, "domains": domains, "ip_cnt": 0}
            
            # 写入 Domain-Set
            with (self.domainset_dir / site_file.name).open('w', encoding='utf-8') as f:
                f.write(HEADER_TEMPLATE.format(name=f"{name} (Domain-Set)", c_time=c_time))
                f.write("\n".join([f".{s}" for s in suffixes] + domains))
            print(f" 完成! ({r_cnt} -> {o_cnt})")

        # 扫描 IP
        print(f"🚀 正在智能合并 IP 规则...")
        for ip_file in self.ip_dir.glob("*.list"):
            name = ip_file.stem
            ip_rules = set()
            with ip_file.open('r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith(('#', '//')): continue
                    prefix = "IP-CIDR6" if ":" in line else "IP-CIDR"
                    ip_rules.add(f"{prefix},{line},no-resolve")
            
            if name not in self.registry:
                self.registry[name] = {"dom_raw": 0, "dom_opt": 0, "suffixes": [], "domains": [], "ip_cnt": 0}
            self.registry[name]["ip_cnt"] = len(ip_rules)

            rules = [f"DOMAIN,{d}" for d in self.registry[name]["domains"]] + \
                    [f"DOMAIN-SUFFIX,{s}" for s in self.registry[name]["suffixes"]] + \
                    sorted(list(ip_rules))
            
            with (self.ruleset_dir / ip_file.name).open('w', encoding='utf-8') as f:
                f.write(HEADER_TEMPLATE.format(name=f"{name} (Rule-Set)", c_time=c_time))
                f.write("\n".join(rules))

        # 补全
        for name, data in self.registry.items():
            if not (self.ruleset_dir / f"{name}.list").exists():
                rules = [f"DOMAIN,{d}" for d in data["domains"]] + [f"DOMAIN-SUFFIX,{s}" for s in data["suffixes"]]
                with (self.ruleset_dir / f"{name}.list").open('w', encoding='utf-8') as f:
                    f.write(HEADER_TEMPLATE.format(name=f"{name} (Rule-Set)", c_time=c_time))
                    f.write("\n".join(rules))

        self.print_summary()

    def print_summary(self):
        print(f"\n{'规则名称':<25} | {'域名优化(原/现)':<18} | {'IP条数':<10} | {'精简率'}")
        print("-" * 85)
        for name in sorted(self.registry.keys()):
            d = self.registry[name]
            dom_info = f"{d['dom_raw']}/{d['dom_opt']}"
            ratio = f"{(1 - d['dom_opt']/d['dom_raw'])*100:.1f}%" if d['dom_raw'] > 0 else "0.0%"
            print(f"{name:<29} | {dom_info:<21} | {d['ip_cnt']:<12} | {ratio}")
        print("-" * 85)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--site", required=True)
    parser.add_argument("-i", "--ip", required=True)
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()
    RuleRefiner(args.site, args.ip, args.output).process()
