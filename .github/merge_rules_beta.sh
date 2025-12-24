#!/bin/bash

# 判断输入类型 → 判断输出类型
# 一共为 9 种可能性, 目前只能实现以下 5 种
#
# 2025-12-20 已经验证的是：文件 → 目录、数组 → 文件
#    输入 → 输出
# 1. 文件 → 文件（追加内容）
# 2. 文件 → 目录（复制/合并）
# 3. 目录 → 文件（合并内容）
# 4. 目录 → 目录（合并同名文件）
# 5. 数组 → 文件（写入内容）


# Github Action yaml 配置中的环境变量转化为数组
# Github Action 配置中的 env 在传递过程中, 会存在最后一个值是空的
# 这里最佳的写法应该是判断空值, 直接删掉
# 而不是向我这样直接删掉最后一个值
# 因为在写 yaml 配置的时候难免会存在注释或者空行, 都会被纳入其中
action_env_to_array_fix() {
    local input_env="$1"
    local output_array_name="$2"
    local base_dir="${3:-}"
    
    # 使用 nameref 声明一个对目标数组的引用
    local -n output_array="$output_array_name"
    
    # 清空目标数组，避免之前的内容干扰
    output_array=()
    
    # 将环境变量的值按行读入数组引用
    readarray -t output_array <<< "$input_env"
    
    # 如果数组不为空，则删除最后一个元素
    if [ ${#output_array[@]} -gt 0 ]; then
        unset 'output_array[-1]'
    fi
    
    if [[ -n "$base_dir" ]]; then
        for index in "${!output_array[@]}"; do
            output_array["$index"]="$base_dir/${output_array[$index]}"
        done
    fi
}



merge_rules() {
    local input="$1"
    local output="$2"
    
	trap 'echo "错误发生在: $BASH_COMMAND"; exit 1' ERR
    
	# 输入验证
    if [[ -z "$input" || -z "$output" ]]; then
        echo "错误: 输入和输出参数不能为空" >&2
        return 1
    fi
	
    if [[ -f "$input" ]]; then
	    echo "输入类型: 文件"
        if [[ -f "$output" ]]; then
            _handle_file_to_file "$input" "$output"
        elif [[ -d "$output" ]]; then
            _handle_file_to_directory "$input" "$output"
        elif _is_array "$output"; then
            _handle_file_to_array "$input" "$output"         
        else
            echo "错误: 不支持的输出类型" >&2
            return 1
        fi
    # 输入类型：目录
    elif [[ -d "$input" ]]; then
	    echo "输入类型: 目录"
        if [[ -f "$output" ]]; then
            _handle_directory_to_file "$input" "$output"
        elif [[ -d "$output" ]]; then
            _handle_directory_to_directory "$input" "$output"
        elif _is_array "$output"; then
            echo "输出类型: 数组"
            _handle_directory_to_array "$input" "$output"
        else
            echo "错误: 不支持的输出类型" >&2
            return 1
        fi

    # 输入类型：数组
    # 输出目前只定义了为文件
    elif _is_array "$input"; then
        echo "输入类型：数组"
        if [[ -f "$output" ]]; then
            echo ""
            echo "输出类型：文件"
            _handle_array_to_file "$input" "$output"
        else
            echo "识别到没有创建输出文件"
            if touch "$output"; then
                echo "已经创建输出文件：$output"
                echo "开始合并文件"
                _handle_array_to_file "$input" "$output"
            else
                echo "ERROR：无法创建输出文件"
            fi
        fi

    else
        echo "错误: 输入类型不被支持 - $input" >&2
        return 1
    fi
}

# ========== 辅助函数 ==========

# 判断是否为数组
_is_array() {
    local input="$1"
	
    if ! declare -p "$input" 2>/dev/null | grep -q '^declare -a'; then
	    echo "✗ 错误: '$input' 不是有效的数组变量" >&2
	    return 1
	fi
}





# ========== 具体处理函数 ==========

# 1. 文件 -> 文件：追加内容（需同名）
_handle_file_to_file() {
    local input="$1"
    local output="$2"
    local input_basename=$(basename "$input")
    local output_basename=$(basename "$output")
    
    echo "处理: 文件 -> 文件"
    echo "输入文件: $input"
    echo "输出文件: $output"
    
    # 安全检查：确保输入文件存在且可读
    if [[ ! -r "$input" ]]; then
        echo "错误: 输入文件不存在或不可读" >&2
        return 1
    fi
    
    # 判断是否同名文件
    if [[ "$input_basename" == "$output_basename" ]]; then
        echo "文件同名，执行内容追加操作"
        
        # 检查是否为同一个文件（相同路径）
        if [[ "$(realpath "$input")" == "$(realpath "$output")" ]]; then
            echo "警告: 输入和输出是同一个文件，将导致内容重复" >&2
        fi
        
        # 执行内容追加
        if cat "$input" >> "$output"; then
            local input_size=$(wc -c < "$input")
            local output_size=$(wc -c < "$output")
            echo "内容追加成功"
            echo "输入文件大小: $input_size 字节"
            echo "输出文件大小: $output_size 字节"
            return 0
        else
            echo "错误: 内容追加失败" >&2
            return 1
        fi
        
    else
        echo "错误: 输入输出文件不同名，不支持此操作" >&2
        echo "输入文件名: $input_basename"
        echo "输出文件名: $output_basename"
        return 1
    fi
}

# 2. 文件 -> 目录
_handle_file_to_directory() {
    local input="$1"
    local output="$2"
    local input_basename=$(basename "$input")
    local target_path="$output/$input_basename"
    
    echo "=========================================="
    echo "处理: 文件 -> 目录"
    echo "输入文件: $input"
    echo "目标目录: $output"
    echo "=========================================="
    echo ""
    
    # 输入验证
    echo "✓ 验证输入文件..."
    if [[ ! -f "$input" ]] || [[ ! -r "$input" ]]; then
        echo "✗ 错误: 输入文件不存在或不可读" >&2
        return 1
    fi
    
    echo "✓ 验证目标目录..."
    if [[ ! -d "$output" ]] || [[ ! -w "$output" ]]; then
        echo "✗ 错误: 目标目录不存在或不可写" >&2
        return 1
    fi
    
    # 确定操作类型
    local operation=""
    if [[ -f "$target_path" ]]; then
        operation="merge"
        echo "✓ 目标文件已存在，执行内容合并操作"
    else
        operation="copy"
        echo "✓ 目标文件不存在，执行复制操作"
    fi
    
    # 执行操作
    case "$operation" in
        "copy")
            echo "✓ 开始复制文件..."
            if cp "$input" "$target_path"; then
                echo "✓ 文件复制成功"
            else
                echo "✗ 错误: 文件复制失败" >&2
                return 1
            fi
            ;;
        "merge")
            echo "✓ 开始合并文件内容..."
            # 检查是否为同一个文件
            if [[ "$(realpath "$input")" == "$(realpath "$target_path")" ]]; then
                echo "⚠️ 警告: 输入文件和目标文件是同一个文件" >&2
            fi
            
            if cat "$input" >> "$target_path"; then
                local input_size=$(wc -c < "$input")
                local target_size=$(wc -c < "$target_path")
                echo "✓ 内容合并成功"
                echo "  → 输入文件: $input_size 字节"
                echo "  → 目标文件: $target_size 字节"
            else
                echo "✗ 错误: 内容合并失败" >&2
                return 1
            fi
            ;;
        *)
            echo "✗ 错误: 未知操作类型" >&2
            return 1
            ;;
    esac
    
    # 调用清理函数（确保在所有操作路径中都执行）
    echo ""
    echo "=========================================="
    echo "开始清理目标文件内容..."
    echo "------------------------------------------"
    
    if _clean_file_content "$target_path"; then
        echo "✅ 目标文件内容清理完成"
        
        # 显示最终文件信息
        if [[ -f "$target_path" ]]; then
            local final_size=$(wc -c < "$target_path")
            local final_lines=$(wc -l < "$target_path")
            echo ""
            echo "最终文件信息:"
            echo "✓ 文件路径: $target_path"
            echo "✓ 文件大小: $final_size 字节"
            echo "✓ 文件行数: $final_lines 行"
        fi
        
        return 0
    else
        echo "⚠️ 警告: 目标文件内容清理过程中出现警告" >&2
        return 1
    fi
}



