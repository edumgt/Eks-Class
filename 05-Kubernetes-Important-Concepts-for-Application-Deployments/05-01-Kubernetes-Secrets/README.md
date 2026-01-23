# Kubernetes - 시크릿(Secrets)

## Step-01: 소개
- Kubernetes 시크릿은 비밀번호, OAuth 토큰, SSH 키 같은 민감한 정보를 저장/관리합니다.
- 민감한 정보를 시크릿에 저장하는 것은 파드 정의나 컨테이너 이미지에 직접 넣는 것보다 더 안전하고 유연합니다.

## Step-02: MySQL DB 비밀번호용 시크릿 생성
###
```
# Mac
echo -n 'dbpassword11' | base64

# URL: https://www.base64encode.org
```
### Kubernetes 시크릿 매니페스트 생성
```yml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-db-password
#type: Opaque means that from kubernetes's point of view the contents of this Secret is unstructured.
#It can contain arbitrary key-value pairs. 
type: Opaque
data:
  # Output of echo -n 'dbpassword11' | base64
  db-password: ZGJwYXNzd29yZDEx
```
## Step-03: MySQL Deployment에 DB 비밀번호 시크릿 적용
```yml
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-db-password
                  key: db-password
```

## Step-04: UMS Deployment에 시크릿 적용
- UMS는 User Management Microservice를 의미합니다.
```yml
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-db-password
                  key: db-password
```

## Step-05: 생성 및 테스트
```
# 전체 객체 생성
kubectl apply -f kube-manifests/

# 파드 목록
kubectl get pods

# 애플리케이션 상태 페이지 접근
http://<WorkerNode-Public-IP>:31231/usermgmt/health-status
```

## Step-06: 정리
- 이 섹션에서 생성한 모든 k8s 객체 삭제
```
# 전체 삭제
kubectl delete -f kube-manifests/

# 파드 목록
kubectl get pods

# sc, pvc, pv 확인
kubectl get sc,pvc,pv
```
