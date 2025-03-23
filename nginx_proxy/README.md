# NGINX Proxy 및 SSL 인증서 설정 가이드

이 가이드는 Kubernetes 클러스터에 NGINX Proxy를 설정하고 SSL 인증서를 자동으로 발급/갱신하는 과정을 설명합니다.

## 사전 요구사항

- Kubernetes 클러스터 접근 권한
- kubectl CLI 도구
- AWS CLI 설정 완료
- 도메인 설정 완료 (예: zoochacha.online)

## 1. 환경변수 설정

### 방법 1: 직접 환경변수 설정 (권장)
```bash
# 1. 템플릿 파일 복사
cp .env.template .env

# 2. .env 파일 수정
vi .env

# 3. 환경변수 적용
source .env
# 또는
. .env

# 4. 환경변수 설정 확인
env | grep AWS
```

### 방법 2: 자동 설치 스크립트 사용
```bash
# 1. 템플릿 파일 복사 및 수정은 동일
cp .env.template .env
vi .env

# 2. 스크립트 실행 권한 부여
chmod +x setup.sh

# 3. 스크립트 실행
./setup.sh
```

스크립트는 다음 작업을 자동으로 수행합니다:
- 환경변수 파일 체크 및 로드
- cert-manager 설치
- Route53 credentials secret 생성
- NGINX ConfigMap 및 Deployment 설정
- 설치 상태 확인

## 2. cert-manager 설치

cert-manager는 Kubernetes 인증서 관리를 자동화합니다.

```bash
# cert-manager 네임스페이스 생성
kubectl create namespace cert-manager

# cert-manager CRD 및 리소스 설치
kubectl apply -f cert-manager-all.yaml
```

설치 확인:
```bash
kubectl get pods -n cert-manager
```

모든 pod가 Running 상태가 될 때까지 기다립니다.

## 3. NGINX 설정

### 3.1 ConfigMap 생성
```bash
# NGINX 설정을 포함한 ConfigMap 생성
kubectl apply -f ConfigMap_proxy.yaml
```

### 3.2 NGINX Deployment 및 Service 생성
```bash
# NGINX Deployment 및 LoadBalancer Service 생성
kubectl apply -f dep_proxy.yaml
```

## 4. SSL 인증서 설정

### 4.1 Route53 Credentials Secret 생성
```bash
# Secret 생성 (환경변수가 설정된 상태에서)
kubectl create secret generic route53-credentials \
    -n zoochacha \
    --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"
```

### 4.2 인증서 상태 확인
```bash
kubectl get certificate -n zoochacha
kubectl get certificaterequest -n zoochacha
kubectl get order -n zoochacha
kubectl get challenge -n zoochacha
```

## 문제 해결

### 인증서 발급 실패 시
1. Challenge 상태 확인:
```bash
kubectl describe challenge -n zoochacha
```

2. cert-manager 로그 확인:
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

### NGINX 연결 문제
1. 서비스 상태 확인:
```bash
kubectl describe svc nginx-loadbalancer -n zoochacha
```

2. 엔드포인트 확인:
```bash
kubectl get endpoints nginx-loadbalancer -n zoochacha
```

## 주의사항

1. 환경변수 및 민감정보 관리:
   - `.env` 파일은 절대 Git에 커밋하지 마세요
   - 환경변수는 현재 쉘 세션에서만 유효합니다
   - 새 터미널을 열면 `source .env`를 다시 실행해야 합니다

2. Let's Encrypt Rate Limits:
   - 동일 도메인에 대해 주당 50회 제한
   - 실패한 검증은 시간당 5회 제한

3. 인증서 갱신:
   - cert-manager가 만료 30일 전에 자동으로 갱신을 시도
   - 수동 갱신이 필요한 경우:
     ```bash
     kubectl delete secret nginx-tls -n zoochacha
     kubectl delete certificate zoochacha-tls -n zoochacha
     kubectl apply -f certificate.yaml
     ```

## 재설치 시 주의사항

시스템을 재설치해야 하는 경우:

1. 기존 설정 백업:
```bash
kubectl get -n cert-manager clusterissuer,certificate,secret -o yaml > cert-backup.yaml
```

2. 제거 순서:
```bash
kubectl delete -f certificate.yaml
kubectl delete -f cluster-issuer.yaml
kubectl delete -f dep_proxy.yaml
kubectl delete -f ConfigMap_proxy.yaml
kubectl delete -f cert-manager-all.yaml
```

3. 재설치는 위의 설치 과정을 순서대로 진행

## 참고 사항

- 도메인 설정이 올바르게 되어 있는지 확인
- AWS Load Balancer가 올바르게 생성되었는지 확인
- Security Group 설정 확인 (80, 443 포트 개방 필요) 