# 3. 文件 -> 数组
_handle_file_to_array() {
    local input="$1"
    local output="$2"
    echo "错误: 文件不能合并到数组，此功能暂不支持" >&2
    return 1
}

# 4. 目录 -> 文件
_handle_directory_to_file() {
    local input="$1"
    local output="$2"
    
    echo "处理: 目录 -> 文件"
    echo "输入目录: $input"
    echo "输出文件: $output"
    
    # 检查输入目录是否为空
    if [[ -z "$(ls -A "$input" 2>/dev/null)" ]]; then
        echo "警告: 输入目录为空，没有内容可合并" >&2
        # 创建空文件或保持原文件不变
        if [[ ! -f "$output" ]]; then
            touch "$output"
            echo "已创建空文件: $output"
        fi
        return 0
    fi
    
    # 检查输出文件的目录是否可写
    local output_dir=$(dirname "$output")
    if [[ ! -w "$output_dir" ]]; then
        echo "错误: 输出文件所在目录不可写" >&2
        return 1
    fi
    
    # 创建或清空输出文件
    > "$output"
    echo "已准备输出文件: $output"
    
    # 统计变量
    local file_count=0
    local merged_count=0
    local error_count=0
    
    echo "开始合并目录内容到文件..."
    
    # 使用 find 命令递归查找所有文件
    while IFS= read -r -d '' file; do
        ((file_count++))
        
        # 跳过目录本身和特殊文件
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        echo "处理文件: $(basename "$file")"
        
        # 将文件内容追加到输出文件
        if cat "$file" >> "$output" 2>/dev/null; then
            ((merged_count++))
            echo "  √ 合并成功"
        else
            ((error_count++))
            echo "  × 合并失败: $file"
        fi
        
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    # 显示合并结果
    echo ""
    echo "合并完成:"
    echo "  - 找到文件总数: $file_count"
    echo "  - 成功合并数: $merged_count"
    echo "  - 合并失败数: $error_count"
    
    if [[ $merged_count -gt 0 ]]; then
        local output_size=$(wc -c < "$output" 2>/dev/null || echo 0)
        echo "  - 输出文件大小: $output_size 字节"
        echo "合并操作完成"
        return 0
    else
        echo "警告: 没有成功合并任何文件" >&2
        return 1
    fi
}

