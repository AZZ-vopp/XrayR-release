#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YEL='\033[0;33m'; BLU='\033[0;34m'; DIM='\033[2m'; RST='\033[0m'
else
  RED=''; GREEN=''; YEL=''; BLU=''; DIM=''; RST=''
fi

CONFIG_DIR="/etc/XrayR"
CONFIG_FILE="$CONFIG_DIR/config.yml"
CERT_DIR="$CONFIG_DIR/cert"
BACKUP_DIR="$CONFIG_DIR/backup"
LOG_TAG="[XrayR-Pro]"
INSTALLER_URL="https://raw.githubusercontent.com/AZZ-vopp/XrayR-release/main/install.sh"

log()  { echo -e "${BLU}${LOG_TAG}${RST} $*"; }
ok()   { echo -e "${GREEN}✔${RST} $*"; }
warn() { echo -e "${YEL}⚠${RST} $*"; }
err()  { echo -e "${RED}✖${RST} $*" >&2; }

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    err "Vui lòng chạy với quyền root (sudo)."; exit 1
  fi
}

pause_any() { read -r -p "Nhấn Enter để tiếp tục..." _ || true; }

confirm() {
  local prompt="${1:-Bạn chắc chứ} [y/N]: "
  read -r -p "$prompt" ans || true
  [[ "${ans,,}" == y || "${ans,,}" == yes ]]
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_pkg() {
  local pkgs=("$@")
  local miss=()
  for p in "${pkgs[@]}"; do has_cmd "$p" || miss+=("$p"); done
  if ((${#miss[@]})); then
    warn "Thiếu gói: ${miss[*]} -> sẽ cài đặt"
    if has_cmd apt-get; then
      apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y "${miss[@]}"
    elif has_cmd dnf; then
      dnf install -y "${miss[@]}"
    elif has_cmd yum; then
      yum install -y "${miss[@]}"
    else
      err "Không tìm thấy trình quản lý gói phù hợp (apt/dnf/yum)."; exit 1
    fi
  fi
}

get_api_info() {
  local _host="${apiHost:-}"
  local _key="${apiKey:-}"

  if [ -z "$_host" ]; then
    read -r -p "Nhập API Host (ví dụ: panel.example.com): " _host
  fi
  if [ -z "$_key" ]; then
    read -r -p "Nhập API Key: " _key
  fi

  _host="${_host#http://}"; _host="${_host#https://}"
  if ! [[ "$_host" =~ ^[A-Za-z0-9.-]+$ ]]; then
    err "API Host không hợp lệ: $_host"; exit 1
  fi
  if [ ${#_key} -lt 8 ]; then
    warn "API Key có vẻ ngắn -> kiểm tra lại."
  fi

  export apiHost="$_host"
  export apiKey="$_key"
  ok "APIHost = ${apiHost}, ApiKey = (ẩn)"
}

install_xrayr() {
  if ! has_cmd xrayr; then
    log "Cài đặt XrayR..."
    bash <(curl -fsSL "$INSTALLER_URL")
    ok "Đã cài đặt XrayR."
  else
    ok "XrayR đã có sẵn."
  fi
}

backup_config() {
  if [ -f "$CONFIG_FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    cp -a "$CONFIG_FILE" "$BACKUP_DIR/config.$ts.yml"
    ok "Đã sao lưu config: $BACKUP_DIR/config.$ts.yml"
  fi
}

init_config() {
  mkdir -p "$CONFIG_DIR"
  backup_config
  cat >"$CONFIG_FILE" <<'YAML'
Log:
  Level: warning
Nodes:
YAML
  ok "Đã khởi tạo file config rỗng."
}

write_config_block() {
  local type="$1" id="$2" enable_vless="${3:-false}"
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    err "NodeID phải là số: '$id'"; exit 1
  fi
  cat >>"$CONFIG_FILE" <<EOF
  -
    PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://${apiHost}"
      ApiKey: "${apiKey}"
      NodeID: ${id}
      NodeType: ${type}
      Timeout: 30
      EnableVless: ${enable_vless}
    ControllerConfig:
      DeviceOnlineMinTraffic: 200
      EnableProxyProtocol: true
EOF
  ok "Đã thêm node ${type} (ID: ${id}) vào config."
}

write_trojan_block() {
  local id="$1" domain="$2"
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    err "NodeID phải là số: '$id'"; exit 1
  fi
  if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]]; then
    err "Domain không hợp lệ: '$domain'"; exit 1
  fi

  mkdir -p "$CERT_DIR"
  local cert="$CERT_DIR/$domain.cert"
  local key="$CERT_DIR/$domain.key"

  if [ ! -f "$cert" ] || [ ! -f "$key" ]; then
    log "Tạo chứng chỉ tự ký cho ${domain} (1 năm)…"
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
      -keyout "$key" -out "$cert" \
      -subj "/C=VN/ST=Hanoi/L=HoanKiem/O=SelfSigned/CN=${domain}"
    ok "Đã tạo cert: $cert và key: $key"
  else
    ok "Đã có sẵn cert/key cho ${domain}"
  fi

  cat >>"$CONFIG_FILE" <<EOF
  -
    PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://${apiHost}"
      ApiKey: "${apiKey}"
      NodeID: ${id}
      NodeType: Trojan
      Timeout: 30
      EnableVless: false
    ControllerConfig:
      EnableProxyProtocol: true
      DeviceOnlineMinTraffic: 200
      DisableLocalREALITYConfig: false
      EnableREALITY: false
      REALITYConfigs:
        Show: true
      CertConfig:
        CertMode: file
        CertFile: ${cert}
        KeyFile: ${key}
EOF
  ok "Đã thêm node Trojan (ID: ${id}, domain: ${domain}) vào config."
}

xrayr_restart() { has_cmd xrayr && xrayr restart || systemctl restart XrayR || true; }
xrayr_status()  { if has_cmd xrayr; then xrayr status || true; else systemctl status --no-pager XrayR || true; fi; }
xrayr_uninstall(){ has_cmd xrayr && xrayr uninstall || warn "Không tìm thấy CLI xrayr để gỡ."; }
xrayr_logs()    { journalctl -u XrayR -e --no-pager -n 200 || warn "Không thể đọc journalctl."; }

finish_install() {
  xrayr_restart
  ok "Hoàn tất! Quản lý bằng menu hoặc CLI xrayr/systemctl."
}

enable_bbr() {
  warn "BBR yêu cầu kernel hỗ trợ; sẽ cập nhật sysctl."
  cat >/etc/sysctl.d/99-bbr.conf <<'SYS'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
SYS
  sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-bbr.conf || true
  if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -qi bbr; then
    ok "BBR đã được bật."
  else
    warn "Không xác nhận được BBR. Có thể kernel không hỗ trợ."
  fi
}

create_quick_menu() {
  cat > /root/xrayr <<'MENU'
#!/usr/bin/env bash
while true; do
  clear
  echo "====== XrayR Menu Nhanh ======"
  echo "1) Chỉnh sửa /etc/XrayR/config.yml"
  echo "2) Khởi động lại XrayR"
  echo "3) Xem trạng thái XrayR"
  echo "4) Xem log gần đây"
  echo "5) Gỡ cài đặt XrayR"
  echo "0) Thoát"
  echo "=============================="
  read -r -p "Chọn: " c
  case "${c,,}" in
    1) nano /etc/XrayR/config.yml ;;
    2) xrayr restart 2>/dev/null || systemctl restart XrayR ;;
    3) xrayr status 2>/dev/null || systemctl status --no-pager XrayR; read -r -p "Enter…" _ ;;
    4) journalctl -u XrayR -e --no-pager -n 200; read -r -p "Enter…" _ ;;
    5) xrayr uninstall || true ;;
    0) exit 0 ;;
    *) echo "Lựa chọn không hợp lệ!" && sleep 1 ;;
  esac
