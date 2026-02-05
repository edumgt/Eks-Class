# EKS에서 마이크로서비스 배포

## Step-00: 마이크로서비스란?
- 마이크로서비스에 대해 매우 높은 수준에서 이해합니다.

## Step-01: 이 섹션에서 무엇을 배우나요?
- 두 개의 마이크로서비스를 배포합니다.
    - 사용자 관리 서비스
    - 알림 서비스

### 사용 사례 설명
- 사용자 관리 **Create User API**가 알림 서비스 **Send Notification API**를 호출하여 사용자를 생성할 때 이메일을 전송합니다.


### 이 섹션에서 사용하는 Docker 이미지 목록
| 애플리케이션 이름                 | Docker 이미지 이름                          |
| ------------------------------- | --------------------------------------------- |
| 사용자 관리 마이크로서비스 | stacksimplify/kube-usermanagement-microservice:1.0.0 |
| 알림 마이크로서비스 V1 | stacksimplify/kube-notifications-microservice:1.0.0 |
| 알림 마이크로서비스 V2 | stacksimplify/kube-notifications-microservice:2.0.0 |

## Step-02: 사전 준비 -1: AWS RDS Database, ALB Ingress Controller & External DNS

### AWS RDS Database
- [06-EKS-Storage-with-RDS-Database](/06-EKS-Storage-with-RDS-Database/README.md) 섹션에서 AWS RDS Database를 생성했습니다.
- RDS Database를 가리키는 `externalName service: 01-MySQL-externalName-Service.yml`도 이미 생성했습니다.

### ALB Ingress Controller & External DNS
- `ALB Ingress Service`와 `External DNS`가 포함된 애플리케이션을 배포합니다.
- 따라서 EKS 클러스터에 관련 Pod가 실행 중이어야 합니다.
- [08-01-ALB-Ingress-Install](/08-ELB-Application-LoadBalancers/08-01-ALB-Ingress-Install/README.md) 섹션에서 **ALB Ingress Controller**를 설치했습니다.
- [08-06-01-Deploy-ExternalDNS-on-EKS](/08-ELB-Application-LoadBalancers/08-06-ALB-Ingress-ExternalDNS/08-06-01-Deploy-ExternalDNS-on-EKS/README.md) 섹션에서 **External DNS**를 설치했습니다.
```
# kube-system 네임스페이스의 alb-ingress-controller Pod 확인
kubectl get pods -n kube-system

# default 네임스페이스의 external-dns Pod 확인
kubectl get pods
```


## Step-03: 사전 준비-2: SES SMTP 자격 증명 생성
### SMTP 자격 증명
- Services -> Simple Email Service 이동
- SMTP Settings --> Create My SMTP Credentials

![alt text](image.png)

---
# AWS CLI로 SMTP(Simple Mail Transfer Protocol) 설정 (Amazon SES 기준)

AWS에서 “SMTP 설정을 AWS CLI로” 한다는 건 보통 **Amazon SES에서 SMTP로 메일을 보내기 위한 준비**(발신자/도메인 검증 → 권한/IAM → SMTP 비밀번호 생성 → 앱/서버 설정)까지를 의미합니다.

---

## 0) 전제

- SMTP 서버는 보통 **Amazon SES(Simple Email Service)** 를 사용합니다.
- SES는 **리전별**로 동작하니(예: `ap-northeast-2`) 한 리전으로 통일하세요.
- 메일 발송 애플리케이션(서버)이 **587(TLS/STARTTLS)** 또는 **465(SSL/TLS)** 로 외부 접속 가능해야 합니다.  
  (EC2라면 보안그룹/네트워크 ACL/사내 방화벽 체크)

---

## 1) SES 발신자(이메일) 또는 도메인 검증

### A. 이메일 주소 검증(빠르게 테스트할 때)

