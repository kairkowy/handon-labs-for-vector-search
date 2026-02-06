### 온프레미스 Oracle26Ai에서 SelectAI 구성 및 테스트

#### 순서

1. DMBS_CLOUD 패키지 설치
2. Wallet 구성
3. Oracle-Ollama 서비스 ACL 오픈
4. SELECTAI 쿼리 실행(프로파일, 쿼리)

### 구성 및 실행

1. DMBS_CLOUD 패키지 설치

DMBS_CLOUD 패키지 설치

Oracle26Ai 온프레미스에서는 SelectAI, SelectAI Agent 관련 패키지를 추가로 관리자가 구성해줘야 함.

```shell

$ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/catcon.pl -u sys/Welcome1 -force_pdb_mode 'READ WRITE' -b dbms_cloud_install -d $ORACLE_HOME/rdbms/admin/ -l /tmp catclouduser.sql

$ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/catcon.pl -u sys/Welcome1 -force_pdb_mode 'READ WRITE' -b dbms_cloud_install -d $ORACLE_HOME/rdbms/admin/ -l /tmp dbms_cloud_install.sql
```
DMBS_CLOUD 패키지 설치 확인

```sql
sqlplus / as sysdba
set pagesize 200
col owner format a20
col OBJECT_NAME format a30

    CON_ID OWNER                OBJECT_NAME                    STATUS  SHARING            O
---------- -------------------- ------------------------------ ------- ------------------ -
~~~
         3 C##CLOUD$SERVICE     DBMS_CLOUD_OCI_REGIONS         VALID   DATA LINK          Y
         3 PUBLIC               DBMS_CLOUD_OCI_REGIONS         VALID   METADATA LINK      Y
         3 C##CLOUD$SERVICE     DBMS_CLOUD_REST_API_RESULTS$   VALID   METADATA LINK      Y
         3 C##CLOUD$SERVICE     DBMS_CLOUD_FILE_SYSTEM$        VALID   METADATA LINK      Y
         3 C##CLOUD$SERVICE     DBMS_CLOUD_FILE_SYSTEM_UNIQUE  VALID   NONE               Y
         3 C##CLOUD$SERVICE     DBMS_CLOUD_PIPELINE$           VALID   METADATA LINK      Y
         1 C##CLOUD$SERVICE     DBMS_CLOUD_AI_AGENT            VALID   METADATA LINK      Y
~~~
144 rows selected.


alter session set container=orclpdb1;
select owner, object_name, status, sharing, oracle_maintained from dba_objects where object_name like 'DBMS_CLOUD%';
OWNER                OBJECT_NAME                    STATUS  SHARING            O
-------------------- ------------------------------ ------- ------------------ -
C##CLOUD$SERVICE     DBMS_CLOUD_TASK_CLASS$         VALID   METADATA LINK      Y
~~~
PUBLIC               DBMS_CLOUD                     VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_AI                  VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_REPO                VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_PIPELINE_INTERNAL   VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_PIPELINE            VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_NOTIFICATION        VALID   METADATA LINK      Y
C##CLOUD$SERVICE     DBMS_CLOUD_AI_AGENT            VALID   METADATA LINK      Y

72 rows selected.
```

2. Wallet 구성

SelectAI에서 실제 사용을 하지 않더라도 내부 로직상 Wallet를 체크하기 때문에 더미로 환경을 구성해줘야 함.

Wallet 미구성시 에러 메시지
```sql
ERROR at line 1:
ORA-20000: Database property SSL_WALLET not found
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18323
ORA-06512: at line 1
```
```shell
  mkdir -p $HOME/wallets/ssl

  chmod 700 /home/oracle/wallets/ssl
  orapki wallet create -wallet /home/oracle/wallets/ssl -auto_login -pwd Welcome1
```

DB에서 SSL_WALLET DB property 설정 (CDB$ROOT에서)

CDB$ROOT에서 설정

```shell
sqlplus / as sysdba
```
```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;

ALTER DATABASE PROPERTY SET SSL_WALLET = '/home/oracle/wallets/ssl';

// 설정 확인

SELECT property_name, property_value
FROM   database_properties
WHERE  property_name = 'SSL_WALLET';

PROPERTY_NAME                  PROPERTY_VALUE
------------------------------ ----------------------------------------
SSL_WALLET                     /home/oracle/wallets/ssl

```

