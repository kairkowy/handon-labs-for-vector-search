===========================================================
### Select AI 자연어 기반 데이터 조회 샘플 - JOIN 쿼리 자동화 
===========================================================

이 예제에서 사용하는 데이터는 오라클에서 제공하는 HR 스키마의 테이블들을 사용합니다.


#### 테이블에 Annotation 추가

NL2SQL이 쿼리 생성 정확도를 높이기 위하여 HR 샘플테이블에 Annotations을 추가함.

참조 SQL 쿼리 - https://github.com/kairkowy/handon-labs-for-vector-search/blob/main/SelectAI/sample_data/annotation_sample.md

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
        {"owner": "LABADMIN", "name" : "countries"},
        {"owner": "LABADMIN", "name" : "departments"},
        {"owner": "LABADMIN", "name" : "employees"},
        {"owner": "LABADMIN", "name" : "jobs"},
        {"owner": "LABADMIN", "name" : "job_history"},
        {"owner": "LABADMIN", "name" : "locations"},
        {"owner": "LABADMIN", "name" : "regions"}
      ]    
    }');
END;
/
```

#### 자연어 데이터 쿼리 실행

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

JOB_TITLE                                   AVG_SALARY
------------------------------------------- ----------
Sales Manager                               12200
Sales Representative                        8396.55172
Human Resources Representative              6500
Public Relations Representative             10000


select ai showsql '유럽 지역의 직무별 평균 급여 계산해줘';

RESPONSE
--------------------------------------------------------------------------------
SELECT
    j.JOB_TITLE,
    AVG(e.SALARY) AS AVG_SALARY
FROM
    LABADMIN.EMPLOYEES e
JOIN
    LABADMIN.DEPARTMENTS d ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
JOIN
    LABADMIN.COUNTRIES c ON d.LOCATION_ID = c.COUNTRY_ID
JOIN
    LABADMIN.REGIONS r ON c.REGION_ID = r.REGION_ID
JOIN
    LABADMIN.JOBS j ON e.JOB_ID = j.JOB_ID
WHERE
    r.REGION_NAME = 'Europe'
GROUP BY
    j.JOB_TITLE

-- q2

select ai runsql '직무 변경 이력이 있는 직원의 현재 부서별 통계를 내줘';

Current Department ID Employee Count
--------------------- --------------
                   90              3
                   30              1
                   50              1
                   80              2
                   10              2
                   20              1


select ai showsql '직무 변경 이력이 있는 직원의 현재 부서별 통계를 내줘';

RESPONSE
----------------------------------------------------------------------
SELECT
    e.DEPARTMENT_ID AS "Current Department ID",
    COUNT(e.EMPLOYEE_ID) AS "Employee Count"
FROM
    "LABADMIN"."EMPLOYEES" e
JOIN
    "LABADMIN"."JOB_HISTORY" jh ON e.EMPLOYEE_ID = jh.EMPLOYEE_ID
GROUP BY
    e.DEPARTMENT_ID
```