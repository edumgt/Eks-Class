# EKS 클러스터 및 노드 그룹 삭제

## Step-01: 노드 그룹 삭제
- 아래 `eksctl delete nodegroup` 명령으로 노드 그룹을 별도로 삭제할 수 있습니다.
```
# EKS 클러스터 목록
 eksctl get clusters

# 노드 그룹 이름 확인
 eksctl get nodegroup --cluster=<clusterName>
 eksctl get nodegroup --cluster=eksdemo1

# 노드 그룹 삭제
 eksctl delete nodegroup --cluster=<clusterName> --name=<nodegroupName>
 eksctl delete nodegroup --cluster=eksdemo1 --name=eksdemo1-ng-public1
```

## Step-02: 클러스터 삭제
- `eksctl delete cluster`로 클러스터를 삭제할 수 있습니다.
```
# 클러스터 삭제
 eksctl delete cluster <clusterName>
 eksctl delete cluster eksdemo1
```

## 중요 참고 사항

### 참고-1: 보안 그룹 변경 사항 롤백
- `eksctl`로 EKS 클러스터를 생성하면 워커 노드 보안 그룹은 기본적으로 22번 포트만 허용합니다.
- 과정 진행 중 여러 **NodePort 서비스**를 생성해 브라우저로 애플리케이션에 접근하고 테스트합니다.
- 이때 자동 생성된 보안 그룹에 애플리케이션 접근 허용 규칙을 추가해야 합니다.
- 따라서 `eksctl`로 클러스터를 삭제할 때는 보안 그룹 변경을 롤백해 원래 상태로 되돌려야 합니다.
- 이렇게 하면 문제 없이 삭제되며, 그렇지 않으면 CloudFormation 이벤트를 확인하고 수동으로 삭제해야 하는 등 작업이 복잡해집니다.

### 참고-2: EC2 워커 노드 IAM 역할/정책 변경 롤백
- `EBS CSI Driver를 사용하는 EBS 스토리지 섹션`에서 워커 노드 IAM 역할에 커스텀 정책을 추가합니다.
- 클러스터 삭제 전 해당 변경을 먼저 롤백하고 정책을 삭제하세요.
- 이렇게 하면 클러스터 삭제 시 문제가 발생하지 않습니다.
