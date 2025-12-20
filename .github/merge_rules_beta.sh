#!/bin/bash

# ================ 基础辅助函数 ================

# 检查文件是否存在且可读
_check_file_readable() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件不存在 - $file" >&2
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        echo "错误: 文件不可读 - $file" >&2
        return 1
    fi
    return 0
}

# 检查目录是否存在且可写
_check_directory_writable() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "错误: 目录不存在 - $dir" >&2
        return 1
    fi
    if [[ ! -w "$dir" ]]; then
        echo "错误: 目录不可写 - $dir" >&2
        return 1
    fi
    return 0
}

# 确保目录存在
_ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "创建目录: $dir"
        if mkdir -p "$dir"; then
            echo "✓ 目录创建成功"
            return 0
        else
            echo "错误: 无法创建目录 - $dir" >&2
            return 1
        fi
    fi
    return 0
}

# 获取文件信息
_get_file_info() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size=$(wc -c < "$file" 2>/dev/null || echo 0)
        local lines=$(wc -l < "$file" 2>/dev/null || echo 0)
        echo "$size $lines"
    else
        echo "0 0"
    fi
}

# ================ 文件操作辅助函数 ================

# 安全复制文件
_safe_copy() {
    local source="$1"
    local target="$2"
    
    if _check_file_readable "$source"; then
        if cp "$source" "$target"; then
            echo "✓ 文件复制成功: $source → $target"
            return 0
        else
            echo "错误: 文件复制失败" >&2
            return 1
        fi
    fi
    return 1
}

# 安全追加文件内容（修复版 - 解决粘连问题）
_safe_append() {
    local source="$1"
    local target="$2"
    
    if ! _check_file_readable "$source"; then
        return 1
    fi
    
    # 检查目标文件是否为空
    if [[ ! -s "$target" ]]; then
        # 目标文件为空，直接复制内容
        if cat "$source" >> "$target"; then
            local source_info=($(_get_file_info "$source"))
            local target_info=($(_get_file_info "$target"))
            echo "✓ 内容追加成功: ${source_info[0]}字节 → ${target_info[0]}字节"
            return 0
        else
            echo "错误: 内容追加失败" >&2
            return 1
        fi
    else
        # 目标文件不为空，需要添加分隔符
        # 检查目标文件最后一行是否以换行符结束
        local last_char=$(tail -c 1 "$target" 2>/dev/null | od -An -tx1 | tr -d ' \n')
        if [[ "$last_char" != "0a" ]]; then
            # 目标文件末尾没有换行符，添加一个
            echo "" >> "$target"
        fi
        
        # 检查源文件是否为空
        if [[ ! -s "$source" ]]; then
            echo "! 源文件为空，跳过追加"
            return 0
        fi
        
        # 追加源文件内容
        if cat "$source" >> "$target"; then
            local source_info=($(_get_file_info "$source"))
            local target_info=($(_get_file_info "$target"))
            echo "✓ 内容追加成功: ${source_info[0]}字节 → ${target_info[0]}字节"
            return 0
        else
            echo "错误: 内容追加失败" >&2
            return 1
        fi
    fi
}


# 清空文件内容
_clear_file() {
    local file="$1"
    if > "$file"; then
        echo "✓ 文件已清空: $file"
        return 0
    else
        echo "错误: 无法清空文件" >&2
        return 1
    fi
}

# ================ 数组操作辅助函数 ================

# 判断是否为数组
_is_array() {
    local var_name="$1"
    if declare -p "$var_name" 2>/dev/null | grep -q '^declare -a'; then
        return 0
    else
        return 1
    fi
}

# 获取数组内容
_get_array_contents() {
    local array_name="$1"
    
    if ! _is_array "$array_name"; then
        echo "错误: '$array_name' 不是数组" >&2
        return 1
    fi
    
    local array_contents
    eval "array_contents=(\"\${$array_name[@]}\")"
}