3. Oracle-Ollama 서비스 ACL 오픈

오라클DB에서 외부 서비스와 API 연결을 위해서는 ACL을 만들어 주어야 함. PDB 뿐만 아니라 CDB에서도 외부 API 연결 서비스를 등록해줘야 함. 그렇지 않으면 Authorization Fail을 만남.

ACL 구성 문제시 에러 메시지
```sql
ERROR at line 1:
ORA-20401: Authorization failed for URI -
http://rwdb23ai.exacspub.exacsvcn.oraclevcn.com/v1/chat/completions
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18323
ORA-06512: at line 1
```
CDB ACL 추가

sqlplus / as sysdba

```sql

BEGIN  
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '10.0.9.197',
    ace  => xs$ace_type(
      privilege_list => xs$name_list('connect','resolve'),
      principal_name => 'C##CLOUD$SERVICE',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/
```

PDB ACL 추가

sqlplus labadmin/labadmin@orclpdb1

```sql
BEGIN  
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
         host => '*',
         ace  => xs$ace_type(privilege_list => xs$name_list('http','connect','resolve'),
                             principal_name => 'labadmin',
                             principal_type => xs_acl.ptype_db)
   );
END;
/
```

패키지 실행권한 부여

```sql
alter session set container=orclpdb1;
GRANT EXECUTE on DBMS_CLOUD to labadmin;
GRANT EXECUTE on DBMS_CLOUD_AI to labadmin;
GRANT EXECUTE on DBMS_CLOUD_PIPELINE to labadmin;
GRANT execute on SYS.UTL_HTTP to labadmin;
GRANT execute on sys.dbms_network_acl_admin to labadmin;

SELECT table_name AS package_name, privilege 
 FROM DBA_TAB_PRIVS 
 WHERE grantee = 'LABADMIN'
 AND   (table_name = 'DBMS_CLOUD_PIPELINE'
        OR table_name = 'DBMS_CLOUD_AI');


col PACKAGE_NAME format a50

PACKAGE_NAME                                       PRIVILEGE
-------------------------------------------------- ----------------------------------------
DBMS_CLOUD_PIPELINE                                EXECUTE
```

### SELECTAI 쿼리 실행(프로파일, 쿼리)

참고[중요] : OLLAMA-Oracle 연계 환경에서는 Ollama 인증 구성을 필요로 하지 않습니다. 아래 메시지를 만나실 경우에는 Nginx Proxy, 오라클 프로파일에 사용자 인증 부분을 제거해주세요

OLLAMA-Oracle 연계시 인증 관련 에러 메시지

```sql
ERROR at line 1:
ORA-20010: Missing credential name
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18323
ORA-06512: at line 1
```

1. SelectAI 프로파일 생성(LLM과 단순 채팅)

- AI 모델서비스 플랫폼 : Ollama
- LLM 모델 : llama3.2

```sql
-- labadmin user
-- 프로파일 생성 
BEGIN
  -- 있으면 삭제 (force => true)
  DBMS_CLOUD_AI.DROP_PROFILE(
    profile_name => 'SELECTAI_CHAT',
    force        => TRUE
  );
END;
/

BEGIN
  -- 생성
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SELECTAI_CHAT',
    attributes   => '{
      "provider":"OPENAI",
      "provider_endpoint": "http://service-ollama",
      "model": "llama3.2",
      "conversation": true
    }',
    status       => 'enabled',
    description  => 'Select AI profile for private Ollama via Nginx proxy'
  );
END;
/

```

SelectAI 실행(LLM과 단순 채팅)

```sql
EXEC DBMS_CLOUD_AI.SET_PROFILE('SELECTAI_CHAT');


select ai chat '오라클26ai 데이터베이스를 한줄로 설명해줘. 한글로';
RESPONSE
--------------------------------------------------------------------------------
Hello! How can I assist you today?
```

2. SelectAI 프로파일 생성(자연어 DB쿼리)

자연어 DB 쿼리는 LLM 모델의 역할이 매우 큼. SQL를 잘 만들수 있도록 학습이 된 모델을 사용하면 보다 더 품질이 좋은 쿼리를 만들 수 있음.

