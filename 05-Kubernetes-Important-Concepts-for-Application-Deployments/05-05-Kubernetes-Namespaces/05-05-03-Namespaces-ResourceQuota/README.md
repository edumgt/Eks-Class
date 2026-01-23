# Kubernetes 네임스페이스 - ResourceQuota - YAML 선언형 방식

## Step-01: 네임스페이스 매니페스트 생성
- **중요:** 파일 이름이 `00-`으로 시작해야 k8s 객체 생성 시 네임스페이스가 먼저 생성되어 오류가 발생하지 않습니다.
```yml
apiVersion: v1
kind: Namespace
metadata:
  name: dev3
```

## Step-02: ResourceQuota 매니페스트 생성
```yml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-resource-quota
  namespace: dev3
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi  
    pods: "5"    
    configmaps: "5" 
    persistentvolumeclaims: "5" 
    replicationcontrollers: "5" 
    secrets: "5" 
    services: "5"                      
```


## Step-03: k8s 객체 생성 및 테스트
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

# ResourceQuota 확인
kubectl get quota -n dev3
kubectl describe quota ns-resource-quota -n dev3

# NodePort 확인
kubectl get svc -n dev3

# 워커 노드 퍼블릭 IP 확인
kubectl get nodes -o wide

# 애플리케이션 상태 페이지 접근
http://<WorkerNode-Public-IP>:<NodePort>/usermgmt/health-status

```
## Step-04: 정리
- 이 섹션에서 생성한 모든 k8s 객체 삭제
```
# 전체 삭제
kubectl delete -f kube-manifests/
```

## 참고 자료
- https://kubernetes.io/docs/tasks/administer-cluster/namespaces-walkthrough/
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/


## 추가 참고 자료
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-constraint-namespace/ 
- https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/memory-constraint-namespace/
