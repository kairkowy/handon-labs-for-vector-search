### ONNX 모델 환경 준비
- ONNX 모델 만들기(23.6)
```python
from oml.utils import EmbeddingModel, EmbeddingModelConfig
em = EmbeddingModelConfig.show_preconfigured()
em = EmbeddingModel(model_name="intfloat/multilingual-e5-small")
em.export2file("multilingual-e5-small",output_dir="/home/dev01/labs/23aiNF/data")
```
```ONNX 모델 만들기(23.7)
from oml.utils import ONNXPipeline, ONNXPipelineConfig

ONNXPipelineConfig.show_preconfigured()

config   = ONNXPipelineConfig.from_template("text", max_seq_length=256,
           distance_metrics=["COSINE"], quantize_model=True)
pipeline = ONNXPipeline(model_name="intfloat/multilingual-e5-small",
           config=config)
pipeline.export2file("multilingual-e5-small", output_dir=".")
print("complete export2file")
```


- ONNX 모델 DB 로딩
```sql
CREATE OR REPLACE DIRECTORY VEC_DUMP as '/home/dev01/labs/23aiNF/data';

exec DBMS_VECTOR.DROP_ONNX_MODEL(model_name => 'doc_model', force => true);

EXECUTE DBMS_VECTOR.LOAD_ONNX_MODEL('VEC_DUMP','multilingual-e5-small.onnx',  'multilingual_e5_small');

PL/SQL procedure successfully completed.

SELECT MODEL_NAME, MINING_FUNCTION, ALGORITHM,
ALGORITHM_TYPE, MODEL_SIZE
FROM user_mining_models
WHERE model_name = 'MULTILINGUAL_E5_SMALL'
ORDER BY MODEL_NAME;

```
- 오라클 채인어블 유틸리티 이용한 HWP 문서 텍스트 임베딩

  - 데이터 준비

     샘플 파일 : 개인정보호법령(priv-law.hwpx, pup_data_quality_man.hwp 등)
     저장위치 : /home/dev01/labs/23aiNF/data/

  - DB 환경 준비
```sql
create or replace directory LAWSPATH as '/home/dev01/labs/23aiNF/data/mnd';

CREATE TABLE laws_doc (docid number, lawsname varchar(1000), laws blob, laws_text blob);

alter table laws_doc add primary key(docid);

create table laws_doc_vec (docid number, vec vector)

SELECT dbms_lob.getlength(t.laws) from laws_doc t where id = 3;

DBMS_LOB.GETLENGTH(T.WORD)
--------------------------
                    162571


select DBMS_VECTOR_CHAIN.UTL_TO_TEXT(t.laws),json('{"plaintext":"true","charset":"UTF8"}') from blob_tbl t where id = 3;
```

   - 청킹
```sql
SELECT S.docid, 
    JSON_VALUE(C.column_value, '$.chunk_id' RETURNING NUMBER) AS id,
    JSON_VALUE(C.column_value, '$.chunk_offset' RETURNING NUMBER) AS pos,
    JSON_VALUE(C.column_value, '$.chunk_length' RETURNING NUMBER) AS siz,
    JSON_VALUE(C.column_value, '$.chunk_data') AS txt
from laws_doc S, dbms_vector_chain.utl_to_chunks(
            dbms_vector_chain.utl_to_text(
                s.laws, json('{"plaintext":"true","charset":"UTF8"}')),
            JSON('{ "by"       : "words",
                    "max"      : "100",
                    "overlap"  : "0",
                    "split"    : "recursively",
                    "language" : "korean",
                    "normalize": "all" }')
) C
where S.docid = 3 ;

```

