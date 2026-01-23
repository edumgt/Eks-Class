# EKS - 수평 Pod 오토스케일링 (HPA)

## Step-01: 소개
- 수평 Pod 오토스케일링이란?
- HPA는 어떻게 동작하나요?
- HPA는 어떻게 구성하나요?

## Step-02: Metrics Server 설치
```
# Metrics Server가 이미 설치되어 있는지 확인
kubectl -n kube-system get deployment/metrics-server

# Metrics Server 설치
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

# 확인
kubectl get deployment metrics-server -n kube-system
```

## Step-03: 애플리케이션 배포 확인
```
# 배포
kubectl apply -f kube-manifests/

# Pods, Deploy & Service 목록
kubectl get pod,svc,deploy

# 애플리케이션 접속 (클러스터가 Public Subnet일 때만)
kubectl get nodes -o wide
http://<Worker-Node-Public-IP>:31231
```

## Step-04: "hpa-demo-deployment"에 대한 수평 Pod 오토스케일러 생성
- 이 명령은 디플로이먼트의 CPU 평균 사용률 50%를 목표로 하는 오토스케일러를 생성하며, 최소 1개에서 최대 10개까지 Pod를 확장합니다.
- 평균 CPU 부하가 50% 미만이면 최소 1개까지 Pod 수를 줄이려 합니다.
- 부하가 50%를 넘으면 최대 10개까지 Pod 수를 늘립니다.
```
# 템플릿
kubectl autoscale deployment <deployment-name> --cpu-percent=50 --min=1 --max=10

# 적용
kubectl autoscale deployment hpa-demo-deployment --cpu-percent=50 --min=1 --max=10

# HPA 상세 확인
kubectl describe hpa/hpa-demo-deployment 

# HPA 목록
kubectl get horizontalpodautoscaler.autoscaling/hpa-demo-deployment 
```

## Step-05: 부하 생성 및 HPA 동작 확인
```
# 부하 생성
kubectl run --generator=run-pod/v1 apache-bench -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://hpa-demo-service-nginx.default.svc.cluster.local/ 

# 모든 HPA 목록
kubectl get hpa

# 특정 HPA 목록
kubectl get hpa hpa-demo-deployment 

# HPA 상세 확인
kubectl describe hpa/hpa-demo-deployment 

# Pods 목록
kubectl get pods
```

## Step-06: 쿨다운 / 스케일다운
- 기본 쿨다운 기간은 5분입니다.
- Pod의 CPU 사용률이 50% 미만이 되면 Pod를 종료하기 시작하며, 최소 1개까지 줄어듭니다.


## Step-07: 정리
```
# HPA 삭제
kubectl delete hpa hpa-demo-deployment

# Deployment & Service 삭제
kubectl delete -f kube-manifests/ 
```

## Step-08: HPA의 명령형 vs 선언형
- Kubernetes v1.18부터는 `behavior` 객체를 사용해 HPA 정책을 선언형으로 정의할 수 있습니다.
- **확장/축소 동작을 구성 가능**
  - v1.18부터 v2beta2 API에서 HPA behavior 필드를 통해 scaling behavior를 구성할 수 있습니다.
  - behavior 필드 아래 scaleUp/scaleDown 섹션에 확장/축소 동작을 각각 정의합니다.
```yml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15
    - type: Pods
      value: 4
      periodSeconds: 15
    selectPolicy: Max
```
- **참고:** Kubernetes 웹사이트 상단 오른쪽에서 V1.18 문서를 선택하세요.
  -  https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/



## 참고 자료
### Metrics Server 릴리스
- https://github.com/kubernetes-sigs/metrics-server/releases

### Horizontal Pod Autoscaling - 다양한 메트릭 기반 확장
- https://v1-16.docs.kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
