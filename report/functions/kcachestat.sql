/* ===== Statements stats functions ===== */

CREATE FUNCTION top_kcache_statements(IN sserver_id integer, IN start_id integer, IN end_id integer)
RETURNS TABLE(
    server_id                integer,
    datid                    oid,
    dbname                   name,
    userid                   oid,
    username                 name,
    queryid                  bigint,
    toplevel                 boolean,
    exec_user_time           double precision, --  User CPU time used
    user_time_pct            float, --  User CPU time used percentage
    exec_system_time         double precision, --  System CPU time used
    system_time_pct          float, --  System CPU time used percentage
    exec_minflts             bigint, -- Number of page reclaims (soft page faults)
    exec_majflts             bigint, -- Number of page faults (hard page faults)
    exec_nswaps              bigint, -- Number of swaps
    exec_reads               bigint, -- Number of bytes read by the filesystem layer
    exec_writes              bigint, -- Number of bytes written by the filesystem layer
    exec_msgsnds             bigint, -- Number of IPC messages sent
    exec_msgrcvs             bigint, -- Number of IPC messages received
    exec_nsignals            bigint, -- Number of signals received
    exec_nvcsws              bigint, -- Number of voluntary context switches
    exec_nivcsws             bigint,
    reads_total_pct          float,
    writes_total_pct         float,
    plan_user_time           double precision, --  User CPU time used
    plan_system_time         double precision, --  System CPU time used
    plan_minflts             bigint, -- Number of page reclaims (soft page faults)
    plan_majflts             bigint, -- Number of page faults (hard page faults)
    plan_nswaps              bigint, -- Number of swaps
    plan_reads               bigint, -- Number of bytes read by the filesystem layer
    plan_writes              bigint, -- Number of bytes written by the filesystem layer
    plan_msgsnds             bigint, -- Number of IPC messages sent
    plan_msgrcvs             bigint, -- Number of IPC messages received
    plan_nsignals            bigint, -- Number of signals received
    plan_nvcsws              bigint, -- Number of voluntary context switches
    plan_nivcsws             bigint
) SET search_path=@extschema@ AS $$
  WITH tot AS (
        SELECT
            COALESCE(sum(exec_user_time), 0.0) + COALESCE(sum(plan_user_time), 0.0) AS user_time,
            COALESCE(sum(exec_system_time), 0.0) + COALESCE(sum(plan_system_time), 0.0)  AS system_time,
            COALESCE(sum(exec_reads), 0) + COALESCE(sum(plan_reads), 0) AS reads,
            COALESCE(sum(exec_writes), 0) + COALESCE(sum(plan_writes), 0) AS writes
        FROM sample_kcache_total
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id)
    SELECT
        kc.server_id as server_id,
        kc.datid as datid,
        sample_db.datname as dbname,
        kc.userid as userid,
        rl.username as username,
        kc.queryid as queryid,
        kc.toplevel as toplevel,
        sum(kc.exec_user_time) as exec_user_time,
        ((COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0))
          *100/NULLIF(min(tot.user_time),0.0))::float AS user_time_pct,
        sum(kc.exec_system_time) as exec_system_time,
        ((COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0))
          *100/NULLIF(min(tot.system_time), 0.0))::float AS system_time_pct,
        sum(kc.exec_minflts)::bigint as exec_minflts,
        sum(kc.exec_majflts)::bigint as exec_majflts,
        sum(kc.exec_nswaps)::bigint as exec_nswaps,
        sum(kc.exec_reads)::bigint as exec_reads,
        sum(kc.exec_writes)::bigint as exec_writes,
        sum(kc.exec_msgsnds)::bigint as exec_msgsnds,
        sum(kc.exec_msgrcvs)::bigint as exec_msgrcvs,
        sum(kc.exec_nsignals)::bigint as exec_nsignals,
        sum(kc.exec_nvcsws)::bigint as exec_nvcsws,
        sum(kc.exec_nivcsws)::bigint as exec_nivcsws,
        ((COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))
          *100/NULLIF(min(tot.reads),0))::float AS reads_total_pct,
        ((COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))
          *100/NULLIF(min(tot.writes),0))::float AS writes_total_pct,
        sum(kc.plan_user_time) as plan_user_time,
        sum(kc.plan_system_time) as plan_system_time,
        sum(kc.plan_minflts)::bigint as plan_minflts,
        sum(kc.plan_majflts)::bigint as plan_majflts,
        sum(kc.plan_nswaps)::bigint as plan_nswaps,
        sum(kc.plan_reads)::bigint as plan_reads,
        sum(kc.plan_writes)::bigint as plan_writes,
        sum(kc.plan_msgsnds)::bigint as plan_msgsnds,
        sum(kc.plan_msgrcvs)::bigint as plan_msgrcvs,
        sum(kc.plan_nsignals)::bigint as plan_nsignals,
        sum(kc.plan_nvcsws)::bigint as plan_nvcsws,
        sum(kc.plan_nivcsws)::bigint as plan_nivcsws
   FROM sample_kcache kc
        -- User name
        JOIN roles_list rl USING (server_id, userid)
        -- Database name
        JOIN sample_stat_database sample_db
        USING (server_id, sample_id, datid)
        -- Total stats
        CROSS JOIN tot
    WHERE kc.server_id = sserver_id AND kc.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY
      kc.server_id,
      kc.datid,
      sample_db.datname,
      kc.userid,
      rl.username,
      kc.queryid,
      kc.toplevel
