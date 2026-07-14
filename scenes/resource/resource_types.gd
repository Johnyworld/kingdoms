class_name ResourceTypes
## 자원 카탈로그 — 자원 판매가(금 단위). ItemTypes·BuildingTypes와 같은 GDScript 카탈로그 패턴.
## 지금은 판매가만 수록. 인구(노동력)·금(화폐)은 판매 불가라 미수록(value 0).

# 자원명 → 판매가(금). 상거래([Trade](../../docs/spec/features/trade.md))에서 화물→금 환산에 쓴다.
const VALUES := {
	"밀": 1,
	"빵": 3,
	"나무": 1,
	"목재": 2,
	"철": 5,
	"철괴": 12,
	"고기": 2,   # 사냥터·축사 산출
	"생선": 2,   # 낚시터 산출
	"은": 8,     # 은광 산출(희소)
	"밀가루": 2, # 제분소 가공(2차 생산)
	"은괴": 20,  # 제련소 가공
	"금괴": 30,  # 제련소 가공
}

## 자원 1개의 판매가(금). 인구·금·미등록 자원은 0(판매 불가).
static func value(res_name: String) -> int:
	return VALUES.get(res_name, 0)
