#!/bin/bash

# ========== 主函数 ==========
merge_rules() {
    local input="$1"
    local output="$2"
    
    # 输入验证
    if [[ -z "$input" || -z "$output" ]]; then
        echo "错误: 输入和输出参数不能为空" >&2
        return 1
    fi
    
    # 主判断逻辑：输入类型 → 输出类型
    if [[ -f "$input" ]]; then
        # 输入：文件
        _handle_file_input "$input" "$output"
    elif [[ -d "$input" ]]; then
        # 输入：目录
        _handle_directory_input "$input" "$output"
    elif _is_array "$input"; then
        # 输入：数组
        _handle_array_input "$input" "$output"
    else
        echo "错误: 输入类型不被支持 - $input" >&2
        return 1
    fi
}

# ========== 输入类型处理函数 ==========

# 处理文件输入
_handle_file_input() {
    local input="$1"
    local output="$2"
    
    echo "输入类型: 文件"
    
    if [[ -f "$output" ]]; then
        # 文件 → 文件
        _handle_file_to_file "$input" "$output"
    elif [[ -d "$output" ]]; then
        # 文件 → 目录
        _handle_file_to_directory "$input" "$output"
    elif _is_array "$output"; then
        # 文件 → 数组（不支持）
        _handle_file_to_array "$input" "$output"
    else
        echo "错误: 不支持的输出类型" >&2
        return 1
    fi
}

# 处理目录输入
_handle_directory_input() {
    local input="$1"
    local output="$2"
    
    echo "输入类型: 目录"
    
    if [[ -f "$output" ]]; then
        # 目录 → 文件
        _handle_directory_to_file "$input" "$output"
    elif [[ -d "$output" ]]; then
        # 目录 → 目录
        _handle_directory_to_directory "$input" "$output"
    elif _is_array "$output"; then
        # 目录 → 数组（不支持）
        _handle_directory_to_array "$input" "$output"
    else
        echo "错误: 不支持的输出类型" >&2
        return 1
    fi
}

# 处理数组输入
_handle_array_input() {
    local input="$1"
    local output="$2"
    
    echo "输入类型: 数组"
    
    if [[ -f "$output" ]]; then
        # 数组 → 文件
        _handle_array_to_file "$input" "$output"
    elif [[ -d "$output" ]]; then
        # 数组 → 目录（不支持）
        _handle_array_to_directory "$input" "$output"
    elif _is_array "$output"; then
        # 数组 → 数组（不支持）
        _handle_array_to_array "$input" "$output"
    else
        echo "错误: 不支持的输出类型" >&2
        return 1
    fi
}

# ========== 辅助函数 ==========

# 判断是否为数组
_is_array() {
    local var_name="$1"
    if declare -p "$var_name" 2>/dev/null | grep -q '^declare -a'; then
        return 0
    else
        return 1
    fi
}

# 确保目录存在
_ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo "错误: 无法创建目录 $dir" >&2
            return 1
        }
    fi
    return 0
}

# 检查文件是否可读
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

# 检查目录是否可写
_check_directory_writable() {
    local dir="$1"
    if [[ ! -w "$dir" ]] && [[ ! -w "$dir/." ]]; then
        echo "错误: 目录不可写 - $dir" >&2
        return 1
    fi
    return 0
}

# ========== 具体处理函数（支持的5种组合） ==========

# 1. 文件 → 文件：追加内容（需同名）
_handle_file_to_file() {
    local input="$1"
    local output="$2"
    
    echo "处理: 文件 → 文件"
    echo "输入: $input"
    echo "输出: $output"
    
    # 输入验证
    _check_file_readable "$input" || return 1
    _ensure_directory "$(dirname "$output")" || return 1
    
    # 检查文件名是否相同
    local input_name=$(basename "$input")
    local output_name=$(basename "$output")
    
    if [[ "$input_name" != "$output_name" ]]; then
        echo "错误: 输入输出文件不同名" >&2
        echo "输入文件: $input_name"
        echo "输出文件: $output_name"
        return 1
    fi
    
    # 执行内容追加
    echo "执行内容追加操作"
    if cat "$input" >> "$output"; then
        local input_size=$(wc -c < "$input")
        local output_size=$(wc -c < "$output")
        echo "追加成功"
        echo "输入文件: $input_size 字节"
        echo "输出文件: $output_size 字节"
        return 0
    else
        echo "错误: 内容追加失败" >&2
        return 1
    fi
}

# 2. 文件 → 目录：复制或合并
_handle_file_to_directory() {
    local input="$1"
    local output="$2"
    
    echo "处理: 文件 → 目录"
    echo "输入: $input"
    echo "输出: $output"
    
    # 输入验证
    _check_file_readable "$input" || return 1
    _check_directory_writable "$output" || return 1
    
    local filename=$(basename "$input")
    local target="$output/$filename"
    
    # 检查目标文件是否存在
    if [[ -f "$target" ]]; then
        echo "存在同名文件，执行内容合并"
        if cat "$input" >> "$target"; then
            echo "内容合并成功: $filename"
            return 0
        else
            echo "错误: 内容合并失败" >&2
            return 1
        fi
    else
        echo "复制文件到目录"
        if cp "$input" "$target"; then
            echo "复制成功: $filename → $output"
            return 0
        else
            echo "错误: 文件复制失败" >&2
            return 1
        fi
    fi
}

