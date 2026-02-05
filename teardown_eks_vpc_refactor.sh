#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# EKS-Centric Teardown (final)
#
# Goal
# - "VPC 기준"이 아니라 "EKS 클러스터 기준"으로 EKS 관련 자원을 최대한 삭제
#
# Features
# - 클러스터 이름(들) 입력 또는 자동 탐지(옵션) 후 삭제
# - EKS API 리소스 삭제: managed nodegroups / fargate profiles / addons / cluster
# - 클러스터가 속한 VPC에 대해 EKS 연관 리소스 정리(가능 범위):
#   - ELBv2(ALB/NLB) (클러스터 SG/태그 힌트 기반 + VPC fallback 옵션)
#   - VPC Endpoints(Interface) (옵션)
#   - ENI/SG 의존성 진단 출력 (subnet/sg 삭제는 VPC 삭제 옵션에서만)
# - CloudFormation 스택: eksctl 관련 스택/클러스터 연관 스택 탐지 후 삭제(옵션)
#   - TerminationProtection 기본 스킵(옵션으로 해제 가능)
#   - eksctl-*-cluster 스택 기본 스킵(옵션으로 삭제 가능)
#
# Usage
#   ./eks_teardown.sh --plan  eksdemo1
#   ./eks_teardown.sh --apply eksdemo1
#   ./eks_teardown.sh --apply "eksdemo1,eksdemo2"
#
# Auto-discover clusters (optional)
#   DISCOVER_CLUSTERS=true ./eks_teardown.sh --plan
#
# Environment overrides
#   AWS_PROFILE=default AWS_REGION=ap-northeast-2 ./eks_teardown.sh --apply eksdemo1
#
# Optional VPC delete (DANGER)
#   DELETE_VPC=true ./eks_teardown.sh --apply eksdemo1
# ============================================================

# -------------------------
# Basic config
# -------------------------
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
AWS="aws --profile ${AWS_PROFILE} --region ${AWS_REGION}"

MODE="${1:---plan}"                 # --plan | --apply
SHIFT_CLUSTERS="${2:-}"             # optional: "eksdemo1,eksdemo2"

DISCOVER_CLUSTERS="${DISCOVER_CLUSTERS:-false}"  # true면 list-clusters로 자동 탐지
CLUSTERS=()
if [[ -n "${SHIFT_CLUSTERS}" ]]; then
  IFS=',' read -r -a CLUSTERS <<< "${SHIFT_CLUSTERS}"
fi

# -------------------------
# Toggles
# -------------------------
DELETE_EKS_API="${DELETE_EKS_API:-true}"     # nodegroups/fargate/addons/cluster
DELETE_CFN="${DELETE_CFN:-true}"             # CFN stacks that look cluster-related
DELETE_ELB="${DELETE_ELB:-true}"             # delete ELBv2 early (cluster hint based)
DELETE_VPCE="${DELETE_VPCE:-false}"          # delete VPC endpoints in cluster VPC (optional)
DELETE_VPC="${DELETE_VPC:-false}"            # DANGER: delete VPC itself (not recommended by default)

# CloudFormation safety
DELETE_CLUSTER_STACK="${DELETE_CLUSTER_STACK:-false}"   # delete eksctl-*-cluster stack (danger)
DISABLE_TP_ON_DELETE="${DISABLE_TP_ON_DELETE:-false}"   # auto disable termination protection

# CFN exclusions
SKIP_CFN_PATTERNS="${SKIP_CFN_PATTERNS:-}"              # e.g. "prod,shared,DoNotDelete"
SKIP_CFN_STACKS="${SKIP_CFN_STACKS:-}"                  # explicit stack names to skip

# Sweep control (mostly for VPC delete mode)
MAX_SWEEPS="${MAX_SWEEPS:-6}"
SLEEP_BETWEEN_SWEEPS_SEC="${SLEEP_BETWEEN_SWEEPS_SEC:-10}"

