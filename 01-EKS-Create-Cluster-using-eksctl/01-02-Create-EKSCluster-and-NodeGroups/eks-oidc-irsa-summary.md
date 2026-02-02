# EKS OIDC 제공자(Provider) 생성/연결의 의미 (IRSA 관점)

## 결론 요약
EKS에서 **OIDC 제공자 생성/연결(associate)** 은  
**계정정보(비밀번호/장기 키)를 서로 “공유”하기 위한 것**이라기보다,

- 쿠버네티스가 발급한 **JWT(ServiceAccount 토큰)** 을
- AWS IAM/STS가 **신뢰할 수 있도록 “토큰 발급자(issuer)”를 등록**해
- 그 토큰을 근거로 **임시 AWS 자격증명(temporary credentials)을 발급받아 쓰는 방식**

즉, **신뢰 연동(Federation) + 임시 자격증명 교환**을 위한 설정이다.

---

## “공유”와 “연동”의 차이
### ❌ 계정정보 공유(공유에 가까운 방식)
- 다른 시스템에 **AWS AccessKey/SecretKey(장기 자격증명)** 를 직접 넣어 사용
- 노출 위험이 크고, 회수/로테이션/최소권한 관리가 어려움

### ✅ OIDC 기반 연동(현재 EKS에서 하는 것)
- Pod는 **자기 신분을 증명하는 JWT**만 사용
- AWS는 그 JWT를 검증한 뒤 **짧은 수명의 임시 자격증명**을 발급
- 장기 키를 Pod에 넣지 않음 → 보안/감사/권한 분리가 쉬움

---

## EKS에서 OIDC 제공자 “생성 및 연결”이 하는 일
쿠버네티스 클러스터(EKS)는 내부적으로 **OIDC issuer URL**을 가진다.  
IRSA를 사용하려면 AWS IAM이 다음을 알게 해야 한다:

- “이 issuer에서 발급된 토큰은 신뢰한다”

그래서 IAM에 **OIDC Provider 리소스**를 만들어,  
클러스터의 issuer URL을 **신뢰 가능한 토큰 발급자**로 등록(associate)한다.

---

## IRSA 동작 흐름 (간단)
1. **Pod**는 자신의 Kubernetes **ServiceAccount 토큰(JWT)** 을 갖는다.
2. Pod는 AWS **STS**에 요청한다:  
   “이 JWT를 근거로 특정 IAM Role을 맡게 해줘 (AssumeRoleWithWebIdentity)”
3. STS/IAM은 다음을 검증한다:
   - 토큰 issuer가 **등록된 OIDC Provider**인지
   - 토큰 클레임(aud, sub 등)이 **Role의 신뢰정책 조건**과 맞는지
4. 검증이 통과하면 STS가 **임시 AWS 자격증명**(짧은 만료)을 발급한다.
5. Pod는 그 임시 자격증명으로 S3/DynamoDB 등 AWS API를 호출한다.

---

## 핵심 포인트
- **계정정보 공유가 아니라 “토큰으로 신원 증명 → 임시 권한 발급”**이다.
- 노드 IAM Role과 분리되어 **Pod(서비스계정) 단위 최소권한** 부여가 가능하다.
- 보안상 장점: 장기 키를 컨테이너/시크릿에 저장하지 않아도 된다.

---

## 한 줄 정리
OIDC 제공자 생성/연결은 **JWT 기반으로 다른 시스템(쿠버네티스 Pod)의 신원을 AWS가 신뢰하도록 만들고, 그 신원에 맞는 IAM 권한을 임시로 교환해 쓰는 방식**이다.
