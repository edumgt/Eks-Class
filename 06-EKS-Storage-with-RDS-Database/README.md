# AWS EKS 클러스터에서 실행되는 워크로드에 RDS 데이터베이스 사용

## Step-01: 소개
- MySQL 파드 & EBS CSI의 문제점은 무엇인가요?
- AWS RDS 데이터베이스로 어떻게 해결할까요?

## Step-02: RDS 데이터베이스 생성

### EKS 클러스터 VPC 확인
- 서비스 -> VPC로 이동
- **VPC 이름:**  eksctl-eksdemo1-cluster/VPC

### 사전 준비-1: DB 보안 그룹 생성
- 3306 포트에서 RDS 데이터베이스에 접근할 수 있도록 보안 그룹 생성
- 보안 그룹 이름: eks_rds_db_sg
- 설명: 3306 포트에서 RDS 데이터베이스 접근 허용
- VPC: eksctl-eksdemo1-cluster/VPC
- **인바운드 규칙**
  - 유형: MySQL/Aurora
  - 프로토콜: TPC
  - 포트: 3306
  - 소스: Anywhere (0.0.0.0/0)
  - 설명: 3306 포트에서 RDS 데이터베이스 접근 허용
- **아웃바운드 규칙**  
  - 기본값 그대로 유지

### 사전 준비-2: RDS에서 DB 서브넷 그룹 생성
- RDS -> Subnet Groups로 이동
- **Create DB Subnet Group** 클릭
  - **이름:** eks-rds-db-subnetgroup
  - **설명:** EKS RDS DB Subnet Group
  - **VPC:** eksctl-eksdemo1-cluster/VPC
  - **가용 영역:** us-east-1a, us-east-1b
  - **서브넷:** 2개 AZ에 2개 서브넷
  - **Create** 클릭

### RDS 데이터베이스 생성
- **Services -> RDS**로 이동
- **Create Database** 클릭
  - **Choose a Database Creation Method:** Standard Create
  - **Engine Options:** MySQL  
  - **Edition**: MySQL Community
  - **Version**: 5.7.22  (기본값)
  - **Template Size:** Free Tier
  - **DB instance identifier:** usermgmtdb
  - **Master Username:** dbadmin
  - **Master Password:** dbpassword11
  - **Confirm Password:** dbpassword11
  - **DB Instance Size:** 기본값 유지
  - **Storage:** 기본값 유지
  - **Connectivity**
    - **VPC:** eksctl-eksdemo1-cluster/VPC
    - **Additional Connectivity Configuration**
      - **Subnet Group:** eks-rds-db-subnetgroup
      - **Publicyly accessible:** YES (학습 및 문제 해결 목적)
    - **VPC Security Group:** Create New
      - **Name:** eks-rds-db-securitygroup    
    - **Availability Zone:** No Preference
    - **Database Port:** 3306 
  - 나머지는 기본값 유지                
- Create Database 클릭

### 0.0.0.0/0에서 접근 가능하도록 보안 그룹 수정
- **EC2 -> Security Groups -> eks-rds-db-securitygroup**로 이동
- **Edit Inboud Rules**
  - **Source:** Anywhere (0.0.0.0/0)  (현재는 어디서든 접근 허용)


## Step-03: Kubernetes ExternalName 서비스 매니페스트 생성 및 배포
- MySQL ExternalName 서비스 생성
- **01-MySQL-externalName-Service.yml**
```yml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  type: ExternalName
  externalName: usermgmtdb.c7hldelt9xfp.us-east-1.rds.amazonaws.com
```
 - **매니페스트 배포**
```
kubectl apply -f kube-manifests/01-MySQL-externalName-Service.yml
```
## Step-04: kubectl로 RDS DB에 연결하고 usermgmt 스키마/DB 생성
```
kubectl run -it --rm --image=mysql:latest --restart=Never mysql-client -- mysql -h usermgmtdb.c7hldelt9xfp.us-east-1.rds.amazonaws.com -u dbadmin -pdbpassword11

mysql> show schemas;
mysql> create database usermgmt;
mysql> show schemas;
mysql> exit
```
## Step-05: 사용자 관리 마이크로서비스 배포 파일에서 사용자명을 `root`에서 `dbadmin`으로 변경
- **02-UserManagementMicroservice-Deployment-Service.yml**
```yml
# Change From
          - name: DB_USERNAME
            value: "root"

# Change To
          - name: DB_USERNAME
            value: "dbadmin"            
```

## Step-06: 사용자 관리 마이크로서비스 배포 및 테스트
```
# Deploy all Manifests
kubectl apply -f kube-manifests/

# List Pods
kubectl get pods

# Stream pod logs to verify DB Connection is successful from SpringBoot Application
kubectl logs -f <pod-name>
```
## Step-07: 애플리케이션 접속
```
# Capture Worker Node External IP or Public IP
kubectl get nodes -o wide

# Access Application
http://<Worker-Node-Public-Ip>:31231/usermgmt/health-status
```

## Step-08: 정리
```
# Delete all Objects created
kubectl delete -f kube-manifests/

# Verify current Kubernetes Objects
kubectl get all
```