# -------------------------
# Logging
# -------------------------
ts() { date +"%Y-%m-%d %H:%M:%S"; }
log()  { echo -e "\n[$(ts)] [INFO] $*"; }
warn() { echo -e "\n[$(ts)] [WARN] $*"; }
err()  { echo -e "\n[$(ts)] [ERROR] $*" >&2; }
die() { err "$*"; exit 1; }

is_true() { [[ "${1,,}" == "true" || "${1,,}" == "1" || "${1,,}" == "yes" ]]; }

run_or_echo() {
  if [[ "$MODE" == "--plan" ]]; then
    echo "PLAN: $*"
  else
    eval "$*"
  fi
}

tab2lines() { tr '\t' '\n' | sed '/^$/d'; }

require_aws() {
  command -v aws >/dev/null 2>&1 || die "aws CLI not found"
  $AWS sts get-caller-identity >/dev/null 2>&1 || die "AWS auth failed (sts get-caller-identity)"
}

# ============================================================
# Helpers: Cluster discovery & describe
# ============================================================
discover_clusters() {
  $AWS eks list-clusters --query "clusters[]" --output text 2>/dev/null | tab2lines || true
}

cluster_exists() {
  local c="$1"
  $AWS eks describe-cluster --name "$c" --query "cluster.name" --output text >/dev/null 2>&1
}

get_cluster_vpc() {
  local c="$1"
  $AWS eks describe-cluster --name "$c" --query "cluster.resourcesVpcConfig.vpcId" --output text 2>/dev/null || true
}

get_cluster_security_group() {
  local c="$1"
  $AWS eks describe-cluster --name "$c" --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text 2>/dev/null || true
}

get_cluster_subnets() {
  local c="$1"
  $AWS eks describe-cluster --name "$c" --query "cluster.resourcesVpcConfig.subnetIds[]" --output text 2>/dev/null | tab2lines || true
}

# ============================================================
# Diagnostics
# ============================================================
show_enis_in_subnet() {
  local subnet="$1"
  $AWS ec2 describe-network-interfaces \
    --filters Name=subnet-id,Values="$subnet" \
    --query "NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Desc:Description,Req:RequesterId,Att:Attachment.InstanceId,IFType:InterfaceType,SGs:Groups[].GroupId,PublicIp:Association.PublicIp}" \
    --output table 2>/dev/null || true
}

show_enis_using_sg() {
  local sg="$1"
  $AWS ec2 describe-network-interfaces \
    --filters Name=group-id,Values="$sg" \
    --query "NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Desc:Description,Req:RequesterId,Att:Attachment.InstanceId,IFType:InterfaceType,Subnet:SubnetId,PublicIp:Association.PublicIp}" \
    --output table 2>/dev/null || true
}

