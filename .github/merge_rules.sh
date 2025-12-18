merge_rules() {
    local input="$1"
    local output="$2"
    local tmpfile=$(mktemp) || { echo "创建临时文件失败!" >&2; exit 1; }
    trap 'rm -f "$tmpfile"' EXIT

    #> 判断输入类型
    # ❶ 输入：文件
    if [ -f $input ]; then
        # 输出：文件
        if [ -f $output ]; then
            # 存在同名
            if [ "$(basename "$input")" == "$(basename "$output")" ]; then
                echo "文件同名,追加内容到 $output"
                cat "$input" >> "$output"
            # 不存在同名
            else
                echo "error"
                return 1
            fi
        # 输出：目录
        elif [ -d $output ]; then
            # 目录为空
            if [ -z "$(ls -A "$output")" ]; then
                echo "目标目录为空"
                echo "执行复制"
                echo "已将 $input 复制到 $output"
                cp -r "$input" "$output/"
            # 目录非空
            else
                echo "目标目录非空"
                echo "比较是否存在同名"
                # 目标目录存在同名
                if [ -e "$output/$(basename "$input")" ]; then
                    echo "存在同名，合并到目标目录文件"
                    cat "$input" >> "$output/$(basename "$input")"
                # 目标目录不存在同名
                else
                    echo "不存在同名，直接复制"
                    cp -r "$input" "$output/"
                fi
            fi
        # 输出：数组
        elif declare -p "$output" 2>/dev/null | grep -q '^declare -a'; then
            echo "error"
            echo "输出不能为数组类型"
            return 1
        else
            echo "输入类型不被支持"
            return 1
        fi
    # ② 输入：目录
    elif [ -d "$input" ]; then
        # 输出：文件
        if [ -f $output ]; then
            # 判断目标目录有无同名
            if [ -e "$output/$(basename "$input")" ]; then
                cat "$input" >> "$output/$(basename "$input")"
            else
                cp -r "$input" "$output/"
            fi
        # 输出：目录
        elif [ -d "$output" ]; then
        # 输出也是目录
        # 需要比较两个目录内相同文件
            if find "$input" -type f -exec basename {} \; | sort | comm -12 - <(find "$output" -type f -exec basename {} \; | sort) | grep -q .; then
                echo "目录 $input 和 $output 中存在同名文件"
                echo "需要追加"
            else
                echo "目录 $input 和 $output 中不存在同名文件"
                echo "复制所有input 到 output"
                cp -r $input/* $output/
            fi
        else
            echo "输入类型不被支持"
            return 1
        fi
    # 输入数组
    else
        echo "输入类型不被支持"
        return 1
    fi
