# Kubernetes - 요청(Requests)과 제한(Limits)

## Step-01: 소개
- 각 파드의 컨테이너에 필요한 CPU/메모리 자원을 지정할 수 있습니다.
- 이 정보를 제공하면 스케줄러가 파드를 어느 노드에 배치할지 결정하는 데 사용합니다.
- 컨테이너에 리소스 제한을 지정하면 kubelet이 해당 `limits`를 적용해 실행 중인 컨테이너가 설정한 제한을 초과해 사용하지 못하도록 합니다.
- 또한 kubelet은 해당 컨테이너가 사용할 수 있도록 시스템 리소스의 `request`만큼을 최소한으로 예약합니다.

## Step-02: 요청 및 제한 추가
```yml
          resources:
            requests:
              memory: "128Mi" # 128 MebiByte는 135 Megabyte(MB)에 해당
              cpu: "500m" # `m`은 milliCPU를 의미
            limits:
              memory: "500Mi"
              cpu: "1000m"  # 1000m은 1 vCPU 코어와 동일
```

## Step-03: k8s 객체 생성 및 테스트
```
# 전체 객체 생성
kubectl apply -f kube-manifests/

# 파드 목록
kubectl get pods

# 파드 목록 화면 감시
kubectl get pods -w

# 파드 상세 및 초기화 컨테이너 확인
kubectl describe pod <usermgmt-microservice-xxxxxx>

# 애플리케이션 상태 페이지 접근
http://<WorkerNode-Public-IP>:31231/usermgmt/health-status

# 노드 목록 및 노드 상세
kubectl get nodes
kubectl describe node <Node-Name>
```
## Step-04: 정리
- 이 섹션에서 생성한 모든 k8s 객체 삭제
```
# 전체 삭제
kubectl delete -f kube-manifests/

# 파드 목록
kubectl get pods

# sc, pvc, pv 확인
kubectl get sc,pvc,pv
```

## 참고 자료
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
