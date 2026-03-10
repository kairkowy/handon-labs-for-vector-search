### 샘플 데이터 생성 스크립트

데이터 출처 : 공공데이터 포털 

데이터명 : 제주특별자치도_개별관광(FIT)_증가에_따른_제주_관광객_소비패턴_변화_분석_BC카드_빅데이터_내국인관광객_20170216

파일명 : jeju_tour_hist_bc_20170216.txtx


테이블 생성

```sql
CREATE TABLE tour_hist_tbl (
  "기준년월"        VARCHAR2(20),
  "관광객유형"      VARCHAR2(100),
  "제주대분류"      VARCHAR2(60),
  "제주중분류"      VARCHAR2(60),
  "업종명"          VARCHAR2(100),
  "성별"            VARCHAR2(20),
  "연령대별"        VARCHAR2(60),
  "카드이용금액"    NUMBER,
  "카드이용건수"    NUMBER,
  "건당이용금액"    NUMBER,
  "데이터기준일자"  DATE
);

```

디렉토리 생성

```sql

crete or replace directory DUMPDIR as '/home/dev01/labs/data';

```

로더 콘트롤 파일 생성(loader.ctl)

```sql
OPTIONS (SKIP = 1)
LOAD DATA
CHARACTERSET UTF8
INFILE './jeju_tour_hist_bc_20170216-utf8.txt'
INTO TABLE tour_hist_tbl
APPEND
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  "기준년월"        CHAR,
  "관광객유형"      CHAR,
  "제주대분류"      CHAR,
  "제주중분류"      CHAR,
  "업종명"          CHAR,
  "성별"            CHAR,
  "연령대별"        CHAR,
  "카드이용금액"    INTEGER EXTERNAL,
  "카드이용건수"    INTEGER EXTERNAL,
  "건당이용금액"    INTEGER EXTERNAL,
  "데이터기준일자"  DATE "YYYY-MM-DD"
)


sqlldr labadmin/Welcome1@orclpdb1 control=loader.ctl

```
