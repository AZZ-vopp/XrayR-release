#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Phải sử dụng tài khoản root để chạy script này！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không phát hiện được phiên bản hệ thống，vui lòng liên hệ tác giả script！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Phát hiện kiến trúc thất bại，sử dụng kiến trúc mặc định: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32 bit (x86)，vui lòng sử dụng hệ thống 64 bit (x86_64)，nếu phát hiện có lỗi，vui lòng liên hệ tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống CentOS 7 hoặc phiên bản cao hơn！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống Ubuntu 16 hoặc phiên bản cao hơn！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống Debian 8 hoặc phiên bản cao hơn！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        # Lấy phiên bản từ repository AZZ-vopp/XrayR
        last_version=$(curl -Ls "https://api.github.com/repos/AZZ-vopp/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
        if [[ ! -n "$last_version" ]]; then
            echo -e "${yellow}Cảnh báo: Repository AZZ-vopp/XrayR chưa có release，sử dụng phiên bản cố định v0.9.4-20250101${plain}"
            last_version="v0.9.4-20250101"
        fi
        echo -e "Phát hiện phiên bản XrayR mới nhất：${last_version}，bắt đầu cài đặt"
        
        # Thử các tên file khác nhau
        download_success=false
        
        # Thử tên file chuẩn
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/AZZ-vopp/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -eq 0 ]]; then
            download_success=true
        else
            # Thử tên file khác cho ARM64
            if [[ "$arch" == "arm64-v8a" ]]; then
                wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/AZZ-vopp/XrayR/releases/download/${last_version}/XrayR-linux-arm64-v8a.zip
                if [[ $? -eq 0 ]]; then
                    download_success=true
                fi
            fi
        fi
        
        if [[ "$download_success" == false ]]; then
            echo -e "${red}Tải XrayR thất bại，vui lòng đảm bảo repository AZZ-vopp/XrayR có file binary phù hợp${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        
        # Tải từ repository AZZ-vopp/XrayR
        echo -e "Bắt đầu cài đặt XrayR ${last_version} từ repository AZZ-vopp/XrayR"
        
        # Thử các tên file khác nhau
        download_success=false
        
        # Thử tên file chuẩn
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/AZZ-vopp/XrayR/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -eq 0 ]]; then
            download_success=true
        else
            # Thử tên file khác cho ARM64
            if [[ "$arch" == "arm64-v8a" ]]; then
                wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/AZZ-vopp/XrayR/releases/download/${last_version}/XrayR-linux-arm64-v8a.zip
                if [[ $? -eq 0 ]]; then
                    download_success=true
                fi
            fi
        fi
        
        if [[ "$download_success" == false ]]; then
            echo -e "${red}Tải XrayR ${last_version} thất bại，vui lòng đảm bảo repository AZZ-vopp/XrayR có file binary phù hợp${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://raw.githubusercontent.com/AZZ-vopp/XrayR-release/main/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} cài đặt hoàn tất，đã thiết lập tự khởi động"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Cài đặt mới，vui lòng tham khảo hướng dẫn trước：https://github.com/XrayR-project/XrayR，cấu hình nội dung cần thiết"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR khởi động lại thành công${plain}"
        else
            echo -e "${red}XrayR có thể khởi động thất bại，vui lòng sử dụng XrayR log để xem thông tin log sau，nếu không thể khởi động，có thể đã thay đổi định dạng cấu hình，vui lòng xem wiki：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/AZZ-vopp/XrayR-release/main/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # Tương thích chữ thường
    chmod +x /usr/bin/xrayr
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Cách sử dụng script quản lý XrayR (tương thích sử dụng xrayr thực thi，không phân biệt chữ hoa thường): "
    echo "------------------------------------------"
    echo "XrayR                    - Hiển thị menu quản lý (chức năng nhiều hơn)"
    echo "XrayR start              - Khởi động XrayR"
    echo "XrayR stop               - Dừng XrayR"
    echo "XrayR restart            - Khởi động lại XrayR"
    echo "XrayR status             - Xem trạng thái XrayR"
    echo "XrayR enable             - Thiết lập XrayR tự khởi động"
    echo "XrayR disable            - Hủy XrayR tự khởi động"
    echo "XrayR log                - Xem log XrayR"
    echo "XrayR update             - Cập nhật XrayR"
    echo "XrayR update x.x.x       - Cập nhật phiên bản XrayR chỉ định"
    echo "XrayR config             - Hiển thị nội dung file cấu hình"
    echo "XrayR install            - Cài đặt XrayR"
    echo "XrayR uninstall          - Gỡ cài đặt XrayR"
    echo "XrayR version            - Xem phiên bản XrayR"
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
# install_acme
install_XrayR $1
