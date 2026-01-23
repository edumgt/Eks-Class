# EKS 클러스터 요금

## Step-01: 매우 중요한 EKS 요금 안내
- EKS는 무료가 아닙니다(다른 AWS 서비스와 다름)
- 즉, EKS에는 프리 티어가 없습니다.
### EKS 클러스터 요금
    - Amazon EKS 클러스터 1개당 시간당 $0.10 과금
    - 하루: $2.4
    - 30일 기준: $72
### EKS 워커 노드 요금 - EC2
    - AWS 리소스(예: EC2 인스턴스, EBS 볼륨)에 대해 비용을 지불합니다.
    - 버지니아 북부(N. Virginia) 지역의 T3 Medium 서버
        - 시간당 $0.0416
        - 하루: $0.9984 - 약 $1
        - 월: t3.medium 서버 1대당 $30
    - 참고: https://aws.amazon.com/ec2/pricing/on-demand/
    - 요약하면, EKS 클러스터 1개와 t3.medium 워커 노드 1개를 **연속**으로 1개월 실행하면 약 $102~$110 정도가 청구됩니다.
    - 이 과정을 5일 동안 수행하고, EKS 클러스터 1개와 t3.medium 워커 노드 2개를 5일간 연속 실행하면 약 $25 정도가 발생합니다.
### EKS Fargate 프로파일
    - AWS Fargate 요금은 컨테이너 이미지 다운로드 시작 시점부터 EKS 파드 종료 시점까지 사용한 **vCPU 및 메모리** 리소스를 기준으로 계산됩니다.
    - **참고:** https://aws.amazon.com/fargate/pricing/
    - Amazon EKS의 AWS Fargate 지원 리전: us-east-1, us-east-2, eu-west-1, ap-northeast-1

### 중요 참고 사항
- **중요 사항-1:** 개인 AWS 계정을 사용하는 경우, 필요할 때마다 클러스터와 워커 노드를 삭제 후 재생성하세요.
- **중요 사항-2:** Kubernetes 클러스터 내 EC2 인스턴스는 일반 EC2처럼 중지할 수 없습니다. 학습 중 사용하지 않을 때는 워커 노드(Node Group)를 삭제해야 합니다.
