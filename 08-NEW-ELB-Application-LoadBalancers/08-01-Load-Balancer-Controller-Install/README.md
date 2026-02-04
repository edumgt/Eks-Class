---
title: AWS Load Balancer Controller 설치(AWS EKS)
description: AWS EKS에서 Ingress 구현을 위한 AWS Load Balancer Controller 설치 학습
---

```
EKS에서는 Traefik “대신” ALB(Ingress)만 쓰는 게 정답이라기보다, 보통 외부 HTTP/HTTPS 진입은 AWS Load Balancer Controller로 ALB를 붙이는 방식을 가장 많이 씁니다. AWS도 기본적으로 AWS Load Balancer Controller 설치를 권장하고, 설치하지 않으면(레거시 클라우드 프로바이더) Classic Load Balancer(CLB) 로 기본 생성될 수 있으니 피하라고 안내합니다.

왜 EKS에서 ALB(Ingress)를 많이 쓰나?

AWS 네이티브 통합: ACM(인증서), WAF, 보안그룹, 타겟그룹, 헬스체크 등 AWS 기능을 그대로 활용하기 쉬움

K8s Ingress → ALB 자동 프로비저닝: Ingress/Service 리소스를 보고 컨트롤러가 ALB/NLB를 만들어 줌

표준 아키텍처: “EKS에서 외부 트래픽 라우팅은 AWS Load Balancer Controller로”라는 흐름이 문서/가이드에 명확함

그럼 Traefik은 EKS에서 안 쓰나?

아니요, Traefik도 EKS에서 충분히 사용합니다. 다만 패턴이 보통 둘 중 하나예요:

ALB만으로 끝(AWS Load Balancer Controller가 Ingress를 처리)

간단한 웹 서비스, AWS 기능(WAF/ACM) 적극 활용, 운영 표준화에 유리

앞단은 ALB/NLB, 클러스터 안쪽 라우팅은 Traefik

멀티테넌시/세밀한 라우팅 정책, Traefik의 CRD/Gateway API, 플러그인/미들웨어 등을 쓰고 싶을 때

실제로 “EKS에서 Traefik을 Ingress Controller로 구성”하는 가이드/사례도 있습니다.

선택 기준(실무 기준으로 딱 정리)

HTTP/HTTPS + 경로/호스트 기반 라우팅 + AWS WAF/ACM → ALB Ingress(AWS Load Balancer Controller) 가 “가장 흔한 선택”

TCP/UDP(소켓, 게임, DB 프록시 등) → 보통 NLB(Service type LoadBalancer) 쪽

클러스터 내부에서 API Gateway/미들웨어 기능을 풍부하게(Traefik 기능을 적극 사용) → (ALB/NLB) + Traefik 조합 고려
```

## 단계-00: 소개
1. IAM 정책을 생성하고 Policy ARN을 기록합니다.
2. IAM Role과 K8s Service Account를 생성해 서로 바인딩합니다.
3. HELM3 CLI로 AWS Load Balancer Controller를 설치합니다.
4. IngressClass 개념을 이해하고 기본 Ingress Class를 생성합니다.