# 获取数组长度
_get_array_length() {
    local array_name="$1"
    local array_contents
    eval "array_contents=(\"\${$array_name[@]}\")"
    echo "${#array_contents[@]}"
}

# ================ 日志和统计辅助函数 ================

# 开始计时
_start_timer() {
    date +%s.%N
}

# 计算持续时间
_calculate_duration() {
    local start_time="$1"
    local end_time=$(date +%s.%N)
    echo "$end_time - $start_time" | bc
}

# 打印步骤开始
_log_step_start() {
    local step_number="$1"
    local step_name="$2"
    local total_steps="${3:-}"
    
    echo ""
    echo "=========================================="
    if [[ -n "$total_steps" ]]; then
        echo "[步骤${step_number}/${total_steps}] ${step_name}"
    else
        echo "[步骤${step_number}] ${step_name}"
    fi
    echo "------------------------------------------"
}

# 打印步骤结束
_log_step_end() {
    local step_name="$1"
    local success="$2"
    local duration="${3:-}"
    
    if [[ "$success" -eq 0 ]]; then
        echo "✓ ${step_name}完成"
    else
        echo "✗ ${step_name}失败" >&2
    fi
    
    if [[ -n "$duration" ]]; then
        printf "耗时: %.3f秒\n" "$duration"
    fi
    echo "------------------------------------------"
}

# 打印操作结果摘要
_log_summary() {
    local operation="$1"
    shift
    local stats=("$@")
    
    echo ""
    echo "=========================================="
    echo "${operation}完成摘要"
    echo "------------------------------------------"
    
    for stat in "${stats[@]}"; do
        echo "  $stat"
    done
    echo "=========================================="
}

# ================ 文件内容清理函数 ================

