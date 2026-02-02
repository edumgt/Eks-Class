# EBS(Elastic Block Store)로 EKS 스토리지 구성

<img width="1594" height="475" alt="image" src="https://github.com/user-attachments/assets/5072c556-701a-4ee4-b2d9-e661bea7667b" />


## Step-01: 소개
- EBS용 IAM 정책 생성
- 워커 노드 IAM 역할에 IAM 정책 연결
- EBS CSI 드라이버 설치

---
# EKS에서 EBS란?

EKS에서 말하는 **EBS(Elastic Block Store)** 는 **쿠버네티스 워크로드(Pod)가 사용할 “영구 디스크(블록 스토리지)”를 AWS에서 제공하는 방식**이다.  
즉, **Pod의 로컬 디스크가 아니라 분리된 디스크를 붙였다 떼도 데이터가 남도록** 해주는 스토리지다.

---

## EKS에서 EBS가 쓰이는 기본 흐름 (가장 흔한 패턴)

1. 앱(Pod/StatefulSet)이 **PVC(PersistentVolumeClaim)** 를 생성한다.

---
# Kubernetes StatefulSet 설명

## 1) StatefulSet이란?

**StatefulSet**은 Kubernetes에서 **“상태(state)를 가지는 애플리케이션”**을 안정적으로 운영하기 위한 워크로드 컨트롤러다.  
Deployment처럼 Pod를 여러 개 띄우는 것은 동일하지만, StatefulSet은 특히 아래를 **보장/지원**한다.

- **고정된 Pod 식별자(이름/순서, ordinal)**  
  `app-0`, `app-1`, `app-2` 처럼 **번호가 붙는 고정된 Pod 이름**을 가진다.  
  재스케줄/재생성되더라도 **해당 ordinal의 정체성**이 유지된다.
- **안정적인 네트워크 식별자(DNS)**  
  각 Pod가 “고정된 이름”으로 접근 가능하도록 구성하는 패턴을 제공한다.  
  보통 **Headless Service**와 함께 사용해 `app-0.<svc>`, `app-1.<svc>` 같은 형태의 DNS를 쓴다.
- **Pod별 영구 스토리지 유지**  
  각 Pod가 **자기 전용 PVC/PV**를 갖고 Pod가 재생성되어도 **같은 볼륨을 계속 사용**할 수 있다.

> 참고(공식 문서): Kubernetes Concepts - StatefulSet  
> https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

---

## 2) 언제 StatefulSet을 쓰나?

다음처럼 “각 인스턴스가 서로 교체 가능한 복제본이 아니라, 고유한 정체성과 디스크를 가져야 하는” 경우에 적합하다.

- DB: MySQL / PostgreSQL 등
- 분산 KV/메타데이터: etcd 등
- 로그/메시징/스트리밍: Kafka 등 (구성에 따라)
- 리더 선출 / 클러스터 멤버십 / 순서 기반 초기화가 필요한 서비스

반대로, 웹/API 서버처럼 **stateless(상태 없음)** 앱은 보통 Deployment가 더 단순하고 운영이 쉽다.

---

## 3) Deployment와의 차이(운영 관점)

### Deployment
- Pod들이 **서로 완전히 동일하고 교체 가능**
- “Pod N개”라는 수량이 핵심
- 어느 Pod가 어느 노드에 떠도 큰 상관이 없음(캐틀)

### StatefulSet
- Pod 각각이 **고유한 정체성(이름/순서/역할)** 을 가짐
- Pod별로 **독립적인 디스크(PVC/PV)** 를 유지
- 순서/안정성(예: `-0` → `-1` → `-2`)이 중요(펫)

---

## 4) Headless Service가 거의 필수인 이유

StatefulSet은 일반적으로 **Headless Service(ClusterIP: None)** 와 함께 사용한다.

- Headless Service를 사용하면
  - 로드밸런싱된 단일 VIP가 아니라
  - **각 Pod의 DNS 레코드**를 안정적으로 제공할 수 있다.
- 그래서 다음처럼 Pod별로 접근 가능해진다:
  - `web-0.web-headless`
  - `web-1.web-headless`

이 패턴이 DB/클러스터링 서비스 구성에서 매우 중요하다.

---

## 5) 스토리지: `volumeClaimTemplates`의 의미

StatefulSet의 핵심 기능 중 하나가 `volumeClaimTemplates` 이다.

- `volumeClaimTemplates`에 PVC 템플릿을 정의해두면,
- Pod가 생성될 때마다 **Pod별 PVC가 자동 생성**된다.
  - 예: `data-web-0`, `data-web-1`, `data-web-2`
- Pod가 재생성되어도 해당 ordinal의 PVC를 다시 연결하여
  **데이터가 유지된다.**

---

## 6) 업데이트/롤링 업데이트 동작

