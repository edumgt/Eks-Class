# EKS 클러스터 및 노드 그룹 생성

## Step-00: 소개
- EKS 핵심 객체 이해
  - 컨트롤 플레인
  - 워커 노드 및 노드 그룹
  - Fargate 프로파일
  - VPC
- EKS 클러스터 생성
- EKS 클러스터와 IAM OIDC 제공자 연결
- EKS 노드 그룹 생성
- 클러스터, 노드 그룹, EC2 인스턴스, IAM 정책 및 노드 그룹 확인


## Step-01: eksctl로 EKS 클러스터 생성
- 클러스터 컨트롤 플레인 생성에 15~20분 소요됩니다.
```
# 클러스터 생성
eksctl create cluster --name=eksdemo1 \
                      --region=us-east-1 \
                      --zones=us-east-1a,us-east-1b \
                      --without-nodegroup 

# 클러스터 목록 확인
eksctl get cluster                  
```


## Step-02: EKS 클러스터용 IAM OIDC 제공자 생성 및 연결
- EKS 클러스터에서 Kubernetes 서비스 계정용 AWS IAM 역할을 사용하려면 OIDC ID 제공자를 생성하고 연결해야 합니다.
- `eksctl`로 아래 명령을 실행합니다.
- 최신 eksctl 버전을 사용하세요(현재 최신은 `0.21.0`).
```                   
# 템플릿
eksctl utils associate-iam-oidc-provider \
    --region region-code \
    --cluster <cluter-name> \
    --approve

# 리전 및 클러스터 이름 교체
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster eksdemo1 \
    --approve
```



## Step-03: EC2 키 페어 생성
- `kube-demo`라는 이름으로 새 EC2 키 페어를 생성합니다.
- 이 키 페어는 EKS 노드 그룹 생성 시 사용합니다.
- 터미널에서 EKS 워커 노드에 로그인하는 데 필요합니다.

## Step-04: 퍼블릭 서브넷에 추가 애드온을 포함한 노드 그룹 생성
- 이 애드온들은 노드 그룹 역할에 필요한 IAM 정책을 자동으로 생성해 줍니다.
```
# 퍼블릭 노드 그룹 생성
eksctl create nodegroup --cluster=eksdemo1 \
                        --region=us-east-1 \
                        --name=eksdemo1-ng-public1 \
                        --node-type=t3.medium \
                        --nodes=2 \
                        --nodes-min=2 \
                        --nodes-max=4 \
                        --node-volume-size=20 \
                        --ssh-access \
                        --ssh-public-key=kube-demo \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access 
```

## Step-05: 클러스터 및 노드 확인

### 노드 그룹 서브넷 확인 (EC2 인스턴스가 퍼블릭 서브넷인지 확인)
- 노드 그룹 서브넷이 퍼블릭 서브넷에 생성됐는지 확인합니다.
  - Services -> EKS -> eksdemo -> eksdemo1-ng1-public 이동
  - **Details** 탭에서 Associated subnet 클릭
  - **Route Table** 탭 클릭
  - 인터넷 게이트웨이 경로(0.0.0.0/0 -> igw-xxxxxxxx)가 있어야 합니다.

### EKS 관리 콘솔에서 클러스터와 노드 그룹 확인
- Services -> Elastic Kubernetes Service -> eksdemo1 이동

### 워커 노드 목록 확인
```
# EKS 클러스터 목록
eksctl get cluster

# 클러스터 내 노드 그룹 목록
eksctl get nodegroup --cluster=<clusterName>

# 현재 Kubernetes 클러스터의 노드 목록
kubectl get nodes -o wide

# kubectl 컨텍스트가 새 클러스터로 자동 변경되었는지 확인
kubectl config view --minify
```

### 워커 노드 IAM 역할 및 정책 목록 확인
- Services -> EC2 -> Worker Nodes 이동
- EC2 워커 노드에 연결된 **IAM Role** 클릭

### 워커 노드 보안 그룹 확인
- Services -> EC2 -> Worker Nodes 이동
- `remote`가 포함된 이름의 EC2 인스턴스 **Security Group** 클릭

### CloudFormation 스택 확인
- 컨트롤 플레인 스택 및 이벤트 확인
- 노드 그룹 스택 및 이벤트 확인

### 키 페어 kube-demo로 워커 노드 로그인
- 워커 노드 로그인
```
# Mac 또는 Linux 또는 Windows10
ssh -i kube-demo.pem ec2-user@<Public-IP-of-Worker-Node>

# Windows 7
Use putty
```

## Step-06: 워커 노드 보안 그룹에 모든 트래픽 허용
- 워커 노드 보안 그룹에서 `All Traffic`을 허용해야 합니다.

## 추가 참고 자료
- https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
- https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html
