===========================================================
### Select AI 자연어 기반 데이터 조회 샘플 - JOIN 쿼리 자동화 
===========================================================

이 예제에서 사용하는 데이터는 오라클에서 제공하는 HR 스키마의 테이블들을 사용합니다.


#### 테이블에 Annotation 추가

NL2SQL이 쿼리 생성 정확도를 높이기 위하여 HR 샘플테이블에 Annotations을 추가함. 하단의 Annotations 을 참고바람.


#### 데이터 프로파일 생성

```sql
-- =============================================
-- Profile Name : HR_NL2SQL_PROFILE
-- =============================================

BEGIN
  -- 기존 프로파일 있으면 삭제 (없어도 무시)
  BEGIN
    DBMS_CLOUD_AI.DROP_PROFILE(
      profile_name => 'NL2SQL_PROFILE',
      force        => TRUE
    );
  EXCEPTION
    WHEN OTHERS THEN
      NULL; 
  END;

  -- 프로파일 생성
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'NL2SQL_PROFILE',
    attributes   => '{
      "provider" :"OPENAI",
      "provider_endpoint": "http://service-ollama",
      "model": "gemma3:12b",
      "conversation": false,
      "max_tokens": 1024,
      "temperature": 0.1,
      "comments": true,
      "annotations": true,
      "object_list": [
        {"owner": "HR", "name" : "COUNTRIES"},
        {"owner": "HR", "name" : "DEPARTMENTS"},
        {"owner": "HR", "name" : "EMPLOYEES"},
        {"owner": "HR", "name" : "JOBS"},
        {"owner": "HR", "name" : "JOB_HISTORY"},
        {"owner": "HR", "name" : "LOCATIONS"},
        {"owner": "HR", "name" : "REGIONS"}
      ]    
    }');
END;
/
```

소규모 서버 환경에서 SQL 추론 성능이 보다 좋은 gemma3:12b 를 사용하고 있음.


#### 자연어 쿼리 실행

```sql
-- ==================================================
-- 세션 프로파일 설정
-- ==================================================

EXECUTE DBMS_CLOUD_AI.CLEAR_PROFILE;

EXECUTE DBMS_CLOUD_AI.SET_PROFILE('NL2SQL_PROFILE');

-- ==================================================
-- Actions : runsql, showsql
-- ==================================================

-- q1
select ai runsql '유럽 지역의 직무별 평균 급여 계산해줘';
JOB_TITLE                                AVG_SALARY
---------------------------------------- ----------
Sales Manager                                 12200
Sales Representative                     8396.55172
Human Resources Representative                 6500
Public Relations Representative               10000



select ai showsql '유럽 지역의 직무별 평균 급여 계산해줘';

RESPONSE
-------------------------------------------------------------------------------------------
SELECT
    j.JOB_TITLE,
    AVG(e.SALARY) AS avg_salary
FROM
    HR.EMPLOYEES e
JOIN
    HR.JOBS j ON e.JOB_ID = j.JOB_ID
JOIN
    HR.DEPARTMENTS d ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
JOIN
    HR.LOCATIONS l ON d.LOCATION_ID = l.LOCATION_ID
JOIN
    HR.COUNTRIES c ON l.COUNTRY_ID = c.COUNTRY_ID
JOIN
    HR.REGIONS r ON c.REGION_ID = r.REGION_ID
WHERE
    UPPER(r.REGION_NAME) = UPPER('Europe')
GROUP BY
    j.JOB_TITLE

-- q2

select ai runsql '직무 변경 이력이 있는 직원의 현재 부서별 통계를 내줘';

Current Department                       Employee Count
---------------------------------------- --------------
Administration                                        2
Executive                                             3
Marketing                                             1
Purchasing                                            1
Sales                                                 2
Shipping                                              1

6 행이 선택되었습니다.


select ai showsql '직무 변경 이력이 있는 직원의 현재 부서별 통계를 내줘';

RESPONSE
------------------------------------------------------------------------------------------------------
SELECT
    d."DEPARTMENT_NAME" AS "Current Department",
    COUNT(e."EMPLOYEE_ID") AS "Employee Count"
FROM
    "HR"."DEPARTMENTS" d
JOIN
    "HR"."EMPLOYEES" e ON d."DEPARTMENT_ID" = e."DEPARTMENT_ID"
JOIN
    "HR"."JOB_HISTORY" jh ON e."EMPLOYEE_ID" = jh."EMPLOYEE_ID"
WHERE
    jh."START_DATE" IS NOT NULL
GROUP BY
    d."DEPARTMENT_NAME"
ORDER BY
    d."DEPARTMENT_NAME"

```