done
MENU
  chmod +x /root/xrayr
  ok "Đã tạo menu nhanh: /root/xrayr (chạy: ./xrayr)"
}

install_ss() {
  read -r -p "NODE ID Shadowsocks: " nid
  init_config
  write_config_block "Shadowsocks" "$nid" "false"
  finish_install
}
install_vmess() {
  read -r -p "NODE ID VMess (V2ray): " nid
  init_config
  write_config_block "V2ray" "$nid" "false"
  finish_install
}
install_vless() {
  read -r -p "NODE ID VLESS (V2ray): " nid
  init_config
  write_config_block "V2ray" "$nid" "true"
  finish_install
}
install_trojan() {
  read -r -p "NODE ID Trojan: " nid
  read -r -p "Domain cho cert (vd: node1.example.com): " dom
  init_config
  write_trojan_block "$nid" "$dom"
  finish_install
}
install_vmess_trojan() {
  read -r -p "NODE ID VMess (V2ray): " nid_vm
  read -r -p "NODE ID Trojan: " nid_tj
  read -r -p "Domain cho cert Trojan: " dom
  init_config
  write_config_block "V2ray" "$nid_vm" "false"
  write_trojan_block "$nid_tj" "$dom"
  finish_install
}

add_node() {
  read -r -p "Loại node muốn thêm (ss/vmess/vless/trojan): " t
  case "${t,,}" in
    ss)
      read -r -p "NODE ID: " nid
      write_config_block "Shadowsocks" "$nid" "false"
      ;;
    vmess)
      read -r -p "NODE ID: " nid
      write_config_block "V2ray" "$nid" "false"
      ;;
    vless)
      read -r -p "NODE ID: " nid
      write_config_block "V2ray" "$nid" "true"
      ;;
    trojan)
      read -r -p "NODE ID: " nid
      read -r -p "Domain cho cert: " dom
      write_trojan_block "$nid" "$dom"
      ;;
    *)
      err "Loại node không hợp lệ!"; return 1
      ;;
  esac
  if confirm "Khởi động lại XrayR ngay?"; then
    xrayr_restart
  fi
}

