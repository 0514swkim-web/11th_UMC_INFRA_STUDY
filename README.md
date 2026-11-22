# UMC Infra

UMC 11기 인프라 트랙 워크북 실습·미션 기록입니다.
이미 만들어진 백엔드를 **안정적으로 운영하는 법**(무중단 배포, 지표, 확장)을 AWS에서 직접 구성하며 배웁니다.

## 기술 스택
- AWS: EC2 (t4g.micro, ARM), ALB, Auto Scaling, RDS (MySQL), ECR, SSM Parameter Store, IAM
- Docker (멀티 스테이지, arm64 빌드), AWS CLI v2
- 배포 대상 앱: Spring Boot 3.5 / Java 21 / MySQL / JWT (UMC 웹 스터디 movie 백엔드)
- 측정: [zero-downtime-lab](https://github.com/UMC-11th-Workbook-Infra/zero-downtime-lab)
- 작업 환경: Windows 11 + Git Bash

## 폴더 구조
| 폴더 | 내용 |
|---|---|
| `app/` | 배포 대상 Spring Boot 앱. 인프라 실습에 맞게 환경 변수화, `/health`, Dockerfile 추가 |
| `week01-zero-downtime-deploy/` | 1주차 무중단 배포 실습 스크립트와 측정 시나리오 |
| `docs/weeks/` | 주차별 개념 정리 |
| `docs/missions/` | 주차별 미션 기록 (진행 과정, 설정, 오류와 해결, 결과) |
| `docs/captures/` | 주차별 결과 화면 캡처 |

## 진행 현황
| 주차 | 주제 | PR | 결과 | 핵심 캡처 |
|---|---|---|---|---|
| 0 | 스터디 준비 (AWS 계정, IAM, CLI) | [#1](https://github.com/0514swkim-web/11th_UMC_INFRA_STUDY/pull/1) | [정리](docs/weeks/week00.md) | [무료 플랜](docs/captures/week00/01-aws-signup-free-plan.png) · [IAM 사용자](docs/captures/week00/03-iam-user-policy.png) |
| 1 | 신뢰할 수 있는 배포 파이프라인 (무중단 배포) | [#2](https://github.com/0514swkim-web/11th_UMC_INFRA_STUDY/pull/2) | 다운타임 **8.6초 → 0초** · [정리](docs/weeks/week01.md) · [미션 기록](docs/missions/week01.md) | [before](docs/captures/week01/01-before-result-chart.png) · [배포 중 Draining](docs/captures/week01/15-tg-draining-mid-deploy.png) · [after](docs/captures/week01/18-after-result.png) |

## 1주차 한눈에 보기

```
인터넷 ──:80──▶ ALB ──▶ 타겟 그룹 (:3000, /health)
                          ├─ EC2 #1 (ASG) ─ docker app
                          └─ EC2 #2 (ASG) ─ docker app ──:3306──▶ RDS MySQL (비공개)
                 설정·비밀값: SSM Parameter Store  ·  이미지: ECR
```

|  | 단일 EC2 배포 | ALB 롤링 배포 |
|---|---|---|
| 실패 | 42건 (2.8%) | **0건** |
| 순단 | 1회 | **0회** |
| 다운타임 | 8,599ms | **0ms** |

## 로컬에서 앱 실행
```bash
cd app
docker compose -f compose.local.yml up --build     # MySQL + 앱
curl http://localhost:3000/health                  # {"status":"UP"}
```

> 비밀값(DB 비밀번호, JWT 시크릿, AWS 키)은 레포에 없습니다. 실습에서는 SSM Parameter Store(SecureString)로 주입했습니다.
> 실습에 사용한 AWS 리소스는 비용 때문에 실습 후 모두 삭제했습니다.
