# EKS - 클러스터 오토스케일러

## Step-01: 소개
- Kubernetes Cluster Autoscaler는 리소스 부족으로 Pod가 실행되지 않거나, 노드가 충분히 여유로워 Pod를 다른 노드로 옮길 수 있을 때 클러스터 노드 수를 자동으로 조정합니다.

## Step-02: NodeGroup에 --asg-access가 있는지 확인
- 클러스터 또는 노드 그룹 생성 시 `--asg-access` 파라미터가 포함되어 있는지 확인합니다.
- 클러스터 노드 그룹을 생성할 때 설정한 내용 확인

### --asg-access 태그를 사용하면?
- cluster-autoscaler용 IAM 정책이 활성화됩니다.
- 노드 그룹 IAM 역할에서 해당 정책이 있는지 확인합니다.
- Services -> IAM -> Roles -> eksctl-eksdemo1-nodegroup-XXXXXX 이동
- **Permissions** 탭에서 `eksctl-eksdemo1-nodegroup-eksdemo1-ng-private1-PolicyAutoScaling` 인라인 정책이 있어야 합니다.

## Step-03: Cluster Autoscaler 배포
```
# 클러스터에 Cluster Autoscaler 배포
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# cluster-autoscaler.kubernetes.io/safe-to-evict 어노테이션 추가
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
```
## Step-04: Cluster Autoscaler Deployment 편집 (클러스터 이름 및 파라미터 추가)
```
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
```
- **클러스터 이름 추가**
```yml
# 변경 전
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME>

# 변경 후
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/eksdemo1
```

- **파라미터 2개 추가**
```yml
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```
- **참고 예시**
```yml
    spec:
      containers:
      - command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/eksdemo1
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```

## Step-05: 현재 EKS 클러스터 버전에 맞는 Cluster Autoscaler 이미지 설정
- https://github.com/kubernetes/autoscaler/releases 를 확인합니다.
- 클러스터 버전에 맞는 릴리스 버전을 찾아 업데이트합니다.
- 예: 클러스터 버전이 1.16이면 Cluster Autoscaler 버전은 1.16.5
```
# 템플릿
# Cluster Autoscaler 이미지 버전 업데이트
kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v1.XY.Z


# Cluster Autoscaler 이미지 버전 업데이트
kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v1.16.5
```

## Step-06: 이미지 버전 업데이트 확인
```
kubectl -n kube-system get deployment.apps/cluster-autoscaler -o yaml
```
- **샘플 일부 출력**
```yml
    spec:
      containers:
      - command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/eksdemo1
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        image: us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v1.16.5
```

## Step-07: Cluster Autoscaler 로그 확인
```
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```
- 샘플 로그 참고
```log
I0607 09:14:37.793323       1 pre_filtering_processor.go:66] Skipping ip-192-168-60-30.ec2.internal - node group min size reached
I0607 09:14:37.793332       1 pre_filtering_processor.go:66] Skipping ip-192-168-27-213.ec2.internal - node group min size reached
I0607 09:14:37.793408       1 static_autoscaler.go:440] Scale down status: unneededOnly=true lastScaleUpTime=2020-06-07 09:12:27.367461648 +0000 UTC m=+37.138078060 lastScaleDownDeleteTime=2020-06-07 09:12:27.367461724 +0000 UTC m=+37.138078135 lastScaleDownFailTime=2020-06-07 09:12:27.367461801 +0000 UTC m=+37.138078213 scaleDownForbidden=false isDeleteInProgress=false scaleDownInCooldown=true
I0607 09:14:47.803891       1 static_autoscaler.go:192] Starting main loop
I0607 09:14:47.804234       1 utils.go:590] No pod using affinity / antiaffinity found in cluster, disabling affinity predicate for this loop
I0607 09:14:47.804251       1 filter_out_schedulable.go:65] Filtering out schedulables
I0607 09:14:47.804319       1 filter_out_schedulable.go:130] 0 other pods marked as unschedulable can be scheduled.
I0607 09:14:47.804343       1 filter_out_schedulable.go:130] 0 other pods marked as unschedulable can be scheduled.
I0607 09:14:47.804351       1 filter_out_schedulable.go:90] No schedulable pods
I0607 09:14:47.804366       1 static_autoscaler.go:334] No unschedulable pods
I0607 09:14:47.804376       1 static_autoscaler.go:381] Calculating unneeded nodes
I0607 09:14:47.804392       1 pre_filtering_processor.go:66] Skipping ip-192-168-60-30.ec2.internal - node group min size reached
I0607 09:14:47.804401       1 pre_filtering_processor.go:66] Skipping ip-192-168-27-213.ec2.internal - node group min size reached
I0607 09:14:47.804460       1 static_autoscaler.go:440] Scale down status: unneededOnly=true lastScaleUpTime=2020-06-07 09:12:27.367461648 +0000 UTC m=+37.138078060 lastScaleDownDeleteTime=2020-06-07 09:12:27.367461724 +0000 UTC m=+37.138078135 lastScaleDownFailTime=2020-06-07 09:12:27.367461801 +0000 UTC m=+37.138078213 scaleDownForbidden=false isDeleteInProgress=false scaleDownInCooldown=true

```

## Step-08: 간단한 애플리케이션 배포
```
# 애플리케이션 배포
kubectl apply -f kube-manifests/
```

## Step-09: 클러스터 스케일 업: 애플리케이션을 30개 Pod로 확장
- 2~3분 내에 새 노드가 순차적으로 추가되고, Pod가 그 노드에 스케줄링됩니다.
- 최대 노드 수는 노드 그룹 생성 시 지정한 4개입니다.
```
# 터미널 1: Cluster Autoscaler 로그 모니터링
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler

# 터미널 2: 데모 애플리케이션을 30개 Pod로 확장
kubectl get pods
kubectl get nodes 
kubectl scale --replicas=30 deploy ca-demo-deployment 
kubectl get pods

# 터미널 2: 노드 확인
kubectl get nodes -o wide
```
## Step-10: 클러스터 스케일 다운: 애플리케이션을 1개 Pod로 축소
- 쿨다운으로 인해 5~20분 정도 소요될 수 있으며, 노드 그룹 생성 시 설정한 최소 노드 수(2개)까지 줄어듭니다.
```
# 터미널 1: Cluster Autoscaler 로그 모니터링
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler

# 터미널 2: 데모 애플리케이션을 1개 Pod로 축소
kubectl scale --replicas=1 deploy ca-demo-deployment 

# 터미널 2: 노드 확인
kubectl get nodes -o wide
```

## Step-11: 정리
- Cluster Autoscaler는 그대로 두고 애플리케이션만 제거합니다.
```
kubectl delete -f kube-manifests/
```
