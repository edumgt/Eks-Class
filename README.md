## AWS EKS

| 번호 | AWS 서비스 이름 |
| ---- | ---------------- |
| 1.   | eksctl CLI를 사용해 AWS EKS 클러스터 생성 |
| 2.   | [Docker 기초](https://github.com/stacksimplify/docker-fundamentals) |
| 3.   | [Kubernetes 기초](https://github.com/stacksimplify/kubernetes-fundamentals) |
| 4.   | AWS EBS CSI 드라이버를 사용한 EKS 스토리지 |
| 5.   | 애플리케이션 배포를 위한 Kubernetes 핵심 개념 |
| 5.1  | Kubernetes - 시크릿 |
| 5.2  | Kubernetes - 초기화 컨테이너 |
| 5.3  | Kubernetes - Liveness & Readiness 프로브 |
| 5.4  | Kubernetes - 요청 & 제한 |
| 5.5  | Kubernetes - 네임스페이스, 리밋 레인지, 리소스 쿼터 |
| 6.   | AWS RDS MySQL 데이터베이스를 사용하는 EKS 스토리지 |
| 7.   | CLB 및 NLB를 사용한 로드 밸런싱 |
| 7.1  | CLB를 사용한 로드 밸런싱 - AWS Classic Load Balancer |
| 7.2  | NLB를 사용한 로드 밸런싱 - AWS Network Load Balancer |
| 8.   | ALB를 사용한 로드 밸런싱 - AWS Application Load Balancer |
| 8.1  | ALB Ingress Controller - 설치 |
| 8.2  | ALB Ingress - 기본 |
| 8.3  | ALB Ingress - 컨텍스트 경로 기반 라우팅 |
| 8.4  | ALB Ingress - SSL |
| 8.5  | ALB Ingress - HTTP에서 HTTPS로 SSL 리다이렉트 |
| 8.6  | ALB Ingress - External DNS |
| 9.   | AWS Fargate 서버리스에 Kubernetes 워크로드 배포 |
| 9.1  | AWS Fargate 프로파일 - 기본 |
| 9.2  | AWS Fargate 프로파일 - YAML을 사용한 고급 |
| 10.  | AWS ECR에 컨테이너를 빌드/푸시하고 EKS에서 사용 |
| 11.  | AWS Developer Tools(CodeCommit, CodeBuild, CodePipeline)로 DevOps |
| 12.  | EKS에서 마이크로서비스 배포 - 서비스 디스커버리 |
| 13.  | AWS X-Ray를 사용한 마이크로서비스 분산 추적 |
| 14.  | 마이크로서비스 카나리 배포 |
| 15.  | EKS HPA - 수평 Pod 오토스케일러 |
| 16.  | EKS VPA - 수직 Pod 오토스케일러 |
| 17.  | EKS CA - 클러스터 오토스케일러 |
| 18.  | CloudWatch Agent & Fluentd를 사용한 EKS 모니터링 - Container Insights |


## 다루는 AWS 서비스

| 번호 | AWS 서비스 이름 |
| ---- | ---------------- |
| 1.   | AWS EKS - Elastic Kubernetes Service  |
| 2.   | AWS EBS - Elastic Block Store  |
| 3.   | AWS RDS - Relational Database Service MySQL  |
| 4.   | AWS CLB - Classic Load Balancer  |
| 5.   | AWS NLB - Network Load Balancer  |
| 6.   | AWS ALB - Application Load Balancer  |
| 7.   | AWS Fargate - Serverless  |
| 8.   | AWS ECR - Elastic Container Registry  |
| 9.   | AWS 개발자 도구 - CodeCommit  |
| 10.  | AWS 개발자 도구 - CodeBuild  |
| 11.  | AWS 개발자 도구 - CodePipeline  |
| 12.  | AWS X-Ray  |
| 13.  | AWS CloudWatch - Container Insights  |
| 14.  | AWS CloudWatch - 로그 그룹 & Log Insights  |
| 15.  | AWS CloudWatch - 알람  |
| 16.  | AWS Route53  |
| 17.  | AWS Certificate Manager  |
| 18.  | EKS CLI - eksctl  |


## 다루는 Kubernetes 개념

| 번호 | Kubernetes 개념 이름 |
| ---- | ------------------- |
| 1.   | Kubernetes 아키텍처  |
| 2.   | 파드(Pods)  |
| 3.   | 레플리카셋(ReplicaSets)  |
| 4.   | 디플로이먼트(Deployments)  |
| 5.   | 서비스 - 노드 포트 서비스  |
| 6.   | 서비스 - 클러스터 IP 서비스  |
| 7.   | 서비스 - External Name 서비스  |
| 8.   | 서비스 - Ingress 서비스  |
| 9.   | 서비스 - Ingress SSL & SSL 리다이렉트  |
| 10.  | 서비스 - Ingress & External DNS  |
| 11.  | 명령형 - kubectl 사용  |
| 12.  | 선언형 - YAML로 선언형 작성  |
| 13.  | 시크릿(Secrets) |
| 14.  | 초기화 컨테이너(Init Containers) |
| 15.  | Liveness & Readiness 프로브 |
| 16.  | 요청 & 제한 |
| 17.  | 네임스페이스 - 명령형 |
| 18.  | 네임스페이스 - 리밋 레인지 |
| 19.  | 네임스페이스 - 리소스 쿼터 |
| 20.  | 스토리지 클래스 |
| 21.  | 퍼시스턴트 볼륨 |
| 22.  | 퍼시스턴트 볼륨 클레임 |
| 23.  | 서비스 - 로드 밸런서 |
| 24.  | 애노테이션 |
| 25.  | 카나리 배포 |
| 26.  | HPA - 수평 Pod 오토스케일러 |
| 27.  | VPA - 수직 Pod 오토스케일러 |
| 28.  | CA - 클러스터 오토스케일러 |
| 29.  | 데몬셋(DaemonSets) |
| 30.  | 데몬셋 - 로그용 Fluentd |
| 31.  | ConfigMap |

## Docker Hub의 Docker 이미지 목록

| 애플리케이션 이름  | Docker 이미지 이름 |
| ----------------- | ----------------- |
| Simple Nginx V1  | stacksimplify/kubenginx:1.0.0  |
| Spring Boot Hello World API  | stacksimplify/kube-helloworld:1.0.0  |
| Simple Nginx V2  | stacksimplify/kubenginx:2.0.0  |
| Simple Nginx V3  | stacksimplify/kubenginx:3.0.0  |
| Simple Nginx V4  | stacksimplify/kubenginx:4.0.0  |
| Backend Application  | stacksimplify/kube-helloworld:1.0.0  |
| Frontend Application  | stacksimplify/kube-frontend-nginx:1.0.0  |
| Kube Nginx App1  | stacksimplify/kube-nginxapp1:1.0.0  |
| Kube Nginx App2  | stacksimplify/kube-nginxapp2:1.0.0  |
| Kube Nginx App2  | stacksimplify/kube-nginxapp2:1.0.0  |
| User Management Microservice with MySQLDB  | stacksimplify/kube-usermanagement-microservice:1.0.0  |
| User Management Microservice with H2 DB  | stacksimplify/kube-usermanagement-microservice:2.0.0-H2DB  |
| User Management Microservice with MySQL DB and AWS X-Ray  | stacksimplify/kube-usermanagement-microservice:3.0.0-AWS-XRay-MySQLDB  |
| User Management Microservice with H2 DB and AWS X-Ray  | stacksimplify/kube-usermanagement-microservice:4.0.0-AWS-XRay-H2DB  |
| Notification Microservice V1  | stacksimplify/kube-notifications-microservice:1.0.0  |
| Notification Microservice V2  | stacksimplify/kube-notifications-microservice:2.0.0  |
| Notification Microservice V1 with AWS X-Ray  | stacksimplify/kube-notifications-microservice:3.0.0-AWS-XRay  |
| Notification Microservice V2 with AWS X-Ray  | stacksimplify/kube-notifications-microservice:4.0.0-AWS-XRay  |


## AWS ECR에서 빌드하는 Docker 이미지 목록

| 애플리케이션 이름  | Docker 이미지 이름 |
| ----------------- | ----------------- |
| AWS Elastic Container Registry  | YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com/aws-ecr-kubenginx:DATETIME-REPOID  |
| DevOps 유스케이스  | YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com/eks-devops-nginx:DATETIME-REPOID  |


## 샘플 애플리케이션
- 사용자 관리 마이크로서비스
- 알림 마이크로서비스
- Nginx 애플리케이션

## 이 과정에서 무엇을 배우나요?
- 실시간 템플릿 작성 섹션을 통해 자신 있게 Kubernetes 매니페스트를 작성할 수 있습니다.
- 30개 이상의 Kubernetes 개념을 배우고 EKS와 조합해 18개의 AWS 서비스를 사용합니다.
- 명령형과 선언형 방식 모두에서 Kubernetes 기초를 학습합니다.
- 스토리지 클래스, 퍼시스턴트 볼륨 클레임(PVC), MySQL, EBS CSI Driver 같은 스토리지 개념의 k8s 매니페스트를 작성 및 배포합니다.
- k8s External Name 서비스를 사용해 기본 EBS 스토리지에서 RDS 데이터베이스로 전환하는 방법을 배웁니다.
- Classic 및 Network 로드 밸런서용 k8s 매니페스트를 작성하고 배포합니다.
- 컨텍스트 경로 기반 라우팅, SSL, SSL 리다이렉트, External DNS 같은 기능을 활성화하는 Ingress k8s 매니페스트를 작성합니다.
- 고급 Fargate 프로파일용 k8s 매니페스트를 작성하고 EC2와 Fargate 서버리스를 혼합한 워크로드 배포를 진행합니다.
- EKS와 함께 ECR(Elastic Container Registry)을 사용하는 방법을 배웁니다.
- CodeCommit, CodeBuild, CodePipeline 같은 AWS Code 서비스로 DevOps 개념을 구현합니다.
- 서비스 디스커버리, X-Ray를 통한 분산 추적, 카나리 배포 같은 마이크로서비스 핵심 개념을 구현합니다.
- HPA, VPA, 클러스터 오토스케일러 같은 오토스케일링 기능을 활성화하는 방법을 배웁니다.
- CloudWatch Container Insights를 사용해 EKS 클러스터 및 워크로드의 모니터링과 로깅을 활성화합니다.
- Docker Hub에서 이미지 다운로드, 로컬에서 실행, 로컬 빌드/테스트 후 Docker Hub로 푸시 등 실습을 통해 Docker 기초를 익힙니다.
- Docker 기초부터 시작해 Kubernetes로 단계적으로 이동합니다.
- 과정 전반에 걸쳐 다양한 kubectl 명령을 숙달합니다.

## 과정 수강 요건이나 사전 지식이 있나요?
- 실습을 따라 하려면 AWS 계정이 필요합니다.
- 이 과정을 시작하기 위해 기본 Docker나 Kubernetes 지식이 반드시 필요한 것은 아닙니다.


## 대상 학습자
- Kubernetes에서 애플리케이션을 실행하기 위해 Elastic Kubernetes Service(EKS)를 마스터하려는 AWS 아키텍트, 시스템 관리자, 개발자
- AWS EKS를 사용한 클라우드 Kubernetes 학습에 관심 있는 초보자
- Kubernetes에서 DevOps와 마이크로서비스 배포를 배우고 싶은 초보자