$$ LANGUAGE sql;

CREATE FUNCTION top_kcache_statements_aggr(IN sserver_id integer, IN start_id integer, IN end_id integer)
RETURNS TABLE(
    server_id                integer,
    datid                    oid,
    dbname                   name,
    userid                   oid,
    username                 name,
    queryid                  bigint,
    toplevel                 boolean,
    exec_user_time           double precision, --  User CPU time used
    user_time_pct            float, --  User CPU time used percentage
    exec_system_time         double precision, --  System CPU time used
    system_time_pct          float, --  System CPU time used percentage
    exec_minflts             bigint, -- Number of page reclaims (soft page faults)
    exec_majflts             bigint, -- Number of page faults (hard page faults)
    exec_nswaps              bigint, -- Number of swaps
    exec_reads               bigint, -- Number of bytes read by the filesystem layer
    exec_writes              bigint, -- Number of bytes written by the filesystem layer
    exec_msgsnds             bigint, -- Number of IPC messages sent
    exec_msgrcvs             bigint, -- Number of IPC messages received
    exec_nsignals            bigint, -- Number of signals received
    exec_nvcsws              bigint, -- Number of voluntary context switches
    exec_nivcsws             bigint,
    reads_total_pct          float,
    writes_total_pct         float,
    plan_user_time           double precision, --  User CPU time used
    plan_system_time         double precision, --  System CPU time used
    plan_minflts             bigint, -- Number of page reclaims (soft page faults)
    plan_majflts             bigint, -- Number of page faults (hard page faults)
    plan_nswaps              bigint, -- Number of swaps
    plan_reads               bigint, -- Number of bytes read by the filesystem layer
    plan_writes              bigint, -- Number of bytes written by the filesystem layer
    plan_msgsnds             bigint, -- Number of IPC messages sent
    plan_msgrcvs             bigint, -- Number of IPC messages received
    plan_nsignals            bigint, -- Number of signals received
    plan_nvcsws              bigint, -- Number of voluntary context switches
    plan_nivcsws             bigint
) SET search_path=@extschema@ AS $$
  WITH tot AS (
        SELECT
            COALESCE(sum(exec_user_time), 0.0) + COALESCE(sum(plan_user_time), 0.0) AS user_time,
            COALESCE(sum(exec_system_time), 0.0) + COALESCE(sum(plan_system_time), 0.0)  AS system_time,
            COALESCE(sum(exec_reads), 0) + COALESCE(sum(plan_reads), 0) AS reads,
            COALESCE(sum(exec_writes), 0) + COALESCE(sum(plan_writes), 0) AS writes
        FROM sample_kcache_total
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id)
    SELECT
        kc.server_id as server_id,
        kc.datid as datid,
        sample_db.datname as dbname,
        kc.userid as userid,
        rl.username as username,
        ('x' || left(kc.queryid_md5, 16))::bit(64)::bigint as queryid,,
        kc.toplevel as toplevel,
        sum(kc.exec_user_time) as exec_user_time,
        ((COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0))
          *100/NULLIF(min(tot.user_time),0.0))::float AS user_time_pct,
        sum(kc.exec_system_time) as exec_system_time,
        ((COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0))
          *100/NULLIF(min(tot.system_time), 0.0))::float AS system_time_pct,
        sum(kc.exec_minflts)::bigint as exec_minflts,
        sum(kc.exec_majflts)::bigint as exec_majflts,
        sum(kc.exec_nswaps)::bigint as exec_nswaps,
        sum(kc.exec_reads)::bigint as exec_reads,
        sum(kc.exec_writes)::bigint as exec_writes,
        sum(kc.exec_msgsnds)::bigint as exec_msgsnds,
        sum(kc.exec_msgrcvs)::bigint as exec_msgrcvs,
        sum(kc.exec_nsignals)::bigint as exec_nsignals,
        sum(kc.exec_nvcsws)::bigint as exec_nvcsws,
        sum(kc.exec_nivcsws)::bigint as exec_nivcsws,
        ((COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))
          *100/NULLIF(min(tot.reads),0))::float AS reads_total_pct,
        ((COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))
          *100/NULLIF(min(tot.writes),0))::float AS writes_total_pct,
        sum(kc.plan_user_time) as plan_user_time,
        sum(kc.plan_system_time) as plan_system_time,
        sum(kc.plan_minflts)::bigint as plan_minflts,
        sum(kc.plan_majflts)::bigint as plan_majflts,
        sum(kc.plan_nswaps)::bigint as plan_nswaps,
        sum(kc.plan_reads)::bigint as plan_reads,
        sum(kc.plan_writes)::bigint as plan_writes,
        sum(kc.plan_msgsnds)::bigint as plan_msgsnds,
        sum(kc.plan_msgrcvs)::bigint as plan_msgrcvs,
        sum(kc.plan_nsignals)::bigint as plan_nsignals,
        sum(kc.plan_nvcsws)::bigint as plan_nvcsws,
        sum(kc.plan_nivcsws)::bigint as plan_nivcsws
   FROM sample_kcache kc
        -- User name
        JOIN roles_list rl USING (server_id, userid)
        -- Database name
        JOIN sample_stat_database sample_db
        USING (server_id, sample_id, datid)
        -- Total stats
        CROSS JOIN tot
    WHERE kc.server_id = sserver_id AND kc.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY
      kc.server_id,
      kc.datid,
      sample_db.datname,
      kc.userid,
      rl.username,
      kc.queryid_md5,
      kc.toplevel