# ============================================================
# EKS API deletions
# ============================================================
delete_eks_cluster_full() {
  local cluster="$1"
  log "EKS delete: $cluster (nodegroups -> fargate -> addons -> cluster)"

  # nodegroups
  local ngs
  ngs="$($AWS eks list-nodegroups --cluster-name "$cluster" --query 'nodegroups[]' --output text 2>/dev/null || true)"
  ngs="$(echo "$ngs" | tab2lines || true)"
  if [[ -n "$ngs" ]]; then
    for ng in $ngs; do
      run_or_echo "$AWS eks delete-nodegroup --cluster-name \"$cluster\" --nodegroup-name \"$ng\" >/dev/null || true"
      if [[ "$MODE" == "--apply" ]]; then
        $AWS eks wait nodegroup-deleted --cluster-name "$cluster" --nodegroup-name "$ng" || true
      fi
    done
  else
    echo "  (no nodegroups)"
  fi

  # fargate profiles
  local fps
  fps="$($AWS eks list-fargate-profiles --cluster-name "$cluster" --query 'fargateProfileNames[]' --output text 2>/dev/null || true)"
  fps="$(echo "$fps" | tab2lines || true)"
  if [[ -n "$fps" ]]; then
    for fp in $fps; do
      run_or_echo "$AWS eks delete-fargate-profile --cluster-name \"$cluster\" --fargate-profile-name \"$fp\" >/dev/null || true"
      if [[ "$MODE" == "--apply" ]]; then
        $AWS eks wait fargate-profile-deleted --cluster-name "$cluster" --fargate-profile-name "$fp" || true
      fi
    done
  else
    echo "  (no fargate profiles)"
  fi

  # addons
  local adds
  adds="$($AWS eks list-addons --cluster-name "$cluster" --query 'addons[]' --output text 2>/dev/null || true)"
  adds="$(echo "$adds" | tab2lines || true)"
  if [[ -n "$adds" ]]; then
    for a in $adds; do
      run_or_echo "$AWS eks delete-addon --cluster-name \"$cluster\" --addon-name \"$a\" >/dev/null || true"
      if [[ "$MODE" == "--apply" ]]; then
        $AWS eks wait addon-deleted --cluster-name "$cluster" --addon-name "$a" 2>/dev/null || true
      fi
    done
  else
    echo "  (no addons)"
  fi

  # cluster
  run_or_echo "$AWS eks delete-cluster --name \"$cluster\" >/dev/null || true"
  if [[ "$MODE" == "--apply" ]]; then
    $AWS eks wait cluster-deleted --name "$cluster" || true
  fi
}

# ============================================================
# ELBv2 deletion (cluster hint based)
# - Best effort:
#   1) clusterSecurityGroupId와 연결된 ENI를 찾아, 그 ENI가 속한 ELB를 추정하기는 어렵지만
#      EKS는 보통 elbv2에 Kubernetes 태그를 남김:
#        - kubernetes.io/cluster/<name> = owned|shared
#   2) elbv2에는 직접 "tag 필터" API가 없어서:
#      - load balancer ARN 목록 -> describe-tags -> cluster 태그 매칭 후 삭제
# ============================================================
list_elbv2_arns_in_vpc() {
  local vpc="$1"
  $AWS elbv2 describe-load-balancers \
    --query "LoadBalancers[?VpcId=='$vpc'].LoadBalancerArn" --output text 2>/dev/null | tab2lines || true
}

elb_has_cluster_tag() {
  local arn="$1"
  local cluster="$2"
  local key="kubernetes.io/cluster/$cluster"
  $AWS elbv2 describe-tags --resource-arns "$arn" \
    --query "TagDescriptions[0].Tags[?Key=='$key'].Value | [0]" --output text 2>/dev/null | grep -Eq '^(owned|shared)$'
}

delete_elbv2_for_cluster() {
  local cluster="$1"
  local vpc="$2"

  log "ELBv2 delete (tagged to cluster): cluster=$cluster vpc=$vpc"
  local arns
  arns="$(list_elbv2_arns_in_vpc "$vpc" || true)"
  [[ -z "$arns" ]] && { echo "  (no ELBv2 in VPC)"; return; }

  while read -r arn; do
    [[ -z "$arn" ]] && continue
    if elb_has_cluster_tag "$arn" "$cluster"; then
      run_or_echo "$AWS elbv2 delete-load-balancer --load-balancer-arn \"$arn\" >/dev/null || true"
    fi
  done <<< "$arns"
}

# ============================================================
# VPC Endpoint deletion (optional)
# - 클러스터 VPC 전체 엔드포인트 삭제는 위험할 수 있어 기본 OFF
# ============================================================
delete_vpc_endpoints_in_vpc() {
  local vpc="$1"
  log "VPC endpoints delete (VPC-wide): $vpc"
  local eps
  eps="$($AWS ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc" \
    --query "VpcEndpoints[].VpcEndpointId" --output text 2>/dev/null || true)"
  eps="$(echo "$eps" | tab2lines || true)"
  [[ -z "$eps" ]] && { echo "  (none)"; return; }
  run_or_echo "$AWS ec2 delete-vpc-endpoints --vpc-endpoint-ids $eps >/dev/null || true"
}

