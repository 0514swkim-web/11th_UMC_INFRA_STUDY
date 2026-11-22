#!/bin/bash
# P4 (before 상태) — 단일 EC2 부팅 스크립트. 워크북 0.1 "EC2에 컨테이너를 직접 띄운" 상태를 재현한다.
# Docker 설치 + 재배포 스크립트만 만든다. DB 비밀번호 등은 .env 로 Session Manager 에서 직접 입력한다.
set -euo pipefail
exec > >(tee /var/log/umc-boot.log) 2>&1

dnf install -y docker
systemctl enable --now docker
mkdir -p /opt/umc

# "기존에 하던 방식"의 배포: 이미지 받고 → 기존 컨테이너 stop/rm → 새로 run (워크북 4.2 의 docker stop && docker run)
cat > /opt/umc/redeploy.sh <<'EOF'
#!/bin/bash
set -euo pipefail
source /opt/umc/image.env          # IMAGE=<ECR>:<tag>
REGION=ap-northeast-2
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${IMAGE%%/*}"
docker pull "$IMAGE"
docker stop app >/dev/null 2>&1 || true
docker rm app   >/dev/null 2>&1 || true
docker run -d --name app --restart unless-stopped -p 3000:3000 --env-file /opt/umc/.env "$IMAGE"
EOF
chmod +x /opt/umc/redeploy.sh
