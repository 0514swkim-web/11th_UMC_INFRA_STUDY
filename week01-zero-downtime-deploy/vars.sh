#!/usr/bin/env bash
# 새 Git Bash 를 열 때마다:  source /c/Dev/umc-infra-study/notes/run/vars.sh
# 지금까지 만든 리소스의 ID 를 AWS 에서 다시 조회해 변수로 잡는다. (비밀값 없음)
# 아직 안 만든 리소스는 None 으로 나온다 — 정상.

export AWS_REGION=ap-northeast-2
export AWS_DEFAULT_REGION=ap-northeast-2
# Git Bash 는 "/umc/app/image" 같은 인자를 "C:/Program Files/Git/umc/app/image" 로 바꿔 버린다 → 끈다
export MSYS_NO_PATHCONV=1
# VS Code 가 설치 전 PATH 를 들고 있어도 aws 를 찾도록
case ":$PATH:" in *AWSCLIV2*) ;; *) export PATH="$PATH:/c/Program Files/Amazon/AWSCLIV2" ;; esac

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
APP_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=umc-app-sg --query 'SecurityGroups[0].GroupId' --output text)
DB_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=umc-db-sg --query 'SecurityGroups[0].GroupId' --output text)
ALB_SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=umc-alb-sg --query 'SecurityGroups[0].GroupId' --output text)
ECR=$(aws ecr describe-repositories --repository-names umc-app --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo None)
DB_HOST=$(aws rds describe-db-instances --db-instance-identifier umc-db --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null || echo None)
BEFORE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=umc-before Name=instance-state-name,Values=pending,running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
BEFORE_IP=$(aws ec2 describe-instances --instance-ids "$BEFORE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo None)
TG=$(aws elbv2 describe-target-groups --names umc-app-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo None)
ALB_ARN=$(aws elbv2 describe-load-balancers --names umc-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo None)
ALB=$(aws elbv2 describe-load-balancers --names umc-alb --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo None)
SUBS=($(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --query 'Subnets[0:3].SubnetId' --output text))

cat <<EOF
VPC_ID=$VPC_ID
APP_SG=$APP_SG  DB_SG=$DB_SG  ALB_SG=$ALB_SG
ECR=$ECR
DB_HOST=$DB_HOST
BEFORE_ID=$BEFORE_ID  BEFORE_IP=$BEFORE_IP
TG=$TG
ALB=$ALB
SUBS=${SUBS[*]}
EOF
