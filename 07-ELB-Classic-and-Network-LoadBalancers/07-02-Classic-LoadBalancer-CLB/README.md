# AWS - 클래식 로드 밸런서 - CLB

## 단계-01: AWS 클래식 로드 밸런서 Kubernetes 매니페스트 생성 및 배포
- **04-ClassicLoadBalancer.yml**
```yml
apiVersion: v1
kind: Service
metadata:
  name: clb-usermgmt-restapp
  labels:
    app: usermgmt-restapp
spec:
  type: LoadBalancer  # 일반적인 k8s Service 매니페스트에서 type을 LoadBalancer로 설정
  selector:
    app: usermgmt-restapp     
  ports:
  - port: 80
    targetPort: 8095
```
---
```
Service.spec.type 에 들어갈 수 있는 값(종류)은 기본적으로 아래 4가지예요. (type을 안 쓰면 기본값은 ClusterIP)

1) ClusterIP (기본값)

클러스터 내부에만 가상 IP(Cluster IP)를 만들고 클러스터 내부 통신용으로만 노출

예: 내부 API, DB 앞단, 내부 마이크로서비스

2) NodePort

각 노드의 특정 포트(보통 30000~32767)를 열어서

NodeIP:NodePort 로 외부에서 접근 가능

클라우드 LB 없이도 테스트 가능하지만, 운영에서는 보통 LB와 같이 쓰거나 제한적으로 사용

3) LoadBalancer

클라우드 제공자(AWS 등)의 외부 로드밸런서를 붙여서 서비스 외부 노출

대부분 내부적으로는 NodePort/ClusterIP를 함께 구성한 뒤, 그 앞에 LB가 붙는 형태

예: type: LoadBalancer (지금 작성하신 케이스)

4) ExternalName

서비스에 프록시/로드밸런싱을 만들지 않고, 외부 DNS 이름(CNAME) 으로 매핑

예: spec.externalName: api.example.com

주로 “클러스터 밖의 서비스”를 내부 DNS처럼 쓰고 싶을 때
```
---


- **모든 매니페스트 배포**
```
# 모든 매니페스트 배포
kubectl apply -f kube-manifests/

# 서비스 목록 조회 (새로 생성된 CLB 서비스 확인)
kubectl get svc

# 파드 확인
kubectl get pods
```
---
# kubectl apply 결과가 eksdemo1 / eksdemo2 중 어디에 적용됐는지 확인하기

`kubectl apply -f kube-manifests/` 실행 결과로 리소스가 생성되었을 때, **어느 EKS 클러스터(eksdemo1 / eksdemo2)에 적용됐는지**는 전적으로 그 순간 `kubectl`이 사용한 **현재 컨텍스트(current-context)** 로 결정된다.

---

## 1) 가장 빠른 확인: current-context 확인

```bash
kubectl config current-context
kubectl config get-contexts
```

- `kubectl config get-contexts` 출력에서 `*` 표시된 항목이 **현재 사용 중인 컨텍스트**
- 그 컨텍스트가 가리키는 클러스터에 `apply`가 수행됨

---

## 2) 현재 컨텍스트가 실제로 바라보는 클러스터(엔드포인트) 확인

```bash
kubectl config view --minify
kubectl cluster-info
```

- `kubectl cluster-info` 에서 나오는 Kubernetes control plane 주소(API server endpoint)가
  현재 `kubectl`이 붙어있는 클러스터의 주소

---

## 3) 가장 확실한 방법: 두 클러스터에 각각 조회해보기 (--context)

먼저 컨텍스트 이름을 확인:

```bash
kubectl config get-contexts
```

예를 들어 컨텍스트 이름이 `eksdemo1`, `eksdemo2` 라면 아래처럼 **각각 조회**한다.

```bash
kubectl get svc    --context eksdemo1
kubectl get deploy  --context eksdemo1
kubectl get secret  --context eksdemo1

kubectl get svc    --context eksdemo2
kubectl get deploy  --context eksdemo2
kubectl get secret  --context eksdemo2
```

방금 생성된 리소스 목록(예시):

- `service/mysql`
- `deployment.apps/usermgmt-microservice`
- `secret/mysql-db-password`
- `service/clb-usermgmt-restapp`

➡️ 위 리소스가 **보이는 쪽 클러스터가 설치(적용)된 클러스터**다.

---

## 4) 헷갈릴 수 있는 원인 체크

### 4-1) KUBECONFIG 환경변수로 여러 kubeconfig를 쓰는 경우
```bash
echo $KUBECONFIG
```
- 여러 설정 파일을 쓰면, 의도치 않은 컨텍스트가 선택되어 있을 수 있음

### 4-2) aws eks update-kubeconfig 를 마지막에 실행한 클러스터가 current-context가 되는 경우
예:
```bash
aws eks update-kubeconfig --region ap-northeast-2 --name eksdemo2
```
- 위를 마지막에 실행했다면 current-context가 eksdemo2로 바뀌어 apply가 eksdemo2에 들어갔을 가능성이 큼

---

## 5) 결론

- **정답:** `kubectl apply` 가 적용된 클러스터는 **apply 실행 당시의 current-context가 가리키는 클러스터**
- 가장 확실한 검증은 `--context`로 **eksdemo1 / eksdemo2에 각각 조회해서 리소스가 존재하는지 확인**하는 것

---


## 단계-02: 배포 확인
- 새로운 CLB가 생성되었는지 확인
  - Services -> EC2 -> Load Balancing -> Load Balancers 로 이동
    - CLB가 생성되어 있어야 함
    - DNS 이름 복사 (예: a85ae6e4030aa4513bd200f08f1eb9cc-7f13b3acc1bcaaa2.elb.us-east-1.amazonaws.com)
  - Services -> EC2 -> Load Balancing -> Target Groups 로 이동
    - 헬스 상태를 확인하고 active 상태인지 확인
- **애플리케이션 접속**
```
# 애플리케이션 접속
http://<CLB-DNS-NAME>/usermgmt/health-status
```    

## 단계-03: 정리
```
# 생성된 모든 오브젝트 삭제
kubectl delete -f kube-manifests/

# 현재 Kubernetes 오브젝트 확인
kubectl get all
```
