# week01-zero-downtime-deploy

1주차 실습에서 직접 작성해 사용한 스크립트와 설정 파일입니다.
워크북이 제공한 `userdata.sh`(3.4.1), `ssm-params.json`(3.4.2), `deploy.sh`(3.7)는 **워크북 원문 그대로** 실행했기 때문에 여기에는 넣지 않았습니다.

| 파일 | 용도 |
|---|---|
| [vars.sh](vars.sh) | 새 Git Bash를 열 때 `source`해서 리전 설정, `MSYS_NO_PATHCONV=1`, 이미 만든 리소스 ID(VPC, SG, ECR, RDS, TG, ALB...)를 다시 잡는다 |
| [p4-userdata.sh](p4-userdata.sh) | **before 상태**(워크북 0.1)를 재현하는 단일 EC2 부팅 스크립트. Docker를 설치하고 `docker stop && docker run` 방식의 `redeploy.sh`를 만든다 |
| [scenario-before.json](scenario-before.json) | zero-downtime-lab 측정 조건 (before: EC2에 직접, 5 RPS × 300초) |
| [scenario-after.json](scenario-after.json) | 측정 조건 (after: ALB, 5 RPS × 600초) |
| [ecr-lifecycle.json](ecr-lifecycle.json) | 3.8 ECR 수명 주기 정책 (untagged 7일 만료, tagged 최근 10개 유지) |

## 측정 실행 예시

```bash
# zero-downtime-lab 실행 (https://github.com/UMC-11th-Workbook-Infra/zero-downtime-lab)
docker compose up -d                       # http://localhost:9376

# 시나리오의 <ALB-DNS> 를 실제 주소로 바꾼 뒤 측정 시작
curl -s -X POST http://localhost:9376/api/runs \
  -H 'Content-Type: application/json' -d @scenario-after.json
# 베이스라인(30초)이 지난 뒤 배포 1회 실행
```

## Windows(Git Bash)에서 주의
- `source vars.sh`로 `MSYS_NO_PATHCONV=1`을 켜야 `/umc/app/...` 같은 인자가 `C:/Program Files/Git/...`로 바뀌지 않는다.
- 이 설정이 켜진 상태에서는 Windows 프로그램(curl, python, `aws ... file://`)에 파일 경로를 `C:/...` 형식으로 넘긴다.
- 한글이 든 파일을 AWS CLI에 넘길 때는 `fileb://`를 쓴다 (`file://`은 CP949로 읽는다).
