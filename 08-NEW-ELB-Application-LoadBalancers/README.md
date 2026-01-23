# AWS Application Load Balancer로 EKS 워크로드 로드 밸런싱

## 주제
- 이 주제는 단계별/모듈별로 매우 상세하게 다룹니다.
- 아래는 AWS ALB Ingress 관점에서 다루는 주제 목록입니다.


| 번호  | 주제 이름 |
| ------------- | ------------- |
| 1.  | AWS Load Balancer Controller 설치  |
| 2.  | ALB Ingress 기본  |
| 3.  | ALB Ingress 컨텍스트 경로 기반 라우팅  |
| 4.  | ALB Ingress SSL  |
| 5.  | ALB Ingress SSL 리다이렉트 (HTTP -> HTTPS) |
| 6.  | ALB Ingress External DNS |
| 7.  | k8s Ingress를 위한 ALB Ingress External DNS |
| 8.  | k8s Service를 위한 ALB Ingress External DNS |
| 9.  | ALB Ingress 이름 기반 가상 호스트 라우팅 |
| 10. | ALB Ingress SSL Discovery - Host |
| 11. | ALB Ingress SSL Discovery - TLS |
| 12. | ALB Ingress 그룹 |
| 13. | ALB Ingress 대상 유형 - IP 모드 |
| 13. | ALB Ingress 내부 로드 밸런서 |


## 참고 자료: 
- 추가 이해를 위해 아래 자료를 참고하세요.

### AWS Load Balancer Controller
- [AWS Load Balancer Controller 문서](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/)


### AWS ALB Ingress 어노테이션 참고
- https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/

### eksctl 시작하기
- https://eksctl.io/introduction/#getting-started

### External DNS
- https://github.com/kubernetes-sigs/external-dns
- https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/alb-ingress.md
- https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md
