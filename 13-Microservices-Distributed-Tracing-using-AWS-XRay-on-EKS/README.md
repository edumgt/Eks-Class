# AWS EKS에서 X-Ray로 마이크로서비스 분산 추적

## Step-01: 소개
### AWS X-Ray & k8s DaemonSets 소개
- AWS X-Ray 서비스 이해
- Kubernetes DaemonSets 이해
- EKS 클러스터에서 AWS X-Ray와 마이크로서비스 네트워크 설계 이해
- AWS X-Ray의 Service Map, Traces, Segments 이해

### 사용 사례 설명
- 사용자 관리 **getNotificationAppInfo**가 알림 서비스 **notification-xray**를 호출하고, 이 과정에서 AWS X-Ray로 트레이스를 전송합니다.
- 하나의 마이크로서비스가 다른 마이크로서비스를 호출하는 구조를 보여줍니다.

### 이 섹션에서 사용하는 Docker 이미지 목록
| 애플리케이션 이름                 | Docker 이미지 이름                          |
| ------------------------------- | --------------------------------------------- |
| 사용자 관리 마이크로서비스 | stacksimplify/kube-usermanagement-microservice:3.0.0-AWS-XRay-MySQLDB |
| 알림 마이크로서비스 V1 | stacksimplify/kube-notifications-microservice:3.0.0-AWS-XRay |

## Step-02: 사전 준비: AWS RDS Database, ALB Ingress Controller & External DNS

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

## Step-03: AWS X-Ray 데몬을 위한 IAM 권한 생성
```
# 템플릿
eksctl create iamserviceaccount \
    --name service_account_name \
    --namespace service_account_namespace \
    --cluster cluster_name \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess \
    --approve \
    --override-existing-serviceaccounts

# 이름, 네임스페이스, 클러스터 정보 교체
eksctl create iamserviceaccount \
    --name xray-daemon \
    --namespace default \
    --cluster eksdemo1 \
    --attach-policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess \
    --approve \
    --override-existing-serviceaccounts
```

### 서비스 어카운트 및 AWS IAM 역할 확인
```
# k8s 서비스 어카운트 목록
kubectl get sa

# 서비스 어카운트 상세 (IAM Role 어노테이션 확인)
kubectl describe sa xray-daemon

# eksdemo1 클러스터에서 eksctl로 생성된 IAM 역할 목록
eksctl  get iamserviceaccount --cluster eksdemo1
```

## Step-04: xray-k8s-daemonset.yml에 IAM 역할 ARN 업데이트
### xray-daemon용 AWS IAM 역할 ARN 확인
```
# AWS IAM 역할 ARN 확인
eksctl  get iamserviceaccount xray-daemon --cluster eksdemo1
```
### xray-k8s-daemonset.yml 업데이트
- 파일 이름: kube-manifests/01-XRay-DaemonSet/xray-k8s-daemonset.yml
```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app: xray-daemon
  name: xray-daemon
  namespace: default
  # X-Ray 접근을 위한 IAM Role ARN 업데이트
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::180789647333:role/eksctl-eksdemo1-addon-iamserviceaccount-defa-Role1-20F5AWU2J61F
```

### EKS 클러스터에 X-Ray DaemonSet 배포
```
# 배포
kubectl apply -f kube-manifests/01-XRay-DaemonSet/xray-k8s-daemonset.yml

# Deployment, Service & Pod 확인
kubectl get deploy,svc,pod

# X-Ray 로그 확인
kubectl logs -f <X-Ray Pod Name>
kubectl logs -f xray-daemon-phszp  

# DaemonSet 목록 및 상세
kubectl get daemonset
kubectl describe daemonset xray-daemon
```

## Step-05: 마이크로서비스 애플리케이션 Deployment 매니페스트 확인
- **02-UserManagementMicroservice-Deployment.yml**
```yml
# 변경-1: 이미지 태그는 3.0.0-AWS-XRay-MySQLDB
      containers:
        - name: usermgmt-restapp
          image: stacksimplify/kube-usermanagement-microservice:3.0.0-AWS-XRay-MySQLDB

# 변경-2: AWS X-Ray 관련 환경 변수 추가
            - name: AWS_XRAY_TRACING_NAME 
              value: "User-Management-Microservice"                
            - name: AWS_XRAY_DAEMON_ADDRESS
              value: "xray-service.default:2000"    
            - name: AWS_XRAY_CONTEXT_MISSING 
              value: "LOG_ERROR"  # 에러를 로그로 남기고 진행 (기본값은 RUNTIME_ERROR)
```
- **04-NotificationMicroservice-Deployment.yml**
```yml
# 변경-1: 이미지 태그는 3.0.0-AWS-XRay
    spec:
      containers:
        - name: notification-service
          image: stacksimplify/kube-notifications-microservice:3.0.0-AWS-XRay

# 변경-2: AWS X-Ray 관련 환경 변수 추가
            - name: AWS_XRAY_TRACING_NAME 
              value: "V1-Notification-Microservice"              
            - name: AWS_XRAY_DAEMON_ADDRESS
              value: "xray-service.default:2000"      
            - name: AWS_XRAY_CONTEXT_MISSING 
              value: "LOG_ERROR"  # 에러를 로그로 남기고 진행 (기본값은 RUNTIME_ERROR)

```

## Step-06: Ingress 매니페스트 확인
- **07-ALB-Ingress-SSL-Redirect-ExternalDNS.yml**
```yml
# 변경-1: 사용 중인 SSL Cert ARN으로 업데이트
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:180789647333:certificate/9f042b5d-86fd-4fad-96d0-c81c5abc71e1

# 변경-2: "yourdomainname.com"으로 업데이트
    # External DNS - Route53에 레코드 셋 생성
    external-dns.alpha.kubernetes.io/hostname: services-xray.kubeoncloud.com, xraydemo.kubeoncloud.com             
```

## Step-07: 매니페스트 배포
```
# 배포
kubectl apply -f kube-manifests/02-Applications

# 확인
kubectl get pods
```

## Step-08: 테스트
```
# 테스트
https://xraydemo.kubeoncloud.com/usermgmt/notification-xray
https://xraydemo.kubeoncloud.com/usermgmt/notification-xray

# 내 도메인
https://<Replace-your-domain-name>/usermgmt/notification-xray
```

## Step-09: 정리
- 이 섹션에서 생성한 애플리케이션을 삭제합니다.
- 다음 섹션(카나리 배포)에서 활용하기 위해 X-Ray DaemonSet은 유지합니다.
```
# 앱 삭제
kubectl delete -f kube-manifests/02-Applications
```

## 참고 자료
- https://github.com/aws-samples/aws-xray-kubernetes/
- https://github.com/aws-samples/aws-xray-kubernetes/blob/master/xray-daemon/xray-k8s-daemonset.yaml
- https://aws.amazon.com/blogs/compute/application-tracing-on-kubernetes-with-aws-x-ray/
- https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-java-configuration.html
- https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-java-configuration.html#xray-sdk-java-configuration-plugins
- https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-java-httpclients.html
- https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-java-filters.html
- https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-java-sqlclients.html
