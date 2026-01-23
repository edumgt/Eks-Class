# EKS - 수직 Pod 오토스케일링 (VPA)

## Step-01: 소개
- Kubernetes 수직 Pod 오토스케일러는 Pod의 CPU와 메모리 예약을 자동으로 조정해 애플리케이션을 적정 규모로 맞춰 줍니다.
- 이 조정은 클러스터 자원 사용 효율을 높이고 다른 Pod를 위한 CPU/메모리를 확보하는 데 도움이 됩니다.

## Step-02: 사전 준비 - Metrics Server
- HPA에서 이미 Metrics Server를 설치했습니다.

## Step-03: 수직 Pod 오토스케일러(VPA) 배포
```
# 저장소 클론
git clone https://github.com/kubernetes/autoscaler.git

# VPA 디렉터리로 이동
cd autoscaler/vertical-pod-autoscaler/

# VPA 제거 (구 버전 사용 시)
./hack/vpa-down.sh

# 새 버전 VPA 설치
./hack/vpa-up.sh

# VPA Pods 확인
kubectl get pods -n kube-system
```

## Step-04: 애플리케이션 매니페스트(Deployment & Service) 확인 및 배포
- `spec.containers.resources.requests`에 정의한 리소스를 확인합니다.
- VPA 정의에서 `limits`를 정의합니다.
```yml
        resources:
          requests:
            cpu: "5m"       
            memory: "5Mi"   
```

- **배포**
```
# 애플리케이션 배포
kubectl apply -f kube-manifests/01-VPA-DemoApplication.yml

# Pods, Deploy & Service 목록
kubectl get pod,svc,deploy

# Pod 상세 보기
kubectl describe pod <pod-name>

# 애플리케이션 접속 (NodeGroup이 Public Subnet일 때만)
kubectl get nodes -o wide
http://<Worker-Node-Public-IP>:31232
```

## Step-05: VPA 매니페스트 생성 및 배포

### VPA 매니페스트 생성
- 위에서 배포한 애플리케이션에 대한 VPA 매니페스트를 생성합니다.
```yml
apiVersion: "autoscaling.k8s.io/v1beta2"
kind: VerticalPodAutoscaler
metadata:
  name: kubengix-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: vpa-demo-deployment
  resourcePolicy:
    containerPolicies:
      - containerName: '*'
        minAllowed:
          cpu: 5m
          memory: 5Mi
        maxAllowed:
          cpu: 1
          memory: 500Mi
        controlledResources: ["cpu", "memory"]
```

### VPA 매니페스트 배포
```
# 배포
kubectl apply -f kube-manifests/02-VPA-Manifest.yml

# VPA 목록
kubectl get vpa

# VPA 상세
kubectl describe vpa kubengix-vpa
```


## Step-06: 부하 생성
- 새 터미널 3개를 더 열어 아래 부하 생성 명령을 실행합니다.
```
# 터미널 1 - Pod 목록을 지속적으로 확인
kubectl get pods -w

# 터미널 2 - 부하 생성
kubectl run --generator=run-pod/v1 apache-bench -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://vpa-demo-service-nginx.default.svc.cluster.local/

# 터미널 3 - 부하 생성
kubectl run --generator=run-pod/v1 apache-bench2 -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://vpa-demo-service-nginx.default.svc.cluster.local/

# 터미널 4 - 부하 생성
kubectl run --generator=run-pod/v1 apache-bench3 -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://vpa-demo-service-nginx.default.svc.cluster.local/
```

## Step-07: VPA Updater에 의해 재시작된 Pod 확인
```
# Pods 목록
kubectl get pods

# Pod 상세
kubectl describe pod <recently-relaunched-pod>
```

## Step-08: VPA 관련 중요 참고사항
1. VPA Updater는 디플로이먼트에 Pod가 최소 2개 이상일 때 CPU/메모리 업데이트로 새로운 Pod를 재시작할 수 있습니다.
2. Pod가 1개뿐이면, 수동으로 해당 Pod를 삭제하지 않는 한 VPA 추천 CPU/메모리를 적용한 새로운 Pod가 생성되지 않습니다.

## Step-09: 정리
```
kubectl delete -f kube-manifests/
```
