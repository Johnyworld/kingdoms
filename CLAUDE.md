# Kingdoms

Godot 4.7 (GL Compatibility) 2D 헥스 기반 게임. 전 플랫폼 배포 목표.

## 폴더 구조

```
kingdoms/
├── project.godot            # 프로젝트 설정 (진입점, 해상도, autoload 등)
├── icon.svg
├── CLAUDE.md
├── autoload/                # 싱글턴 스크립트 (project.godot에 등록)
│   └── scene_manager.gd     # 페이드 씬 전환 (SceneManager)
├── scenes/                  # 씬별 폴더. 각 폴더에 .tscn + .gd 를 함께 둔다
│   ├── splash/              # 스플래시 (진입점)
│   ├── title/               # 타이틀 메뉴
│   ├── game/                # 게임 본편 (game / range_overlay / fog)
│   ├── character/           # 주인공
│   └── camp/                # 캠프 (camp / camp_menu)
├── assets/                  # 원본 에셋
│   └── tiles/               # 타일 이미지 (svg 등)
├── tiles/                   # 타일셋 리소스 (.tres)
└── docs/
    └── spec/                # 스펙 문서 (아래 구조 참고)
        ├── SPEC.md
        ├── entities/
        ├── features/
        └── data/
```

규칙:
- **씬은 기능 단위 폴더**로 묶고, 그 안에 씬 파일(`.tscn`)과 스크립트(`.gd`)를 함께 둔다.
- **싱글턴**은 `autoload/`에 두고 `project.godot`의 `[autoload]`에 등록한다.
- **원본 에셋**은 `assets/`, 이를 사용하는 **리소스(`.tres`)**는 종류별 폴더(예: `tiles/`)에 둔다.

## 핵심 원칙: 스펙 · 테스트 · 코드는 항상 Sync

기능을 추가하거나 변경할 때는 **스펙 · 테스트 · 코드 세 가지를 항상 동기화**한다. 셋 중 하나만 바뀐 상태로 두지 않는다.

- **코드**를 바꾸면 → 관련 **스펙 문서**(`docs/spec/`)와 **테스트**를 같은 작업 안에서 갱신한다.
- **스펙**을 먼저 정하면 → 그에 맞게 코드를 구현하고 테스트를 추가한다.
- 스펙 문서에는 **실제 구현된 내용만** 적는다. 미구현 항목은 지어내지 말고 `TODO` / `미구현` / `(미사용)`으로 사실대로 표시한다. 아직 없는 관계·로직·값을 추측해 넣지 않는다.
- 아직 만들지 않은 방향성/제안은 `docs/spec/SPEC.md`의 "추천 스펙" 같은 별도 섹션에 명확히 구분해 둔다.

## 스펙 문서 구조 (`docs/spec/`)

- `SPEC.md` — 전체 요약 + 목차(TOC). 개별 스펙은 여기 나열하지 않고 링크만 둔다.
- `entities/<엔티티이름>.md` — 데이터 모델. 파일명은 엔티티 이름, 내용은 properties 중심.
- `features/<기능>.md` — 동작하는 기능 정의.
- `data/<리스트>.md` — 캐릭터 · 아이템 · 자원 등의 리스트.

새 엔티티/기능/데이터를 추가하면 해당 폴더에 문서를 만들고 `SPEC.md` 목차에 링크를 추가한다.

## 테스트

[GUT](https://github.com/bitwes/Gut) 9.x를 쓴다. 테스트는 `test/unit/`에 `test_*.gd`로 둔다.

실행 (헤드리스):
```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```
- GUT 클래스가 임포트 안 됐다는 에러가 나면 최초 1회 `godot --headless --import` 실행.
- BFS 등 헥스 그리드 로직은 실제 `TileMapLayer` + 헥스 타일셋을 테스트에서 생성해 검증한다(엔진 인접 동작에 의존하므로).

## 커밋 규칙

**Conventional Commits** 컨벤션을 따른다. 형식: `type(scope): 내용`

- **타입(type)**:

  | 타입 | 용도 |
  | --- | --- |
  | `feat` | 새 기능 |
  | `fix` | 버그 수정 |
  | `refactor` | 동작 변화 없는 코드 정리 |
  | `docs` | 문서(스펙 등) |
  | `test` | 테스트 추가/수정 |
  | `chore` | 설정 · 빌드 · 기타 잡무 |
  | `style` | 포맷팅(로직 변화 없음) |

- **스코프(scope)**: 선택. 씬/기능 단위로 적는다 — `fog`, `camp`, `character`, `camera`, `title`, `splash` 등.
- **내용은 한국어**로, 무엇을 했는지 간결하게. 필요하면 효과·수치를 괄호로 덧붙인다. 체언/명사형 종결, 불필요한 마침표 생략.
  - 예: `feat(fog): 주인공/캠프 시야(5) 기준 2레이어 안개 추가`
  - 예: `feat(camp): 중앙 캠프 + 클릭 메뉴(자원 정보 / 건축)`
  - 예: `feat(camera): 마우스 휠 줌 (배율 0.5~3)`
- **하나의 논리적 변경**만 담는다. 성격이 다른 변경은 나눠서 커밋한다.
- **스펙·테스트·코드는 한 커밋에 함께** 담는다 (Sync 원칙). 스펙/테스트만 따로 커밋해 코드와 어긋난 상태를 남기지 않는다.
  - 타입은 **그 커밋의 주목적**을 기준으로 정한다. 새 기능이면 딸려오는 스펙/테스트가 있어도 `feat`.
- **커밋·푸시는 사용자가 요청할 때만** 한다.