# 3. 目录 → 文件：合并目录内容到文件
_handle_directory_to_file() {
    local input="$1"
    local output="$2"
    
    echo "处理: 目录 → 文件"
    echo "输入: $input"
    echo "输出: $output"
    
    # 输入验证
    if [[ ! -d "$input" ]]; then
        echo "错误: 输入目录不存在" >&2
        return 1
    fi
    _ensure_directory "$(dirname "$output")" || return 1
    
    # 检查目录是否为空
    if [[ -z "$(ls -A "$input" 2>/dev/null)" ]]; then
        echo "警告: 输入目录为空" >&2
        touch "$output"
        echo "已创建空文件: $output"
        return 0
    fi
    
    # 创建/清空输出文件
    > "$output"
    echo "开始合并目录内容..."
    
    local success_count=0
    local error_count=0
    
    # 合并所有文件内容
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if cat "$file" >> "$output" 2>/dev/null; then
                ((success_count++))
                echo "  √ $(basename "$file")"
            else
                ((error_count++))
                echo "  × $(basename "$file")" >&2
            fi
        fi
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    echo "合并完成: 成功 $success_count 个文件, 失败 $error_count 个文件"
    
    if [[ $success_count -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 4. 目录 → 目录：合并同名文件
_handle_directory_to_directory() {
    local input="$1"
    local output="$2"
    
    echo "处理: 目录 → 目录"
    echo "输入: $input"
    echo "输出: $output"
    
    # 输入验证
    if [[ ! -d "$input" ]]; then
        echo "错误: 输入目录不存在" >&2
        return 1
    fi
    _check_directory_writable "$output" || return 1
    
    # 检查输入目录是否为空
    if [[ -z "$(ls -A "$input" 2>/dev/null)" ]]; then
        echo "警告: 输入目录为空" >&2
        return 0
    fi
    
    local processed=0
    local moved=0
    local merged=0
    local errors=0
    
    echo "开始处理目录内容..."
    
    # 处理所有文件
    while IFS= read -r -d '' file; do
        ((processed++))
        
        local rel_path="${file#$input/}"
        local target="$output/$rel_path"
        local target_dir=$(dirname "$target")
        
        _ensure_directory "$target_dir" || {
            ((errors++))
            continue
        }
        
        if [[ -f "$target" ]]; then
            # 合并内容
            if cat "$file" >> "$target"; then
                ((merged++))
                echo "  √ 合并: $rel_path"
                rm -f "$file"
            else
                ((errors++))
                echo "  × 合并失败: $rel_path" >&2
            fi
        else
            # 移动文件
            if mv "$file" "$target" 2>/dev/null; then
                ((moved++))
                echo "  √ 移动: $rel_path"
            else
                ((errors++))
                echo "  × 移动失败: $rel_path" >&2
            fi
        fi
    done < <(find "$input" -type f -print0 2>/dev/null)
    
    # 清理空目录
    find "$input" -type d -empty -delete 2>/dev/null
    
    echo "处理完成: 移动 $moved, 合并 $merged, 错误 $errors"
    return $((errors > 0 ? 1 : 0))
}

# 5. 数组 → 文件：将数组中的文件内容合并
_handle_array_to_file() {
    local input_var="$1"
    local output="$2"
    
    echo "处理: 数组 → 文件"
    echo "输入数组: $input_var"
    echo "输出: $output"
    
    # 获取数组内容（文件路径列表）
    local array_ref="${input_var}[@]"
    local files=("${!array_ref}")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "警告: 输入数组为空" >&2
        touch "$output"
        echo "已创建空文件: $output"
        return 0
    fi
    
    _ensure_directory "$(dirname "$output")" || return 1
    > "$output"  # 清空输出文件
    
    local success=0
    local errors=0
    
    echo "开始合并数组中的文件内容..."
    
    for file in "${files[@]}"; do
        if _check_file_readable "$file"; then
            if cat "$file" >> "$output"; then
                ((success++))
                echo "  √ $(basename "$file")"
            else
                ((errors++))
                echo "  × 追加失败: $file" >&2
            fi
        else
            ((errors++))
        fi
    done
    
    echo "合并完成: 成功 $success 个文件, 失败 $errors 个文件"
    return $((errors > 0 ? 1 : 0))
}

# ========== 不支持的处理函数 ==========

_handle_file_to_array() {
    echo "错误: 文件 → 数组 不支持" >&2
    return 1
}

_handle_directory_to_array() {
    echo "错误: 目录 → 数组 不支持" >&2
    return 1
}

_handle_array_to_directory() {
    echo "错误: 数组 → 目录 不支持" >&2
    return 1
}

_handle_array_to_array() {
    echo "错误: 数组 → 数组 不支持" >&2
    return 1
}
