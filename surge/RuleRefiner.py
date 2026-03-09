import argparse
import sys
import time
import shutil
from pathlib import Path

# ================= 配置区 =================
# 生成文件的头部注释模板（中文版）
HEADER_TEMPLATE = """# 标题: {name}
# 更新时间: {c_time}
# 策略: 精品化 / 全量扫描 / 智能合并 / 自动清空
# 来源: MetaCubeX/meta-rules-dat (洋山芋定制版)
"""
# ==========================================

class BoutiqueProcessor:
    def __init__(self, site_dir, ip_dir, out_dir):
        self.site_dir = Path(site_dir)
        self.ip_dir = Path(ip_dir)
        self.out_dir = Path(out_dir)
        self.domainset_dir = self.out_dir / "domainset"
        self.ruleset_dir = self.out_dir / "ruleset"
        
        # --- 核心改进：清理旧数据 ---
        if self.out_dir.exists():
            print(f"🧹 发现旧输出目录，正在清理: {self.out_dir}")
            shutil.rmtree(self.out_dir)
        
        # 重新创建干净的目录结构
        for d in [self.domainset_dir, self.ruleset_dir]:
            d.mkdir(parents=True, exist_ok=True)
        
        # 缓存结构: {文件名: {"dom_raw": 0, "dom_opt": 0, "ip_cnt": 0, "suffixes": [], "domains": []}}
        self.registry = {}

    def parse_domain(self, line):
        """解析并统一化域名格式"""
        line = line.strip()
        if not line or line.startswith(('#', '//', 'PROCESS-NAME', 'USER-AGENT')):
            return None
        if 'DOMAIN-SUFFIX,' in line: return ('SUFFIX', line.split(',')[1])
        if 'DOMAIN,' in line: return ('DOMAIN', line.split(',')[1])
        if line.startswith('+.'): return ('SUFFIX', line[2:])
        if line.startswith('.'): return ('SUFFIX', line[1:])
        if line.startswith('+'): return ('SUFFIX', line[1:])
        return ('DOMAIN', line)

    def optimize_domains(self, tuples):
        """核心去重逻辑：递归清理嵌套后缀和冗余域名"""
        raw_count = len(tuples)
        # 按长度排序，优先处理短域名
        raw_suffixes = sorted({d for t, d in tuples if t == 'SUFFIX'}, key=len)
        domains = {d for t, d in tuples if t == 'DOMAIN'}
        
        # 1. 后缀递归去重
        final_suffixes = []
        for s in raw_suffixes:
            if not any(s.endswith('.' + existing) or s == existing for existing in final_suffixes):
                final_suffixes.append(s)
        
        # 2. 域名与后缀交叉去重
        optimized_domains = [
            d for d in domains 
            if not any(d.endswith('.' + s) or d == s for s in final_suffixes)
        ]
        
        opt_count = len(final_suffixes) + len(optimized_domains)
        return sorted(final_suffixes), sorted(optimized_domains), raw_count, opt_count

    def process(self):
        c_time = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"🚀 开始执行精品化转换 | 模式: 自动扫描合并\n" + "="*80)
        
        # --- 1. 扫描 Geosite ---
        for site_file in self.site_dir.glob("*.list"):
            name = site_file.stem
            raw_tuples = []
            with site_file.open('r', encoding='utf-8') as f:
                for line in f:
                    res = self.parse_domain(line)
                    if res: raw_tuples.append(res)
            
            suffixes, domains, r_cnt, o_cnt = self.optimize_domains(raw_tuples)
            self.registry[name] = {
                "dom_raw": r_cnt, "dom_opt": o_cnt, 
                "suffixes": suffixes, "domains": domains,
                "ip_cnt": 0
            }
            
            # 写入 Domain-Set
            with (self.domainset_dir / site_file.name).open('w', encoding='utf-8') as f:
                f.write(HEADER_TEMPLATE.format(name=f"{name} (Domain-Set)", c_time=c_time))
                f.write("\n".join([f".{s}" for s in suffixes] + domains))

        # --- 2. 扫描 GeoIP 并智能合并 ---
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

            # 写入 Rule-Set
            rules = []
            entry = self.registry[name]
            rules += [f"DOMAIN,{d}" for d in entry["domains"]]
            rules += [f"DOMAIN-SUFFIX,{s}" for s in entry["suffixes"]]
            rules += sorted(list(ip_rules))
            
            with (self.ruleset_dir / ip_file.name).open('w', encoding='utf-8') as f:
                f.write(HEADER_TEMPLATE.format(name=f"{name} (Rule-Set)", c_time=c_time))
                f.write("\n".join(rules))

        # --- 3. 补齐只有域名没有 IP 的 Rule-Set ---
        for name, data in self.registry.items():
            rs_file = self.ruleset_dir / f"{name}.list"
            if not rs_file.exists() and (data["suffixes"] or data["domains"]):
                rules = [f"DOMAIN,{d}" for d in data["domains"]] + [f"DOMAIN-SUFFIX,{s}" for s in data["suffixes"]]
                with rs_file.open('w', encoding='utf-8') as f:
                    f.write(HEADER_TEMPLATE.format(name=f"{name} (Rule-Set)", c_time=c_time))
                    f.write("\n".join(rules))

        self.print_summary()

    def print_summary(self):
        print(f"{'规则名称':<25} | {'域名(原/现)':<15} | {'IP数量':<8} | {'瘦身率'}")
        print("-" * 80)
        # 按照文件名排序打印，更美观
        for name in sorted(self.registry.keys()):
            d = self.registry[name]
            dom_info = f"{d['dom_raw']}/{d['dom_opt']}"
            ratio = f"{(1 - d['dom_opt']/d['dom_raw'])*100:.1f}%" if d['dom_raw'] > 0 else "0.0%"
            print(f"{name:<27} | {dom_info:<17} | {d['ip_cnt']:<10} | {ratio}")
        print("-" * 80)
        print(f"✅ 转换完成！输出目录已刷新: {self.out_dir.absolute()}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="洋山芋的精品规则全自动同步器")
    parser.add_argument("-s", "--site", required=True, help="Geosite Classical 目录")
    parser.add_argument("-i", "--ip", required=True, help="GeoIP 纯 IP 列表目录")
    parser.add_argument("-o", "--output", required=True, help="输出根目录")
    args = parser.parse_args()

    processor = BoutiqueProcessor(args.site, args.ip, args.output)
    processor.process()
