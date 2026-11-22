# 1주차 INFRA: 신뢰할 수 있는 배포 파이프라인

> 한 줄 요약: **배포할 때마다 8.6초씩 끊기던 서비스를 ALB + Auto Scaling 그룹 + 롤링 배포로 0초 끊김으로 만든다.** 핵심은 "요청을 받을 서버가 항상 한 대 이상 살아 있게" 하는 것이다.

| | 단일 EC2 배포 (before) | ALB 롤링 배포 (after) |
|---|---|---|
| 실패 | **42건** (전부 `network`) | **0건** |
| 다운타임 | **8,599ms** | **0ms** |

자세한 진행 과정, 설정, 오류와 해결은 👉 [미션 기록](../missions/week01.md)

## 1. 핵심 개념

| 개념 | 쉬운 설명 | 비유 |
|---|---|---|
| **다운타임이 생기는 이유** | 컨테이너를 교체하는 동안 포트를 잡은 프로세스가 없으면 커널이 `TCP RST`를 보내고 클라이언트는 `Connection refused`를 받는다 | 가게 문을 닫고 간판을 바꾸는 동안 손님이 돌아감 |
| **무중단 배포** | 새 버전으로 바꾸는 동안에도 요청을 받을 서버가 항상 하나 이상 있게 하는 배포 | 계산대를 하나씩 교대로 닫기 |
| **ALB (Application Load Balancer)** | 앞에서 요청을 나누고, `/health`로 죽은 서버를 자동으로 빼고, API로 서버를 넣고 뺄 수 있다 | 식당 입구의 안내 직원 |
| **타겟 그룹 / 헬스 체크** | ALB가 요청을 보낼 서버 목록. 10초마다 `/health`를 호출해 2번 연속 성공하면 투입, 2번 연속 실패하면 제외 | 출근 체크 |
| **Draining (`deregistration_delay`)** | 빠지는 서버에 새 요청은 안 보내고, 처리 중인 요청은 정한 시간(30초)까지 끝나기를 기다림 | 마지막 손님까지 계산하고 문 닫기 |
| **Rolling Update** | 서버를 한 대씩 순서대로 교체. 추가 자원이 거의 안 들지만, 교체 중에는 구버전과 신버전이 함께 응답 | 한 줄씩 교대 |
| **Auto Scaling 그룹 (ASG)** | 시작 템플릿으로 찍어 낸 서버를 정한 대수(2대)만큼 항상 유지 | 정원 관리 |
| **시작 템플릿 / user-data** | 새 서버의 설계도와, 처음 부팅할 때 실행할 스크립트 | 신입 사원 온보딩 매뉴얼 |
| **SSM Parameter Store** | 설정값과 비밀값을 중앙에 보관. SecureString은 암호화. 이미지에 넣지 않고 실행할 때 주입 | 금고 |
| **IAM 역할 (인스턴스 프로파일)** | 서버 안에 키를 두지 않고, 서버가 역할에서 임시 권한을 받아 ECR·SSM에 접근 | 사원증 |
| **보안 그룹 체이닝** | 소스를 IP가 아니라 다른 보안 그룹으로 지정 → 인터넷 → ALB → 앱 → DB 순서로만 열림 | 층마다 다른 출입증 |
| **이미지 태그 vs digest** | 태그는 이름표(여러 개 가능), digest는 내용의 해시(정체성). 롤백은 버전 태그로 | 별명과 주민번호 |

## 2. 이번 주 실습 → 파일 위치

