#!/bin/bash

merge_rules() {
    local input="$1"
    local output="$2"
    
    # 输入验证
    if [[ -z "$input" || -z "$output" ]]; then
        echo "错误: 输入和输出参数不能为空" >&2
        return 1
    fi

	# 显示输入参数的类型信息
    echo "调试: 输入参数类型检查:"
    echo "  -f 检查: $([[ -f "$input" ]] && echo "是文件" || echo "不是文件")"
    echo "  -d 检查: $([[ -d "$input" ]] && echo "是目录" || echo "不是目录")"
    echo "  数组检查: $(_is_array "$input" && echo "是数组" || echo "不是数组")"

	# 显示输出参数的类型信息
    echo "调试: 输出参数类型检查:"
    echo "  -f 检查: $([[ -f "$output" ]] && echo "是文件" || echo "不是文件")"
    echo "  -d 检查: $([[ -d "$output" ]] && echo "是目录" || echo "不是目录")"
    echo "  数组检查: $(_is_array "$output" && echo "是数组" || echo "不是数组")"
	
	# 判断输入类型 → 判断输出类型
	# 一共为 9 种可能性, 目前只能实现以下 5 种
	#    输入 → 输出
	# 1. 文件 → 文件（追加内容）
	# 2. 文件 → 目录（复制/合并）
	# 3. 目录 → 文件（合并内容）
	# 4. 目录 → 目录（合并同名文件）
	# 5. 数组 → 文件（写入内容）
	
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

    elif [[ -d "$input" ]]; then
	    echo "输入类型: 文件"
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

    elif _is_array "$input"; then
        if [[ -f "$output" ]]; then
            _handle_array_to_file "$input" "$output"
        elif [[ -d "$output" ]]; then
            _handle_array_to_directory "$input" "$output"
        elif _is_array "$output"; then
            _handle_array_to_array "$input" "$output"     
        else
            echo "错误: 不支持的输出类型" >&2
            return 1
        fi

    else
        echo "错误: 输入类型不被支持 - $input" >&2
        return 1
    fi
}

# ========== 辅助函数 ==========