# 文件内容清理函数（修复统计问题版）
_clean_file_content() {
    local file="$1"
    local temp_file=$(mktemp) || {
        echo "错误: 无法创建临时文件" >&2
        return 1
    }
    
    echo "开始清理文件内容: $file"
    
    # 备份原始文件信息
    local original_info=($(_get_file_info "$file"))
    local original_size="${original_info[0]}"
    local original_lines="${original_info[1]}"
    
    echo "原始文件: ${original_lines}行, ${original_size}字节"
    
    # 统计变量
    local -i removed_empty=0
    local -i removed_comments=0
    local -i removed_domain_regex=0
    local -i modified_ip_cidr=0
    local -i modified_ip_cidr6=0
    local -i removed_duplicates=0
    
    # 处理步骤
    local step_files=()
    step_files[0]="$file"
    
    # 步骤1: 删除空行和注释
    echo "✓ 步骤1: 删除空行和注释行..."
    local before_empty=$original_lines
    grep -v -e '^[[:space:]]*$' -e '^#' "${step_files[0]}" > "${temp_file}.step1"
    local after_empty=$(wc -l < "${temp_file}.step1" 2>/dev/null || echo 0)
    removed_empty=$((before_empty - after_empty))
    echo "  → 删除了 $removed_empty 个空行和注释行"
    step_files[1]="${temp_file}.step1"
    
    # 步骤2: 删除DOMAIN-REGEX规则
    echo "✓ 步骤2: 删除DOMAIN-REGEX规则..."
    local before_domain_regex=$after_empty
    grep -v '^DOMAIN-REGEX' "${step_files[1]}" > "${temp_file}.step2"
    local after_domain_regex=$(wc -l < "${temp_file}.step2" 2>/dev/null || echo 0)
    removed_domain_regex=$((before_domain_regex - after_domain_regex))
    echo "  → 删除了 $removed_domain_regex 个DOMAIN-REGEX规则"
    step_files[2]="${temp_file}.step2"
    
    # 步骤3: 处理IP-CIDR规则（修复统计问题）
    echo "✓ 步骤3: 处理IP-CIDR规则..."
    local before_ip_cidr=$after_domain_regex
    
    # 使用临时文件存储统计信息
    local stats_temp=$(mktemp)
    
    # 处理IP-CIDR规则并统计修改次数
    awk '
    BEGIN {
        no_resolve_added = 0
        ipv6_converted = 0
    }
    {
        original_line = $0
        line_modified = 0
        ipv6_converted = 0
        
        # 检查是否是IP-CIDR规则
        if ($0 ~ /^IP-CIDR,/) {
            # 检查是否是IPv6地址（包含冒号）
            if ($0 ~ /^IP-CIDR,[^,]*(:[^,]*)/) {
                # 替换为IP-CIDR6
                gsub(/^IP-CIDR,/, "IP-CIDR6,", $0)
                ipv6_converted++
                ipv6_converted_flag = 1
                line_modified = 1
            }
            
            # 检查是否已经有no-resolve
            if ($0 !~ /,no-resolve$/) {
                $0 = $0 ",no-resolve"
                no_resolve_added++
                line_modified = 1
            }
        }
        
        print $0
        
        # 如果行被修改，输出统计信息
        if (line_modified) {
            if (ipv6_converted_flag) {
                print "IPV6_CONVERTED" >> "/dev/stderr"
            } else {
                print "NO_RESOLVE_ADDED" >> "/dev/stderr"
            }
        }
    }
    END {
        # 输出总统计信息
        print "TOTAL_NO_RESOLVE:" no_resolve_added >> "/dev/stderr"
        print "TOTAL_IPV6_CONVERTED:" ipv6_converted >> "/dev/stderr"
    }
    ' "${step_files[2]}" > "${temp_file}.step3" 2> "$stats_temp"
    
    # 读取统计信息
    if [[ -f "$stats_temp" ]]; then
        modified_ip_cidr=$(grep -c "NO_RESOLVE_ADDED" "$stats_temp" 2>/dev/null || echo 0)
        modified_ip_cidr6=$(grep -c "IPV6_CONVERTED" "$stats_temp" 2>/dev/null || echo 0)
        
        # 也读取总数（从END块）
        local total_no_resolve=$(grep "TOTAL_NO_RESOLVE:" "$stats_temp" | cut -d: -f2)
        local total_ipv6_converted=$(grep "TOTAL_IPV6_CONVERTED:" "$stats_temp" | cut -d: -f2)
        
        # 使用总数（更准确）
        modified_ip_cidr=${total_no_resolve:-0}
        modified_ip_cidr6=${total_ipv6_converted:-0}
        
        rm -f "$stats_temp"
    fi
    
    local after_ip_cidr=$(wc -l < "${temp_file}.step3" 2>/dev/null || echo 0)
    echo "  → 修改了 $modified_ip_cidr 个IP-CIDR规则（添加了,no-resolve）"
    echo "  → 转换了 $modified_ip_cidr6 个IPv6规则为IP-CIDR6"
    step_files[3]="${temp_file}.step3"
    
    # 步骤4: 排序和去重
    echo "✓ 步骤4: 排序和去重..."
    local before_duplicates=$after_ip_cidr
    awk '!seen[$0]++' "${step_files[3]}" | sort > "${temp_file}.step4"
    local after_duplicates=$(wc -l < "${temp_file}.step4" 2>/dev/null || echo 0)
    removed_duplicates=$((before_duplicates - after_duplicates))
    echo "  → 删除了 $removed_duplicates 个重复行"
    step_files[4]="${temp_file}.step4"
    
    # 替换原文件
    if cp "${step_files[4]}" "$file"; then
        local final_info=($(_get_file_info "$file"))
        local final_size="${final_info[0]}"
        local final_lines="${final_info[1]}"
        local total_removed=$((original_lines - final_lines))
        
        echo ""
        echo "✅ 文件清理完成:"
        echo "  → 原始: ${original_lines}行, ${original_size}字节"
        echo "  → 最终: ${final_lines}行, ${final_size}字节"
        echo "  → 总共删除了 $total_removed 行"
        echo ""
        echo "📊 清理统计:"
        echo "  - 空行和注释: $removed_empty 行"
        echo "  - DOMAIN-REGEX: $removed_domain_regex 行"
        echo "  - IP-CIDR修改: $modified_ip_cidr 个规则添加了,no-resolve"
        echo "  - IP-CIDR6转换: $modified_ip_cidr6 个IPv6规则转换为IP-CIDR6"
        echo "  - 重复行: $removed_duplicates 行"
        
        # 清理临时文件
        rm -f "${temp_file}.step1" "${temp_file}.step2" "${temp_file}.step3" "${temp_file}.step4"
        return 0
    else
        echo "错误: 无法更新文件" >&2
        # 清理临时文件
        rm -f "${temp_file}.step1" "${temp_file}.step2" "${temp_file}.step3" "${temp_file}.step4"
        return 1
    fi
}

