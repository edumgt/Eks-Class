# CloudWatch Container Insights로 EKS 모니터링

## Step-01: 소개
- CloudWatch란?
- CloudWatch Container Insights란?
- CloudWatch Agent와 Fluentd란?

## Step-02: EKS 워커 노드 역할에 CloudWatch 정책 연결
- Services -> EC2 -> Worker Node EC2 Instance -> IAM Role -> 해당 역할 클릭
```
# Sample Role ARN
arn:aws:iam::180789647333:role/eksctl-eksdemo1-nodegroup-eksdemo-NodeInstanceRole-1FVWZ2H3TMQ2M

# 연결할 정책
Associate Policy: CloudWatchAgentServerPolicy
```

## Step-03: Container Insights 설치

### CloudWatch Agent와 Fluentd를 DaemonSet으로 배포
- 이 명령은 다음을 수행합니다.
  - Namespace `amazon-cloudwatch` 생성
  - 두 DaemonSet에 필요한 보안 객체 생성:
    - SecurityAccount
    - ClusterRole
    - ClusterRoleBinding
  - 메트릭을 CloudWatch로 전송하는 `Cloudwatch-Agent` DaemonSet 배포
  - 로그를 CloudWatch로 전송하는 Fluentd DaemonSet 배포
  - 두 DaemonSet의 ConfigMap 구성 배포
```
# 템플릿
curl -s https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/<REPLACE_CLUSTER_NAME>/;s/{{region_name}}/<REPLACE-AWS_REGION>/" | kubectl apply -f -

# 클러스터 이름과 리전 교체
curl -s https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/eksdemo1/;s/{{region_name}}/us-east-1/" | kubectl apply -f -
```

## 확인
```
# DaemonSets 목록
kubectl -n amazon-cloudwatch get daemonsets
```


## Step-04: 샘플 Nginx 애플리케이션 배포
```
# 배포
kubectl apply -f kube-manifests
```

## Step-05: 샘플 Nginx 애플리케이션에 부하 생성
```
# 부하 생성
kubectl run --generator=run-pod/v1 apache-bench -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://sample-nginx-service.default.svc.cluster.local/ 
```

## Step-06: CloudWatch 대시보드 접속
- CloudWatch Container Insights 대시보드에 접속


## Step-07: CloudWatch Log Insights
- 컨테이너 로그 확인
- 컨테이너 성능 로그 확인

## Step-08: Container Insights - Log Insights 심화
- 로그 그룹
- Log Insights
- 대시보드 생성

### 평균 노드 CPU 사용률 그래프 만들기
- DashBoard Name: EKS-Performance
- Widget Type: Bar
- Log Group: /aws/containerinsights/eksdemo1/performance
```
STATS avg(node_cpu_utilization) as avg_node_cpu_utilization by NodeName
| SORT avg_node_cpu_utilization DESC 
```

### 컨테이너 재시작
- DashBoard Name: EKS-Performance
- Widget Type: Table
- Log Group: /aws/containerinsights/eksdemo1/performance
```
STATS avg(number_of_container_restarts) as avg_number_of_container_restarts by PodName
| SORT avg_number_of_container_restarts DESC
```

### 클러스터 노드 장애
- DashBoard Name: EKS-Performance
- Widget Type: Table
- Log Group: /aws/containerinsights/eksdemo1/performance
```
stats avg(cluster_failed_node_count) as CountOfNodeFailures 
| filter Type="Cluster" 
| sort @timestamp desc
```
### 컨테이너별 CPU 사용량
- DashBoard Name: EKS-Performance
- Widget Type: Bar
- Log Group: /aws/containerinsights/eksdemo1/performance
```
stats pct(container_cpu_usage_total, 50) as CPUPercMedian by kubernetes.container_name 
| filter Type="Container"
```

### 요청된 Pod vs 실행 중인 Pod
- DashBoard Name: EKS-Performance
- Widget Type: Bar
- Log Group: /aws/containerinsights/eksdemo1/performance
```
fields @timestamp, @message 
| sort @timestamp desc 
| filter Type="Pod" 
| stats min(pod_number_of_containers) as requested, min(pod_number_of_running_containers) as running, ceil(avg(pod_number_of_containers-pod_number_of_running_containers)) as pods_missing by kubernetes.pod_name 
| sort pods_missing desc
```

### 컨테이너 이름별 애플리케이션 로그 에러
- DashBoard Name: EKS-Performance
- Widget Type: Bar
- Log Group: /aws/containerinsights/eksdemo1/application
```
stats count() as countoferrors by kubernetes.container_name 
| filter stream="stderr" 
| sort countoferrors desc
```

- **참고**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-view-metrics.html


## Step-09: Container Insights - CloudWatch 알람
### 알람 생성 - 노드 CPU 사용률
- **메트릭 및 조건 지정**
  - **Select Metric:** Container Insights -> ClusterName -> node_cpu_utilization
  - **Metric Name:** eksdemo1_node_cpu_utilization
  - **Threshold Value:** 4 
  - **중요:** 4% 이상의 CPU 사용률에서 알림 이메일 발송 (테스트용) 
- **액션 구성**
  - **새 주제 생성:** eks-alerts
  - **Email:** dkalyanreddy@gmail.com
  - **Create Topic** 클릭
  - **중요:** 이메일 구독 확인이 필요합니다.
- **이름 및 설명 추가**
  - **Name:** EKS-Nodes-CPU-Alert
  - **Description:** EKS Nodes CPU alert notification  
  - Next 클릭
- **Preview**
  - Preview and Create Alarm
- **사용자 대시보드에 알람 추가**
- 부하 생성 및 알람 확인
```
# 부하 생성
kubectl run --generator=run-pod/v1 apache-bench -i --tty --rm --image=httpd -- ab -n 500000 -c 1000 http://sample-nginx-service.default.svc.cluster.local/ 
```

## Step-10: Container Insights 정리
```
# 템플릿
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/cluster-name/;s/{{region_name}}/cluster-region/" | kubectl delete -f -

# 클러스터 이름 & 리전 교체
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/eksdemo1/;s/{{region_name}}/us-east-1/" | kubectl delete -f -
```

## Step-11: 애플리케이션 정리
```
# 앱 삭제
kubectl delete -f  kube-manifests/
```

## 참고 자료
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights-Prometheus-Setup.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-reference-performance-entries-EKS.html
