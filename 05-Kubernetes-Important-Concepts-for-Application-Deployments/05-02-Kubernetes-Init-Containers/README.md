# Kubernetes - 초기화 컨테이너(Init Containers)

## Step-01: 소개
- 초기화 컨테이너는 앱 컨테이너보다 **먼저** 실행됩니다.
- 앱 이미지에 없는 **유틸리티나 설정 스크립트**를 포함할 수 있습니다.
- 앱 컨테이너 전에 **여러 개의 초기화 컨테이너**를 실행할 수 있습니다.
- 초기화 컨테이너는 일반 컨테이너와 동일하지만 **차이점은 다음과 같습니다.**
  - 항상 **완료될 때까지 실행**됩니다.
  - 각 초기화 컨테이너는 다음 컨테이너가 시작되기 전에 **성공적으로 완료**되어야 합니다.
- 파드의 초기화 컨테이너가 실패하면, Kubernetes는 성공할 때까지 파드를 반복 재시작합니다.
- 단, 파드의 `restartPolicy`가 `Never`라면 Kubernetes는 파드를 재시작하지 않습니다.


## Step-02: 초기화 컨테이너 구현
- Deployment의 `spec.template.spec`에 있는 Pod Template Spec 아래 `initContainers` 섹션을 업데이트합니다.
```yml
  template:
    metadata:
      labels:
        app: usermgmt-restapp
    spec:
      initContainers:
        - name: init-db
          image: busybox:1.31
          command: ['sh', '-c', 'echo -e "Checking for the availability of MySQL Server deployment"; while ! nc -z mysql 3306; do sleep 1; printf "-"; done; echo -e "  >> MySQL DB Server has started";']
```


## Step-03: 생성 및 테스트
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
- https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
