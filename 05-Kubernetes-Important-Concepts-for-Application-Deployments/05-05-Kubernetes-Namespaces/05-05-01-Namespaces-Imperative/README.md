# Kubernetes 네임스페이스 - kubectl 명령형 방식

## Step-01: 소개
- 네임스페이스는 리소스를 서로 다른 그룹으로 분리할 수 있습니다.
- 리소스 이름은 네임스페이스 내에서 고유해야 합니다.
- 네임스페이스를 사용해 dev, staging, production 등 여러 환경을 만들 수 있습니다.
- Kubernetes는 별도 지정이 없으면 항상 `default namespace`의 리소스를 표시합니다.

## Step-02: 네임스페이스 일반 - Dev1과 Dev2에 배포
### 네임스페이스 생성
```
# 네임스페이스 목록
kubectl get ns 

# 네임스페이스 생성
kubectl create namespace <namespace-name>
kubectl create namespace dev1
kubectl create namespace dev2

# 네임스페이스 목록
kubectl get ns 
```
### UserMgmt NodePort 서비스에서 NodePort 주석 처리
- **파일:** 07-UserManagement-Service.yml
- **이유:**
  - 네임스페이스로 dev1, dev2 등 여러 환경을 동일한 매니페스트로 생성할 때 동일한 워커 노드 포트를 사용할 수 없습니다.
  - 포트 충돌이 발생합니다.
  - 이런 경우 k8s가 동적 nodeport를 할당하도록 두는 것이 좋습니다.
```yml
      #nodePort: 31231
```
- 주석 처리하지 않을 경우 **오류**
```log
The Service "usermgmt-restapp-service" is invalid: spec.ports[0].nodePort: Invalid value: 31231: provided port is already allocated
```
### 모든 k8s 객체 배포
```
# 모든 k8s 객체 배포
kubectl apply -f kube-manifests/ -n dev1
kubectl apply -f kube-manifests/ -n dev2

# dev1 및 dev2 네임스페이스의 모든 객체 목록
kubectl get all -n dev1
kubectl get all -n dev2
```
## Step-03: SC, PVC, PV 확인
- **짧은 메모**
  - PVC는 네임스페이스 전용 리소스
  - PV와 SC는 공용 리소스
- **관찰-1:** `Persistent Volume Claim(PVC)`은 해당 네임스페이스에 생성됩니다.
```
# dev1과 dev2의 PVC 목록
kubectl get pvc -n dev1
kubectl get pvc -n dev2
```
- **관찰-2:** `Storage Class(SC)와 Persistent Volume(PV)`은 공용으로 생성되며 네임스페이스가 없습니다.
```
# sc, pv 목록
kubect get sc,pv
```
## Step-04: 애플리케이션 접근
### Dev1 네임스페이스
```
# 퍼블릭 IP 확인
kubectl get nodes -o wide

# dev1 usermgmt 서비스 NodePort 확인
kubectl get svc -n dev1

# 애플리케이션 접근
http://<Worker-Node-Public-Ip>:<Dev1-NodePort>/usermgmt/health-stauts
```
### Dev2 네임스페이스
```
# 퍼블릭 IP 확인
kubectl get nodes -o wide

# dev2 usermgmt 서비스 NodePort 확인
kubectl get svc -n dev2

# 애플리케이션 접근
http://<Worker-Node-Public-Ip>:<Dev2-NodePort>/usermgmt/health-stauts
```
## Step-05: 정리
```
# dev1 및 dev2 네임스페이스 삭제
kubectl delete ns dev1
kubectl delete ns dev2

# dev1 및 dev2 네임스페이스의 모든 객체 목록
kubectl get all -n dev1
kubectl get all -n dev2

# 네임스페이스 목록
kubectl get ns

# sc, pv 목록
kubectl get sc,pv

# Storage Class 삭제
kubectl delete sc ebs-sc

# 모든 네임스페이스에서 모든 객체 확인
kubectl get all -all-namespaces
```

## 참고 자료
- https://kubernetes.io/docs/tasks/administer-cluster/namespaces-walkthrough/
