# AWS EKS에서 X-Ray로 마이크로서비스 분산 추적

## Step-01: 소개
### AWS X-Ray & k8s DaemonSets 소개
- AWS X-Ray 서비스 이해
- Kubernetes DaemonSets 이해

---

# Kubernetes DaemonSet 이해 (정리)

DaemonSet(데몬셋)은 **클러스터의 모든 노드(또는 조건에 맞는 일부 노드)** 에 **같은 Pod를 1개씩** 항상 실행되도록 보장하는 Kubernetes 워크로드 컨트롤러다.  
노드가 추가되면 해당 노드에 Pod가 자동으로 생성되고, 노드가 제거되면 Pod도 같이 정리된다.  
공식 개념 문서: Kubernetes DaemonSet 소개(Concepts) 참고.  
(출처: Kubernetes 공식 문서)

---

## 1. DaemonSet이 필요한 이유

Kubernetes에서 일반적인 애플리케이션은 **Deployment** 로 운영하며, “Pod N개”를 스케일하고 스케줄러가 적절한 노드에 분산 배치한다.

반면, DaemonSet은 “스케일 수”를 맞추는 목적이 아니라, **노드마다 반드시 존재해야 하는 에이전트/데몬**을 배치하기 위해 존재한다.

예를 들어:
- 노드의 로그 파일 / 컨테이너 로그를 수집
- 노드의 CPU/메모리/디스크/네트워크 메트릭을 수집
- 보안/감사/침입 탐지 에이전트 실행
- 노드별 네트워크/스토리지 관련 구성 요소 실행

---

## 2. Deployment vs DaemonSet 차이

### Deployment
- “Pod N개”를 원하는 만큼 생성
- 스케줄러가 적절한 노드에 분산 배치
- 서비스 트래픽을 받는 일반 앱(웹, API 서버 등)에 적합

### DaemonSet
- “노드 1대당 Pod 1개”가 기본 원칙
- 노드가 늘면 Pod도 자동으로 늘어남
- 노드가 줄면 Pod도 자동으로 줄어듦
- 노드별 에이전트/데몬에 적합

---

## 3. `kubectl drain` 할 때 DaemonSet Pod 때문에 막히는 이유

`kubectl drain <node>` 는 해당 노드의 Pod를 다른 노드로 “비우는” 작업이다.

그런데 DaemonSet Pod는 “노드마다 항상 있어야 하는 것”이므로,
기본적으로 drain은 DaemonSet-managed Pod를 강제로 삭제하지 않도록 막는다.

그래서 이런 메시지가 흔히 보인다:

- `cannot delete DaemonSet-managed Pods ...`

실무에서는 보통 다음 옵션을 함께 쓴다:

- `kubectl drain <node> --ignore-daemonsets`

> 참고: DaemonSet Pod는 “원래 해당 노드에 있어야 하는” 성격이라  
> drain 시에는 “무시”하는 게 일반적이다(다만 운영 정책에 따라 예외가 있을 수 있음).

---

## 4. 모든 노드가 아니라 “일부 노드에만” 배치하는 방법

DaemonSet은 기본적으로 “모든 노드” 대상이지만, 다음 조건으로 제한할 수 있다:

- `nodeSelector` : 특정 라벨 가진 노드에만 배치
- `nodeAffinity` : 더 복잡한 조건 기반 배치
- `tolerations` : taint가 걸린 노드(control-plane 등)에도 배치할지 결정

예:
- “워크 노드에만 설치”
- “GPU 노드에만 설치”
- “control-plane에도 에이전트를 올리기”

---

## 5. DaemonSet 업데이트 전략

DaemonSet도 업데이트 방식이 있다(주로 2개).

### RollingUpdate (일반적으로 많이 사용)
- 템플릿 변경 시 노드들을 순차적으로 업데이트
- 기존 Pod를 교체하며 점진적으로 반영

### OnDelete
- 템플릿을 바꿔도 기존 Pod는 그대로 유지
- 운영자가 Pod를 직접 삭제할 때만 새 템플릿으로 재생성

> 운영 환경에서는 “에이전트가 동시에 모두 내려가는 상황”을 피하기 위해  
> RollingUpdate 전략과 업데이트 속도 조절이 중요하다.

---

## 6. 가장 단순한 DaemonSet YAML 뼈대

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      containers:
        - name: agent
          image: your-image:latest


---
---
# Kubernetes Headless Service 정리

## 1) Headless Service란?

**Headless Service**는 Kubernetes Service의 한 형태로,  
일반 Service처럼 **클러스터 내부 가상 IP(ClusterIP)를 만들지 않고**,  
대신 **Service가 선택한 Pod들의 IP 목록을 DNS로 그대로 반환**하도록 하는 Service다.

- 핵심 설정: `spec.clusterIP: None`

> 참고(공식 문서)  
> - Service 개념: https://kubernetes.io/docs/concepts/services-networking/service/  
> - DNS for Services/Pods: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

---

## 2) 일반 Service(ClusterIP) vs Headless Service 차이

### 일반 Service (ClusterIP 있음)
- Service DNS를 조회하면 **Service의 ClusterIP 1개**가 나온다.
- 트래픽은 kube-proxy(iptables/ipvs) 규칙을 통해 **뒤의 Pod들로 로드밸런싱**된다.
- 클라이언트 입장에서는 “하나의 Service IP로 접속”하면 됨.

### Headless Service (ClusterIP: None)
- Service DNS를 조회하면 **Pod들의 IP가 여러 개(A/AAAA 레코드 여러 개)** 로 반환된다.
- Service가 “가상 IP로 프록시/로드밸런싱”을 하지 않고,
  클라이언트가 **직접 Pod IP로 접속**하는 형태가 된다.
- 주로 **Pod 개별 식별이 중요한 워크로드**에 사용된다.

---

## 3) 언제 쓰나? (대표 사용 사례)

### StatefulSet과 함께 (가장 흔한 사용)
StatefulSet은 `app-0`, `app-1` 처럼 Pod마다 **고정된 이름/정체성**이 중요하다.  
Headless Service를 사용하면 각 Pod에 **예측 가능한 DNS**로 접근 가능해진다.

예시 접근 형태:
- `web-0.web-headless.<namespace>.svc.cluster.local`
- `web-1.web-headless.<namespace>.svc.cluster.local`

이 패턴은 다음 상황에서 유리하다:
- DB 클러스터(Primary/Replica) 구성
- 분산 시스템의 멤버 간 직접 통신
- 특정 인스턴스(리더/팔로워 등)에 정확히 붙어야 하는 서비스

> 참고(공식 문서)  
> - StatefulSet 개념: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

---

## 4) Headless Service YAML 예시

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  namespace: demo
spec:
  clusterIP: None         # Headless의 핵심
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80

---



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
