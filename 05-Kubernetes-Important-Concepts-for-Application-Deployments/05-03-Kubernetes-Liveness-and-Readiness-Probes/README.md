# Kubernetes - Liveness 및 Readiness 프로브

## Step-01: 소개
- 추가 상세는 `Probes` 슬라이드를 참고하세요.

## Step-02: 명령 기반 Liveness 프로브 생성
```yml
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - nc -z localhost 8095
            initialDelaySeconds: 60
            periodSeconds: 10
```

## Step-03: HTTP GET 기반 Readiness 프로브 생성
```yml
          readinessProbe:
            httpGet:
              path: /usermgmt/health-status
              port: 8095
            initialDelaySeconds: 60
            periodSeconds: 10     
```


## Step-04: k8s 객체 생성 및 테스트
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
```
- **관찰:** User Management 마이크로서비스 파드는 `initialDelaySeconds=60seconds`가 완료되기 전까지 READY 상태가 되지 않습니다.

## Step-05: 정리
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
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
