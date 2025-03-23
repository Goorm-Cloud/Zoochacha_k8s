#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 환경변수 파일 체크 및 로드
if [ ! -f .env ]; then
    if [ -f .env.template ]; then
        log_info "환경변수 템플릿 파일을 찾았습니다. .env 파일을 생성합니다."
        cp .env.template .env
        log_warn "생성된 .env 파일을 편집하여 실제 값을 입력해주세요."
        exit 1
    else
        log_error ".env.template 파일을 찾을 수 없습니다."
        exit 1
    fi
fi

# 환경변수 로드
source .env

# 필수 환경변수 체크
required_vars=(
    "AWS_ROLE_ARN"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "DOMAIN_NAME"
    "CERT_MANAGER_EMAIL"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "$var 가 설정되지 않았습니다. .env 파일을 확인해주세요."
        exit 1
    fi
done

log_info "모든 필수 환경변수가 설정되었습니다."

# cert-manager 네임스페이스 생성
log_info "cert-manager 네임스페이스 생성 중..."
kubectl create namespace cert-manager 2>/dev/null || true

# cert-manager 설치
log_info "cert-manager CRD 및 리소스 설치 중..."
kubectl apply -f cert-manager-all.yaml

# Route53 credentials secret 생성
log_info "Route53 credentials secret 생성 중..."
kubectl create secret generic route53-credentials \
    -n zoochacha \
    --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# ConfigMap 생성
log_info "NGINX ConfigMap 생성 중..."
kubectl apply -f ConfigMap_proxy.yaml

# Deployment 및 Service 생성
log_info "NGINX Deployment 및 Service 생성 중..."
kubectl apply -f dep_proxy.yaml

# 설치 상태 확인
log_info "설치 상태 확인 중..."
echo ""
echo "cert-manager pods:"
kubectl get pods -n cert-manager
echo ""
echo "nginx-proxy pods:"
kubectl get pods -n zoochacha -l app=nginx-proxy
echo ""
echo "LoadBalancer service:"
kubectl get svc nginx-loadbalancer -n zoochacha
echo ""
echo "Certificate status:"
kubectl get certificate -n zoochacha

log_info "설치가 완료되었습니다."
log_warn "새로운 터미널을 열 때마다 환경변수를 다시 로드하려면 다음 명령어를 실행하세요:"
echo "source .env" 