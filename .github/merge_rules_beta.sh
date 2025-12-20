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

# 安全追加文件内容
_safe_append() {
    local source="$1"
    local target="$2"
    
    if _check_file_readable "$source"; then
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
    return 1
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

# 安全获取数组内容
_get_array_contents() {
    local array_name="$1"
    
    if ! _is_array "$array_name"; then
        echo "错误: '$array_name' 不是数组" >&2
        return 1
    fi
    
    local array_contents
    eval "array_contents=(\"\${$array_name[@]}\")"
    printf '%s\n' "${array_contents[@]}"
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
    local -i removed_duplicates=0
    
    # 处理步骤
    local step_files=()
    step_files[0]="$file"
    
    # 步骤1: 删除空行和注释
    grep -v -e '^[[:space:]]*$' -e '^#' "${step_files[0]}" > "${temp_file}.step1"
    removed_empty=$((original_lines - $(wc -l < "${temp_file}.step1" 2>/dev/null || echo 0)))
    step_files[1]="${temp_file}.step1"
    
    # 步骤2: 删除DOMAIN-REGEX规则
    grep -v '^DOMAIN-REGEX' "${step_files[1]}" > "${temp_file}.step2"
    removed_domain_regex=$(( $(wc -l < "${step_files[1]}") - $(wc -l < "${temp_file}.step2") ))
    step_files[2]="${temp_file}.step2"
    
    # 步骤3: 处理IP-CIDR规则
    awk '
    {
        if (/^IP-CIDR,/) {
            # 处理IPv6
            if (/^IP-CIDR,[^,]*(:[^,]*)/) {
                sub(/^IP-CIDR,/, "IP-CIDR6,")
                ipv6_count++
            }
            # 添加no-resolve
            if (!/,no-resolve$/) {
                $0 = $0 ",no-resolve"
                noresolve_count++
            }
        }
        print
    }
    ' "${step_files[2]}" > "${temp_file}.step3"
    step_files[3]="${temp_file}.step3"
    
    # 步骤4: 排序和去重
    awk '!seen[$0]++' "${step_files[3]}" | sort > "${temp_file}.step4"
    removed_duplicates=$(( $(wc -l < "${step_files[3]}") - $(wc -l < "${temp_file}.step4") ))
    step_files[4]="${temp_file}.step4"
    
    # 替换原文件
    if cp "${step_files[4]}" "$file"; then
        local final_info=($(_get_file_info "$file"))
        local final_size="${final_info[0]}"
        local final_lines="${final_info[1]}"
        
        echo "✅ 文件清理完成:"
        echo "  → 原始: ${original_lines}行, ${original_size}字节"
        echo "  → 最终: ${final_lines}行, ${final_size}字节"
        echo ""
        echo "📊 清理统计:"
        echo "  - 空行和注释: $removed_empty 行"
        echo "  - DOMAIN-REGEX: $removed_domain_regex 行"
        echo "  - IP-CIDR处理: $modified_ip_cidr 个规则添加了 ,no-resolve"
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

# 5. 数组 -> 文件（调试版）
_handle_array_to_file() {
    local input_var="$1"
    local output="$2"
    
    echo "=========================================="
    echo "开始处理: 数组 → 文件"
    echo "输入数组变量: $input_var"
    echo "输出文件路径: $output"
    echo "=========================================="
    echo ""
    
    # 明确声明整数变量
    local -i success_count=0
    local -i error_count=0
    local -i skip_count=0
    local -i array_length=0
    
    # ========== 1. 展开数组 ==========
    echo "[步骤1/4] 展开数组..."
    echo "------------------------------------------"
    
    # 验证输入是否为数组变量
    echo "✓ 检查输入变量 '$input_var' 是否为数组..."
    if ! declare -p "$input_var" 2>/dev/null | grep -q '^declare -a'; then
        echo "错误: '$input_var' 不是有效的数组变量" >&2
        return 1
    fi
    echo "✓ 输入变量是有效的数组"
    
    # 安全地获取数组内容
    echo "✓ 获取数组内容..."
    local array_files
    eval "array_files=(\"\${$input_var[@]}\")"
    array_length=${#array_files[@]}
    echo "✓ 数组包含 $array_length 个元素"
    
    # 检查数组是否为空
    if [[ $array_length -eq 0 ]]; then
        echo "警告: 输入数组为空"
        # 创建空输出文件（如果不存在）
        if [[ ! -f "$output" ]]; then
            echo "✓ 创建空输出文件..."
            if touch "$output"; then
                echo "✓ 已创建空文件: $output"
                return 0
            else
                echo "错误: 无法创建空文件" >&2
                return 1
            fi
        else
            echo "✓ 输出文件已存在，无需修改"
            return 0
        fi
    fi
    
    # 显示数组内容
    echo "✓ 数组内容预览:"
    for i in "${!array_files[@]}"; do
        echo "  [$((i+1))/$array_length] ${array_files[$i]}"
    done
    echo ""
    
    # ========== 2. 准备输出文件 ==========
    echo "[步骤2/4] 准备输出文件..."
    echo "------------------------------------------"
    
    # 确保输出目录存在
    local output_dir=$(dirname "$output")
    echo "✓ 检查输出目录: $output_dir"
    
    if [[ ! -d "$output_dir" ]]; then
        echo "✓ 创建输出目录..."
        if mkdir -p "$output_dir"; then
            echo "✓ 目录创建成功: $output_dir"
        else
            echo "错误: 无法创建输出目录" >&2
            return 1
        fi
    else
        echo "✓ 输出目录已存在"
    fi
    
    # 检查输出文件权限
    echo "✓ 检查输出文件权限..."
    if [[ -f "$output" ]]; then
        if [[ -w "$output" ]]; then
            echo "✓ 输出文件存在且可写"
        else
            echo "错误: 输出文件存在但不可写" >&2
            return 1
        fi
    else
        echo "✓ 输出文件不存在，将创建新文件"
    fi
    
    # 清空或创建输出文件
    echo "✓ 准备输出文件内容..."
    if > "$output"; then
        echo "✓ 输出文件准备完成"
    else
        echo "错误: 无法准备输出文件" >&2
        return 1
    fi
    echo ""
    
    # ========== 3. 合并文件内容 ==========
    echo "[步骤3/4] 开始合并文件内容..."
    echo "------------------------------------------"
    
    # 遍历数组中的每个文件路径
    for i in "${!array_files[@]}"; do
        local file_path="${array_files[$i]}"
        local current_file=$((i+1))
        
        echo "✓ 处理文件 [$current_file/$array_length]: $file_path"
        
        # 详细检查文件状态
        echo "  ├─ 检查文件是否存在..."
        if [[ ! -e "$file_path" ]]; then
            echo "  ├─ ✗ 文件路径不存在，跳过"
            ((skip_count++))
            echo "  └─ [跳过]"
            echo ""
            continue
        fi
        
        echo "  ├─ 检查是否为普通文件..."
        if [[ ! -f "$file_path" ]]; then
            echo "  ├─ ✗ 不是普通文件（可能是目录），跳过"
            ((skip_count++))
            echo "  └─ [跳过]"
            echo ""
            continue
        fi
        
        echo "  ├─ 检查文件可读性..."
        if [[ ! -r "$file_path" ]]; then
            echo "  ├─ ✗ 文件不可读，跳过"
            ((skip_count++))
            echo "  └─ [跳过]"
            echo ""
            continue
        fi
        
        echo "  ├─ 检查文件大小..."
        local file_size=$(wc -c < "$file_path" 2>/dev/null || echo 0)
        echo "  ├─ 文件大小: $file_size
}