## 단계-01: 사전 준비
### 사전 준비-1: eksctl & kubectl CLI
- 최신 eksctl 버전을 사용해야 합니다.
```t
# eksctl 버전 확인
eksctl version

# 최신 eksctl 설치 또는 업그레이드
https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html

# EKS 클러스터 버전 확인
kubectl version --short
kubectl version
중요: kubectl 버전은 Amazon EKS 컨트롤 플레인의 마이너 버전 차이가 1 이하인 것을 사용해야 합니다. 예: kubectl 1.20 클라이언트는 Kubernetes 1.19, 1.20, 1.21 클러스터와 호환됩니다.

# kubectl CLI 설치
https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
```
### 사전 준비-2: EKS 클러스터 및 워커 노드 생성(미생성 시)
```t
# 클러스터 생성(Section-01-02)
eksctl create cluster --name=eksdemo1 \
                      --region=us-east-1 \
                      --zones=us-east-1a,us-east-1b \
                      --version="1.21" \
                      --without-nodegroup 


# 클러스터 목록 확인(Section-01-02)
eksctl get cluster   

# 템플릿(Section-01-02)
eksctl utils associate-iam-oidc-provider \
    --region region-code \
    --cluster <cluter-name> \
    --approve

# region 및 cluster name으로 교체(Section-01-02)
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster eksdemo1 \
    --approve

# VPC 프라이빗 서브넷에 EKS NodeGroup 생성(Section-07-01)
eksctl create nodegroup --cluster=eksdemo1 \
                        --region=us-east-1 \
                        --name=eksdemo1-ng-private1 \
                        --node-type=t3.medium \
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
                        --alb-ingress-access \
                        --node-private-networking       
```
### 사전 준비-3: 클러스터/노드 그룹 확인 및 kubectl 설정
1. EKS 클러스터
2. 프라이빗 서브넷의 EKS 노드 그룹
```t
# EKS 클러스터 확인
eksctl get cluster

# EKS 노드 그룹 확인
eksctl get nodegroup --cluster=eksdemo1

# EKS 클러스터에 IAM Service Account 존재 여부 확인
eksctl get iamserviceaccount --cluster=eksdemo1
관찰 사항:
1. 현재 k8s Service Account가 없습니다.

# kubectl용 kubeconfig 설정
eksctl get cluster # TO GET CLUSTER NAME
aws eks --region <region-code> update-kubeconfig --name <cluster_name>
aws eks --region us-east-1 update-kubeconfig --name eksdemo1

# kubectl로 EKS 노드 확인
kubectl get nodes

# AWS 관리 콘솔에서 확인
1. EKS EC2 노드(네트워킹 탭에서 서브넷 확인)
2. EKS 클러스터
```

