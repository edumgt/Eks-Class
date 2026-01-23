# Kubernetes 네임스페이스 - LimitRange - YAML 선언형 방식
## Step-01: 네임스페이스 매니페스트 생성
- **중요:** 파일 이름이 `00-`으로 시작해야 k8s 객체 생성 시 네임스페이스가 먼저 생성되어 오류가 발생하지 않습니다.
```yml
apiVersion: v1
kind: Namespace
metadata:
  name: dev3
```

## Step-02: LimitRange 매니페스트 생성
- 파드 정의의 각 컨테이너 스펙에 `CPU/메모리 리소스`를 직접 지정하는 대신, `LimitRange`로 네임스페이스 내 모든 컨테이너의 기본 CPU/메모리를 설정할 수 있습니다.
```yml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-resource-quota
  namespace: dev3
spec:
  limits:
    - default:
        memory: "512Mi" # 지정하지 않으면 컨테이너의 메모리 제한은 512Mi(네임스페이스 기본값)
        cpu: "500m"  # 지정하지 않으면 컨테이너당 기본 제한은 1 vCPU
      defaultRequest:
        memory: "256Mi" # 지정하지 않으면 limits.default.memory 값을 사용
        cpu: "300m" # 지정하지 않으면 limits.default.cpu 값을 사용
      type: Container                        
```

## Step-03: 모든 k8s 매니페스트에 네임스페이스 추가
- `kube-manifests/02-Declarative` 폴더의 02~08 파일 상단 metadata 섹션에 `namespace: dev3`를 추가합니다.
- **예시**
```yml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-mysql-pv-claim
  namespace: dev3
```

## Step-04: k8s 객체 생성 및 테스트
```
# 전체 객체 생성
kubectl apply -f kube-manifests/

# 파드 목록
kubectl get pods -n dev3 -w

# 파드 스펙 확인(CPU & Memory)
kubectl get pod <pod-name> -o yaml -n dev3

# Limit 확인
kubectl get limits -n dev3
kubectl describe limits default-cpu-mem-limit-range -n dev3

# NodePort 확인
kubectl get svc -n dev3

# 워커 노드 퍼블릭 IP 확인
kubectl get nodes -o wide

# 애플리케이션 상태 페이지 접근
http://<WorkerNode-Public-IP>:<NodePort>/usermgmt/health-status

```
## Step-05: 정리
- 이 섹션에서 생성한 모든 k8s 객체 삭제
```
# 전체 삭제
kubectl delete -f kube-manifests/
```






## 참고 자료
- https://kubernetes.io/docs/tasks/administer-cluster/namespaces-walkthrough/
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/memory-default-namespace/