```bash
REGION=ap-northeast-2
aws sesv2 create-email-identity \
  --region "$REGION" \
  --email-identity "no-reply@example.com"
```
---
```
지금 결과는 “생성은 됐지만 아직 검증(Verified)이 안 끝난 상태”예요. 바로 확인/검증 진행 방법과, 다음 단계(IAM+SMTP)로 넘어가기 위한 체크 명령들을 정리해서 안내할게요.

지금 출력은 정상이에요. **SES에 이메일 아이덴티티가 “등록은 됐지만(VerifiedForSendingStatus=false) 아직 검증 링크를 클릭해서 승인되지 않은 상태”**라는 뜻입니다.

아래 순서대로 하면 바로 다음 단계로 넘어갈 수 있어요.

1) 검증 상태 확인 (CLI)
REGION=ap-northeast-2
aws sesv2 get-email-identity \
  --region "$REGION" \
  --email-identity "kimdypm@gmail.com"


여기서 VerifiedForSendingStatus 가 true로 바뀌면 검증 완료입니다.

2) 해야 할 일: Gmail 받은편지함에서 “Amazon SES verification” 메일 찾기

create-email-identity 실행하면 Gmail로 검증 메일이 갑니다.

메일 안의 verification link를 클릭해야 VerifiedForSendingStatus=true로 바뀝니다.

만약 메일이 안 오면

스팸함 확인

Gmail “프로모션” 탭 확인

5~10분 뒤 다시 확인 (SES 쪽에서 지연되는 경우가 종종 있음)

3) (중요) ap-northeast-2에서 SES가 SMTP/발송 지원 리전인지 확인

리전에 따라 SES 이메일 전송/SMTP 지원 여부가 달라질 수 있어서, 아래로 리전 지원 상태를 확인하세요.

aws sesv2 get-account --region "$REGION"


여기서 “SendingEnabled” 류 정보(계정 송신 가능 여부)가 확인됩니다.

만약 리전 이슈가 있으면, 보통 us-east-1 같은 SES 메인 리전으로 진행하는 게 빠릅니다.

4) 다음 단계 미리 점검: 샌드박스인지 확인

샌드박스면 “검증된 주소로만” 보낼 수 있습니다.

aws ses get-send-quota --region "$REGION"


Max24HourSend, MaxSendRate, SentLast24Hours 확인

샌드박스 해제는 보통 Support Case(콘솔)로 진행합니다.

5) 검증 완료 후에 할 일(요약)

검증이 true로 바뀌면, 그 다음은:

IAM 유저 생성 + ses:SendRawEmail 권한 부여

AccessKey 생성

SecretAccessKey → SMTP Password(v4) 변환

서버 설정

SMTP 서버: email-smtp.<region>.amazonaws.com

포트: 587(STARTTLS) 또는 465(TLS)
```
---

- 해당 이메일로 검증 메일이 발송됩니다. 링크 클릭 시 검증 완료.

### B. 도메인 검증(운영 권장)

```bash
REGION=ap-northeast-2
aws sesv2 create-email-identity \
  --region "$REGION" \
  --email-identity "example.com"
```

검증 상태 확인:

```bash
aws sesv2 get-email-identity \
  --region "$REGION" \
  --email-identity "example.com"
```

> 도메인 검증은 **DNS 레코드(TXT/CNAME)** 추가가 필요합니다.  
> `get-email-identity` 결과에 나오는 값(토큰/레코드)을 DNS에 반영해야 완료됩니다.

---

## 2) (권장) DKIM / SPF / DMARC 설정

- DKIM: `create-email-identity` 후 반환/조회되는 DKIM CNAME들을 DNS에 등록
- SPF: 보통 아래를 TXT로 추가
  - `v=spf1 include:amazonses.com ~all`
- DMARC: 예시
  - `_dmarc.example.com TXT "v=DMARC1; p=none; rua=mailto:dmarc@example.com;"`

> 이 단계는 CLI로 “생성”은 하되, 실제 적용은 DNS에 레코드 반영이 필요합니다.

---

## 3) SES 샌드박스 여부 확인 + 운영 전환(필요 시)

샌드박스면 **검증된 주소로만** 발송되거나 제한이 큽니다.

CLI로 송신 한도(일/초) 확인:

```bash
aws ses get-send-quota --region "$REGION"
```

> 운영 전환(샌드박스 해제)은 보통 Support Case로 요청합니다. (CLI만으로 즉시 해제되는 형태는 아닙니다.)

---

## 4) SMTP 자격 증명용 IAM 유저 생성 (권한 최소화)

SES SMTP는 “SMTP 전용 계정”이 따로 있는 게 아니라, **IAM Access Key를 기반으로 SMTP 사용자/비밀번호를 파생**합니다.

### A. IAM 유저 생성

```bash
SMTP_USER=ses-smtp-user
aws iam create-user --user-name "$SMTP_USER"
```

### B. 최소 권한 정책 부여 (SendEmail / SendRawEmail)

```bash
cat > ses-smtp-policy.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSesSend",
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    }
  ]
}
JSON

aws iam put-user-policy \
  --user-name "$SMTP_USER" \
  --policy-name "AllowSesSend" \
  --policy-document file://ses-smtp-policy.json
```