# ============================================================
# CloudFormation deletion (cluster related)
# - best-effort: 스택 body/parameters/outputs 안에 cluster name 또는 vpc id가 언급되면 후보
# ============================================================
list_active_stacks() {
  $AWS cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE IMPORT_COMPLETE \
    --query "StackSummaries[].StackName" --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d'
}

stack_mentions_text() {
  local stack="$1"
  local pattern="$2"
  $AWS cloudformation describe-stacks --stack-name "$stack" --output text 2>/dev/null | grep -q "$pattern"
}

stack_termination_protection_enabled() {
  local stack="$1"
  local tp
  tp="$($AWS cloudformation describe-stacks --stack-name "$stack" \
    --query "Stacks[0].EnableTerminationProtection" --output text 2>/dev/null || echo "False")"
  [[ "$tp" == "True" ]]
}

disable_termination_protection() {
  local stack="$1"
  run_or_echo "$AWS cloudformation update-termination-protection --stack-name \"$stack\" --no-enable-termination-protection >/dev/null || true"
}

should_skip_stack_by_pattern() {
  local stack="$1"
  [[ -z "$SKIP_CFN_PATTERNS" ]] && return 1
  IFS=',' read -r -a pats <<< "$SKIP_CFN_PATTERNS"
  for p in "${pats[@]}"; do
    [[ -n "$p" ]] && echo "$stack" | grep -qi "$p" && return 0
  done
  return 1
}

should_skip_stack_exact() {
  local stack="$1"
  [[ -z "$SKIP_CFN_STACKS" ]] && return 1
  IFS=',' read -r -a arr <<< "$SKIP_CFN_STACKS"
  for x in "${arr[@]}"; do
    [[ -n "$x" && "$stack" == "$x" ]] && return 0
  done
  return 1
}

rank_stack_child_first() {
  local s="$1"
  if echo "$s" | grep -Eqi 'nodegroup|managednodegroup|addon|fargate|alb|ingress|lb|loadbalancer|targetgroup'; then
    echo "1 $s"
  elif echo "$s" | grep -Eqi 'eksctl|eks|cluster'; then
    echo "9 $s"
  else
    echo "5 $s"
  fi
}

delete_cfn_stacks_for_cluster() {
  local cluster="$1"
  local vpc="$2"

  log "CloudFormation: find stacks related to cluster=$cluster (or vpc=$vpc)"
  local stacks candidates sorted
  stacks="$(list_active_stacks || true)"
  candidates=""

  while read -r s; do
    [[ -z "$s" ]] && continue

    # explicit skip list
    if should_skip_stack_exact "$s"; then
      warn "Skip stack (explicit): $s"
      continue
    fi

    # cluster stack guard (eksctl-*-cluster)
    if echo "$s" | grep -Eq '^eksctl-.*-cluster$'; then
      if ! is_true "$DELETE_CLUSTER_STACK"; then
        warn "Skip cluster stack (DELETE_CLUSTER_STACK=false): $s"
        continue
      fi
    fi

    # match by cluster name OR vpc id (best-effort)
    if ! stack_mentions_text "$s" "$cluster"; then
      stack_mentions_text "$s" "$vpc" || continue
    fi

    # termination protection guard
    if stack_termination_protection_enabled "$s"; then
      if is_true "$DISABLE_TP_ON_DELETE"; then
        warn "TerminationProtection enabled; disabling then deleting: $s"
        disable_termination_protection "$s"
      else
        warn "Skip stack (TerminationProtection enabled): $s"
        continue
      fi
    fi

    # pattern skip
    if should_skip_stack_by_pattern "$s"; then
      warn "Skip stack (pattern): $s"
      continue
    fi

    candidates+="$s"$'\n'
  done <<< "$stacks"

  candidates="$(echo "$candidates" | sed '/^$/d' || true)"
  [[ -z "$candidates" ]] && { echo "  (no stacks found)"; return; }

  sorted="$(while read -r s; do rank_stack_child_first "$s"; done <<< "$candidates" | sort -n | cut -d' ' -f2-)"
  log "Stacks to delete (child-first heuristic):"
  echo "$sorted"

  if [[ "$MODE" == "--plan" ]]; then
    echo "PLAN: would delete stacks above"
    return
  fi

  while read -r s; do
    [[ -z "$s" ]] && continue
    echo "Delete stack: $s"
    $AWS cloudformation delete-stack --stack-name "$s" || true
  done <<< "$sorted"

  while read -r s; do
    [[ -z "$s" ]] && continue
    echo "Wait delete complete: $s"
    $AWS cloudformation wait stack-delete-complete --stack-name "$s" 2>/dev/null || true
  done <<< "$sorted"
}