main_menu() {
  require_root
  ensure_pkg curl openssl nano
  get_api_info
  install_xrayr
  create_quick_menu

  while true; do
    clear
    echo -e "${DIM}API Host:${RST} ${apiHost}  ${DIM}API Key:${RST} (ẩn)"
    echo "========== SCRIPT CÀI ĐẶT XRAYR (PRO) =========="
    echo "1) Cài đặt Shadowsocks"
    echo "2) Cài đặt VMess (V2ray)"
    echo "3) Cài đặt Trojan (tạo cert tự ký)"
    echo "4) Cài đặt VMess + Trojan"
    echo "5) Cài đặt VLESS (V2ray)"
    echo "6) Thêm node vào config hiện tại"
    echo "7) Bật BBR (TCP Congestion Control)"
    echo "8) Xem trạng thái dịch vụ"
    echo "9) Xem log dịch vụ"
    echo "u) Gỡ cài đặt XrayR"
    echo "q) Thoát"
    echo "================================================"
    read -r -p "Chọn một tùy chọn: " choice
    case "${choice,,}" in
      1) install_ss ;;
      2) install_vmess ;;
      3) install_trojan ;;
      4) install_vmess_trojan ;;
      5) install_vless ;;
      6) add_node ;;
      7) enable_bbr; pause_any ;;
      8) xrayr_status; pause_any ;;
      9) xrayr_logs; pause_any ;;
      u) if confirm "Gỡ XrayR?"; then xrayr_uninstall; fi ;;
      q|0) exit 0 ;;
      *) warn "Lựa chọn không hợp lệ!"; sleep 1 ;;
    esac
  done
}

main_menu "$@"