#### Annotations 추가

모델의 추론 성능을 돕기 위하여 테이블 및 컬럼에 annotations를 추가해준다.

```sql
-- =========================================================
-- HR SAMPLE SCHEMA - TABLE LEVEL ANNOTATIONS
-- =========================================================

ALTER TABLE HR.REGIONS
  ANNOTATIONS (
      DESCRIPTION '대륙 또는 권역 마스터 테이블이다. 국가를 상위 지역 단위로 분류한다.',
      ALIASES '권역,지역,리전,대륙'
  );

ALTER TABLE HR.COUNTRIES
  ANNOTATIONS (
      DESCRIPTION '국가 마스터 테이블이다. 국가는 하나의 권역(REGION)에 속한다.',
      ALIASES '국가,나라,컨트리'
  );

ALTER TABLE HR.LOCATIONS
  ANNOTATIONS (
      DESCRIPTION '사업장 또는 사무실 위치 정보 테이블이다. 주소, 우편번호, 도시, 주/도, 국가를 저장한다.',
      ALIASES '근무지,사업장,오피스위치,주소'
  );

ALTER TABLE HR.DEPARTMENTS
  ANNOTATIONS (
      DESCRIPTION '부서 마스터 테이블이다. 각 부서는 부서명(DEPARTMENT_NAME), 관리자(MANAGER_ID), 위치 정보(LOCATION_ID)를 가진다.각 부서는 LOCATION_ID로 LOCATIONS와 연결되고, LOCATIONS는 COUNTRIES, REGIONS를 통해 상위 지역과 연결된다.',
      ALIASES '부서,조직,팀,디파트먼트'
  );


ALTER TABLE HR.JOBS
  ANNOTATIONS (
      DESCRIPTION '직무 마스터 테이블이다. 직무명과 최소/최대 급여 범위를 정의한다.',
      ALIASES '직무,직책,포지션,잡'
  );

ALTER TABLE HR.EMPLOYEES
  ANNOTATIONS (
      DESCRIPTION '직원 기본 정보 테이블이다. 직원의 인적사항, 입사일, 현재 직무, 급여, 관리자, 소속 부서를 저장한다.',
      ALIASES '직원,사원,임직원,직원마스터'
  );

ALTER TABLE HR.JOB_HISTORY
  ANNOTATIONS (
      DESCRIPTION '직원의 과거 직무 및 부서 변경 이력 테이블이다. 시작일과 종료일 기준으로 이력을 관리한다.',
      ALIASES '직무이력,인사이력,경력이력,부서이력'
  );

-- =========================================================
-- HR SAMPLE SCHEMA - COLUMN LEVEL ANNOTATIONS
-- =========================================================

ALTER TABLE HR.REGIONS MODIFY (
  REGION_ID ANNOTATIONS ( DESCRIPTION '권역 식별자', ALIASES '권역ID,지역ID,리전ID', DISPLAY '권역ID'),
  REGION_NAME ANNOTATIONS ( DESCRIPTION '권역명',ALIASES '권역명,지역명,리전명,대륙명', DISPLAY '권역명')
);

ALTER TABLE HR.COUNTRIES MODIFY (
  COUNTRY_ID ANNOTATIONS (  DESCRIPTION '국가 코드(2자리)',   ALIASES '국가코드,나라코드,컨트리코드',   DISPLAY '국가코드'),
  COUNTRY_NAME ANNOTATIONS (  DESCRIPTION '국가명',   ALIASES '국가명,나라명',   DISPLAY '국가명' ),
  REGION_ID ANNOTATIONS (  DESCRIPTION '소속 권역 식별자',   ALIASES '권역ID,상위권역ID',  DISPLAY '권역ID')
);


ALTER TABLE HR.LOCATIONS MODIFY (
  LOCATION_ID ANNOTATIONS (  DESCRIPTION '위치 식별자',   ALIASES '위치ID,사업장ID,근무지ID',   DISPLAY '위치ID'),
  STREET_ADDRESS ANNOTATIONS (  DESCRIPTION '도로명 또는 상세 주소',   ALIASES '주소,도로명주소,상세주소',   DISPLAY '주소'),
  POSTAL_CODE ANNOTATIONS (  DESCRIPTION '우편번호',  ALIASES '우편번호,ZIP',  DISPLAY '우편번호'),
  CITY ANNOTATIONS (  DESCRIPTION '도시명',   ALIASES '도시,시티',   DISPLAY '도시' ),
  STATE_PROVINCE ANNOTATIONS (  DESCRIPTION '주 또는 도/성 정보',   ALIASES '주,도,성,광역행정구역',  DISPLAY '주/도' ),
  COUNTRY_ID ANNOTATIONS (  DESCRIPTION '국가 코드',   ALIASES '국가코드,나라코드',   DISPLAY '국가코드')
);

ALTER TABLE HR.DEPARTMENTS MODIFY (
  DEPARTMENT_ID ANNOTATIONS (   DESCRIPTION '부서 식별자',   ALIASES '부서ID,조직ID,팀ID',   DISPLAY '부서ID'),
  DEPARTMENT_NAME ANNOTATIONS (   DESCRIPTION '부서명',   ALIASES '부서명,조직명,팀명',   DISPLAY '부서명'),
  MANAGER_ID ANNOTATIONS (   DESCRIPTION '부서 관리자 직원 식별자',   ALIASES '부서장ID,매니저ID,관리자ID',   DISPLAY '부서장ID'
  ),
  LOCATION_ID ANNOTATIONS (  DESCRIPTION '부서가 위치한 사업장 식별자',   ALIASES '위치ID,근무지ID,사업장ID',   DISPLAY '위치ID'
  )
);

ALTER TABLE HR.JOBS MODIFY (
  JOB_ID ANNOTATIONS (   DESCRIPTION '직무 식별자',   ALIASES '직무ID,직책ID,포지션ID', DISPLAY '직무ID'),
  JOB_TITLE ANNOTATIONS (  DESCRIPTION '직무명',   ALIASES '직무명,직책명,포지션명',   DISPLAY '직무명'),
  MIN_SALARY ANNOTATIONS (  DESCRIPTION '해당 직무의 최소 급여',   ALIASES '최소급여,급여하한,연봉최소',   DISPLAY '최소급여'
  ),
  MAX_SALARY ANNOTATIONS (  DESCRIPTION '해당 직무의 최대 급여',   ALIASES '최대급여,급여상한,연봉최대',   DISPLAY '최대급여'
  )
);

ALTER TABLE HR.EMPLOYEES MODIFY (
    EMPLOYEE_ID ANNOTATIONS (  DESCRIPTION '직원 식별자',   ALIASES '직원ID,사번,사원번호',   DISPLAY '직원ID' ),
  FIRST_NAME ANNOTATIONS (  DESCRIPTION '이름',   ALIASES '이름,퍼스트네임,명',   DISPLAY '이름'),
  LAST_NAME ANNOTATIONS (  DESCRIPTION '성',   ALIASES '성,라스트네임,성명중 성',   DISPLAY '성' ),
  EMAIL ANNOTATIONS (  DESCRIPTION '직원 이메일 계정',   ALIASES '이메일,메일주소,이메일계정',   DISPLAY '이메일'),
  PHONE_NUMBER ANNOTATIONS (   DESCRIPTION '직원 전화번호',   ALIASES '전화번호,연락처,휴대전화',   DISPLAY '전화번호'),
  HIRE_DATE ANNOTATIONS (  DESCRIPTION '입사일',  ALIASES '입사일자,채용일,고용시작일',  DISPLAY '입사일'),
  JOB_ID ANNOTATIONS (  DESCRIPTION '현재 직무 식별자',  ALIASES '직무ID,현재직무,직책ID',  DISPLAY '직무ID'),
  SALARY ANNOTATIONS (  DESCRIPTION '현재 급여',  ALIASES '급여,월급,연봉기준급여,보수',  DISPLAY '급여'),
  COMMISSION_PCT ANNOTATIONS (  DESCRIPTION '커미션 비율',   ALIASES '수당비율,성과수수료율,인센티브비율',   DISPLAY '커미션비율'),
  MANAGER_ID ANNOTATIONS (  DESCRIPTION '직속 관리자 직원 식별자',   ALIASES '상사ID,매니저ID,관리자ID',   DISPLAY '관리자ID'
  ),
  DEPARTMENT_ID ANNOTATIONS (  DESCRIPTION '현재 소속 부서 식별자',   ALIASES '부서ID,소속부서ID,조직ID',  DISPLAY '부서ID'
  )
);

ALTER TABLE HR.JOB_HISTORY MODIFY (
  EMPLOYEE_ID ANNOTATIONS (  DESCRIPTION '이력 대상 직원 식별자',   ALIASES '직원ID,사번,사원번호',   DISPLAY '직원ID'),
  START_DATE ANNOTATIONS (  DESCRIPTION '해당 직무/부서 이력 시작일',   ALIASES '시작일,발령시작일,이력시작일',  DISPLAY '시작일'),
  END_DATE ANNOTATIONS (  DESCRIPTION '해당 직무/부서 이력 종료일',   ALIASES '종료일,발령종료일,이력종료일',   DISPLAY '종료일'
  ),
  JOB_ID ANNOTATIONS (  DESCRIPTION '과거 수행 직무 식별자',   ALIASES '직무ID,이전직무ID,과거직무ID',   DISPLAY '직무ID' ),
  DEPARTMENT_ID ANNOTATIONS (  DESCRIPTION '과거 소속 부서 식별자',  ALIASES '부서ID,이전부서ID,과거부서ID',  DISPLAY '부서ID')
);

```