#######################################################################
#============================ 目录 -> 目录 ============================#
# 4. 目录 -> 目录（最简化版）
_handle_directory_to_directory() {
    local input="$1"
    local output="$2"
    
    echo "处理目录: $input → $output"
    
    # 基本检查
    [[ -d "$input" && -r "$input" ]] || {
        echo "错误: 输入目录无效" >&2
        return 1
    }
    
    # 确保输出目录存在
    mkdir -p "$output" || return 1
    
    # 使用简单的 find 和循环
    local -i count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((count++))
        
        local rel_path="${file#$input/}"
        local target="$output/$rel_path"
        local target_dir=$(dirname "$target")
        
        echo "[$count] 处理: $rel_path"
        
        # 创建目标目录
        mkdir -p "$target_dir" || continue
        
        # 复制或追加文件
        if [[ -f "$target" ]]; then
            # 追加内容
            [[ $(tail -c 1 "$target") != $'\n' ]] && echo "" >> "$target"
            cat "$file" >> "$target" && echo "  ✓ 追加成功"
        else
            # 复制文件
            cp "$file" "$target" && echo "  ✓ 复制成功"
        fi
    done < <(find "$input" -type f)
    
    echo "完成: 处理了 $count 个文件"
    return 0
}

#######################################################################
#######################################################################

#######################################################################
#============================ 目录 -> 数组 ============================#
_handle_directory_to_array() {
    local input="$1"
    local output="$2"
    echo "错误: 目录不能合并到数组，此功能暂不支持" >&2
    return 1
}
#######################################################################
#######################################################################