# ================ 主处理函数 ================

# 主入口函数
merge_rules() {
    local input="$1"
    local output="$2"
    
    # 输入验证
    if [[ -z "$input" || -z "$output" ]]; then
        echo "错误: 输入和输出参数不能为空" >&2
        return 1
    fi
    
    echo "=========================================="
    echo "开始合并规则"
    echo "输入: $input"
    echo "输出: $output"
    echo "=========================================="
    
    # 根据输入类型路由到相应的处理函数
    if [[ -f "$input" ]]; then
        if [[ -f "$output" ]]; then
            _handle_file_to_file "$input" "$output"
        elif [[ -d "$output" ]]; then
            _handle_file_to_directory "$input" "$output"
        else
            echo "错误: 不支持的输出类型" >&2
            return 1
        fi
    elif [[ -d "$input" ]]; then
        if [[ -f "$output" ]]; then
            _handle_directory_to_file "$input" "$output"
        elif [[ -d "$output" ]]; then
            _handle_directory_to_directory "$input" "$output"
        else
            echo "错误: 不支持的输出类型" >&2
            return 1
        fi
    elif _is_array "$input"; then
        if [[ -f "$output" ]]; then
            _handle_array_to_file "$input" "$output"
        else
            echo "错误: 数组只能合并到文件" >&2
            return 1
        fi
    else
        echo "错误: 不支持的输入类型" >&2
        return 1
    fi
}

# 1. 文件 -> 文件
_handle_file_to_file() {
    local input="$1"
    local output="$2"
    local input_basename=$(basename "$input")
    local output_basename=$(basename "$output")
    
    _log_step_start "1" "文件 -> 文件"
    echo "输入文件: $input"
    echo "输出文件: $output"
    
    # 验证输入文件
    _check_file_readable "$input" || return 1
    
    # 检查文件名是否相同
    if [[ "$input_basename" != "$output_basename" ]]; then
        echo "错误: 输入输出文件不同名" >&2
        return 1
    fi
    
    local start_time=$(_start_timer)
    
    # 执行内容追加
    if _safe_append "$input" "$output"; then
        local duration=$(_calculate_duration "$start_time")
        _log_step_end "内容追加" 0 "$duration"
        return 0
    else
        local duration=$(_calculate_duration "$start_time")
        _log_step_end "内容追加" 1 "$duration"
        return 1
    fi
}

# 2. 文件 -> 目录
_handle_file_to_directory() {
    local input="$1"
    local output="$2"
    local input_basename=$(basename "$input")
    local target_path="$output/$input_basename"
    
    _log_step_start "1" "文件 -> 目录" "2"
    echo "输入文件: $input"
    echo "目标目录: $output"
    
    # 验证输入和目标
    _check_file_readable "$input" || return 1
    _check_directory_writable "$output" || return 1
    
    local start_time=$(_start_timer)
    local operation_result=0
    
    # 确定操作类型
    if [[ -f "$target_path" ]]; then
        echo "目标文件已存在，执行内容合并"
        _safe_append "$input" "$target_path" || operation_result=1
    else
        echo "目标文件不存在，执行复制操作"
        _safe_copy "$input" "$target_path" || operation_result=1
    fi
    
    local duration=$(_calculate_duration "$start_time")
    _log_step_end "文件处理" "$operation_result" "$duration"
    
    # 清理目标文件
    if [[ $operation_result -eq 0 ]]; then
        _log_step_start "2" "文件内容清理" "2"
        _clean_file_content "$target_path"
        local clean_result=$?
        _log_step_end "内容清理" "$clean_result"
    fi
    
    return $operation_result
}