### C. Access Key 발급

```bash
aws iam create-access-key --user-name "$SMTP_USER"
```

출력에서 다음을 안전하게 보관하세요(Secret은 재조회 불가):

- `AccessKeyId`
- `SecretAccessKey`

---

## 5) SecretAccessKey → SMTP Password 변환 (중요)

SES SMTP 비밀번호는 **SecretAccessKey를 HMAC-SHA256으로 변환한 값**입니다.  
AWS CLI가 자동으로 “SMTP 비번”을 출력하지 않으므로, 아래 스크립트로 생성합니다.

### Python 스크립트 (SMTP Password v4 생성)

```python
# gen_ses_smtp_password.py
import base64, hashlib, hmac, sys

# Usage: python gen_ses_smtp_password.py <secret_access_key>
secret = sys.argv[1].encode("utf-8")
message = b"SendRawEmail"
version = b"\x04"

sig = hmac.new(secret, message, hashlib.sha256).digest()
smtp_password = base64.b64encode(version + sig).decode("utf-8")
print(smtp_password)
```

실행:

```bash
SECRET="(create-access-key에서 받은 SecretAccessKey)"
python3 gen_ses_smtp_password.py "$SECRET"
```

- 결과 문자열이 **SMTP 비밀번호**
- SMTP 사용자명은 `AccessKeyId`

---

## 6) SMTP 엔드포인트/포트

리전에 맞는 SES SMTP 엔드포인트를 사용합니다.

- 서버: `email-smtp.<region>.amazonaws.com`  
  예: `email-smtp.ap-northeast-2.amazonaws.com`
- 포트: `587` (STARTTLS 권장) 또는 `465` (TLS)
- 인증: Username=`AccessKeyId`, Password=`(변환된 SMTP Password)`
- TLS: 사용(권장)

---

## 7) 빠른 발송 테스트 (swaks 예시)

```bash
swaks --to you@example.com \
  --from no-reply@example.com \
  --server email-smtp.ap-northeast-2.amazonaws.com \
  --port 587 \
  --auth LOGIN \
  --auth-user "$ACCESS_KEY_ID" \
  --auth-password "$SMTP_PASSWORD" \
  --tls
```

---

## 흔한 장애 포인트 체크리스트

- **샌드박스 상태**라서 수신자 제한/거절
- 도메인 검증/DKIM 미설정으로 스팸 처리
- 보안그룹/방화벽에서 587/465 outbound 차단 (특히 EC2 환경)
- IAM 권한 누락 (`ses:SendRawEmail` 권장)
- 리전 불일치(검증은 `ap-northeast-2`인데 SMTP는 다른 리전 엔드포인트 사용)

---

- **IAM User Name:** 기본 생성된 이름에 microservice 등 식별용 접미사를 붙입니다.
- 자격 증명을 다운로드하고 아래 환경 변수를 `04-NotificationMicroservice-Deployment.yml`에 설정합니다.
```
AWS_MAIL_SERVER_HOST=email-smtp.us-east-1.amazonaws.com
AWS_MAIL_SERVER_USERNAME=****
AWS_MAIL_SERVER_PASSWORD=***
AWS_MAIL_SERVER_FROM_ADDRESS= use-a-valid-email@gmail.com 
```
- **중요:** AWS_MAIL_SERVER_FROM_ADDRESS는 **유효한** 이메일 주소이며 SES에서 검증되어야 합니다.

### 알림을 받을 이메일 주소 확인
- 알림 서비스 테스트를 위해 두 개의 이메일 주소가 필요합니다.
-  **Email Addresses**
    - 새 이메일 주소 검증
    - 검증 요청 이메일이 발송되며, 링크를 클릭해 검증 완료
    - **From Address:** stacksimplify@gmail.com (본인 이메일로 대체)
    - **To Address:** dkalyanreddy@gmail.com (본인 이메일로 대체)
- **중요:** FromAddress와 ToAddress 모두 SES에서 검증되어야 합니다.
    - 참고 링크: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-email-addresses.html    
- 환경 변수
    - AWS_MAIL_SERVER_HOST=email-smtp.us-east-1.amazonaws.com
    - AWS_MAIL_SERVER_USERNAME=*****
    - AWS_MAIL_SERVER_PASSWORD=*****
    - AWS_MAIL_SERVER_FROM_ADDRESS=stacksimplify@gmail.com