## 단계-02: IAM 정책 생성
- AWS Load Balancer Controller가 AWS API를 호출할 수 있도록 IAM 정책을 생성합니다.
- 현재 `2.3.1`이 최신 Load Balancer Controller입니다.
- Git 저장소의 main 브랜치에서 최신 버전을 항상 다운로드합니다.
- [AWS Load Balancer Controller 메인 Git 저장소](https://github.com/kubernetes-sigs/aws-load-balancer-controller)
```t
# 디렉터리 이동
cd 08-NEW-ELB-Application-LoadBalancers/
cd 08-01-Load-Balancer-Controller-Install

# 다운로드 전에 파일 삭제(있는 경우)
rm iam_policy_latest.json

# IAM 정책 다운로드
## 최신 버전 다운로드
curl -o iam_policy_latest.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
## 최신 버전 확인
ls -lrta 

## 특정 버전 다운로드
curl -o iam_policy_v2.3.1.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.3.1/docs/install/iam_policy.json


# 다운로드한 정책으로 IAM 정책 생성
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy_latest.json

## 출력 예시
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ aws iam create-policy \
>     --policy-name AWSLoadBalancerControllerIAMPolicy \
>     --policy-document file://iam_policy_latest.json
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "PolicyId": "ANPASUF7HC7S52ZQAPETR",
        "Arn": "arn:aws:iam::180789647333:policy/AWSLoadBalancerControllerIAMPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2022-02-02T04:51:21+00:00",
        "UpdateDate": "2022-02-02T04:51:21+00:00"
    }
}
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 
```
- **중요:** AWS 관리 콘솔에서 정책을 보면 ELB 관련 경고가 표시될 수 있습니다. 이는 일부 작업이 ELB v2에서만 존재하기 때문에 발생하며 무시해도 됩니다. ELB v2에는 경고가 나타나지 않습니다.

### Policy ARN 기록
- 다음 단계에서 IAM Role을 만들 때 사용하므로 Policy ARN을 기록합니다.
```t
# Policy ARN
Policy ARN:  arn:aws:iam::086015456585:policy/AWSLoadBalancerControllerIAMPolicy
```


## 단계-03: AWS LoadBalancer Controller용 IAM Role 생성 및 Kubernetes Service Account에 연결
- `eksctl`로 관리되는 클러스터에만 적용됩니다.
- 이 명령은 AWS IAM Role을 생성합니다.
- 또한 K8s 클러스터에 Kubernetes Service Account를 생성합니다.
- 생성된 IAM Role과 Kubernetes Service Account를 바인딩합니다.
### 단계-03-01: eksctl로 IAM Role 생성
```t
# 기존 서비스 계정 확인
kubectl get sa -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system
관찰 사항:
1. "aws-load-balancer-controller" 이름의 Service Account가 없어야 합니다.

# 템플릿
eksctl create iamserviceaccount \
  --cluster=my_cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \ #Note:  K8S Service Account Name that need to be bound to newly created IAM Role
  --attach-policy-arn=arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve


# name, cluster, policy arn을 실제 값으로 교체(단계-02에서 기록한 Policy ARN 사용)
eksctl create iamserviceaccount \
  --cluster=eksdemo1 \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::180789647333:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```
- **출력 예시**
```t
# IAM Service Account 생성 출력 예시
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ eksctl create iamserviceaccount \
>   --cluster=eksdemo1 \
>   --namespace=kube-system \
>   --name=aws-load-balancer-controller \
>   --attach-policy-arn=arn:aws:iam::180789647333:policy/AWSLoadBalancerControllerIAMPolicy \
>   --override-existing-serviceaccounts \
>   --approve
2022-02-02 10:22:49 [ℹ]  eksctl version 0.82.0
2022-02-02 10:22:49 [ℹ]  using region us-east-1
2022-02-02 10:22:52 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)
2022-02-02 10:22:52 [!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set
2022-02-02 10:22:52 [ℹ]  1 task: { 
    2 sequential sub-tasks: { 
        create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
        create serviceaccount "kube-system/aws-load-balancer-controller",
    } }2022-02-02 10:22:52 [ℹ]  building iamserviceaccount stack "eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2022-02-02 10:22:53 [ℹ]  deploying stack "eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2022-02-02 10:22:53 [ℹ]  waiting for CloudFormation stack "eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2022-02-02 10:23:10 [ℹ]  waiting for CloudFormation stack "eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2022-02-02 10:23:29 [ℹ]  waiting for CloudFormation stack "eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2022-02-02 10:23:32 [ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 
```

### 단계-03-02: eksctl CLI로 확인
```t
# IAM Service Account 조회
eksctl  get iamserviceaccount --cluster eksdemo1

# 출력 예시
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ eksctl  get iamserviceaccount --cluster eksdemo1
2022-02-02 10:23:50 [ℹ]  eksctl version 0.82.0
2022-02-02 10:23:50 [ℹ]  using region us-east-1
NAMESPACE	NAME				ROLE ARN
kube-system	aws-load-balancer-controller	arn:aws:iam::180789647333:role/eksctl-eksdemo1-addon-iamserviceaccount-kube-Role1-1244GWMVEAKEN
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 
```

### 단계-03-03: eksctl이 생성한 CloudFormation 템플릿 및 IAM Role 확인
- Services -> CloudFormation으로 이동
- **CFN 템플릿 이름:** eksctl-eksdemo1-addon-iamserviceaccount-kube-system-aws-load-balancer-controller
- **Resources** 탭 클릭
- **Physical Id**의 링크를 클릭해 IAM Role 열기
- **eksctl-eksdemo1-addon-iamserviceaccount-kube-Role1-WFAWGQKTAVLR**가 연결되어 있는지 확인

### 단계-03-04: kubectl로 K8s Service Account 확인
```t
# 기존 서비스 계정 확인
kubectl get sa -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system
관찰 사항:
1. 새 Service Account가 생성되어 있어야 합니다.

# Service Account aws-load-balancer-controller 상세 확인
kubectl describe sa aws-load-balancer-controller -n kube-system
```
- **관찰:** `Annotations`에 새 Role ARN이 추가된 것을 확인할 수 있으며, 이는 **AWS IAM Role이 Kubernetes Service Account에 바인딩되었음을 의미합니다.**
- **출력 예시**
```t
## Sample Output
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ kubectl describe sa aws-load-balancer-controller -n kube-system
Name:                aws-load-balancer-controller
Namespace:           kube-system
Labels:              app.kubernetes.io/managed-by=eksctl
Annotations:         eks.amazonaws.com/role-arn: arn:aws:iam::180789647333:role/eksctl-eksdemo1-addon-iamserviceaccount-kube-Role1-1244GWMVEAKEN
Image pull secrets:  <none>
Mountable secrets:   aws-load-balancer-controller-token-5w8th
Tokens:              aws-load-balancer-controller-token-5w8th
Events:              <none>
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 
```

## 단계-04: Helm V3로 AWS Load Balancer Controller 설치
### 단계-04-01: Helm 설치
- 설치되어 있지 않다면 [Helm 설치](https://helm.sh/docs/intro/install/)
- [AWS EKS용 Helm 설치](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)
```t
# Helm 설치(미설치 시) MacOS
brew install helm

# Helm 버전 확인
helm version
```
### 단계-04-02: AWS Load Balancer Controller 설치
- **중요 1:** IMDS 접근이 제한된 Amazon EC2 노드에 컨트롤러를 배포하거나 Fargate에 배포하는 경우 다음 플래그를 추가하세요.
```t
--set region=region-code
--set vpcId=vpc-xxxxxxxx
```
 - **중요 2:** **사용 중단(Deprecated)**
  - us-west-2 이외의 리전에 배포할 경우 다음 플래그를 추가하고, account 및 region-code를 Amazon EKS 애드온 컨테이너 이미지 주소에 있는 값으로 바꿉니다.
- [리전 코드 및 계정 정보 확인](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html)
```t
--set image.repository=account.dkr.ecr.region-code.amazonaws.com/amazon/aws-load-balancer-controller
```
- **중요 3:** **새로 추가됨 - 권장**
  - 리전별 이미지 URI를 더 이상 사용할 필요가 없습니다.
```t
# eks-charts 저장소 추가
helm repo add eks https://aws.github.io/eks-charts

# 로컬 저장소 업데이트(최신 차트 확보)
helm repo update

# AWS Load Balancer Controller 설치
## 템플릿
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=<region-code> \
  --set vpcId=<vpc-xxxxxxxx> \
  --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller

## 클러스터 이름, 리전 코드, VPC ID, 이미지 리포지토리 계정/리전 코드를 실제 값으로 교체
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eksdemo1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=vpc-0165a396e41e292a3 \
  --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller
```
- **AWS Load Balancer Controller 설치 단계 출력 예시**
```t
## AWS Load Balancer Controller 설치 단계 출력 예시
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
>   -n kube-system \
>   --set clusterName=eksdemo1 \
>   --set serviceAccount.create=false \
>   --set serviceAccount.name=aws-load-balancer-controller \
>   --set region=us-east-1 \
>   --set vpcId=vpc-0570fda59c5aaf192 \
>   --set image.repository=public.ecr.aws/eks/aws-load-balancer-controller
NAME: aws-load-balancer-controller
LAST DEPLOYED: Wed Feb  2 10:33:57 2022
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
AWS Load Balancer controller installed!
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 
```
### 단계-04-03: 컨트롤러 설치 및 Webhook Service 생성 확인
```t
# 컨트롤러 설치 확인
kubectl -n kube-system get deployment 
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system describe deployment aws-load-balancer-controller

# 출력 예시
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ kubectl get deployment -n kube-system aws-load-balancer-controller
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           27s
Kalyans-MacBook-Pro:08-01-Load-Balancer-Controller-Install kdaida$ 

# AWS Load Balancer Controller Webhook Service 생성 확인
kubectl -n kube-system get svc 
kubectl -n kube-system get svc aws-load-balancer-webhook-service
kubectl -n kube-system describe svc aws-load-balancer-webhook-service

# 출력 예시
Kalyans-MacBook-Pro:aws-eks-kubernetes-masterclass-internal kdaida$ kubectl -n kube-system get svc aws-load-balancer-webhook-service
NAME                                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
aws-load-balancer-webhook-service   ClusterIP   10.100.53.52   <none>        443/TCP   61m
Kalyans-MacBook-Pro:aws-eks-kubernetes-masterclass-internal kdaida$ 

# Service/Deployment의 라벨 및 셀렉터 라벨 확인
kubectl -n kube-system get svc aws-load-balancer-webhook-service -o yaml
kubectl -n kube-system get deployment aws-load-balancer-controller -o yaml
관찰 사항:
1. "aws-load-balancer-webhook-service"의 "spec.selector" 라벨 확인
2. "aws-load-balancer-controller" Deployment의 "spec.selector.matchLabels"와 비교
3. 값이 동일해야 하며, 443 포트로 들어오는 트래픽이 "aws-load-balancer-controller" 파드의 9443 포트로 전달됩니다.
```

### 단계-04-04: AWS Load Balancer Controller 로그 확인
```t
# 파드 목록
kubectl get pods -n kube-system

# AWS LB Controller 파드-1 로그 확인
kubectl -n kube-system logs -f <POD-NAME> 
kubectl -n kube-system logs -f  aws-load-balancer-controller-86b598cbd6-5pjfk

# AWS LB Controller 파드-2 로그 확인
kubectl -n kube-system logs -f <POD-NAME> 
kubectl -n kube-system logs -f aws-load-balancer-controller-86b598cbd6-vqqsk
```

### 단계-04-05: AWS Load Balancer Controller K8s Service Account 내부 확인
```t
# Service Account 및 Secret 목록
kubectl -n kube-system get sa aws-load-balancer-controller
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml
kubectl -n kube-system get secret <GET_FROM_PREVIOUS_COMMAND - secrets.name> -o yaml
kubectl -n kube-system get secret aws-load-balancer-controller-token-5w8th 
kubectl -n kube-system get secret aws-load-balancer-controller-token-5w8th -o yaml
## 아래 사이트에서 ca.crt 디코딩
https://www.base64decode.org/
https://www.sslchecker.com/certdecoder

## 아래 사이트에서 토큰 디코딩
https://www.base64decode.org/
https://jwt.io/
관찰 사항:
1. 디코딩된 JWT 토큰 확인

# YAML 형식으로 Deployment 확인
kubectl -n kube-system get deploy aws-load-balancer-controller -o yaml
관찰 사항:
1. "aws-load-balancer-controller" Deployment의 "spec.template.spec.serviceAccount" 및 "spec.template.spec.serviceAccountName" 확인
2. Service Account 이름이 "aws-load-balancer-controller"여야 합니다.

# YAML 형식으로 파드 확인
kubectl -n kube-system get pods
kubectl -n kube-system get pod <AWS-Load-Balancer-Controller-POD-NAME> -o yaml
kubectl -n kube-system get pod aws-load-balancer-controller-65b4f64d6c-h2vh4 -o yaml
관찰 사항:
1. "spec.serviceAccount" 및 "spec.serviceAccountName" 확인
2. Service Account 이름이 "aws-load-balancer-controller"여야 합니다.
3. "spec.volumes" 확인. AWS 서비스 접근용 임시 자격 증명이 아래와 같이 있어야 합니다.
CHECK-1: "spec.volumes.name = aws-iam-token" 확인
  - name: aws-iam-token
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          audience: sts.amazonaws.com
          expirationSeconds: 86400
          path: token
CHECK-2: Volume Mounts 확인
    volumeMounts:
    - mountPath: /var/run/secrets/eks.amazonaws.com/serviceaccount
      name: aws-iam-token
      readOnly: true          
CHECK-3: 경로 이름이 "token"인 환경 변수 확인
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token          
```

### 단계-04-06: AWS Load Balancer Controller TLS 인증서 내부 확인
```t
# aws-load-balancer-tls secret 목록
kubectl -n kube-system get secret aws-load-balancer-tls -o yaml

# 아래 사이트에서 ca.crt 및 tls.crt 확인
https://www.base64decode.org/
https://www.sslchecker.com/certdecoder

# 위에서 Common Name 및 SAN 기록
Common Name: aws-load-balancer-controller
SAN: aws-load-balancer-webhook-service.kube-system, aws-load-balancer-webhook-service.kube-system.svc

# YAML 형식으로 파드 확인
kubectl -n kube-system get pods
kubectl -n kube-system get pod <AWS-Load-Balancer-Controller-POD-NAME> -o yaml
kubectl -n kube-system get pod aws-load-balancer-controller-65b4f64d6c-h2vh4 -o yaml
관찰 사항:
1. AWS Load Balancer Controller 파드에서 secret이 마운트된 방식 확인
CHECK-2: Volume Mounts 확인
    volumeMounts:
    - mountPath: /tmp/k8s-webhook-server/serving-certs
      name: cert
      readOnly: true
CHECK-3: Volumes 확인
  volumes:
  - name: cert
    secret:
      defaultMode: 420
      secretName: aws-load-balancer-tls
```

### 단계-04-07: Helm 명령으로 AWS Load Balancer Controller 제거(정보용 - 실행 금지)
- 이 단계는 실행하지 않습니다.
- EKS 클러스터에서 aws load balancer controller를 제거하는 방법을 참고용으로만 제공합니다.
```t
# AWS Load Balancer Controller 제거
helm uninstall aws-load-balancer-controller -n kube-system 
```



## 단계-05: Ingress Class 개념
- Ingress Class가 무엇인지 이해합니다.
- 기본(Deprecated) 애노테이션 `#kubernetes.io/ingress.class: "alb"`를 어떻게 대체하는지 이해합니다.
- [Ingress Class 문서 참고](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/ingress_class/)
- [현재 사용 가능한 다양한 Ingress 컨트롤러](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)


## 단계-06: IngressClass Kubernetes 매니페스트 검토
- **파일 위치:** `08-01-Load-Balancer-Controller-Install/kube-manifests/01-ingressclass-resource.yaml`
- `ingressclass.kubernetes.io/is-default-class: "true"` 애노테이션을 상세히 이해합니다.
```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: my-aws-ingress-class
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb

## 추가 참고
# 1. 특정 IngressClass를 클러스터의 기본으로 지정할 수 있습니다.
# 2. IngressClass 리소스에 ingressclass.kubernetes.io/is-default-class 애노테이션을 true로 설정하면, ingressClassName이 없는 새 Ingress가 기본 IngressClass에 할당됩니다.
# 3. 참고: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.3/guide/ingress/ingress_class/
```

## 단계-07: IngressClass 리소스 생성
```t
# 디렉터리 이동
cd 08-01-Load-Balancer-Controller-Install

# IngressClass 리소스 생성
kubectl apply -f kube-manifests

# IngressClass 리소스 확인
kubectl get ingressclass

# IngressClass 리소스 상세 확인
kubectl describe ingressclass my-aws-ingress-class
```

## 참고 자료
- [AWS Load Balancer Controller Install](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
- [ECR Repository per region](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html)