# ============================================================
# Optional: VPC delete (DANGER)
# - 원래 스크립트의 VPC teardown 로직을 최소 수준으로만 포함
# - 기본은 DELETE_VPC=false
# ============================================================
delete_subnets_sweep() {
  local vpc="$1"
  local deleted_any="false"

  local subs
  subs="$($AWS ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" \
    --query "Subnets[].SubnetId" --output text 2>/dev/null || true)"
  subs="$(echo "$subs" | tab2lines || true)"
  [[ -z "$subs" ]] && { echo "  (no subnets)"; echo "$deleted_any"; return; }

  for s in $subs; do
    if [[ "$MODE" == "--plan" ]]; then
      echo "PLAN: $AWS ec2 delete-subnet --subnet-id \"$s\""
      continue
    fi

    if $AWS ec2 delete-subnet --subnet-id "$s" >/dev/null 2>/tmp/delete_subnet_err.txt; then
      echo "Deleted subnet: $s"
      deleted_any="true"
    else
      warn "DeleteSubnet failed: $s"
      cat /tmp/delete_subnet_err.txt || true
      warn "Dependencies (ENIs) in subnet $s:"
      show_enis_in_subnet "$s"
      warn "Skip subnet for now: $s"
    fi
  done

  echo "$deleted_any"
}

delete_security_groups_sweep() {
  local vpc="$1"
  local deleted_any="false"

  local sgs
  sgs="$($AWS ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || true)"
  sgs="$(echo "$sgs" | tab2lines || true)"
  [[ -z "$sgs" ]] && { echo "  (no security groups)"; echo "$deleted_any"; return; }

  for sg in $sgs; do
    if [[ "$MODE" == "--plan" ]]; then
      echo "PLAN: $AWS ec2 delete-security-group --group-id \"$sg\""
      continue
    fi

    if $AWS ec2 delete-security-group --group-id "$sg" >/dev/null 2>/tmp/delete_sg_err.txt; then
      echo "Deleted SG: $sg"
      deleted_any="true"
    else
      warn "DeleteSecurityGroup failed: $sg"
      cat /tmp/delete_sg_err.txt || true
      warn "Dependencies (ENIs) using SG $sg:"
      show_enis_using_sg "$sg"
      warn "Skip SG for now: $sg"
    fi
  done

  echo "$deleted_any"
}

delete_vpc_itself() {
  local vpc="$1"
  log "VPC delete: $vpc"
  run_or_echo "$AWS ec2 delete-vpc --vpc-id \"$vpc\" >/dev/null || true"
}

