#!/bin/bash

# 以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi


# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="availf"
    local profile_found=0

    # 定义一个关联数组，以支持多种Shell
    declare -A shell_profiles=(
        [bash]="$HOME/.bashrc"
        [zsh]="$HOME/.zshrc"
        [sh]="$HOME/.profile"
    )

    # 检查当前Shell环境并相应地设置alias
    for shell in "${!shell_profiles[@]}"; do
        local shell_rc="${shell_profiles[$shell]}"
        if [[ -f "$shell_rc" ]]; then
            if ! grep -q "$alias_name" "$shell_rc"; then
                echo "设置快捷键 '$alias_name' 到 $shell_rc"
                echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
                echo "快捷键 '$alias_name' 已设置。请运行 'source $shell_rc' 来激活快捷键，或重新打开终端。"
                profile_found=1
                break  # 找到当前用户的shell配置文件后就停止循环
            else
                echo "快捷键 '$alias_name' 已经设置在 $shell_rc。"
                profile_found=1
                break
            fi
        fi
    done

    if [[ $profile_found -eq 0 ]]; then
        echo "未找到支持的Shell配置文件。"
    fi
}

function install_node() {
    install_dependencies() {
        local to_install=()
        for dep in "$@"; do
            if ! command -v "$dep" >/dev/null 2>&1; then
                to_install+=("$dep")
            fi
        done

        if [ "${#to_install[@]}" -ne 0 ]; then
            sudo apt update -y
            echo "安装依赖项：${to_install[*]}"
            sudo apt install -y "${to_install[@]}"
        else
            echo "相关资源已安装。"
        fi
    }

    dependencies=(curl make clang pkg-config libssl-dev build-essential)
    install_dependencies "${dependencies[@]}"

    INSTALL_DIR="${HOME}/avail-light"
    RELEASE_URL="https://github.com/availproject/avail-light/releases/download/v1.7.10/avail-light-linux-amd64.tar.gz"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit

    wget "$RELEASE_URL"
    tar -xvzf avail-light-linux-amd64.tar.gz
    cp avail-light-linux-amd64 avail-light

    read -sp "输入12位钱包助记词：" PHRASE
    cat > identity.toml <<EOF
avail_secret_seed_phrase = "$PHRASE"
EOF

    # 配置 systemd 服务文件
    tee /etc/systemd/system/availd.service > /dev/null <<EOF
[Unit]
Description=Avail Light Client
After=network.target
StartLimitIntervalSec=0
[Service]
User=root
ExecStart=/root/avail-light/avail-light --network goldberg --identity /root/avail-light/identity.toml
Restart=always
RestartSec=120
[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 并启用并启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable availd
    sudo systemctl start availd.service

    echo "====================================== 安装完成 ========================================"
}

# 查看Avail服务状态
function check_service_status() {
    systemctl status availd
}

# 查询节点匹配的公钥
function public_key() {
    journalctl -u availd | grep "public key"
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "输入对应数组进行安装部署:"
        echo "1. 安装节点"
        echo "2. Avail服务状态"
        echo "3. 获取public key"
        echo "退出脚本，使用ctrl+c"
        read -p "请输入选项（1-3）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) check_service_status ;;
        3) public_key ;;
        *) echo "无效选项，请重新输入。" ;;
        esac
        read -p "按任意键返回" 
    done
}

# 显示主菜单
main_menu