#######################################################################
#============================ 数组 -> 文件 ============================#
_handle_array_to_file() {
    local input_var="$1"    # 输入数组
    local output="$2"       # 输出文件
    
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
    
    # 获取数组内容
    echo "获取数组内容"
    local array_files
    eval "array_files=(\"\${$input_var[@]}\")"
    array_length=${#array_files[@]}
    echo "数组包含 $array_length 个元素"
    
    # 检查数组是否为空
    if [[ $array_length -eq 0 ]]; then
        echo "! 警告: 输入数组为空"
        # 创建空输出文件（如果不存在）
        if [[ ! -f "$output" ]]; then
            echo "✓ 创建空输出文件..."
            if touch "$output"; then
                echo "✓ 已创建空文件: $output"
                return 0
            else
                echo "✗ 错误: 无法创建空文件" >&2
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
    echo "[步骤2/3] 准备输出文件..."
    echo "------------------------------------------"
    
    # 清空或创建输出文件
    if echo "" > "$output"; then
        echo "✓ 输出文件准备完成"
    else
        echo "✗ 错误: 无法准备输出文件" >&2
        return 1
    fi
    echo ""
    
    # ========== 3. 合并文件内容 ==========
    echo "[步骤3/3] 开始合并文件内容..."
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
        echo "  ├─ 文件大小: $file_size 字节"
        
        if [[ $file_size -eq 0 ]]; then
            echo "  ├─ ! 文件为空，跳过"
            ((skip_count++))
            echo "  └─ [跳过]"
            echo ""
            continue
        fi
        
        # 开始追加内容
        echo "  ├─ 开始追加文件内容到输出文件..."
        echo "  ├─ 执行命令: cat \"$file_path\" >> \"$output\""
        
        # 使用time命令计时
        local start_time=$(date +%s.%N)
        
        # 尝试追加内容
        if cat "$file_path" >> "$output" 2>&1; then
            echo "" >> "$output"
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            echo "  ├─ ✓ 追加成功 (耗时: ${duration}秒)"
            # 使用安全的整数递增
            success_count=$((success_count + 1))
        else
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            echo "  ├─ ✗ 追加失败 (耗时: ${duration}秒)" >&2
            error_count=$((error_count + 1))
        fi
        
        echo "  └─ [文件 $current_file/$array_length 处理完成]"
        echo ""
        
        # 添加小延迟，避免过快处理
        sleep 0.1
    done
    
    # ========== 4. 结果统计 ==========
    echo "=========================================="
    echo "合并完成总结:"
    echo "------------------------------------------"
    echo "✓ 数组文件总数: $array_length"
    echo "✓ 成功合并: $success_count"
    echo "! 跳过文件: $skip_count"
    echo "✗ 合并失败: $error_count"
    
    # 显示输出文件信息
    if [[ -f "$output" ]]; then
        local output_size=$(wc -c < "$output" 2>/dev/null || echo 0)
        local output_lines=$(wc -l < "$output" 2>/dev/null || echo 0)
        echo ""
        echo "输出文件信息:"
        echo "✓ 文件路径: $output"
        echo "✓ 文件大小: $output_size 字节"
        echo "✓ 文件行数: $output_lines 行"
    fi
    
    echo ""

	# ========== 5. 文件内容清理 ==========
	echo "[步骤4/4] 开始文件内容清理..."
	echo "------------------------------------------"
    
	if [[ -f "$output" ]] && [[ -s "$output" ]]; then
	    _clean_file_content "$output"
	    local clean_result=$?
        
	    if [[ $clean_result -eq 0 ]]; then
            echo "✅ 文件内容清理完成"
	    else
            echo "⚠️ 文件内容清理过程中出现警告"
	    fi
	else
        echo "! 输出文件为空或不存在，跳过清理步骤"
	fi
    
    echo ""


	
    # 返回结果
    if [[ $success_count -gt 0 ]]; then
        echo "✅ 数组合并操作成功完成"
        return 0
    elif [[ $skip_count -eq $array_length ]] && [[ $array_length -gt 0 ]]; then
        echo "⚠️ 警告: 所有文件都被跳过，但操作完成"
        return 0
    elif [[ $error_count -gt 0 ]]; then
        echo "❌ 错误: 合并过程中发生错误" >&2
        return 1
    else
        echo "✅ 操作完成"
        return 0
    fi
}

# 文件内容清理函数（修复版）
_clean_file_content() {
    local file="$1"
    local temp_file=$(mktemp) || {
        echo "✗ 错误: 无法创建临时文件" >&2
        return 1
    }
    
    echo "✓ 开始清理文件内容: $file"
    
    # 备份原始文件信息
    local original_size=$(wc -c < "$file")
    local original_lines=$(wc -l < "$file")
    
    echo "✓ 原始文件: $original_lines 行, $original_size 字节"
    
    # 统计变量
    local -i removed_empty=0
    local -i removed_comments=0
    local -i removed_domain_regex=0
    local -i modified_ip_cidr=0
    local -i modified_ip_cidr6=0
    local -i removed_duplicates=0
    
    # 第一步：删除空行和仅含空格的行
    echo "✓ 步骤1: 删除空行和仅含空格的行..."
    local before_empty=$original_lines
    grep -v '^[[:space:]]*$' "$file" > "${temp_file}.step1"
    local after_empty=$(wc -l < "${temp_file}.step1" 2>/dev/null || echo 0)
    removed_empty=$((before_empty - after_empty))
    echo "  → 删除了 $removed_empty 个空行"
    
    # 第二步：删除行首行尾空格
    echo "✓ 步骤2: 删除行首行尾空格..."
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "${temp_file}.step1" > "${temp_file}.step2"
    
    # 第三步：删除注释行（以#开头的行）
    echo "✓ 步骤3: 删除注释行..."
    local before_comments=$after_empty
    grep -v '^#' "${temp_file}.step2" > "${temp_file}.step3"
    local after_comments=$(wc -l < "${temp_file}.step3" 2>/dev/null || echo 0)
    removed_comments=$((before_comments - after_comments))
    echo "  → 删除了 $removed_comments 个注释行"
    
    # 第四步：删除所有以 DOMAIN-REGEX 开头的行
    echo "✓ 步骤4: 删除所有以 DOMAIN-REGEX 开头的行..."
    local before_domain_regex=$after_comments
    grep -v '^DOMAIN-REGEX' "${temp_file}.step3" > "${temp_file}.step4"
    local after_domain_regex=$(wc -l < "${temp_file}.step4" 2>/dev/null || echo 0)
    removed_domain_regex=$((before_domain_regex - after_domain_regex))
    echo "  → 删除了 $removed_domain_regex 个 DOMAIN-REGEX 规则"
    
    # 第五步：处理 IP-CIDR 和 IP-CIDR6 规则（修复版本）
    echo "✓ 步骤5: 处理 IP-CIDR 和 IP-CIDR6 规则..."
    local before_ip_cidr=$after_domain_regex
    
    # 使用 awk 处理 IP-CIDR 规则
    awk '
    {
        # 检查是否是 IP-CIDR 规则
        if ($0 ~ /^IP-CIDR,/) {
            # 检查是否是 IPv6 地址（包含冒号）
            if ($0 ~ /^IP-CIDR,[^,]*(:[^,]*)/) {
                # 替换为 IP-CIDR6
                sub(/^IP-CIDR,/, "IP-CIDR6,", $0)
                ipv6_converted++
            }
            
            # 检查是否已经有 no-resolve
            if ($0 !~ /,no-resolve$/) {
                $0 = $0 ",no-resolve"
                no_resolve_added++
            }
        }
        
        print $0
    }
    END {
        # 输出统计信息
        print "AWK_STATS: " no_resolve_added " " ipv6_converted > "/dev/stderr"
    }
    ' "${temp_file}.step4" > "${temp_file}.step5" 2> "${temp_file}.awk_stats"
    
    # 从 awk 输出中提取统计信息
    if [[ -f "${temp_file}.awk_stats" ]]; then
        local awk_stats=$(grep "AWK_STATS:" "${temp_file}.awk_stats" | cut -d' ' -f2-)
        local no_resolve_added=$(echo "$awk_stats" | cut -d' ' -f1)
        local ipv6_converted=$(echo "$awk_stats" | cut -d' ' -f2)
        
        no_resolve_added=${no_resolve_added:-0}
        ipv6_converted=${ipv6_converted:-0}
        
        modified_ip_cidr=$no_resolve_added
        modified_ip_cidr6=$ipv6_converted
        
        rm -f "${temp_file}.awk_stats"
    fi
    
    local after_ip_cidr=$(wc -l < "${temp_file}.step5" 2>/dev/null || echo 0)
    echo "  → 修改了 $modified_ip_cidr 个 IP-CIDR 规则（添加 ,no-resolve）"
    echo "  → 转换了 $modified_ip_cidr6 个 IPv6 规则为 IP-CIDR6"
    
    # 第六步：使用 awk 进行排序（按优先级）
    echo "✓ 步骤6: 使用 awk 进行排序..."
    awk '
    {
        # 为每行添加排序键（按指定优先级）
        if ($0 ~ /^DOMAIN,/) {
            # DOMAIN 规则 - 最高优先级
            sort_key = "1_" $0
        }
        else if ($0 ~ /^DOMAIN-SUFFIX,/) {
            # DOMAIN-SUFFIX 规则 - 第二优先级
            sort_key = "2_" $0
        }
        else if ($0 ~ /^DOMAIN-KEYWORD,/) {
            # DOMAIN-KEYWORD 规则 - 第三优先级
            sort_key = "3_" $0
        }
        else if ($0 ~ /^IP-CIDR,/) {
            # IP-CIDR 规则 - 第四优先级
            sort_key = "4_" $0
        }
        else if ($0 ~ /^IP-CIDR6,/) {
            # IP-CIDR6 规则 - 第五优先级
            sort_key = "5_" $0
        }
        else {
            # 其他规则 - 最低优先级
            sort_key = "6_" $0
        }
        
        # 存储行和排序键
        lines[sort_key] = $0
    }
    END {
        # 按排序键排序并输出
        n = asorti(lines, sorted)
        for (i = 1; i <= n; i++) {
            print lines[sorted[i]]
        }
    }
    ' "${temp_file}.step5" > "${temp_file}.step6"
    
    echo "  → 已完成规则分类排序（按优先级）"
    
    # 第七步：去重（保留顺序）
    echo "✓ 步骤7: 去重处理..."
    local before_duplicates=$after_ip_cidr
    awk '!seen[$0]++' "${temp_file}.step6" > "${temp_file}.step7"
    local after_duplicates=$(wc -l < "${temp_file}.step7" 2>/dev/null || echo 0)
    removed_duplicates=$((before_duplicates - after_duplicates))
    echo "  → 删除了 $removed_duplicates 个重复行"
    
    # 检查清理后的文件是否为空
    if [[ ! -s "${temp_file}.step7" ]]; then
        echo "⚠️ 警告: 清理后文件为空，保留原始内容"
        cp "$file" "$temp_file"
    else
        cp "${temp_file}.step7" "$temp_file"
    fi
    
    # 替换原文件
    if mv "$temp_file" "$file"; then
        local final_size=$(wc -c < "$file")
        local final_lines=$(wc -l < "$file")
        local total_removed=$((original_lines - final_lines))
        
        echo ""
        echo "✅ 文件清理完成:"
        echo "  → 原始: $original_lines 行, $original_size 字节"
        echo "  → 最终: $final_lines 行, $final_size 字节"
        echo "  → 总共删除了 $total_removed 行"
        echo ""
        echo "📊 清理统计:"
        echo "  - 空行: $removed_empty 行"
        echo "  - 注释: $removed_comments 行"
        echo "  - DOMAIN-REGEX: $removed_domain_regex 行"
        echo "  - IP-CIDR 修改: $modified_ip_cidr 个规则添加了 ,no-resolve"
        echo "  - IP-CIDR6 转换: $modified_ip_cidr6 个 IPv6 规则转换为 IP-CIDR6"
        echo "  - 排序: 已按优先级排序 (DOMAIN > DOMAIN-SUFFIX > DOMAIN-KEYWORD > IP-CIDR > IP-CIDR6 > 其他)"
        echo "  - 重复: $removed_duplicates 行"
        echo "  - 空格: 已清理所有行首行尾空格"
        
        # 清理临时文件
        rm -f "${temp_file}.step1" "${temp_file}.step2" "${temp_file}.step3" 
        rm -f "${temp_file}.step4" "${temp_file}.step5" "${temp_file}.step6" "${temp_file}.step7"
        
        return 0
    else
        echo "✗ 错误: 无法替换原文件" >&2
        # 清理临时文件
        rm -f "$temp_file" "${temp_file}.step1" "${temp_file}.step2" "${temp_file}.step3"
        rm -f "${temp_file}.step4" "${temp_file}.step5" "${temp_file}.step6" "${temp_file}.step7"
        return 1
    fi
}

##################################################################
##################################################################
# 8. 数组 -> 目录
_handle_array_to_directory() {
    local input="$1"
    local output="$2"
    echo "错误: 数组不能合并到目录，此功能暂不支持" >&2
    return 1
}

# 9. 数组 -> 数组
_handle_array_to_array() {
    local input="$1"
    local output="$2"
    echo "错误: 数组不能合并到数组，此功能暂不支持" >&2
    return 1
}
