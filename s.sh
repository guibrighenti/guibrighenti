#!/usr/bin/env bash
# Instalador do soulocador em VPS Ubuntu. Uso: curl -fsSL <url> | bash -s soulocador.com.br
set -euo pipefail
DOMINIO="${1:-soulocador.com.br}"; PB_VERSION="0.40.4"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y unzip curl debian-keyring debian-archive-keyring apt-transport-https gpg
mkdir -p /opt/soulocador/{backups,incoming,pb_public,pb_migrations,pb_hooks}
cd /opt/soulocador
curl -fsSL -o pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip"
unzip -o pb.zip pocketbase && rm pb.zip && chmod +x pocketbase
cat > /etc/systemd/system/soulocador.service <<UNIT
[Unit]
Description=Soulocador
After=network.target
[Service]
WorkingDirectory=/opt/soulocador
Environment=APP_URL=https://${DOMINIO}
ExecStart=/opt/soulocador/pocketbase serve --http=127.0.0.1:8090
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now soulocador
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y && apt-get install -y caddy
printf '%s, www.%s {\n    reverse_proxy 127.0.0.1:8090\n}\n' "$DOMINIO" "$DOMINIO" > /etc/caddy/Caddyfile
systemctl restart caddy
if command -v ufw >/dev/null; then ufw allow OpenSSH; ufw allow 80; ufw allow 443; ufw --force enable; fi
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [ ! -f /root/.ssh/soulocador_deploy ]; then
  ssh-keygen -t ed25519 -N "" -C soulocador-deploy -f /root/.ssh/soulocador_deploy -q
  cat /root/.ssh/soulocador_deploy.pub >> /root/.ssh/authorized_keys
fi
echo
echo "===== COPIE DAQUI PARA BAIXO (PARA O SECRET VPS_SSH_KEY) ====="
cat /root/.ssh/soulocador_deploy
echo "===== ATE AQUI ====="
echo "INSTALACAO CONCLUIDA. IP DESTA VPS: $(curl -s -4 ifconfig.me)"
