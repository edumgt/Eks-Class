# EKS 스토리지 - 스토리지 클래스, 영구 볼륨 클레임

## Step-01: 소개
- AWS EBS 볼륨을 사용해 영속 스토리지가 있는 MySQL 데이터베이스를 생성합니다.

| Kubernetes 오브젝트  | YAML 파일 |
| ------------- | ------------- |
| Storage Class  | 01-storage-class.yml |
| Persistent Volume Claim | 02-persistent-volume-claim.yml   |
| Config Map  | 03-UserManagement-ConfigMap.yml  |
| Deployment, Environment Variables, Volumes, VolumeMounts  | 04-mysql-deployment.yml  |
| ClusterIP Service  | 05-mysql-clusterip-service.yml  |

## Step-02: 다음 Kubernetes 매니페스트 생성
### Storage Class 매니페스트 생성
- https://kubernetes.io/docs/concepts/storage/storage-classes/#volume-binding-mode
- **중요:** `WaitForFirstConsumer` 모드는 PersistentVolumeClaim을 사용하는 파드가 생성될 때까지 PersistentVolume의 바인딩 및 프로비저닝을 지연합니다.

### Persistent Volume Claim 매니페스트 생성
```
# Storage Class 및 PVC 생성
kubectl apply -f kube-manifests/

# Storage Classes 목록
kubectl get sc

# PVC 목록
kubectl get pvc 

# PV 목록
kubectl get pv
```
### ConfigMap 매니페스트 생성
- MySQL 파드 생성 시 `usermgmt` 데이터베이스 스키마를 만들고, 이후 User Management 마이크로서비스 배포 시 활용합니다.

### MySQL Deployment 매니페스트 생성
- 환경 변수
- 볼륨
- 볼륨 마운트

### MySQL ClusterIP Service 매니페스트 생성
- 이 설계에서는 MySQL 파드가 하나만 존재하므로 `ClusterIP: None`을 사용해 별도의 IP를 생성/할당하지 않고 `Pod IP Address`를 사용합니다.

## Step-03: 위 매니페스트로 MySQL 데이터베이스 생성
```
# MySQL 데이터베이스 생성
kubectl apply -f kube-manifests/

# Storage Classes 목록
kubectl get sc

# PVC 목록
kubectl get pvc 

# PV 목록
kubectl get pv

# 파드 목록
kubectl get pods 

# 라벨 이름으로 파드 목록
kubectl get pods -l app=mysql
```

## Step-04: MySQL 데이터베이스 연결
```
# MySQL 데이터베이스 연결
kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql -pdbpassword11

[or]

# 최신 mysql 클라이언트 태그 사용
kubectl run -it --rm --image=mysql:latest --restart=Never mysql-client -- mysql -h mysql -pdbpassword11

# ConfigMap에 설정한 usermgmt 스키마가 생성되었는지 확인
mysql> show schemas;
```

## Step-05: 참고 자료
- 참고 자료는 여기에서 별도로 확인합니다.
- 환경에 맞는 템플릿을 작성하는 데 도움이 됩니다.
- 일부 기능은 현재 알파 단계입니다(예: Resizing). 베타 단계에 도달하면 템플릿을 활용해 테스트할 수 있습니다.
- **EBS CSI Driver:** https://github.com/kubernetes-sigs/aws-ebs-csi-driver
- **EBS CSI Driver 동적 프로비저닝:**  https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes/dynamic-provisioning
- **EBS CSI Driver - Resizing, Snapshot 등 다른 예시:** https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes
- **k8s API 참고 문서:** https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#storageclass-v1-storage-k8s-io


