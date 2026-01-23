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