# 判断是否为数组
# 判断是否为数组（改进版）
_is_array() {
    local var_name="$1"
    
    # 检查是否是有效的变量名
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    
    # 检查变量是否存在且是数组
    if declare -p "$var_name" 2>/dev/null | grep -q '^declare -a'; then
        return 0
    else
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
    
    echo "处理: 文件 -> 目录"
    echo "输入文件: $input"
    echo "目标目录: $output"
    
    # 安全检查：确保输入文件存在且可读
    if [[ ! -r "$input" ]]; then
        echo "错误: 输入文件不存在或不可读" >&2
        return 1
    fi
    
    # 检查目标目录是否可写（主函数已确保是目录，但可能不可写）
    if [[ ! -w "$output" ]]; then
        echo "错误: 目标目录不可写" >&2
        return 1
    fi
    
    # 检查目标目录是否为空
    if [[ -z "$(ls -A "$output" 2>/dev/null)" ]]; then
        echo "目标目录为空，执行复制操作"
        
        if cp "$input" "$target_path"; then
            echo "复制成功: 已将 $input_basename 复制到 $output"
            return 0
        else
            echo "错误: 文件复制失败" >&2
            return 1
        fi
    else
        echo "目标目录非空"
        echo "检查是否存在同名文件: $input_basename"
        
        # 检查目标目录是否存在同名文件
        if [[ -e "$target_path" ]]; then
            if [[ -f "$target_path" ]]; then
                echo "存在同名文件，执行内容合并"
                
                # 检查是否为同一个文件（相同路径）
                if [[ "$(realpath "$input")" == "$(realpath "$target_path")" ]]; then
                    echo "警告: 输入文件和目标文件是同一个文件，将导致内容重复" >&2
                fi
                
                # 执行内容合并
                if cat "$input" >> "$target_path"; then
                    local input_size=$(wc -c < "$input")
                    local target_size=$(wc -c < "$target_path")
                    echo "内容合并成功"
                    echo "输入文件大小: $input_size 字节"
                    echo "目标文件大小: $target_size 字节"
                    return 0
                else
                    echo "错误: 内容合并失败" >&2
                    return 1
                fi
            else
                echo "错误: 目标路径已存在但不是文件（可能是目录或其他类型）" >&2
                return 1
            fi
        else
            echo "不存在同名文件，执行复制操作"
            
            if cp "$input" "$target_path"; then
                echo "复制成功: 已将 $input_basename 复制到 $output"
                return 0
            else
                echo "错误: 文件复制失败" >&2
                return 1
            fi
        fi
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

# 5. 目录 -> 目录
_handle_directory_to_directory() {
    local input="$1"
    local output="$2"
    
    echo "处理: 目录 -> 目录"
    echo "输入目录: $input"
    echo "输出目录: $output"
    
    # 检查输入目录是否为空
    if [[ -z "$(ls -A "$input" 2>/dev/null)" ]]; then
        echo "警告: 输入目录为空，没有内容可处理" >&2
        return 0
    fi
    
    # 检查输出目录是否可写
    if [[ ! -w "$output" ]]; then
        echo "错误: 输出目录不可写" >&2
        return 1
    fi
    
    # 统计变量
    local processed_count=0
    local moved_count=0
    local merged_count=0
    local error_count=0
    
    echo "开始处理目录内容..."
    
    # 使用 find 命令递归查找输入目录中的所有文件
    while IFS= read -r -d '' file; do
        ((processed_count++))
        
        # 获取相对于输入目录的相对路径
        local rel_path="${file#$input/}"
        local target_file="$output/$rel_path"
        local target_dir=$(dirname "$target_file")
        
        echo "处理文件: $rel_path"
        
        # 确保目标目录存在
        if [[ ! -d "$target_dir" ]]; then
            mkdir -p "$target_dir" || {
                echo "  × 创建目录失败: $target_dir" >&2
                ((error_count++))
                continue
            }
        fi
        
        # 检查目标文件是否已存在
        if [[ -f "$target_file" ]]; then
            # 目标文件已存在，追加内容
            echo "  存在同名文件，追加内容"
            if cat "$file" >> "$target_file" 2>/dev/null; then
                ((merged_count++))
                echo "  √ 内容追加成功"
                # 删除原文件（因为已经合并）
                rm -f "$file"
            else
                echo "  × 内容追加失败" >&2
                ((error_count++))
            fi
        else
            # 目标文件不存在，直接移动
            echo "  不存在同名文件，移动文件"
            if mv "$file" "$target_file" 2>/dev/null; then
                ((moved_count++))
                echo "  √ 文件移动成功"
            else
                echo "  × 文件移动失败" >&2
                ((error_count++))
            fi
        fi
        
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    # 尝试删除空的输入目录（如果所有文件都已处理）
    if [[ -d "$input" ]] && [[ -z "$(ls -A "$input" 2>/dev/null)" ]]; then
        rmdir "$input" 2>/dev/null && echo "已删除空输入目录: $input"
    fi
    
    # 显示处理结果
    echo ""
    echo "处理完成:"
    echo "  - 处理文件总数: $processed_count"
    echo "  - 移动文件数: $moved_count"
    echo "  - 合并文件数: $merged_count"
    echo "  - 错误数: $error_count"
    
    if [[ $error_count -eq 0 ]]; then
        echo "目录处理操作完成"
        return 0
    else
        echo "警告: 处理过程中发生了 $error_count 个错误" >&2
        return 1
    fi
}

# 6. 目录 -> 数组
_handle_directory_to_array() {
    local input="$1"
    local output="$2"
    echo "错误: 目录不能合并到数组，此功能暂不支持" >&2
    return 1
}

#============================ 数组 -> 文件 ============================#
# 数组 → 文件：将数组中的文件内容合并到输出文件
_handle_array_to_file() {
    local input_var="$1"    # 数组变量名
    local output="$2"       # 输出文件路径
    
    echo "=========================================="
    echo "开始处理: 数组 → 文件"
    echo "输入数组变量: $input_var"
    echo "输出文件路径: $output"
    echo "=========================================="
    echo ""
    
    # ========== 1. 展开数组 ==========
    echo "[步骤1/3] 展开数组..."
    echo "------------------------------------------"
    
    # 验证输入是否为数组变量
    echo "✓ 检查输入变量 '$input_var' 是否为数组..."
    if ! declare -p "$input_var" 2>/dev/null | grep -q '^declare -a'; then
        echo "✗ 错误: '$input_var' 不是有效的数组变量" >&2
        echo "调试信息:"
        declare -p "$input_var" 2>&1 || echo "无法获取变量信息"
        return 1
    fi
    echo "✓ 输入变量是有效的数组"
    
    # 安全地获取数组内容
    echo "✓ 获取数组内容..."
    local array_files
    eval "array_files=(\"\${$input_var[@]}\")"
    local array_length=${#array_files[@]}
    echo "✓ 数组包含 $array_length 个元素"
    
    # 检查数组是否为空
    if [[ $array_length -eq 0 ]]; then
        echo "! 警告: 输入数组为空"
        # 创建空输出文件（如果不存在）
        if [[ ! -f "$output" ]]; then
            echo "✓ 创建空输出文件..."
            touch "$output"
            echo "✓ 已创建空文件: $output"
        fi
        return 0
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
    
    # 确保输出目录存在
    local output_dir=$(dirname "$output")
    echo "✓ 检查输出目录: $output_dir"
    
    if [[ ! -d "$output_dir" ]]; then
        echo "✓ 创建输出目录..."
        if mkdir -p "$output_dir"; then
            echo "✓ 目录创建成功: $output_dir"
        else
            echo "✗ 错误: 无法创建输出目录" >&2
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
            echo "✗ 错误: 输出文件存在但不可写" >&2
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
        echo "✗ 错误: 无法准备输出文件" >&2
        return 1
    fi
    echo ""
    
    # ========== 3. 合并文件内容 ==========
    echo "[步骤3/3] 开始合并文件内容..."
    echo "------------------------------------------"
    
    local success_count=0
    local error_count=0
    local skip_count=0
    
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
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            echo "  ├─ ✓ 追加成功 (耗时: ${duration}秒)"
            ((success_count++))
        else
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            echo "  ├─ ✗ 追加失败 (耗时: ${duration}秒)" >&2
            ((error_count++))
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
    
    # 返回结果
    if [[ $success_count -gt 0 ]]; then
        echo "✅ 数组合并操作成功完成"
        return 0
    else
        echo "❌ 错误: 没有成功合并任何文件" >&2
        return 1
    fi
}


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