# ============================================================
# Main per cluster
# ============================================================
process_cluster() {
  local cluster="$1"

  log "================================================"
  log "PROCESS CLUSTER: $cluster | MODE=$MODE | profile=$AWS_PROFILE | region=$AWS_REGION"
  log "DELETE_EKS_API=$DELETE_EKS_API DELETE_ELB=$DELETE_ELB DELETE_VPCE=$DELETE_VPCE DELETE_CFN=$DELETE_CFN DELETE_VPC=$DELETE_VPC"
  log "DELETE_CLUSTER_STACK=$DELETE_CLUSTER_STACK DISABLE_TP_ON_DELETE=$DISABLE_TP_ON_DELETE"
  log "================================================"

  if ! cluster_exists "$cluster"; then
    warn "Cluster not found (skip): $cluster"
    return
  fi

  local vpc csg
  vpc="$(get_cluster_vpc "$cluster")"
  csg="$(get_cluster_security_group "$cluster")"
  log "Cluster VPC: $vpc | Cluster SG: $csg"
  log "Cluster Subnets:"
  get_cluster_subnets "$cluster" | sed 's/^/  - /' || true

  # 1) Early deletes to release ENI/SG deps (LB first)
  if is_true "$DELETE_ELB"; then
    delete_elbv2_for_cluster "$cluster" "$vpc"
  else
    warn "Skip ELBv2 deletion (DELETE_ELB=false)"
  fi

  if is_true "$DELETE_VPCE"; then
    delete_vpc_endpoints_in_vpc "$vpc"
  else
    warn "Skip VPC endpoint deletion (DELETE_VPCE=false)"
  fi

  # 2) CloudFormation (cluster-related) deletion
  if is_true "$DELETE_CFN"; then
    delete_cfn_stacks_for_cluster "$cluster" "$vpc"
  else
    warn "Skip CloudFormation deletion (DELETE_CFN=false)"
  fi

  # 3) EKS API deletion
  if is_true "$DELETE_EKS_API"; then
    delete_eks_cluster_full "$cluster"
  else
    warn "Skip EKS API deletion (DELETE_EKS_API=false)"
  fi

  # 4) Diagnostics: if something remains blocking, show ENIs attached to cluster SG
  warn "If deletion is blocked, inspect ENIs using the cluster SG ($csg):"
  echo "  $AWS ec2 describe-network-interfaces --filters Name=group-id,Values=$csg \\"
  echo "    --query \"NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Desc:Description,Req:RequesterId,Att:Attachment.InstanceId,Subnet:SubnetId,PublicIp:Association.PublicIp}\" --output table"
  if [[ "$MODE" == "--apply" ]]; then
    show_enis_using_sg "$csg" || true
  fi

  # 5) Optional: delete VPC itself (very dangerous)
  if is_true "$DELETE_VPC"; then
    warn "DELETE_VPC=true: attempting subnet/SG sweeps then VPC delete: $vpc"
    for i in $(seq 1 "$MAX_SWEEPS"); do
      log "SWEEP $i/$MAX_SWEEPS: attempt subnet/SG deletion"
      local sub_deleted sg_deleted
      sub_deleted="$(delete_subnets_sweep "$vpc" || echo "false")"
      sg_deleted="$(delete_security_groups_sweep "$vpc" || echo "false")"

      [[ "$MODE" == "--plan" ]] && break
      if [[ "$sub_deleted" != "true" && "$sg_deleted" != "true" ]]; then
        echo "No progress in this sweep. Sleep ${SLEEP_BETWEEN_SWEEPS_SEC}s..."
        sleep "$SLEEP_BETWEEN_SWEEPS_SEC"
      fi
    done
    delete_vpc_itself "$vpc"
  fi
}

# ============================================================
# Entry
# ============================================================
require_aws
[[ "$MODE" == "--plan" || "$MODE" == "--apply" ]] || die "Usage: $0 --plan|--apply [clusterA,clusterB]"

if is_true "$DISCOVER_CLUSTERS"; then
  log "DISCOVER_CLUSTERS=true: discovering clusters..."
  mapfile -t CLUSTERS < <(discover_clusters)
fi

[[ "${#CLUSTERS[@]}" -gt 0 ]] || die "No clusters provided. Example: $0 --plan eksdemo1 OR DISCOVER_CLUSTERS=true $0 --plan"

log "Target clusters:"
printf ' - %s\n' "${CLUSTERS[@]}"

if [[ "$MODE" == "--apply" ]]; then
  warn "DANGER: This will DELETE resources. Run --plan first."
fi

for c in "${CLUSTERS[@]}"; do
  process_cluster "$c"
done

log "DONE"
