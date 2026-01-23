# EBS(Elastic Block Store)로 EKS 스토리지 구성

## Step-01: 소개
- EBS용 IAM 정책 생성
- 워커 노드 IAM 역할에 IAM 정책 연결
- EBS CSI 드라이버 설치

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

# 출력에서 rolearn 확인
rolearn: arn:aws:iam::180789647333:role/eksctl-eksdemo1-nodegroup-eksdemo-NodeInstanceRole-IJN07ZKXAWNN
```
- Services -> IAM -> Roles 이동
- **eksctl-eksdemo1-nodegroup** 이름의 역할 검색 후 열기
- **Permissions** 탭 클릭
- **Attach Policies** 클릭
- **Amazon_EBS_CSI_Driver**를 검색해 **Attach Policy** 클릭

## Step-04: Amazon EBS CSI 드라이버 배포
- kubectl 버전이 1.14 이상인지 확인
```
kubectl version --client --short
```
- Amazon EBS CSI 드라이버 배포
```
# EBS CSI 드라이버 배포
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# ebs-csi 파드 실행 확인
kubectl get pods -n kube-system
```
