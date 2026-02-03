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


---
# EKS 환경에서 노드당 Pod 개수 제한 정리 (현재 결과: pods=17)

작성일: 2026-02-03 (Asia/Seoul)

---

## 1) 현재 확인 결과

사용자가 `kubectl describe node ... | egrep -n "Capacity:|Allocatable:|pods"` 로 확인한 결과:

- 노드 `ip-192-168-0-101.ap-northeast-2.compute.internal`
  - Capacity pods: **17**
  - Allocatable pods: **17**
- 노드 `ip-192-168-60-15.ap-northeast-2.compute.internal`
  - Capacity pods: **17**
  - Allocatable pods: **17**

즉, **해당 노드에서 스케줄링 가능한 Pod 상한(maxPods)이 17로 설정**되어 있습니다.

---

## 2) 왜 17인가? (가장 흔한 원인: VPC CNI IP/ENI 한계 + EKS 추천 maxPods)

EKS 기본 네트워킹인 **Amazon VPC CNI**는 보통 **Pod 1개당 VPC IP 1개**를 사용합니다.  
따라서 노드(EC2 인스턴스)가 확보 가능한 **ENI 개수**와 **ENI당 IPv4 개수**가 Pod 상한을 강하게 제한합니다.

또한 EKS 최적화 AMI는 인스턴스 타입별로 “권장 maxPods” 값을 적용하는데,  
대표적으로 **t3.medium의 권장 maxPods = 17**인 경우가 흔합니다.

> 결론: **대부분의 경우 `pods: 17`은 인스턴스 타입 + VPC CNI IP 수 제한을 반영한 정상적인 값**입니다.

---

## 3) 내 클러스터에서 추가로 확인할 것들

### 3.1 노드 인스턴스 타입 확인 (정확한 원인 확정용)

```bash
kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.node\.kubernetes\.io/instance-type}{"\tpods="}{.status.capacity.pods}{"\n"}{end}'
```

- 여기서 instance-type이 `t3.medium`이면 `pods=17`과 매우 잘 맞습니다.

---

### 3.2 노드별 현재 Pod 사용량(몇 개가 떠있는지)

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<NODE_NAME> | wc -l
```

---

### 3.3 VPC CNI(aws-node) 설정 확인 (Prefix Delegation 여부, warm IP 설정 등)

```bash
kubectl -n kube-system get ds aws-node -o wide
kubectl -n kube-system describe ds aws-node | egrep -n "ENABLE_PREFIX_DELEGATION|WARM_IP_TARGET|MINIMUM_IP_TARGET|WARM_PREFIX_TARGET"
```

- `ENABLE_PREFIX_DELEGATION=true` 등의 값이 보이면 Prefix 방식으로 IP를 더 촘촘히 확보하는 구성이 가능할 수 있습니다.
- 단, Prefix Delegation으로 IP를 늘려도 **kubelet maxPods가 낮으면** `Capacity pods` 자체는 그대로일 수 있습니다.

---

## 4) Pod 상한을 늘리는 현실적인 방법 3가지

### A) 스케일 아웃(노드 수 증가) — 가장 안전하고 흔한 방법
- 노드당 17 제한은 유지되지만 **클러스터 전체 Pod 수용량은 노드 수만큼 증가**합니다.
- 운영 관점에서 가장 단순하고 예측 가능합니다.

---

### B) 스케일 업(더 큰 인스턴스 타입으로 교체)
- 더 큰 인스턴스는 ENI/IPv4 여유가 커져서 **노드당 pods Capacity도 증가**합니다.
- 단, 비용과 워크로드 특성을 함께 고려해야 합니다.

---

### C) Prefix Delegation(Prefix mode) + maxPods 조정 (고밀도 운영)
- VPC CNI의 IP 할당 방식을 개선해 **노드당 Pod 밀도를 크게 올릴 수 있는 방식**입니다.
- 단, 다음이 필요합니다:
  1. CNI/커널/애드온 조건 충족
  2. CNI 설정 변경(ENABLE_PREFIX_DELEGATION 등)
  3. **kubelet maxPods 설정도 함께 조정**해야 `Capacity pods`가 실제로 올라갈 수 있음
  4. 대개 노드 롤링/재프로비저닝 필요

---

## 5) 참고: “Capacity pods”와 “IP 실제 여유”는 다를 수 있음

- `Capacity/Allocatable pods`는 kubelet의 스케줄링 한계(= maxPods)를 의미합니다.
- 실제로는 IP, 서브넷 잔여 IP, ENI/IPv4 제한이 함께 걸리므로:
  - **maxPods를 무작정 높여도 IP가 부족하면 Pod가 Pending**될 수 있습니다.
  - 따라서 “인스턴스 타입 / 서브넷 IP / CNI 설정 / maxPods”를 함께 보는 것이 핵심입니다.

---

## 6) 요약

- 현재 노드 두 대 모두 `pods: 17` → **노드당 Pod 상한이 17로 설정**
- 가장 흔한 이유: **(t3.medium 등) 인스턴스 타입의 ENI/IP 한계 + EKS 권장 maxPods**
- 늘리는 방법:
  - **노드 수 증가(스케일아웃)**, **인스턴스 업그레이드(스케일업)**, 또는 **Prefix Delegation + maxPods 조정**

---

## 7) 다음 단계(원인 확정에 가장 도움되는 1줄)

아래 명령 결과(인스턴스 타입)만 확인하면 “왜 17인지”를 거의 확정할 수 있습니다:

```bash
kubectl get node ip-192-168-0-101.ap-northeast-2.compute.internal -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}{"\n"}'
```