- AI 모델서비스 플랫폼 : Ollama
- LLM 모델 : qwen2.5-coder:7b

```sql

BEGIN
  -- 기존 프로파일 있으면 삭제 (없어도 무시)
  BEGIN
    DBMS_CLOUD_AI.DROP_PROFILE(
      profile_name => 'SELECTAI_QRY',
      force        => TRUE
    );
  EXCEPTION
    WHEN OTHERS THEN
      NULL; 
  END;

  -- 프로파일 생성
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'SELECTAI_QRY',
    attributes   => '{
      "provider_endpoint": "http://service-ollama",
      "model": "qwen2.5-coder:7b",
      "object_list": [
        {"owner": "LABADMIN", "name": "DOC_STORE"},
        {"owner": "LABADMIN", "name": "DOC_STORE_V"},
        {"owner": "LABADMIN", "name": "RAG_TBL"},
        {"owner": "LABADMIN", "name": "FRIENDS"}
      ],
      "max_tokens": 1024,
      "temperature": 0.1,
     "conversation": "false"
    }',
    status       => 'enabled',
    description  => 'Select AI profile for private Ollama via Nginx proxy'
  );
END;
/

```

SelectAI 자연어 DB쿼리 실행

```sql
SELECT DBMS_CLOUD_AI.get_profile();    -- 현재 프로파일 확인

EXEC DBMS_CLOUD_AI.SET_PROFILE('SELECTAI_QRY');

set long 1024

select ai runsql 'doc_store 테이블에서 DOCNO가 10-1인 로우를 출력해줄래?';

DOCNO
------------------------------
DOC_NAME
--------------------------------------------------------------------------------
DOC_CR_DATE
------------------------------------------------------------
DOC_DEPT
--------------------------------------------------------------------------------
10-1
광역 교통망 확충 3개 사업 예타 통과로 대도교통혼잡 해소기대
20250710
기획재정부

select ai runsql 'doc_store 테이블에서 dept_name이 행정안전부인 레코드가 몇개니';
     COUNT
----------
         6

select ai narrate doc_store 테이블에서 dept_name 컬럼값이 행정안전부인 레코드가 몇개니?;

RESPONSE
--------------------------------------------------------------------------------
To find out how many records in the `doc_store` table have a `DOC_DEPT` value
of "행정안전부", we need to count the number of rows that
 match this condition.

The query counts all rows where the `DOC_DEPT` column
is equal to "행정안전부". The result shows that there are
 6 such records in the table.

select ai narrate doc_store 테이블에서 dept_name 컬럼값이 행정안전부인 레코드가 몇개니? 한글로 답해줘;
RESPONSE
--------------------------------------------------------------------------------
행정안전부라는 부서의 문서가 6개 있습니다.


select ai showsql doc_store 테이블에서 dept_name 컬럼값이 행정안전부인 레코드가 몇개니? 한글로 답해줘;

RESPONSE
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*) AS "행정안전부 레코드 수"
FROM LABADMIN."DOC_STORE"
WHERE DOC_DEPT = '행정안전부'

```

참고 : Select AI 구동(Action) 파라미터

```sql
SELECT AI action natural_language_prompt;
```
- runsql : 자연어 프롬프트를 SQL로 실행
- showsql : 자연어 프롬프트를 SQL로 생성
- explainsql : 프롬프트에서 생성된 SQL을 자연어로 설명
- narrate : 데이터베이스에서 실행된 SQL 쿼리 결과를 LLM으로 다시 전송하여 해당 결과에 대한 자연어 설명을 생성
- chat :  프롬프트를 LLM에 전달하여 응답을 생성하고, 응답을 사용자에게 다시 제공. 프로파일(BMS_CLOUD_AI.CREATE_PROFILE)에 "conversation" 파라미터가 true인 경우, 이전 상호 작용 또는 프롬프트의 콘텐츠(스키마 메타데이터 포함 가능)가 응답에 포함됨.


프로파일 초기화

Select AI 환경에서 현재 프로파일을 리셋 할때 사용됨.

```sql
EXEC DBMS_CLOUD_AI.CLEAR_PROFILE;
```
---------  end of document
