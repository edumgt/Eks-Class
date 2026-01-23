# AWS, kubectl, eksctl CLI 설치

## Step-00: 소개
- AWS CLI 설치
- kubectl CLI 설치
- eksctl CLI 설치

## Step-01: AWS CLI 설치
- 참고-1: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html
- 참고-2: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html

### Step-01-01: Mac - AWS CLI 설치 및 구성
- 아래 두 개 명령으로 바이너리를 다운로드하고 커맨드 라인에서 설치합니다.
```
# 바이너리 다운로드
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

# 바이너리 설치
sudo installer -pkg ./AWSCLIV2.pkg -target /
```
- 설치 확인
```
aws --version
aws-cli/2.0.7 Python/3.7.4 Darwin/19.4.0 botocore/2.0.0dev11

which aws
```
- 참고: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html

### Step-01-02: Windows 10 - AWS CLI 설치 및 구성
- AWS CLI 버전 2는 Windows XP 이상에서 지원됩니다.
- AWS CLI 버전 2는 64비트 Windows만 지원합니다.
- 바이너리 다운로드: https://awscli.amazonaws.com/AWSCLIV2.msi
- 다운로드한 바이너리 설치(일반 Windows 설치)
```
aws --version
aws-cli/2.0.8 Python/3.7.5 Windows/10 botocore/2.0.0dev12
```
- 참고: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html

### Step-01-03: 보안 자격 증명을 사용해 AWS CLI 구성
- AWS Management Console --> Services --> IAM으로 이동
- IAM 사용자 선택: kalyan
- **중요:** 루트 사용자가 아닌 IAM 사용자로만 **보안 자격 증명**을 생성하세요. (강력히 비권장)
- **Security credentials** 탭 클릭
- **Create access key** 클릭
- Access ID와 Secret access key 복사
- 커맨드 라인에서 필요한 정보를 입력
```
aws configure
AWS Access Key ID [None]: ABCDEFGHIAZBERTUCNGG  (요청 시 본인 자격 증명으로 교체)
AWS Secret Access Key [None]: uMe7fumK1IdDB094q2sGFhM5Bqt3HQRw3IHZzBDTm  (요청 시 본인 자격 증명으로 교체)
Default region name [None]: us-east-1
Default output format [None]: json
```
- 위 설정 이후 AWS CLI가 정상 동작하는지 테스트
```
aws ec2 describe-vpcs
```

## Step-02: kubectl CLI 설치
- **중요:** EKS용 kubectl 바이너리는 Amazon에서 제공하는 버전(**Amazon EKS-vended kubectl binary**)을 사용하는 것을 권장합니다.
- EKS 클러스터 버전에 맞는 정확한 kubectl 클라이언트 버전을 받을 수 있습니다. 아래 문서 링크를 참고해 바이너리를 다운로드하세요.
- 참고: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html

### Step-02-01: Mac - kubectl 설치 및 구성
- 여기서는 kubectl 1.16.8 버전을 사용합니다. (EKS 클러스터 버전에 따라 달라질 수 있음)

```
# 패키지 다운로드
mkdir kubectlbinary
cd kubectlbinary
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/darwin/amd64/kubectl

# 실행 권한 부여
chmod +x ./kubectl

# 사용자 홈 디렉터리에 복사해 PATH 설정
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bash_profile

# kubectl 버전 확인
kubectl version --short --client
Output: Client Version: v1.16.8-eks-e16311
```


### Step-02-02: Windows 10 - kubectl 설치 및 구성
- Windows 10에 kubectl 설치
```
mkdir kubectlbinary
cd kubectlbinary
curl -o kubectl.exe https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/windows/amd64/kubectl.exe
```
- 시스템 **Path** 환경 변수 업데이트
```
C:\Users\KALYAN\Documents\kubectlbinary
```
- kubectl 클라이언트 버전 확인
```
kubectl version --short --client
kubectl version --client
```

## Step-03: eksctl CLI 설치
### Step-03-01: Mac에서 eksctl 설치
```
# MacOS에 Homebrew 설치
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# Weaveworks Homebrew 탭 추가
brew tap weaveworks/tap

# Weaveworks Homebrew 탭에서 eksctl 설치
brew install weaveworks/tap/eksctl

# eksctl 버전 확인
eksctl version
```

### Step-03-02: Windows 또는 Linux에서 eksctl 설치
- Windows 및 Linux OS는 아래 문서를 참고하세요.
- **참고:** https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl


## 참고 자료
- https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html
