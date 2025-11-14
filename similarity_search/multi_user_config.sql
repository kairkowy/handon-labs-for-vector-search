sql>@create_users.sql

vi del_users.sql

-- DDL with plsql

SET SERVEROUTPUT ON;

DECLARE
    v_count NUMBER := &인원수;  -- 삭제할 인원수 입력
    v_username VARCHAR2(30);
BEGIN
    FOR i IN 1 .. v_count LOOP
        v_username := 'USER_' || TO_CHAR(i, 'FM00');
        BEGIN
            EXECUTE IMMEDIATE 'DROP USER ' || v_username || ' CASCADE';
            DBMS_OUTPUT.PUT_LINE('Dropped user ' || v_username);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Skipping ' || v_username || 
                                     ' (reason: ' || SQLERRM || ')');
        END;
    END LOOP;
END;
/

sql>@del_users.sql