StatefulSet도 `.spec.updateStrategy`로 업데이트 방식을 제어한다.

- **RollingUpdate**
  - 기본적으로 **순차 업데이트** (운영 안정성을 우선)
- **OnDelete**
  - 템플릿을 바꿔도 자동으로 교체되지 않음
  - 운영자가 Pod를 **직접 삭제**할 때 새 템플릿으로 재생성
- (선택) **partition**
  - “일부 ordinal까지만 먼저 업데이트” 같은 단계적/카나리 운영이 가능

> 참고(공식 문서/튜토리얼):  
> - StatefulSet 개념: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/  
> - 기본 StatefulSet 튜토리얼: https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/

---

## 7) 최소 뼈대 예시 (구조 이해용)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web-headless   # 보통 Headless Service 이름
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: your-image:tag
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi

---

2. PVC가 **StorageClass** 를 참고한다.
3. 클러스터에 설치된 **Amazon EBS CSI Driver** 가
   - 필요한 EBS 볼륨을 **동적으로 생성(동적 프로비저닝)** 하고
   - PV(PersistentVolume)로 연결한다.
4. Pod가 해당 PV를 **마운트** 해서 디스크처럼 사용한다.

---

## EBS를 쓰면 좋은 경우

- **DB / 메시지 큐 / 상태가 있는 서비스** 등 “디스크에 데이터 저장이 반드시 필요한” 워크로드
- “빠른 단일 디스크” 성격의 블록 스토리지가 필요할 때

---

## 실무에서 중요한 제약/특징

### 1) AZ(가용 영역) 제약
- **EBS 볼륨은 특정 AZ에 묶인다.**
- 그 볼륨을 쓰는 Pod도 보통 **같은 AZ에 배치되어야** 한다.
- 그래서 StorageClass에서 `volumeBindingMode: WaitForFirstConsumer` 를 많이 사용한다.  
  (Pod가 어디에 뜰지 정해진 뒤, 그 AZ에 맞춰 볼륨 생성)

### 2) 접근 모드 제약 (일반적인 경우)
- EBS는 보통 **RWO(ReadWriteOnce)** 형태로 사용된다.
- 즉, **여러 노드가 동시에 같은 디스크를 공유** 하는 용도에는 보통 적합하지 않다.
  (공유 파일 스토리지는 EFS가 더 적합)

---

## EBS vs EFS 한 줄 비교

- **EBS**: 한 Pod(노드) 중심의 빠른 **블록 디스크**  
  → DB/상태 저장 워크로드에 적합
- **EFS**: 여러 Pod가 동시에 붙는 **공유 파일 시스템**  
  → 업로드 공유, 정적 파일 공유, 다중 리더/라이터에 적합

---

## 설치/운영 방식 (EKS 기준)

- EKS에서는 보통 **EKS Add-on (`aws-ebs-csi-driver`)** 로 설치/관리한다.
- (환경에 따라 Auto Mode 같은 구성에서는 설치/구성이 달라질 수 있음)

---

## 용어 미니 정리

- **PV (PersistentVolume)**: 클러스터에 “실제 스토리지 리소스”로 등록된 볼륨
- **PVC (PersistentVolumeClaim)**: 앱이 “이런 디스크가 필요해요”라고 요청하는 청구서
- **StorageClass**: “어떤 타입의 디스크를 어떤 정책으로 만들지” 정의
- **CSI Driver**: 쿠버네티스가 외부 스토리지(EBS 등)를 붙이기 위해 쓰는 표준 드라이버

---
---

## Step-02: IAM 정책 생성
- Services -> IAM 이동
- 정책 생성
  - JSON 탭을 선택하고 아래 JSON을 복사하여 붙여넣기
```json

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteSnapshot",
        "ec2:DeleteTags",
        "ec2:DeleteVolume",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume"
      ],
      "Resource": "*"
    }
  ]
}
```
  - **Visual Editor**에서 내용 확인
  - **Review Policy** 클릭
  - **Name:** Amazon_EBS_CSI_Driver
  - **Description:** EC2 인스턴스가 Elastic Block Store에 접근하기 위한 정책
  - **Create Policy** 클릭