$$ LANGUAGE sql;


CREATE FUNCTION top_cpu_time_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT
        kc.datid as datid,
        kc.dbname as dbname,
        kc.userid as userid,
        kc.username as username,
        kc.queryid as queryid,
        kc.toplevel as toplevel,
        NULLIF(kc.plan_user_time, 0.0) as plan_user_time,
        NULLIF(kc.exec_user_time, 0.0) as exec_user_time,
        NULLIF(kc.user_time_pct, 0.0) as user_time_pct,
        NULLIF(kc.plan_system_time, 0.0) as plan_system_time,
        NULLIF(kc.exec_system_time, 0.0) as exec_system_time,
        NULLIF(kc.system_time_pct, 0.0) as system_time_pct
    FROM top_kcache_statements1 kc
    WHERE COALESCE(kc.plan_user_time, 0.0) + COALESCE(kc.plan_system_time, 0.0) +
      COALESCE(kc.exec_user_time, 0.0) + COALESCE(kc.exec_system_time, 0.0) > 0
    ORDER BY COALESCE(kc.plan_user_time, 0.0) + COALESCE(kc.plan_system_time, 0.0) +
      COALESCE(kc.exec_user_time, 0.0) + COALESCE(kc.exec_system_time, 0.0) DESC,
      kc.datid,
      kc.userid,
      kc.queryid,
      kc.toplevel
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
        '<tr>'
          '<th rowspan="2">Query ID</th>'
          '<th rowspan="2">Database</th>'
          '<th rowspan="2">User</th>'
          '<th title="Userspace CPU" colspan="{rusage_planstats?cputime_colspan}">User Time</th>'
          '<th title="Kernelspace CPU" colspan="{rusage_planstats?cputime_colspan}">System Time</th>'
        '</tr>'
        '<tr>'
          '{rusage_planstats?user_plan_time_hdr}'
          '<th title="User CPU time elapsed during execution">Exec (s)</th>'
          '<th title="User CPU time elapsed by this statement as a percentage of total user CPU time">%Total</th>'
          '{rusage_planstats?system_plan_time_hdr}'
          '<th title="System CPU time elapsed during execution">Exec (s)</th>'
          '<th title="System CPU time elapsed by this statement as a percentage of total system CPU time">%Total</th>'
        '</tr>'
        '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '{rusage_planstats?user_plan_time_row}'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{rusage_planstats?system_plan_time_row}'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'rusage_planstats?cputime_colspan','3',
      '!rusage_planstats?cputime_colspan','2',
      'rusage_planstats?user_plan_time_hdr',
        '<th title="User CPU time elapsed during planning">Plan (s)</th>',
      'rusage_planstats?system_plan_time_hdr',
        '<th title="System CPU time elapsed during planning">Plan (s)</th>',
      'rusage_planstats?user_plan_time_row',
        '<td {value}>%6$s</td>',
      'rusage_planstats?system_plan_time_row',
        '<td {value}>%9$s</td>'
    );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,
            to_hex(r_result.queryid),
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            r_result.dbname,
            r_result.username,
            round(CAST(r_result.plan_user_time AS numeric),2),
            round(CAST(r_result.exec_user_time AS numeric),2),
            round(CAST(r_result.user_time_pct AS numeric),2),
            round(CAST(r_result.plan_system_time AS numeric),2),
            round(CAST(r_result.exec_system_time AS numeric),2),
            round(CAST(r_result.system_time_pct AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION top_cpu_time_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(kc1.datid,kc2.datid) as datid,
        COALESCE(kc1.dbname,kc2.dbname) as dbname,
        COALESCE(kc1.userid,kc2.userid) as userid,
        COALESCE(kc1.username,kc2.username) as username,
        COALESCE(kc1.queryid,kc2.queryid) as queryid,
        COALESCE(kc1.toplevel,kc2.toplevel) as toplevel,
        NULLIF(kc1.plan_user_time, 0.0) as plan_user_time1,
        NULLIF(kc1.exec_user_time, 0.0) as exec_user_time1,
        NULLIF(kc1.user_time_pct, 0.0) as user_time_pct1,
        NULLIF(kc1.plan_system_time, 0.0) as plan_system_time1,
        NULLIF(kc1.exec_system_time, 0.0) as exec_system_time1,
        NULLIF(kc1.system_time_pct, 0.0) as system_time_pct1,
        NULLIF(kc2.plan_user_time, 0.0) as plan_user_time2,
        NULLIF(kc2.exec_user_time, 0.0) as exec_user_time2,
        NULLIF(kc2.user_time_pct, 0.0) as user_time_pct2,
        NULLIF(kc2.plan_system_time, 0.0) as plan_system_time2,
        NULLIF(kc2.exec_system_time, 0.0) as exec_system_time2,
        NULLIF(kc2.system_time_pct, 0.0) as system_time_pct2,
        row_number() over (ORDER BY COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc1.exec_system_time, 0.0) DESC NULLS LAST) as time1,
        row_number() over (ORDER BY COALESCE(kc2.exec_user_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) DESC NULLS LAST) as time2
    FROM top_kcache_statements1 kc1
        FULL OUTER JOIN top_kcache_statements2 kc2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(kc1.plan_user_time, 0.0) + COALESCE(kc2.plan_user_time, 0.0) +
        COALESCE(kc1.plan_system_time, 0.0) + COALESCE(kc2.plan_system_time, 0.0) +
        COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc2.exec_user_time, 0.0) +
        COALESCE(kc1.exec_system_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) > 0
    ORDER BY COALESCE(kc1.plan_user_time, 0.0) + COALESCE(kc2.plan_user_time, 0.0) +
        COALESCE(kc1.plan_system_time, 0.0) + COALESCE(kc2.plan_system_time, 0.0) +
        COALESCE(kc1.exec_user_time, 0.0) + COALESCE(kc2.exec_user_time, 0.0) +
        COALESCE(kc1.exec_system_time, 0.0) + COALESCE(kc2.exec_system_time, 0.0) DESC,
        COALESCE(kc1.datid,kc2.datid),
        COALESCE(kc1.userid,kc2.userid),
        COALESCE(kc1.queryid,kc2.queryid),
        COALESCE(kc1.toplevel,kc2.toplevel)
        ) t1
    WHERE least(
        time1,
        time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
        '<tr>'
          '<th rowspan="2">Query ID</th>'
          '<th rowspan="2">Database</th>'
          '<th rowspan="2">User</th>'
          '<th rowspan="2">I</th>'
          '<th title="Userspace CPU" colspan="{rusage_planstats?cputime_colspan}">User Time</th>'
          '<th title="Kernelspace CPU" colspan="{rusage_planstats?cputime_colspan}">System Time</th>'
        '</tr>'
        '<tr>'
          '{rusage_planstats?user_plan_time_hdr}'
          '<th title="User CPU time elapsed during execution">Exec (s)</th>'
          '<th title="User CPU time elapsed by this statement as a percentage of total user CPU time">%Total</th>'
          '{rusage_planstats?system_plan_time_hdr}'
          '<th title="System CPU time elapsed during execution">Exec (s)</th>'
          '<th title="System CPU time elapsed by this statement as a percentage of total system CPU time">%Total</th>'
        '</tr>'
        '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%5$s</td>'
          '<td {label} {title1}>1</td>'
          '{rusage_planstats?user_plan_time_row1}'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{rusage_planstats?system_plan_time_row1}'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '{rusage_planstats?user_plan_time_row2}'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '{rusage_planstats?system_plan_time_row2}'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'rusage_planstats?cputime_colspan','3',
      '!rusage_planstats?cputime_colspan','2',
      'rusage_planstats?user_plan_time_hdr',
        '<th title="User CPU time elapsed during planning">Plan (s)</th>',
      'rusage_planstats?system_plan_time_hdr',
        '<th title="System CPU time elapsed during planning">Plan (s)</th>',
      'rusage_planstats?user_plan_time_row1',
        '<td {value}>%6$s</td>',
      'rusage_planstats?system_plan_time_row1',
        '<td {value}>%9$s</td>',
      'rusage_planstats?user_plan_time_row2',
        '<td {value}>%12$s</td>',
      'rusage_planstats?system_plan_time_row2',
        '<td {value}>%15$s</td>'
    );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,
            to_hex(r_result.queryid),
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            r_result.dbname,
            r_result.username,
            round(CAST(r_result.plan_user_time1 AS numeric),2),
            round(CAST(r_result.exec_user_time1 AS numeric),2),
            round(CAST(r_result.user_time_pct1 AS numeric),2),
            round(CAST(r_result.plan_system_time1 AS numeric),2),
            round(CAST(r_result.exec_system_time1 AS numeric),2),
            round(CAST(r_result.system_time_pct1 AS numeric),2),
            round(CAST(r_result.plan_user_time2 AS numeric),2),
            round(CAST(r_result.exec_user_time2 AS numeric),2),
            round(CAST(r_result.user_time_pct2 AS numeric),2),
            round(CAST(r_result.plan_system_time2 AS numeric),2),
            round(CAST(r_result.exec_system_time2 AS numeric),2),
            round(CAST(r_result.system_time_pct2 AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION top_io_filesystem_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT
        kc.datid as datid,
        kc.dbname as dbname,
        kc.userid as userid,
        kc.username as username,
        kc.queryid as queryid,
        kc.toplevel as toplevel,
        NULLIF(kc.plan_reads, 0) as plan_reads,
        NULLIF(kc.exec_reads, 0) as exec_reads,
        NULLIF(kc.reads_total_pct, 0.0) as reads_total_pct,
        NULLIF(kc.plan_writes, 0)  as plan_writes,
        NULLIF(kc.exec_writes, 0)  as exec_writes,
        NULLIF(kc.writes_total_pct, 0.0) as writes_total_pct
    FROM top_kcache_statements1 kc
    WHERE COALESCE(kc.plan_reads, 0) + COALESCE(kc.plan_writes, 0) +
      COALESCE(kc.exec_reads, 0) + COALESCE(kc.exec_writes, 0) > 0
    ORDER BY COALESCE(kc.plan_reads, 0) + COALESCE(kc.plan_writes, 0) +
      COALESCE(kc.exec_reads, 0) + COALESCE(kc.exec_writes, 0) DESC,
      kc.datid,
      kc.userid,
      kc.queryid,
      kc.toplevel
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th title="Filesystem reads" colspan="{rusage_planstats?fs_colspan}">Read Bytes</th>'
            '<th title="Filesystem writes" colspan="{rusage_planstats?fs_colspan}">Write Bytes</th>'
          '</tr>'
          '<tr>'
            '{rusage_planstats?plan_reads_hdr}'
            '<th title="Filesystem read amount during execution">Exec</th>'
            '<th title="Filesystem read amount of this statement as a percentage of all statements FS read amount">%Total</th>'
            '{rusage_planstats?plan_writes_hdr}'
            '<th title="Filesystem write amount during execution">Exec</th>'
            '<th title="Filesystem write amount of this statement as a percentage of all statements FS write amount">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '{rusage_planstats?plan_reads_row}'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{rusage_planstats?plan_writes_row}'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'rusage_planstats?fs_colspan','3',
      '!rusage_planstats?fs_colspan','2',
      'rusage_planstats?plan_reads_hdr',
        '<th title="Filesystem read amount during planning">Plan</th>',
      'rusage_planstats?plan_writes_hdr',
        '<th title="Filesystem write amount during planning">Plan</th>',
      'rusage_planstats?plan_reads_row',
        '<td {value}>%6$s</td>',
      'rusage_planstats?plan_writes_row',
        '<td {value}>%9$s</td>'
    );

    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,
            to_hex(r_result.queryid),
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            r_result.dbname,
            r_result.username,
            pg_size_pretty(r_result.plan_reads),
            pg_size_pretty(r_result.exec_reads),
            round(CAST(r_result.reads_total_pct AS numeric),2),
            pg_size_pretty(r_result.plan_writes),
            pg_size_pretty(r_result.exec_writes),
            round(CAST(r_result.writes_total_pct AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION top_io_filesystem_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(kc1.datid,kc2.datid) as datid,
        COALESCE(kc1.dbname,kc2.dbname) as dbname,
        COALESCE(kc1.userid,kc2.userid) as userid,
        COALESCE(kc1.username,kc2.username) as username,
        COALESCE(kc1.queryid,kc2.queryid) as queryid,
        COALESCE(kc1.toplevel,kc2.toplevel) as toplevel,
        NULLIF(kc1.plan_reads, 0) as plan_reads1,
        NULLIF(kc1.exec_reads, 0) as exec_reads1,
        NULLIF(kc1.reads_total_pct, 0.0) as reads_total_pct1,
        NULLIF(kc1.plan_writes, 0)  as plan_writes1,
        NULLIF(kc1.exec_writes, 0)  as exec_writes1,
        NULLIF(kc1.writes_total_pct, 0.0) as writes_total_pct1,
        NULLIF(kc2.plan_reads, 0) as plan_reads2,
        NULLIF(kc2.exec_reads, 0) as exec_reads2,
        NULLIF(kc2.reads_total_pct, 0.0) as reads_total_pct2,
        NULLIF(kc2.plan_writes, 0) as plan_writes2,
        NULLIF(kc2.exec_writes, 0) as exec_writes2,
        NULLIF(kc2.writes_total_pct, 0.0) as writes_total_pct2,
        row_number() OVER (ORDER BY COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc1.exec_writes, 0.0) DESC NULLS LAST) as io_count1,
        row_number() OVER (ORDER BY COALESCE(kc2.exec_reads, 0.0) + COALESCE(kc2.exec_writes, 0.0)  DESC NULLS LAST) as io_count2
    FROM top_kcache_statements1 kc1
        FULL OUTER JOIN top_kcache_statements2 kc2 USING (server_id, datid, userid, queryid)
    WHERE COALESCE(kc1.plan_writes, 0.0) + COALESCE(kc2.plan_writes, 0.0) +
        COALESCE(kc1.plan_reads, 0.0) + COALESCE(kc2.plan_reads, 0.0) +
        COALESCE(kc1.exec_writes, 0.0) + COALESCE(kc2.exec_writes, 0.0) +
        COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc2.exec_reads, 0.0) > 0
    ORDER BY COALESCE(kc1.plan_writes, 0.0) + COALESCE(kc2.plan_writes, 0.0) +
        COALESCE(kc1.plan_reads, 0.0) + COALESCE(kc2.plan_reads, 0.0) +
        COALESCE(kc1.exec_writes, 0.0) + COALESCE(kc2.exec_writes, 0.0) +
        COALESCE(kc1.exec_reads, 0.0) + COALESCE(kc2.exec_reads, 0.0) DESC,
        COALESCE(kc1.datid,kc2.datid),
        COALESCE(kc1.userid,kc2.userid),
        COALESCE(kc1.queryid,kc2.queryid),
        COALESCE(kc1.toplevel,kc2.toplevel)
        ) t1
    WHERE least(
        io_count1,
        io_count2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th title="Filesystem reads" colspan="{rusage_planstats?fs_colspan}">Read Bytes</th>'
            '<th title="Filesystem writes" colspan="{rusage_planstats?fs_colspan}">Write Bytes</th>'
          '</tr>'
          '<tr>'
            '{rusage_planstats?plan_reads_hdr}'
            '<th title="Filesystem read amount during execution">Exec</th>'
            '<th title="Filesystem read amount of this statement as a percentage of all statements FS read amount">%Total</th>'
            '{rusage_planstats?plan_writes_hdr}'
            '<th title="Filesystem write amount during execution">Exec</th>'
            '<th title="Filesystem write amount of this statement as a percentage of all statements FS write amount">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%5$s</td>'
          '<td {label} {title1}>1</td>'
          '{rusage_planstats?plan_reads_row1}'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{rusage_planstats?plan_writes_row1}'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '{rusage_planstats?plan_reads_row2}'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '{rusage_planstats?plan_writes_row2}'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'rusage_planstats?fs_colspan','3',
      '!rusage_planstats?fs_colspan','2',
      'rusage_planstats?plan_reads_hdr',
        '<th title="Filesystem read amount during planning">Plan</th>',
      'rusage_planstats?plan_writes_hdr',
        '<th title="Filesystem write amount during planning">Plan</th>',
      'rusage_planstats?plan_reads_row1',
        '<td {value}>%6$s</td>',
      'rusage_planstats?plan_writes_row1',
        '<td {value}>%9$s</td>',
      'rusage_planstats?plan_reads_row2',
        '<td {value}>%12$s</td>',
      'rusage_planstats?plan_writes_row2',
        '<td {value}>%15$s</td>'
    );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_elapsed_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,
            to_hex(r_result.queryid),
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),
            r_result.dbname,
            r_result.username,
            pg_size_pretty(r_result.plan_reads1),
            pg_size_pretty(r_result.exec_reads1),
            round(CAST(r_result.reads_total_pct1 AS numeric),2),
            pg_size_pretty(r_result.plan_writes1),
            pg_size_pretty(r_result.exec_writes1),
            round(CAST(r_result.writes_total_pct1 AS numeric),2),
            pg_size_pretty(r_result.plan_reads2),
            pg_size_pretty(r_result.exec_reads2),
            round(CAST(r_result.reads_total_pct2 AS numeric),2),
            pg_size_pretty(r_result.plan_writes2),
            pg_size_pretty(r_result.exec_writes2),
            round(CAST(r_result.writes_total_pct2 AS numeric),2)
        );

        report := report || tab_row;
        PERFORM collect_queries(
            r_result.userid,r_result.datid,r_result.queryid
        );
    END LOOP;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$$ LANGUAGE plpgsql;