| 워크북 단원 | 실습 | 파일 |
|---|---|---|
| (전제) 앱 준비 | 설정을 환경 변수로, `/health` 추가, 인증 예외 | [application.yml](../../app/src/main/resources/application.yml), [HealthController.java](../../app/src/main/java/com/umc/movie/controller/HealthController.java), [WebConfig.java](../../app/src/main/java/com/umc/movie/config/WebConfig.java) |
| (전제) 컨테이너화 | arm64 멀티 스테이지 이미지, 로컬 검증 | [Dockerfile](../../app/Dockerfile), [compose.local.yml](../../app/compose.local.yml) |
| 0.1 before 상태 | 단일 EC2 부팅 스크립트 (`docker stop && docker run`) | [p4-userdata.sh](../../week01-zero-downtime-deploy/p4-userdata.sh) |
| 1 다운타임 측정 | zero-downtime-lab 측정 조건 | [scenario-before.json](../../week01-zero-downtime-deploy/scenario-before.json), [scenario-after.json](../../week01-zero-downtime-deploy/scenario-after.json) |
| 3.2 ~ 3.7 | 보안 그룹, SSM, 시작 템플릿, ALB, ASG, `deploy.sh` | 워크북 명령을 그대로 실행 → [미션 기록](../missions/week01.md#2-무중단-배포-구성--alb--auto-scaling-그룹) |
| 3.8 | ECR 수명 주기 정책 | [ecr-lifecycle.json](../../week01-zero-downtime-deploy/ecr-lifecycle.json) |
| 공통 | Git Bash에서 리소스 ID를 다시 잡는 변수 스크립트 | [vars.sh](../../week01-zero-downtime-deploy/vars.sh) |

### 필수 미션 키워드 → 구현
| 키워드 | 구현 |
|---|---|
| 단일 배포 다운타임 측정 | 5 RPS × 300초, 배포 1회 → 순단 1회, **8,599ms** |
| ALB + 타겟 그룹 | HTTP 80 → `umc-app-tg`(3000, `/health`, draining 30초) |
| Rolling Update | `deploy.sh`: deregister → `wait target-deregistered` → `swap.sh` → register → `wait target-in-service` |
| 무중단 배포 다운타임 재측정 | 같은 조건(600초) → 순단 0회, **0ms** |
| before / after 측정표 | [미션 기록 — 최종 결과](../missions/week01.md#-최종-결과) |

### 사용 리소스 (실습 후 모두 삭제)
```
ALB umc-alb ─ 리스너 :80 ─ 타겟 그룹 umc-app-tg (:3000 /health)
ASG umc-asg (2/2/4) ─ 시작 템플릿 umc-app-lt (t4g.micro, AL2023 arm64) ─ IAM 역할 umc-app-instance
RDS umc-db (MySQL 8.4, 비공개) · ECR umc-app · SSM /umc/app/* (6개)
SG: umc-alb-sg(80/443 ← 인터넷) → umc-app-sg(3000 ← ALB SG) → umc-db-sg(3306 ← 앱 SG)
```

## 3. 자주 하는 실수
- `/health`가 인증 인터셉터에 막혀 **401** → 서버는 멀쩡한데 ALB가 unhealthy로 판단해 트래픽에서 뺀다.
- 실행 이미지를 내 PC 아키텍처(amd64)로 빌드 → `t4g`(ARM)에서 `exec format error`.
- `ENTRYPOINT`를 셸 형식으로 쓰기 → java가 PID 1이 아니라서 `docker stop`의 SIGTERM을 못 받는다.
- 측정 부하를 너무 높게 잡기 → 배포하기 **전부터** 서버가 포화돼 측정이 무의미해진다(베이스라인 실패율부터 확인).
- (Windows) Git Bash에서 `MSYS_NO_PATHCONV=1` 없이 `/umc/app/...` 같은 인자를 넘기기 → `C:/Program Files/Git/...`로 바뀐다.
- (Windows) 한글이 든 파일을 `file://`로 넘기기 → AWS CLI가 CP949로 읽다 실패. `fileb://`를 쓴다.
- 보안 그룹을 참조 순서 그대로 삭제하기 → 다른 SG가 참조 중이면 삭제되지 않는다. 역순(db → app → alb)으로 지운다.

## 4. 스스로 점검하기
<details><summary>Q1. 단일 EC2에서 docker stop && docker run을 하면 왜 요청이 실패하나?</summary>

컨테이너가 내려가면 3000 포트를 받는 프로세스가 사라진다. 그 포트로 들어온 연결에 커널이 TCP RST를 보내 클라이언트가 즉시 `Connection refused`(network 실패)를 받는다. 새 컨테이너가 뜨고 Spring 기동이 끝날 때까지 이 상태가 이어진다.
</details>

<details><summary>Q2. 무중단을 만드는 두 줄이 각각 없으면 무슨 일이 생기나?</summary>

`wait target-deregistered`가 없으면 처리 중인 요청이 있는 컨테이너를 바로 죽여 그 요청들이 실패한다. `wait target-in-service`가 없으면 새 컨테이너가 아직 기동 중인데 다음 서버를 빼서, 두 대 모두 응답하지 못하는 순간이 생긴다.
</details>

<details><summary>Q3. deregistration_delay가 너무 짧으면? 너무 길면?</summary>

짧으면 오래 걸리는 요청이 끝나기 전에 연결이 끊겨 실패가 남는다. 길면 배포 한 번이 그만큼 느려진다. 서비스의 가장 긴 요청 시간에 맞춰 정한다(이번 실습은 30초, 기본값은 300초).
</details>

<details><summary>Q4. Rolling 배포 중에 조심해야 할 변경은?</summary>

교체 중에는 구버전과 신버전이 동시에 트래픽을 받는다. DB 스키마를 호환되지 않게 바꾸거나 API 응답 형식을 바꾸면 이 구간에서 깨진다. 이전 버전과 호환되게 나눠서 배포해야 한다.
</details>

<details><summary>Q5. DB 비밀번호를 Dockerfile의 ENV에 넣으면 안 되는 이유는?</summary>

이미지 레이어에 그대로 남아서 이미지를 받을 수 있는 누구나 볼 수 있다. 비밀번호를 바꾸려면 이미지를 다시 빌드해야 한다. SSM(SecureString)에 두고 실행할 때 주입하면 이미지와 비밀값이 분리된다.
</details>

<details><summary>Q6. /health가 200인데 배포 직후 5xx가 난다면?</summary>

`/health`가 앱이 실제로 요청을 처리할 준비(DB 연결 등)가 되기 전에 200을 주는 경우다. 헬스 체크가 진짜 준비 상태를 반영하는지 확인한다.
</details>

<details><summary>Q7. 측정할 때 실패 유형(network / timeout / server / client)은 각각 무엇을 뜻하나?</summary>

network는 붙을 곳이 없음(배포로 프로세스가 없음, 주소가 틀림), timeout은 앱이 살아 있지만 느림(포화), server(5xx)는 앱 내부 오류, client(4xx)는 요청 자체가 틀림(인증, 필드, 중복 409)이다.
</details>