## Step-03: 워커 노드 IAM 역할 확인 및 정책 연결
```
# 워커 노드 IAM 역할 ARN 확인
kubectl -n kube-system describe configmap aws-auth
```
---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl -n kube-system describe configmap aws-auth
E0203 06:15:01.309021    8128 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
E0203 06:15:01.310763    8128 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
E0203 06:15:01.312222    8128 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
E0203 06:15:01.313814    8128 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
E0203 06:15:01.315258    8128 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
The connection to the server kubernetes.docker.internal:6443 was refused - did you specify the right host or port?
```
---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ aws sts get-caller-identity
aws configure get region

aws eks list-clusters --region ap-northeast-2
aws eks update-kubeconfig --region ap-northeast-2 --name eksdemo1
```
---
```
{
    "UserId": "AIDARIBXLWVE6SSOENPWT",
    "Account": "086015456585",
    "Arn": "arn:aws:iam::086015456585:user/devuser"
}
ap-northeast-2
{
    "clusters": [
        "eksdemo1"
    ]
}
Added new context arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1 to /home/kimdy/.kube/config
```
---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl config get-contexts
kubectl config use-context arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1
```
---
```
CURRENT   NAME                                                       CLUSTER                                                    AUTHINFO                                                   NAMESPACE
*         arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1   arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1   arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1   
          docker-desktop                                             docker-desktop                                             docker-desktop                                             
Switched to context "arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1".
```
---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl config view --minify | egrep "current-context:|server:|name:"
kubectl get nodes
    server: https://346264711D0B5AAC4717CFF57E3D0C45.gr7.ap-northeast-2.eks.amazonaws.com
  name: arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1
  name: arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1
current-context: arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1
- name: arn:aws:eks:ap-northeast-2:086015456585:cluster/eksdemo1
NAME                                               STATUS   ROLES    AGE   VERSION
ip-192-168-0-101.ap-northeast-2.compute.internal   Ready    <none>   12h   v1.32.9-eks-ecaa3a6
ip-192-168-60-15.ap-northeast-2.compute.internal   Ready    <none>   12h   v1.32.9-eks-ecaa3a6
```

---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl -n kube-system describe configmap aws-auth
Name:         aws-auth
Namespace:    kube-system
Labels:       <none>
Annotations:  <none>

Data
====
mapRoles:
----
- rolearn: arn:aws:iam::086015456585:role/eksctl-eksdemo1-nodegroup-eksdemo1-NodeInstanceRole-BOxQqYiPVBTa
  groups:
  - system:bootstrappers
  - system:nodes
  username: system:node:{{EC2PrivateDNSName}}



BinaryData
====

Events:  <none>
```
---

```

# 출력에서 rolearn 확인
rolearn: arn:aws:iam::086015456585:role/eksctl-eksdemo1-nodegroup-eksdemo1-NodeInstanceRole-BOxQqYiPVBTa

```
- Services -> IAM -> Roles 이동
- **eksctl-eksdemo1-nodegroup** 이름의 역할 검색 후 열기

![alt text](image.png)

- **Permissions** 탭 클릭
- **Attach Policies** 클릭

![alt text](image-1.png)

- **AmazonEBS**를 검색해 **Attach Policy** 클릭

![alt text](image-2.png)

## Step-04: Amazon EBS CSI 드라이버 배포
- kubectl 버전이 1.14 이상인지 확인
```
kubectl version --client

kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl version --client
Client Version: v1.35.0
Kustomize Version: v5.7.1
```
- Amazon EBS CSI 드라이버 배포

# EBS CSI 드라이버 배포
# 1) kustomize 결과를 파일로 뽑고
### Kustomize는 쿠버네티스 매니페스트(YAML)를 “템플릿 없이” 환경별로 변형/조합해서 최종 YAML을 만들어 주는 도구

```
kubectl kustomize "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master" > ebs.yaml
```

# 2) 문제 필드 제거 (그냥 한 줄 삭제)
```
sed -i '/nodeAllocatableUpdatePeriodSeconds/d' ebs.yaml
```
# 3) 다시 적용
```
kubectl apply -f ebs.yaml
```

kubectl get csidriver | grep ebs
kubectl -n kube-system get pods -l app=ebs-csi-controller
kubectl -n kube-system get pods -l app=ebs-csi-node


# ebs-csi 파드 실행 확인
kubectl get pods -n kube-system
```
---
```
kimdy@DESKTOP-CLQV18N:~/Eks-Class$ kubectl get pods -n kube-system
NAME                                  READY   STATUS    RESTARTS   AGE
aws-node-5wnfz                        2/2     Running   0          13h
aws-node-rqm2l                        2/2     Running   0          13h
coredns-844d8f59bb-j9dnn              1/1     Running   0          13h
coredns-844d8f59bb-ml8xv              1/1     Running   0          13h
ebs-csi-controller-65697479cb-67l2c   6/6     Running   0          2m42s
ebs-csi-controller-65697479cb-s9tpz   6/6     Running   0          2m42s
ebs-csi-node-5hl26                    3/3     Running   0          2m41s
ebs-csi-node-tvzpg                    3/3     Running   0          2m41s
kube-proxy-9b6wb                      1/1     Running   0          13h
kube-proxy-fsz28                      1/1     Running   0          13h
metrics-server-6d994b8776-6gdx6       1/1     Running   0          13h
metrics-server-6d994b8776-7nzkr       1/1     Running   0          13h
```