## Step-04: 알림 마이크로서비스 Deployment 매니페스트 생성
- 알림 마이크로서비스의 환경 변수를 업데이트합니다.
- **알림 마이크로서비스 Deployment**
```yml
          - name: AWS_MAIL_SERVER_HOST
            value: "smtp-service"
          - name: AWS_MAIL_SERVER_USERNAME
            value: "AKIABCDEDFASUBKLDOAX"
          - name: AWS_MAIL_SERVER_PASSWORD
            value: "Bdsdsadsd32qcsads65B4oLo7kMgmKZqhJtEipuE5unLx"
          - name: AWS_MAIL_SERVER_FROM_ADDRESS
            value: "stacksimplify@gmail.com"
```

## Step-05: 알림 마이크로서비스 SMTP ExternalName 서비스 생성
```yml
apiVersion: v1
kind: Service
metadata:
  name: smtp-service
spec:
  type: ExternalName
  externalName: email-smtp.us-east-1.amazonaws.com
```

## Step-06: 알림 마이크로서비스 NodePort 서비스 생성
```yml
apiVersion: v1
kind: Service
metadata:
  name: notification-clusterip-service
  labels:
    app: notification-restapp
spec:
  type: ClusterIP
  selector:
    app: notification-restapp
  ports:
  - port: 8096
    targetPort: 8096
```
## Step-07: 사용자 관리 마이크로서비스 Deployment 매니페스트에 알림 서비스 환경 변수 추가
- MySQL 관련 환경 변수에 더해 알림 서비스 관련 환경 변수를 추가합니다.
- `02-UserManagementMicroservice-Deployment.yml` 업데이트
```yml
          - name: NOTIFICATION_SERVICE_HOST
            value: "notification-clusterip-service"
          - name: NOTIFICATION_SERVICE_PORT
            value: "8096"    
```
## Step-08: ALB Ingress Service 매니페스트 업데이트
- Ingress Service에서 User Management Service만 대상으로 하도록 업데이트합니다.
- /app1, /app2 컨텍스트 제거
```yml
    # External DNS - Route53에 레코드 셋 생성
    external-dns.alpha.kubernetes.io/hostname: services.kubeoncloud.com, ums.kubeoncloud.com
spec:
  rules:
    - http:
        paths:
          - path: /* # SSL Redirect Setting
            backend:
              serviceName: ssl-redirect
              servicePort: use-annotation                   
          - path: /*
            backend:
              serviceName: usermgmt-restapp-nodeport-service
              servicePort: 8095              
```

## Step-09: 마이크로서비스 매니페스트 배포
```
# 마이크로서비스 매니페스트 배포
kubectl apply -f V1-Microservices/
```

## Step-10: kubectl로 배포 확인
```
# Pods 목록
kubectl get pods

# 사용자 관리 마이크로서비스 로그
kubectl logs -f $(kubectl get po | egrep -o 'usermgmt-microservice-[A-Za-z0-9-]+')

# 알림 마이크로서비스 로그
kubectl logs -f $(kubectl get po | egrep -o 'notification-microservice-[A-Za-z0-9-]+')

# External DNS 로그
kubectl logs -f $(kubectl get po | egrep -o 'external-dns-[A-Za-z0-9-]+')

# Ingress 목록
kubectl get ingress
```

## Step-11: 브라우저에서 마이크로서비스 health-status 확인
```
# 사용자 관리 서비스 Health-Status
https://services.kubeoncloud.com/usermgmt/health-status

# 사용자 관리 서비스 경유 알림 서비스 Health-Status
https://services.kubeoncloud.com/usermgmt/notification-health-status
https://services.kubeoncloud.com/usermgmt/notification-service-info
```

## Step-12: Postman 클라이언트에 프로젝트 가져오기
- Postman 프로젝트를 Import
- 환경 URL 추가
    - https://services.kubeoncloud.com (**환경에 맞는 ALB DNS로 대체**)

## Step-13: Postman으로 두 마이크로서비스 테스트
### 사용자 관리 서비스
- **Create User**
    - 계정 생성 이메일 수신 여부 확인
- **List User**   
    - 새로 생성된 사용자가 목록에 표시되는지 확인
    


## Step-14: 롤아웃 새 배포 - Set Image
```
# Set Image로 새 배포 롤아웃
kubectl set image deployment/notification-microservice notification-service=stacksimplify/kube-notifications-microservice:2.0.0 --record=true

# 롤아웃 상태 확인
kubectl rollout status deployment/notification-microservice

# ReplicaSets 확인
kubectl get rs