#### Annotations 삭제(샘플)

테이블에 지정된 Annotations 벌크 삭제하는 스크립트임.

```sql
CREATE OR REPLACE PROCEDURE DROP_TABLE_ANNOTATIONS (
    p_table_name IN VARCHAR2
)
IS
    v_table_name VARCHAR2(128);
    v_sql        CLOB;
BEGIN
    -- 테이블명 검증 (SQL Injection 방지 + 대문자 정규화)
    v_table_name := UPPER(DBMS_ASSERT.SQL_OBJECT_NAME(p_table_name));

    -- 1) 테이블 레벨 annotations 삭제
    FOR r IN (
        SELECT LISTAGG('DROP "' || annotation_name || '"', ', ')
                 WITHIN GROUP (ORDER BY annotation_name) AS drop_list
        FROM user_annotations_usage
        WHERE object_type = 'TABLE'
          AND object_name = v_table_name
          AND column_name IS NULL
    )
    LOOP
        IF r.drop_list IS NOT NULL THEN
            v_sql := 'ALTER TABLE "' || v_table_name || '" ANNOTATIONS (' || r.drop_list || ')';
            EXECUTE IMMEDIATE v_sql;
            DBMS_OUTPUT.PUT_LINE(v_sql);
        END IF;
    END LOOP;

    -- 2) 컬럼 레벨 annotations 삭제
    FOR c IN (
        SELECT column_name,
               LISTAGG('DROP "' || annotation_name || '"', ', ')
                 WITHIN GROUP (ORDER BY annotation_name) AS drop_list
        FROM user_annotations_usage
        WHERE object_type = 'TABLE'
          AND object_name = v_table_name
          AND column_name IS NOT NULL
        GROUP BY column_name
    )
    LOOP
        v_sql := 'ALTER TABLE "' || v_table_name || '" MODIFY "' ||
                 c.column_name || '" ANNOTATIONS (' || c.drop_list || ')';

        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE(v_sql);
    END LOOP;
END;
/

EXECUTE DROP_TABLE_ANNOTATIONS('REGIONS');
EXECUTE DROP_TABLE_ANNOTATIONS('COUNTRIES');
EXECUTE DROP_TABLE_ANNOTATIONS('LOCATIONS');
EXECUTE DROP_TABLE_ANNOTATIONS('DEPARTMENTS');
EXECUTE DROP_TABLE_ANNOTATIONS('JOBS');
EXECUTE DROP_TABLE_ANNOTATIONS('EMPLOYEES');
EXECUTE DROP_TABLE_ANNOTATIONS('JOB_HISTORY');

```