# 3. 目录 -> 文件
_handle_directory_to_file() {
    local input="$1"
    local output="$2"
    
    _log_step_start "1" "目录 -> 文件"
    echo "输入目录: $input"
    echo "输出文件: $output"
    
    # 验证输出目录
    _ensure_directory "$(dirname "$output")" || return 1
    
    # 检查目录是否为空
    if [[ -z "$(find "$input" -type f 2>/dev/null | head -1)" ]]; then
        echo "警告: 输入目录为空"
        touch "$output"
        echo "已创建空文件"
        return 0
    fi
    
    local start_time=$(_start_timer)
    
    # 清空输出文件
    _clear_file "$output" || return 1
    
    # 合并所有文件内容
    local success_count=0
    while IFS= read -r -d '' file; do
        if _safe_append "$file" "$output"; then
            ((success_count++))
        fi
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    local duration=$(_calculate_duration "$start_time")
    
    if [[ $success_count -gt 0 ]]; then
        _log_step_end "目录合并" 0 "$duration"
        _log_summary "目录合并" "成功合并文件: $success_count个"
        return 0
    else
        _log_step_end "目录合并" 1 "$duration"
        return 1
    fi
}

# 4. 目录 -> 目录
_handle_directory_to_directory() {
    local input="$1"
    local output="$2"
    
    _log_step_start "1" "目录 -> 目录"
    echo "输入目录: $input"
    echo "输出目录: $output"
    
    # 验证目录
    _check_directory_writable "$input" || return 1
    _check_directory_writable "$output" || return 1
    
    local start_time=$(_start_timer)
    local processed_count=0 success_count=0
    
    # 处理目录中的所有文件
    while IFS= read -r -d '' file; do
        ((processed_count++))
        local rel_path="${file#$input/}"
        local target_file="$output/$rel_path"
        
        _ensure_directory "$(dirname "$target_file")" || continue
        
        if [[ -f "$target_file" ]]; then
            # 合并到现有文件
            if _safe_append "$file" "$target_file"; then
                ((success_count++))
            fi
        else
            # 复制到新位置
            if _safe_copy "$file" "$target_file"; then
                ((success_count++))
            fi
        fi
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    local duration=$(_calculate_duration "$start_time")
    
    if [[ $success_count -gt 0 ]]; then
        _log_step_end "目录处理" 0 "$duration"
        _log_summary "目录处理" \
            "处理文件总数: $processed_count" \
            "成功处理: $success_count" \
            "失败: $((processed_count - success_count))"
        return 0
    else
        _log_step_end "目录处理" 1 "$duration"
        return 1
    fi
}


# 5. 数组 -> 文件
_handle_array_to_file() {
    local input_var="$1"
    local output="$2"
    
    # 获取数组内容
    local array_files
    array_files=($(_get_array_contents "$input_var")) || {
        echo "ERROR: 无法获取数组内容"
        return 1
    }
    
    # 清空输出文件
    if > "$output"; then
        echo "✓ 输出文件清空完成"
    else
        echo "ERROR: 无法准备输出文件" >&2
        return 1
    fi

    echo ""
    
    # 遍历数组中的每个文件
    for i in "${!array_files[@]}"; do
        # 追加内容
        cat "${array_files[$i]}" >> "$output"
    done
    
    if _clean_file_content "$output"; then
        echo "✓ 文件内容清理完成"
    else
        echo "警告: 文件内容清理过程中出现问题" >&2
    fi
}
