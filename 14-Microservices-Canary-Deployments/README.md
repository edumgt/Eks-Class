# 마이크로서비스 카나리 배포

## Step-01: 소개
### 사용 사례 설명
- 사용자 관리 **getNotificationAppInfo**가 알림 서비스 V1과 V2를 호출합니다.
- 레플리카 수에 따라 V1과 V2로 트래픽을 분산합니다.

| NS V1 레플리카 | NS V2 레플리카 | 트래픽 분산 |
| -------------- | -------------- | -------------------- |
| 4 | 0 | NS V1 버전에 100% 트래픽 |
| 3 | 1 | NS V2 버전에 25% 트래픽 |
| 2 | 2 | NS V2 버전에 50% 트래픽 |
| 1 | 3 | NS V2 버전에 75% 트래픽 |
| 0 | 4 | NS V2 버전에 100% 트래픽 |

- 데모에서는 V1과 V2에 각각 50% 트래픽을 분산합니다.
- NS V1 - 2 레플리카, NS V2 - 2 레플리카
- AWS X-Ray에서 서로 다른 버전의 마이크로서비스 호출을 확인합니다.

### 이 섹션에서 사용하는 Docker 이미지 목록
| 애플리케이션 이름                 | Docker 이미지 이름                          |
| ------------------------------- | --------------------------------------------- |
| 사용자 관리 마이크로서비스 | stacksimplify/kube-usermanagement-microservice:3.0.0-AWS-XRay-MySQLDB |
| 알림 마이크로서비스 V1 | stacksimplify/kube-notifications-microservice:3.0.0-AWS-XRay |
| 알림 마이크로서비스 V2 | stacksimplify/kube-notifications-microservice:4.0.0-AWS-XRay |

## Step-02: 사전 준비: AWS RDS Database, ALB Ingress Controller, External DNS & X-Ray 데몬

### AWS RDS Database
- [06-EKS-Storage-with-RDS-Database](/06-EKS-Storage-with-RDS-Database/README.md) 섹션에서 AWS RDS Database를 생성했습니다.
- RDS Database를 가리키는 `externalName service: 01-MySQL-externalName-Service.yml`도 이미 생성했습니다.

### ALB Ingress Controller & External DNS
- `ALB Ingress Service`와 `External DNS`가 포함된 애플리케이션을 배포합니다.
- 따라서 EKS 클러스터에 관련 Pod가 실행 중이어야 합니다.
- [08-01-ALB-Ingress-Install](/08-ELB-Application-LoadBalancers/08-01-ALB-Ingress-Install/README.md) 섹션에서 **ALB Ingress Controller**를 설치했습니다.
- [08-06-01-Deploy-ExternalDNS-on-EKS](/08-ELB-Application-LoadBalancers/08-06-ALB-Ingress-ExternalDNS/08-06-01-Deploy-ExternalDNS-on-EKS/README.md) 섹션에서 **External DNS**를 설치했습니다.

### XRay Daemon
- AWS X-Ray에서 애플리케이션 트레이스를 보기 위해 XRay Daemon이 DaemonSet으로 실행되어야 합니다.
```
# kube-system 네임스페이스의 alb-ingress-controller Pod 확인
kubectl get pods -n kube-system

# default 네임스페이스의 external-dns & xray-daemon Pod 확인
kubectl get pods
```

## Step-03: V2 알림 서비스 Deployment 매니페스트 확인
- V1과 V2 각각 50% 트래픽을 분산합니다.


| NS V1 레플리카 | NS V2 레플리카 | 트래픽 분산 |
| -------------- | -------------- | -------------------- |
| 2 | 2 | NS V2 버전에 50% 트래픽 |

- **08-V2-NotificationMicroservice-Deployment.yml**
```yml
# 변경-1: 이미지 태그는 4.0.0-AWS-XRay
    spec:
      containers:
        - name: notification-service
          image: stacksimplify/kube-notifications-microservice:4.0.0-AWS-XRay

# 변경-2: AWS X-Ray 관련 환경 변수 추가
            - name: AWS_XRAY_TRACING_NAME 
              value: "V2-Notification-Microservice"              
            - name: AWS_XRAY_DAEMON_ADDRESS
              value: "xray-service.default:2000"      
            - name: AWS_XRAY_CONTEXT_MISSING 
              value: "LOG_ERROR"  # 에러를 로그로 남기고 진행 (기본값은 RUNTIME_ERROR)
```


## Step-04: Ingress 매니페스트 확인
- **07-ALB-Ingress-SSL-Redirect-ExternalDNS.yml**
```yml
# 변경-1: 사용 중인 SSL Cert ARN으로 업데이트
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:180789647333:certificate/9f042b5d-86fd-4fad-96d0-c81c5abc71e1

# 변경-2: "yourdomainname.com"으로 업데이트
    # External DNS - Route53에 레코드 셋 생성
    external-dns.alpha.kubernetes.io/hostname: canarydemo.kubeoncloud.com
```

## Step-05: 매니페스트 배포
```
# 배포
kubectl apply -f kube-manifests/

# 확인
kubectl get deploy,svc,pod
```
## Step-06: 테스트
```
# 테스트
https://canarydemo.kubeoncloud.com/usermgmt/notification-xray

# 내 도메인
https://<Replace-your-domain-name>/usermgmt/notification-xray
```

## Step-07: 백그라운드 동작 설명
- `Notification Cluster IP Service`의 selector label이 `Notification V1/V2 Deployment`의 selector.matchLabels과 일치하면 해당 Pod로 트래픽이 전달됩니다.
```yml
# Notification Cluster IP Service - Selector Label
  selector:
    app: notification-restapp

# Notification V1/V2 Deployment - Selector Match Labels
  selector:
    matchLabels:
      app: notification-restapp         
```

## Step-08: 정리
- 이 섹션에서 생성한 애플리케이션을 삭제합니다.
```
# 앱 삭제
kubectl delete -f kube-manifests/
```

## Step-09: 이 접근 방식의 단점
- 프레젠테이션에서 단점을 검토합니다.

## Step-10: 카나리 배포의 베스트 프랙티스
- Istio (오픈 소스)
- AWS AppMesh (AWS 버전의 Istio)
