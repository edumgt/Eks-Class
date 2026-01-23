# AWS ECR - Elastic Container Registry 통합 & EKS

## Step-01: 무엇을 배우나요?
- Docker 이미지를 빌드합니다.
- ECR 리포지토리에 푸시합니다.
- Kubernetes Deployment 매니페스트에서 ECR 이미지 리포지토리 URL을 업데이트합니다.
- EKS에 배포합니다.
- Kubernetes Deployment, NodePort Service, Ingress Service, External-DNS를 사용해 전체 배포 흐름을 보여줍니다.
- 등록된 DNS `http://ecrdemo.kubeoncloud.com`으로 ECR 데모 애플리케이션에 접근합니다.

## Step-02: ECR 용어
- **레지스트리(Registry):** 각 AWS 계정마다 ECR 레지스트리가 제공되며, 레지스트리 안에 이미지 리포지토리를 만들고 이미지를 저장합니다.
- **리포지토리(Repository):** ECR 이미지 리포지토리는 Docker 이미지를 보관합니다.
- **리포지토리 정책(Repository policy):** 리포지토리와 그 안의 이미지 접근을 정책으로 제어합니다.
- **인증 토큰(Authorization token):** Docker 클라이언트가 Amazon ECR에 이미지를 푸시/풀하기 전에 AWS 사용자로 인증해야 합니다. AWS CLI의 get-login 명령으로 Docker에 전달할 인증 정보를 얻습니다.
- **이미지(Image):** 리포지토리에 컨테이너 이미지를 푸시/풀할 수 있습니다.

## Step-03: 사전 준비
- 로컬 데스크톱에 필요한 CLI 소프트웨어 설치
  - **AWS CLI V2 설치**
    - [01-EKS-Create-Clusters-using-eksctl](/01-EKS-Create-Cluster-using-eksctl/01-01-Install-CLIs/README.md) 섹션에서 이미 다루었습니다.
    - 문서 참고: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
  - **Docker CLI 설치**
    - [Docker Fundamentals](https://github.com/stacksimplify/docker-fundamentals/tree/master/02-Docker-Installation) 섹션에서 로컬 설치를 다루었습니다.
    - Docker Desktop for MAC: https://docs.docker.com/docker-for-mac/install/
    - Docker Desktop for Windows: https://docs.docker.com/docker-for-windows/install/
    - Docker on Linux: https://docs.docker.com/install/linux/docker-ce/centos/

  - **AWS 콘솔에서**
    - [01-EKS-Create-Clusters-using-eksctl](/01-EKS-Create-Cluster-using-eksctl/01-01-Install-CLIs/README.md) 섹션에서 이미 다루었습니다.
    - 관리 사용자에 대한 인증 토큰이 없다면 생성합니다.
    - **AWS CLI를 인증 토큰으로 구성**
```
aws configure
AWS Access Key ID: ****
AWS Secret Access Key: ****
Default Region Name: us-east-1
```

## Step-04: ECR 리포지토리 생성
- AWS 콘솔에서 간단한 ECR 리포지토리 생성
  - 리포지토리 이름: aws-ecr-kubenginx
  - Tag Immutability: Enable
  - Scan on Push: Enable
- ECR 콘솔 탐색
- **AWS CLI로 ECR 리포지토리 생성**
```
aws ecr create-repository --repository-name aws-ecr-kubenginx --region us-east-1
aws ecr create-repository --repository-name <your-repo-name> --region <your-region>
```

## Step-05: 로컬에서 Docker 이미지 생성
- 과정 GitHub 콘텐츠 다운로드 후 **10-ECR-Elastic-Container-Registry\01-aws-ecr-kubenginx** 폴더로 이동
- 로컬에서 Docker 이미지 생성
- 로컬에서 실행하고 테스트
```
# Build Docker Image
docker build -t <ECR-REPOSITORY-URI>:<TAG> . 
docker build -t 180789647333.dkr.ecr.us-east-1.amazonaws.com/aws-ecr-kubenginx:1.0.0 . 

# Run Docker Image locally & Test
docker run --name <name-of-container> -p 80:80 --rm -d <ECR-REPOSITORY-URI>:<TAG>
docker run --name aws-ecr-kubenginx -p 80:80 --rm -d 180789647333.dkr.ecr.us-east-1.amazonaws.com/aws-ecr-kubenginx:1.0.0

# Access Application locally
http://localhost

# Stop Docker Container
docker ps
docker stop aws-ecr-kubenginx
docker ps -a -q
```

## Step-06: Docker 이미지를 AWS ECR에 푸시
- 먼저 ECR 리포지토리에 로그인
- Docker 이미지를 ECR에 푸시
- **AWS CLI Version 2.x**
```
# Get Login Password
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <ECR-REPOSITORY-URI>
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 180789647333.dkr.ecr.us-east-1.amazonaws.com/aws-ecr-kubenginx

# Push the Docker Image
docker push <ECR-REPOSITORY-URI>:<TAG>
docker push 180789647333.dkr.ecr.us-east-1.amazonaws.com/aws-ecr-kubenginx:1.0.0
```
- AWS ECR에서 새로 푸시된 Docker 이미지를 확인합니다.
- 취약점 스캔 결과를 확인합니다.

## Step-07: Amazon EKS에서 ECR 이미지 사용

### k8s 매니페스트 확인
- **10-ECR-Elastic-Container-Registry\02-kube-manifests** 폴더에 있는 Deployment 및 Service Kubernetes 매니페스트를 이해합니다.
  - **Deployment:** 01-ECR-Nginx-Deployment.yml
  - **NodePort Service:** 02-ECR-Nginx-NodePortService.yml
  - **ALB Ingress Service:** 03-ECR-Nginx-ALB-IngressService.yml

### EKS 워커 노드에서 ECR 접근 권한 확인
- Services -> EC2 -> Running Instances > 워커 노드 선택 -> Description 탭
- `IAM Role` 필드 값을 클릭
```
# Sample Role Name 
eksctl-eksdemo1-nodegroup-eksdemo-NodeInstanceRole-1U4PSS3YLALN6
```
- 해당 IAM 역할의 **permissions** 탭에서 확인
- `AmazonEC2ContainerRegistryReadOnly, AmazonEC2ContainerRegistryPowerUser` 정책이 연결되어 있어야 함

### Kubernetes 매니페스트 배포
```
# Deploy
kubectl apply -f 02-kube-manifests/

# Verify
kubectl get deploy
kubectl get svc
kubectl get po
kubectl get ingress
```
### 애플리케이션 접근
- ALB Ingress가 프로비저닝될 때까지 대기
- Route 53 DNS 등록 `ecrdemo.kubeoncloud.com` 확인
```
# Get external ip of EKS Cluster Kubernetes worker nodes
kubectl get nodes -o wide

# Access Application
http://ecrdemo.kubeoncloud.com/index.html
```

## Step-08: 정리
```
# Clean-Up
kubectl delete -f 02-kube-manifests/
```
