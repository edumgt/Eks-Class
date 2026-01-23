# MySQL 데이터베이스와 함께 UserManagement 서비스 배포


## Step-01: 소개
- 시작 시 MySQL 데이터베이스 스키마 **usermgmt**에 연결하는 **User Management 마이크로서비스**를 배포합니다.
- 다음 API를 테스트할 수 있습니다.
  - 사용자 생성
  - 사용자 목록
  - 사용자 삭제
  - 상태 점검

| Kubernetes 오브젝트  | YAML 파일 |
| ------------- | ------------- |
| Deployment, Environment Variables  | 06-UserManagementMicroservice-Deployment.yml  |
| NodePort Service  | 07-UserManagement-Service.yml  |

## Step-02: 다음 Kubernetes 매니페스트 생성

### User Management 마이크로서비스 Deployment 매니페스트 생성
- **환경 변수**

| 키 이름  | 값 |
| ------------- | ------------- |
| DB_HOSTNAME  | mysql |
| DB_PORT  | 3306  |
| DB_NAME  | usermgmt  |
| DB_USERNAME  | root  |
| DB_PASSWORD | dbpassword11  |  

### User Management 마이크로서비스 NodePort Service 매니페스트 생성
- NodePort 서비스

## Step-03: UserManagement 서비스 Deployment 및 Service 생성
```
# Deployment 및 NodePort 서비스 생성
kubectl apply -f kube-manifests/

# 파드 목록
kubectl get pods

# Usermgmt 마이크로서비스 파드 로그 확인
kubectl logs -f <Pod-Name>

# sc, pvc, pv 확인
kubectl get sc,pvc,pv
```
- **문제 관찰:**
  - 모든 매니페스트를 한 번에 배포하면, mysql이 준비되기 전에 `User Management Microservice` 파드가 DB 미가용으로 여러 번 재시작할 수 있습니다.
  - 이를 방지하려면 User management 마이크로서비스 `Deployment manifest`에 `initContainers` 개념을 적용할 수 있습니다.
  - 다음 섹션에서 다루며, 지금은 애플리케이션 테스트를 계속 진행합니다.
- **애플리케이션 접근**
```
# 서비스 목록
kubectl get svc

# 퍼블릭 IP 확인
kubectl get nodes -o wide

# User Management 서비스 상태 점검 API 접근
http://<EKS-WorkerNode-Public-IP>:31231/usermgmt/health-status
```

## Step-04: Postman으로 User Management 마이크로서비스 테스트
### Postman 클라이언트 다운로드
- https://www.postman.com/downloads/
### Postman에 프로젝트 가져오기
- `04-03-UserManagement-MicroService-with-MySQLDB` 폴더에 있는 `AWS-EKS-Masterclass-Microservices.postman_collection.json` 프로젝트를 가져옵니다.
### Postman에서 환경 생성
- Settings -> Add 클릭
- **환경 이름:** UMS-NodePort
  - **변수:** url
  - **초기 값:** http://WorkerNode-Public-IP:31231
  - **현재 값:** http://WorkerNode-Public-IP:31231
  - **Add** 클릭
### User Management 서비스 테스트
- API 호출 전에 환경을 선택합니다.
- **Health Status API**
  - URL: `{{url}}/usermgmt/health-status`
- **Create User 서비스**
  - URL: `{{url}}/usermgmt/user`
  - `url` 변수는 선택한 환경 값으로 대체됩니다.
```json
    {
        "username": "admin1",
        "email": "dkalyanreddy@gmail.com",
        "role": "ROLE_ADMIN",
        "enabled": true,
        "firstname": "fname1",
        "lastname": "lname1",
        "password": "Pass@123"
    }
```
- **List User 서비스**
  - URL: `{{url}}/usermgmt/users`

- **Update User 서비스**
  - URL: `{{url}}/usermgmt/user`
```json
    {
        "username": "admin1",
        "email": "dkalyanreddy@gmail.com",
        "role": "ROLE_ADMIN",
        "enabled": true,
        "firstname": "fname2",
        "lastname": "lname2",
        "password": "Pass@123"
    }
```  
- **Delete User 서비스**
  - URL: `{{url}}/usermgmt/user/admin1`

## Step-05: MySQL 데이터베이스에서 사용자 확인
```
# MySQL 데이터베이스 연결
kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql -u root -pdbpassword11

# ConfigMap에 제공한 usermgmt 스키마가 생성되었는지 확인
mysql> show schemas;
mysql> use usermgmt;
mysql> show tables;
mysql> select * from users;
```

## Step-06: 정리
- 이 섹션에서 생성한 모든 k8s 객체 삭제
```
# 전체 삭제
kubectl delete -f kube-manifests/

# 파드 목록
kubectl get pods

# sc, pvc, pv 확인
kubectl get sc,pvc,pv
```