```sql
INSERT INTO laws_doc(docid, lawsname, laws) values
(1,'국군조직법법률제10821호_20111015',to_blob(bfilename('LAWSPATH','국군조직법법률제10821호_20111015.hwpx'))),
(2,'국방대학교설치법법률제14609호_20170622',to_blob(bfilename('LAWSPATH','국방대학교설치법법률제14609호_20170622.hwpx'))),
(3,'군수품관리법법률제17997호_20210413',to_blob(bfilename('LAWSPATH','군수품관리법법률제17997호_20210413.hwpx'))),
(4,'군형법법률제18465호_20220701',to_blob(bfilename('LAWSPATH','군형법법률제18465호_20220701.hwpx'))),
(5,'예비군법법률제19082호_20230614',to_blob(bfilename('LAWSPATH','예비군법법률제19082호_20230614.hwpx'))),
(6,'군용항공기운용등에관한법률_법률제19573호_20240126',to_blob(bfilename('LAWSPATH','군용항공기운용등에관한법률_법률제19573호_20240126.hwpx'))),
(7,'군사법원법법률제19839호_20240118',to_blob(bfilename('LAWSPATH','군사법원법법률_제19839호_20240118.hwpx'))),
(8,'군인공제회법법률제19949호_20240710',to_blob(bfilename('LAWSPATH','군인공제회법법률제19949호_20240710.hwpx'))),
(9,'국방군사시설사업에관한법률법률제20010호_20240717',to_blob(bfilename('LAWSPATH','국방군사시설사업에관한법률법률제20010호_20240717.hwpx'))),
(10,'군인의지및복무에관한 기본법_법률_제20189호_20240807',to_blob(bfilename('LAWSPATH','군인의지및복무에관한기본법_법률_제20189호_20240807.hwpx'))),
(11,'군인보수법법률제20637호_20250107',to_blob(bfilename('LAWSPATH','군인보수법법률제20637호_20250107.hwpx'))),
(12,'방위사업법법률제20644호_20250107',to_blob(bfilename('LAWSPATH','방위사업법법률_제20644호_20250107.hwpx'))),
(13,'군무원인사법법률제20799호_20250919',to_blob(bfilename('LAWSPATH','군무원인사법_법률제20799호_20250919.hwpx'))),
(14,'방어해면법법률제20806호_20250318',to_blob(bfilename('LAWSPATH','방어해면법법률_제20806호_20250318.hwpx'))),
(15,'제2연평해전전사자보상에관한특별법_법률제19228호_20230605',to_blob(bfilename('LAWSPATH','제2연평해전_전사자보상에관한특별법_법률제19228호_20230605.hwpx'))),
(16,'공군본부직제대통령령제34167호_20240130',to_blob(bfilename('LAWSPATH','공군본부직제_대통령령제34167호_20240130.hwpx'))),
(17,'육군본부직제대통령령제34167호_20240130',to_blob(bfilename('LAWSPATH','육군본부직제_대통령령제34167호_20240130.hwpx'))),
(18,'해군본부직제대통령령제34167호_20240130',to_blob(bfilename('LAWSPATH','해군본부직제_대통령령제34167호_20240130.hwpx'))),
(19,'공공데이터 품질관리 수준평가 가이드',to_blob(bfilename('LAWSPATH','공공데이터품질관리수준평가가이드.hwp')))
```
```sql
create table if not exists doc_vector(doc_id number,embed_id number,embed_data varchar2(4000),embed_vector vector)
```
```sql 
insert into doc_vector
    select dt.docid, et.embed_id, et.embed_data, to_vector(et.embed_vector) embed_vector
    from laws_doc dt,
         dbms_vector.utl_to_embeddings(
             dbms_vector_chain.utl_to_chunks(
                    dbms_vector_chain.utl_to_text(
                         dt.laws, JSON('{"plaintext":"true","charset":"UTF8"}')),
             JSON('{ "by"       : "words",
                     "max"      : "100",
                    "overlap"  : "0",
                    "split"    : "newline",
                    "language" : "korean",
                    "normalize": "all" }')),
        json('{"provider":"database", "model":"multilingual_e5_small"}')) t,
    json_table(t.column_value, '$' columns (embed_id number,embed_data varchar2(4000), embed_vector CLOB)) et
    ;
commit;
```