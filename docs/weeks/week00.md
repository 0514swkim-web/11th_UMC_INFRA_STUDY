# 0주차 INFRA: 스터디 준비 — AWS 계정과 CLI

> 한 줄 요약: **비용 사고 없이 실습할 수 있도록 AWS 계정을 안전하게 만들고, 터미널에서 AWS를 조작할 준비를 한다.**

## 1. 핵심 개념

| 개념 | 쉬운 설명 | 비유 |
|---|---|---|
| **무료 플랜** | 6개월, 크레딧 최대 200달러. 크레딧을 다 쓰면 과금되지 않고 사용이 멈춘다 | 선불 교통카드 |
| **리전 (Region)** | 리소스는 리전마다 따로 존재한다. 다른 리전에서 만든 것은 목록에 보이지 않는다 (IAM은 글로벌) | 지점별 창고 |
| **루트 사용자 vs IAM 사용자** | 루트는 제한할 수 없는 마스터키, IAM 사용자는 권한 범위를 정한 계정 | 건물주 마스터키와 직원 출입카드 |
| **MFA** | 비밀번호(아는 것)에 휴대폰 코드(가진 것)를 더해 비밀번호가 유출돼도 로그인을 막는다 | 이중 잠금 |
| **액세스 키** | CLI가 "내가 누구인지" 증명하는 장기 자격 증명. 유출되면 즉시 교체(rotation) | 복제 가능한 열쇠 |
| **AWS CLI** | 콘솔 클릭과 같은 AWS API를 명령으로 호출. 기록이 남고 다시 실행할 수 있다 | 리모컨 |

## 2. 진행 과정

| 단계 | 내용 | 캡처 |
|---|---|---|
| 1 | AWS 신규 가입, **무료 플랜** 선택 | [01](../captures/week00/01-aws-signup-free-plan.png) |
| 2 | 콘솔 리전을 시드니 → **서울(`ap-northeast-2`)**로 변경 | [02](../captures/week00/02-console-region-sydney.png) |
| 3 | 루트 계정 **MFA** 설정 | |
| 4 | CLI 전용 IAM 사용자 `umc-cli` 생성 (콘솔 접근 없음) | [03](../captures/week00/03-iam-user-policy.png) · [04](../captures/week00/04-iam-user-created.png) |
| 5 | 액세스 키 발급 (사용 사례: CLI) | [05](../captures/week00/05-iam-access-key-cli.png) · [06](../captures/week00/06-iam-access-key-created.png) |
| 6 | AWS CLI v2 설치 → `aws configure` → `aws sts get-caller-identity` | |

```bash
winget install Amazon.AWSCLI
aws configure                  # region: ap-northeast-2, output: json
aws sts get-caller-identity    # "Arn": "arn:aws:iam::****:user/umc-cli"
```

## 3. 자주 하는 실수
- 루트 계정의 액세스 키로 CLI를 쓰기 → 유출되면 계정 전체를 잃는다.
- 비밀 키가 보이는 화면(`aws configure` 입력 화면 등)을 캡처해 공유하기 → 즉시 교체해야 한다.
- 리전을 확인하지 않고 리소스를 만들기 → 다른 리전에 만들어져 "없어졌다"고 착각한다.
- 설치 직후 이미 열려 있던 VS Code 터미널에서 `aws`를 실행하기 → PATH가 반영되지 않아 명령을 못 찾는다(재시작 필요).

## 4. 스스로 점검하기
<details><summary>Q1. 루트 계정 키를 CLI에 쓰면 안 되는 이유는?</summary>

루트는 권한을 제한할 수 없어서, 키가 유출되면 결제와 계정 삭제까지 가능하다. IAM 사용자는 권한 범위를 정할 수 있고, 문제가 생기면 그 키만 비활성화하면 된다.
</details>

<details><summary>Q2. 액세스 키가 GitHub에 올라갔다면 가장 먼저 할 일은?</summary>

그 키를 즉시 비활성화하고 삭제한 뒤 새 키를 발급한다. 커밋을 지워도 이미 복제됐을 수 있으므로 키 교체가 우선이다.
</details>
