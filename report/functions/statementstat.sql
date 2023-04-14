/* ===== Statements stats functions ===== */

CREATE FUNCTION top_statements(IN sserver_id integer, IN start_id integer, IN end_id integer)
RETURNS TABLE(
    server_id               integer,
    datid                   oid,
    dbname                  name,
    userid                  oid,
    username                name,
    queryid                 bigint,
    toplevel                boolean,
    plans                   bigint,
    plans_pct               float,
    calls                   bigint,
    calls_pct               float,
    total_time              double precision,
    total_time_pct          double precision,
    total_plan_time         double precision,
    plan_time_pct           float,
    total_exec_time         double precision,
    total_exec_time_pct     float,
    exec_time_pct           float,
    min_exec_time           double precision,
    max_exec_time           double precision,
    mean_exec_time          double precision,
    stddev_exec_time        double precision,
    min_plan_time           double precision,
    max_plan_time           double precision,
    mean_plan_time          double precision,
    stddev_plan_time        double precision,
    rows                    bigint,
    shared_blks_hit         bigint,
    shared_hit_pct          float,
    shared_blks_read        bigint,
    read_pct                float,
    shared_blks_fetched     bigint,
    shared_blks_fetched_pct float,
    shared_blks_dirtied     bigint,
    dirtied_pct             float,
    shared_blks_written     bigint,
    tot_written_pct         float,
    backend_written_pct     float,
    local_blks_hit          bigint,
    local_hit_pct           float,
    local_blks_read         bigint,
    local_blks_fetched      bigint,
    local_blks_dirtied      bigint,
    local_blks_written      bigint,
    temp_blks_read          bigint,
    temp_blks_written       bigint,
    blk_read_time           double precision,
    blk_write_time          double precision,
    io_time                 double precision,
    io_time_pct             float,
    temp_read_total_pct     float,
    temp_write_total_pct    float,
    local_read_total_pct    float,
    local_write_total_pct   float,
    wal_records             bigint,
    wal_fpi                 bigint,
    wal_bytes               numeric,
    wal_bytes_pct           float,
    user_time               double precision,
    system_time             double precision,
    reads                   bigint,
    writes                  bigint,
    jit_functions           bigint,
    jit_generation_time     double precision,
    jit_inlining_count      bigint,
    jit_inlining_time       double precision,
    jit_optimization_count  bigint,
    jit_optimization_time   double precision,
    jit_emission_count      bigint,
    jit_emission_time       double precision
) SET search_path=@extschema@ AS $$
    WITH
      tot AS (
        SELECT
            COALESCE(sum(total_plan_time), 0.0) + sum(total_exec_time) AS total_time,
            sum(blk_read_time) AS blk_read_time,
            sum(blk_write_time) AS blk_write_time,
            sum(shared_blks_hit) AS shared_blks_hit,
            sum(shared_blks_read) AS shared_blks_read,
            sum(shared_blks_dirtied) AS shared_blks_dirtied,
            sum(temp_blks_read) AS temp_blks_read,
            sum(temp_blks_written) AS temp_blks_written,
            sum(local_blks_read) AS local_blks_read,
            sum(local_blks_written) AS local_blks_written,
            sum(calls) AS calls,
            sum(plans) AS plans
        FROM sample_statements_total st
        WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
      ),
      totbgwr AS (
        SELECT
          sum(buffers_checkpoint) + sum(buffers_clean) + sum(buffers_backend) AS written,
          sum(buffers_backend) AS buffers_backend,
          sum(wal_size) AS wal_size
        FROM sample_stat_cluster
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
      )
    SELECT
        st.server_id as server_id,
        st.datid as datid,
        sample_db.datname as dbname,
        st.userid as userid,
        rl.username as username,
        st.queryid as queryid,
        st.toplevel as toplevel,
        sum(st.plans)::bigint as plans,
        (sum(st.plans)*100/NULLIF(min(tot.plans), 0))::float as plans_pct,
        sum(st.calls)::bigint as calls,
        (sum(st.calls)*100/NULLIF(min(tot.calls), 0))::float as calls_pct,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))/1000 as total_time,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))*100/NULLIF(min(tot.total_time), 0) as total_time_pct,
        sum(st.total_plan_time)/1000::double precision as total_plan_time,
        sum(st.total_plan_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as plan_time_pct,
        sum(st.total_exec_time)/1000::double precision as total_exec_time,
        sum(st.total_exec_time)*100/NULLIF(min(tot.total_time), 0) as total_exec_time_pct,
        sum(st.total_exec_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as exec_time_pct,
        min(st.min_exec_time) as min_exec_time,
        max(st.max_exec_time) as max_exec_time,
        sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls), 0) as mean_exec_time,
        sqrt(sum((power(st.stddev_exec_time,2)+power(st.mean_exec_time,2))*st.calls)/NULLIF(sum(st.calls),0)-power(sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls),0),2)) as stddev_exec_time,
        min(st.min_plan_time) as min_plan_time,
        max(st.max_plan_time) as max_plan_time,
        sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0) as mean_plan_time,
        sqrt(sum((power(st.stddev_plan_time,2)+power(st.mean_plan_time,2))*st.plans)/NULLIF(sum(st.plans),0)-power(sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0),2)) as stddev_plan_time,
        sum(st.rows)::bigint as rows,
        sum(st.shared_blks_hit)::bigint as shared_blks_hit,
        (sum(st.shared_blks_hit) * 100 / NULLIF(sum(st.shared_blks_hit) + sum(st.shared_blks_read), 0))::float as shared_hit_pct,
        sum(st.shared_blks_read)::bigint as shared_blks_read,
        (sum(st.shared_blks_read) * 100 / NULLIF(min(tot.shared_blks_read), 0))::float as read_pct,
        (sum(st.shared_blks_hit) + sum(st.shared_blks_read))::bigint as shared_blks_fetched,
        ((sum(st.shared_blks_hit) + sum(st.shared_blks_read)) * 100 / NULLIF(min(tot.shared_blks_hit) + min(tot.shared_blks_read), 0))::float as shared_blks_fetched_pct,
        sum(st.shared_blks_dirtied)::bigint as shared_blks_dirtied,
        (sum(st.shared_blks_dirtied) * 100 / NULLIF(min(tot.shared_blks_dirtied), 0))::float as dirtied_pct,
        sum(st.shared_blks_written)::bigint as shared_blks_written,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.written), 0))::float as tot_written_pct,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.buffers_backend), 0))::float as backend_written_pct,
        sum(st.local_blks_hit)::bigint as local_blks_hit,
        (sum(st.local_blks_hit) * 100 / NULLIF(sum(st.local_blks_hit) + sum(st.local_blks_read),0))::float as local_hit_pct,
        sum(st.local_blks_read)::bigint as local_blks_read,
        (sum(st.local_blks_hit) + sum(st.local_blks_read))::bigint as local_blks_fetched,
        sum(st.local_blks_dirtied)::bigint as local_blks_dirtied,
        sum(st.local_blks_written)::bigint as local_blks_written,
        sum(st.temp_blks_read)::bigint as temp_blks_read,
        sum(st.temp_blks_written)::bigint as temp_blks_written,
        sum(st.blk_read_time)/1000::double precision as blk_read_time,
        sum(st.blk_write_time)/1000::double precision as blk_write_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time))/1000::double precision as io_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time)) * 100 / NULLIF(min(tot.blk_read_time) + min(tot.blk_write_time),0) as io_time_pct,
        (sum(st.temp_blks_read) * 100 / NULLIF(min(tot.temp_blks_read), 0))::float as temp_read_total_pct,
        (sum(st.temp_blks_written) * 100 / NULLIF(min(tot.temp_blks_written), 0))::float as temp_write_total_pct,
        (sum(st.local_blks_read) * 100 / NULLIF(min(tot.local_blks_read), 0))::float as local_read_total_pct,
        (sum(st.local_blks_written) * 100 / NULLIF(min(tot.local_blks_written), 0))::float as local_write_total_pct,
        sum(st.wal_records)::bigint as wal_records,
        sum(st.wal_fpi)::bigint as wal_fpi,
        sum(st.wal_bytes) as wal_bytes,
        (sum(st.wal_bytes) * 100 / NULLIF(min(totbgwr.wal_size), 0))::float wal_bytes_pct,
        -- kcache stats
        COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0) as user_time,
        COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0) as system_time,
        (COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))::bigint as reads,
        (COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))::bigint as writes,
        sum(st.jit_functions)::bigint AS jit_functions,
        sum(st.jit_generation_time)/1000::double precision AS jit_generation_time,
        sum(st.jit_inlining_count)::bigint AS jit_inlining_count,
        sum(st.jit_inlining_time)/1000::double precision AS jit_inlining_time,
        sum(st.jit_optimization_count)::bigint AS jit_optimization_count,
        sum(st.jit_optimization_time)/1000::double precision AS jit_optimization_time,
        sum(st.jit_emission_count)::bigint AS jit_emission_count,
        sum(st.jit_emission_time)/1000::double precision AS jit_emission_time
    FROM sample_statements st
        -- User name
        JOIN roles_list rl USING (server_id, userid)
        -- Database name
        JOIN sample_stat_database sample_db
        USING (server_id, sample_id, datid)
        -- kcache join
        LEFT OUTER JOIN sample_kcache kc USING(server_id, sample_id, userid, datid, queryid, toplevel)
        -- Total stats
        CROSS JOIN tot CROSS JOIN totbgwr
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY
      st.server_id,
      st.datid,
      sample_db.datname,
      st.userid,
      rl.username,
      st.queryid,
      st.toplevel
$$ LANGUAGE sql;

CREATE FUNCTION top_statements_aggr(IN sserver_id integer, IN start_id integer, IN end_id integer)
RETURNS TABLE(
    server_id               integer,
    datid                   oid,
    dbname                  name,
    userid                  oid,
    username                name,
    queryid                 bigint,
    toplevel                boolean,
    plans                   bigint,
    plans_pct               float,
    calls                   bigint,
    calls_pct               float,
    total_time              double precision,
    total_time_pct          double precision,
    total_plan_time         double precision,
    plan_time_pct           float,
    total_exec_time         double precision,
    total_exec_time_pct     float,
    exec_time_pct           float,
    min_exec_time           double precision,
    max_exec_time           double precision,
    mean_exec_time          double precision,
    stddev_exec_time        double precision,
    min_plan_time           double precision,
    max_plan_time           double precision,
    mean_plan_time          double precision,
    stddev_plan_time        double precision,
    rows                    bigint,
    shared_blks_hit         bigint,
    shared_hit_pct          float,
    shared_blks_read        bigint,
    read_pct                float,
    shared_blks_fetched     bigint,
    shared_blks_fetched_pct float,
    shared_blks_dirtied     bigint,
    dirtied_pct             float,
    shared_blks_written     bigint,
    tot_written_pct         float,
    backend_written_pct     float,
    local_blks_hit          bigint,
    local_hit_pct           float,
    local_blks_read         bigint,
    local_blks_fetched      bigint,
    local_blks_dirtied      bigint,
    local_blks_written      bigint,
    temp_blks_read          bigint,
    temp_blks_written       bigint,
    blk_read_time           double precision,
    blk_write_time          double precision,
    io_time                 double precision,
    io_time_pct             float,
    temp_read_total_pct     float,
    temp_write_total_pct    float,
    local_read_total_pct    float,
    local_write_total_pct   float,
    wal_records             bigint,
    wal_fpi                 bigint,
    wal_bytes               numeric,
    wal_bytes_pct           float,
    user_time               double precision,
    system_time             double precision,
    reads                   bigint,
    writes                  bigint,
    jit_functions           bigint,
    jit_generation_time     double precision,
    jit_inlining_count      bigint,
    jit_inlining_time       double precision,
    jit_optimization_count  bigint,
    jit_optimization_time   double precision,
    jit_emission_count      bigint,
    jit_emission_time       double precision
) SET search_path=@extschema@ AS $$
    WITH
      tot AS (
        SELECT
            COALESCE(sum(total_plan_time), 0.0) + sum(total_exec_time) AS total_time,
            sum(blk_read_time) AS blk_read_time,
            sum(blk_write_time) AS blk_write_time,
            sum(shared_blks_hit) AS shared_blks_hit,
            sum(shared_blks_read) AS shared_blks_read,
            sum(shared_blks_dirtied) AS shared_blks_dirtied,
            sum(temp_blks_read) AS temp_blks_read,
            sum(temp_blks_written) AS temp_blks_written,
            sum(local_blks_read) AS local_blks_read,
            sum(local_blks_written) AS local_blks_written,
            sum(calls) AS calls,
            sum(plans) AS plans
        FROM sample_statements_total st
        WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
      ),
      totbgwr AS (
        SELECT
          sum(buffers_checkpoint) + sum(buffers_clean) + sum(buffers_backend) AS written,
          sum(buffers_backend) AS buffers_backend,
          sum(wal_size) AS wal_size
        FROM sample_stat_cluster
        WHERE server_id = sserver_id AND sample_id BETWEEN start_id + 1 AND end_id
      )
    SELECT
        st.server_id as server_id,
        st.datid as datid,
        sample_db.datname as dbname,
        st.userid as userid,
        rl.username as username,
        ('x' || left(st.queryid_md5, 16))::bit(64)::bigint as queryid,
        st.toplevel as toplevel,
        sum(st.plans)::bigint as plans,
        (sum(st.plans)*100/NULLIF(min(tot.plans), 0))::float as plans_pct,
        sum(st.calls)::bigint as calls,
        (sum(st.calls)*100/NULLIF(min(tot.calls), 0))::float as calls_pct,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))/1000 as total_time,
        (sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0))*100/NULLIF(min(tot.total_time), 0) as total_time_pct,
        sum(st.total_plan_time)/1000::double precision as total_plan_time,
        sum(st.total_plan_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as plan_time_pct,
        sum(st.total_exec_time)/1000::double precision as total_exec_time,
        sum(st.total_exec_time)*100/NULLIF(min(tot.total_time), 0) as total_exec_time_pct,
        sum(st.total_exec_time)*100/NULLIF(sum(st.total_exec_time) + COALESCE(sum(st.total_plan_time), 0.0), 0) as exec_time_pct,
        min(st.min_exec_time) as min_exec_time,
        max(st.max_exec_time) as max_exec_time,
        sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls), 0) as mean_exec_time,
        sqrt(sum((power(st.stddev_exec_time,2)+power(st.mean_exec_time,2))*st.calls)/NULLIF(sum(st.calls),0)-power(sum(st.mean_exec_time*st.calls)/NULLIF(sum(st.calls),0),2)) as stddev_exec_time,
        min(st.min_plan_time) as min_plan_time,
        max(st.max_plan_time) as max_plan_time,
        sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0) as mean_plan_time,
        sqrt(sum((power(st.stddev_plan_time,2)+power(st.mean_plan_time,2))*st.plans)/NULLIF(sum(st.plans),0)-power(sum(st.mean_plan_time*st.plans)/NULLIF(sum(st.plans),0),2)) as stddev_plan_time,
        sum(st.rows)::bigint as rows,
        sum(st.shared_blks_hit)::bigint as shared_blks_hit,
        (sum(st.shared_blks_hit) * 100 / NULLIF(sum(st.shared_blks_hit) + sum(st.shared_blks_read), 0))::float as shared_hit_pct,
        sum(st.shared_blks_read)::bigint as shared_blks_read,
        (sum(st.shared_blks_read) * 100 / NULLIF(min(tot.shared_blks_read), 0))::float as read_pct,
        (sum(st.shared_blks_hit) + sum(st.shared_blks_read))::bigint as shared_blks_fetched,
        ((sum(st.shared_blks_hit) + sum(st.shared_blks_read)) * 100 / NULLIF(min(tot.shared_blks_hit) + min(tot.shared_blks_read), 0))::float as shared_blks_fetched_pct,
        sum(st.shared_blks_dirtied)::bigint as shared_blks_dirtied,
        (sum(st.shared_blks_dirtied) * 100 / NULLIF(min(tot.shared_blks_dirtied), 0))::float as dirtied_pct,
        sum(st.shared_blks_written)::bigint as shared_blks_written,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.written), 0))::float as tot_written_pct,
        (sum(st.shared_blks_written) * 100 / NULLIF(min(totbgwr.buffers_backend), 0))::float as backend_written_pct,
        sum(st.local_blks_hit)::bigint as local_blks_hit,
        (sum(st.local_blks_hit) * 100 / NULLIF(sum(st.local_blks_hit) + sum(st.local_blks_read),0))::float as local_hit_pct,
        sum(st.local_blks_read)::bigint as local_blks_read,
        (sum(st.local_blks_hit) + sum(st.local_blks_read))::bigint as local_blks_fetched,
        sum(st.local_blks_dirtied)::bigint as local_blks_dirtied,
        sum(st.local_blks_written)::bigint as local_blks_written,
        sum(st.temp_blks_read)::bigint as temp_blks_read,
        sum(st.temp_blks_written)::bigint as temp_blks_written,
        sum(st.blk_read_time)/1000::double precision as blk_read_time,
        sum(st.blk_write_time)/1000::double precision as blk_write_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time))/1000::double precision as io_time,
        (sum(st.blk_read_time) + sum(st.blk_write_time)) * 100 / NULLIF(min(tot.blk_read_time) + min(tot.blk_write_time),0) as io_time_pct,
        (sum(st.temp_blks_read) * 100 / NULLIF(min(tot.temp_blks_read), 0))::float as temp_read_total_pct,
        (sum(st.temp_blks_written) * 100 / NULLIF(min(tot.temp_blks_written), 0))::float as temp_write_total_pct,
        (sum(st.local_blks_read) * 100 / NULLIF(min(tot.local_blks_read), 0))::float as local_read_total_pct,
        (sum(st.local_blks_written) * 100 / NULLIF(min(tot.local_blks_written), 0))::float as local_write_total_pct,
        sum(st.wal_records)::bigint as wal_records,
        sum(st.wal_fpi)::bigint as wal_fpi,
        sum(st.wal_bytes) as wal_bytes,
        (sum(st.wal_bytes) * 100 / NULLIF(min(totbgwr.wal_size), 0))::float wal_bytes_pct,
        -- kcache stats
        COALESCE(sum(kc.exec_user_time), 0.0) + COALESCE(sum(kc.plan_user_time), 0.0) as user_time,
        COALESCE(sum(kc.exec_system_time), 0.0) + COALESCE(sum(kc.plan_system_time), 0.0) as system_time,
        (COALESCE(sum(kc.exec_reads), 0) + COALESCE(sum(kc.plan_reads), 0))::bigint as reads,
        (COALESCE(sum(kc.exec_writes), 0) + COALESCE(sum(kc.plan_writes), 0))::bigint as writes,
        sum(st.jit_functions)::bigint AS jit_functions,
        sum(st.jit_generation_time)/1000::double precision AS jit_generation_time,
        sum(st.jit_inlining_count)::bigint AS jit_inlining_count,
        sum(st.jit_inlining_time)/1000::double precision AS jit_inlining_time,
        sum(st.jit_optimization_count)::bigint AS jit_optimization_count,
        sum(st.jit_optimization_time)/1000::double precision AS jit_optimization_time,
        sum(st.jit_emission_count)::bigint AS jit_emission_count,
        sum(st.jit_emission_time)/1000::double precision AS jit_emission_time
    FROM sample_statements st
        -- User name
        JOIN roles_list rl USING (server_id, userid)
        -- Database name
        JOIN sample_stat_database sample_db
        USING (server_id, sample_id, datid)
        -- kcache join
        LEFT OUTER JOIN sample_kcache kc USING(server_id, sample_id, userid, datid, queryid, toplevel)
        -- Total stats
        CROSS JOIN tot CROSS JOIN totbgwr
    WHERE st.server_id = sserver_id AND st.sample_id BETWEEN start_id + 1 AND end_id
    GROUP BY
      st.server_id,
      st.datid,
      sample_db.datname,
      st.userid,
      rl.username,
      st.queryid_md5,
      st.toplevel
$$ LANGUAGE sql;

CREATE FUNCTION top_jit_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;
    r_result RECORD;

    --Cursor for top(cnt) queries ordered by JIT total time
    c_jit_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_plan_time, 0) as total_plan_time,
        NULLIF(st.total_exec_time, 0) as total_exec_time,
        NULLIF(st.io_time, 0) as io_time,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.jit_functions, 0) as jit_functions,
        NULLIF(st.jit_generation_time, 0) as jit_generation_time,
        NULLIF(st.jit_inlining_count, 0) as jit_inlining_count,
        NULLIF(st.jit_inlining_time, 0) as jit_inlining_time,
        NULLIF(st.jit_optimization_count, 0) as jit_optimization_count,
        NULLIF(st.jit_optimization_time, 0) as jit_optimization_time,
        NULLIF(st.jit_emission_count, 0) as jit_emission_count,
        NULLIF(st.jit_emission_time, 0) as jit_emission_time,
        st.jit_generation_time + st.jit_inlining_time + st.jit_optimization_time + st.jit_emission_time as jit_total_time,
        row_number() over(order by st.total_exec_time DESC NULLS LAST) as num_exec_time,
        row_number() over(order by st.total_time DESC NULLS LAST) as num_total_time
    FROM top_statements1 st
    ORDER BY (st.jit_generation_time + st.jit_inlining_time + st.jit_optimization_time + st.jit_emission_time) DESC NULLS LAST,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
      ) t1
    WHERE jit_functions + jit_inlining_count + jit_optimization_count + jit_emission_count > 0
      AND least(
          num_exec_time,
          num_total_time
          ) <= topn;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2" title="Total time spent on JIT in seconds">JIT total (s)</th>'
            '<th colspan="2">Generation</th>'
            '<th colspan="2">Inlining</th>'
            '<th colspan="2">Optimization</th>'
            '<th colspan="2">Emission</th>'
            '<th colspan="{planning_times?planning_colspan}">Time (s)</th>'
            '{io_times?iotime_hdr1}'
          '</tr>'
          '<tr>'
            '<th title="Total number of functions JIT-compiled by the statement.">Count</th>'
            '<th title="Total time spent by the statement on generating JIT code, in seconds.">Time (s)</th>'
            '<th title="Number of times functions have been inlined.">Count</th>'
            '<th title="Total time spent by the statement on inlining functions, in seconds.">Time (s)</th>'
            '<th title="Number of times the statement has been optimized.">Count</th>'
            '<th title="Total time spent by the statement on optimizing, in seconds.">Time (s)</th>'
            '<th title="Number of times code has been emitted.">Count</th>'
            '<th title="Total time spent by the statement on emitting code, in seconds.">Time (s)</th>'
            '{planning_times?planning_hdr}'
            '<th title="Time spent executing statement">Exec</th>'
            '{io_times?iotime_hdr2}'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td class="mono hdr" id="%20$s"><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '{planning_times?planning_row}'
          '<td {value}>%9$s</td>'
          '{io_times?iotime_row}'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'planning_times?planning_colspan','2',
      'planning_times?planning_hdr',
        '<th title="Time spent planning statement">Plan</th>',
      'planning_times?planning_row',
        '<td {value}>%8$s</td>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row',
        '<td {value}>%10$s</td>'
        '<td {value}>%11$s</td>'
      );

    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries
    FOR r_result IN c_jit_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,  -- 1
            to_hex(r_result.queryid), -- 2
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10), -- 3
            r_result.dbname, -- 4
            r_result.username, -- 5
            round(CAST(r_result.jit_total_time AS numeric), 2), -- 6
            round(CAST(r_result.total_plan_time + r_result.total_exec_time AS numeric),2), -- 7
            round(CAST(r_result.total_plan_time AS numeric),2),  -- 8
            round(CAST(r_result.total_exec_time AS numeric),2),  -- 9
            round(CAST(r_result.blk_read_time AS numeric),2), -- 10
            round(CAST(r_result.blk_write_time AS numeric),2), -- 11
            r_result.jit_functions, -- 12
            round(CAST(r_result.jit_generation_time AS numeric),2), -- 13
            r_result.jit_inlining_count, -- 14
            round(CAST(r_result.jit_inlining_time AS numeric),2), -- 15
            r_result.jit_optimization_count, -- 16
            round(CAST(r_result.jit_optimization_time AS numeric),2), -- 17
            r_result.jit_emission_count, -- 18
            round(CAST(r_result.jit_emission_time AS numeric),2), -- 19
            format(
                'jit_%s_%s_%s_%s',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text)  -- 20
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

CREATE FUNCTION top_jit_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by JIT total time
    c_jit_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,

        -- top_statements1
        NULLIF(st1.total_plan_time, 0.0) as total_plan_time1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.jit_generation_time + st1.jit_inlining_time +
          st1.jit_optimization_time + st1.jit_emission_time, 0) as total_jit_time1,
        NULLIF(st1.jit_functions, 0) as jit_functions1,
        NULLIF(st1.jit_generation_time, 0) as jit_generation_time1,
        NULLIF(st1.jit_inlining_count, 0) as jit_inlining_count1,
        NULLIF(st1.jit_inlining_time, 0) as jit_inlining_time1,
        NULLIF(st1.jit_optimization_count, 0) as jit_optimization_count1,
        NULLIF(st1.jit_optimization_time, 0) as jit_optimization_time1,
        NULLIF(st1.jit_emission_count, 0) as jit_emission_count1,
        NULLIF(st1.jit_emission_time, 0) as jit_emission_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,

        -- top_statements2
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.total_time_pct, 0.0) as total_time_pct2,
        NULLIF(st2.total_plan_time, 0.0) as total_plan_time2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.jit_generation_time + st2.jit_inlining_time +
          st2.jit_optimization_time + st2.jit_emission_time, 0) as total_jit_time2,
        NULLIF(st2.jit_functions, 0) as jit_functions2,
        NULLIF(st2.jit_generation_time, 0) as jit_generation_time2,
        NULLIF(st2.jit_inlining_count, 0) as jit_inlining_count2,
        NULLIF(st2.jit_inlining_time, 0) as jit_inlining_time2,
        NULLIF(st2.jit_optimization_count, 0) as jit_optimization_count2,
        NULLIF(st2.jit_optimization_time, 0) as jit_optimization_time2,
        NULLIF(st2.jit_emission_count, 0) as jit_emission_count2,
        NULLIF(st2.jit_emission_time, 0) as jit_emission_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,

        -- other
        row_number() over (ORDER BY st1.total_exec_time DESC NULLS LAST) as num_exec_time1,
        row_number() over (ORDER BY st2.total_exec_time DESC NULLS LAST) as num_exec_time2,
        row_number() over (ORDER BY st1.total_time DESC NULLS LAST) as num_total_time1,
        row_number() over (ORDER BY st2.total_time DESC NULLS LAST) as num_total_time2

    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    ORDER BY
        COALESCE(st1.jit_generation_time + st1.jit_inlining_time + st1.jit_optimization_time + st1.jit_emission_time, 0) +
        COALESCE(st2.jit_generation_time + st2.jit_inlining_time + st2.jit_optimization_time + st2.jit_emission_time, 0) DESC,
        COALESCE(st1.queryid,st2.queryid) ASC,
        COALESCE(st1.datid,st2.datid) ASC,
        COALESCE(st1.userid,st2.userid) ASC,
        COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE
        COALESCE(jit_functions1 + jit_inlining_count1 + jit_optimization_count1 + jit_emission_count1, 0) +
        COALESCE(jit_functions2 + jit_inlining_count2 + jit_optimization_count2 + jit_emission_count2, 0) > 0
      AND least(
          num_exec_time1,
          num_exec_time1,
          num_total_time1,
          num_total_time2
          ) <= topn;

BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Total time spent on JIT in seconds">JIT total (s)</th>'
            '<th colspan="2">Generation</th>'
            '<th colspan="2">Inlining</th>'
            '<th colspan="2">Optimization</th>'
            '<th colspan="2">Emission</th>'
           '<th colspan="{planning_times?planning_colspan}">Time (s)</th>'
            '{io_times?iotime_hdr1}'
          '</tr>'
          '<tr>'
            '<th title="Total number of functions JIT-compiled by the statement.">Count</th>'
            '<th title="Total time spent by the statement on generating JIT code, in seconds.">Time (s)</th>'
            '<th title="Number of times functions have been inlined.">Count</th>'
            '<th title="Total time spent by the statement on inlining functions, in seconds.">Time (s)</th>'
            '<th title="Number of times the statement has been optimized.">Count</th>'
            '<th title="Total time spent by the statement on optimizing, in seconds.">Time (s)</th>'
            '<th title="Number of times code has been emitted.">Count</th>'
            '<th title="Total time spent by the statement on emitting code, in seconds.">Time (s)</th>'
            '{planning_times?planning_hdr}'
            '<th title="Time spent executing statement">Exec</th>'
            '{io_times?iotime_hdr2}'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
          '<tr {interval1}>'
          '<td {rowtdspanhdr_mono} id="%34$s"><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%5$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '{planning_times?planning_row1}'
          '<td {value}>%17$s</td>'
          '{io_times?iotime_row1}'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%20$s</td>'
          '<td {value}>%21$s</td>'
          '<td {value}>%22$s</td>'
          '<td {value}>%23$s</td>'
          '<td {value}>%24$s</td>'
          '<td {value}>%25$s</td>'
          '<td {value}>%26$s</td>'
          '<td {value}>%27$s</td>'
          '<td {value}>%28$s</td>'
          '{planning_times?planning_row2}'
          '<td {value}>%31$s</td>'
          '{io_times?iotime_row2}'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        '<small title="Nested level">(N)</small>',
      'planning_times?planning_colspan', '2',
      'planning_times?planning_hdr',
        '<th title="Time spent planning statement">Plan</th>',
      'planning_times?planning_row1',
        '<td {value}>%16$s</td>',
      'planning_times?planning_row2',
        '<td {value}>%30$s</td>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row1',
        '<td {value}>%18$s</td>'
        '<td {value}>%19$s</td>',
      'io_times?iotime_row2',
        '<td {value}>%32$s</td>'
        '<td {value}>%33$s</td>'
    );

    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries
    FOR r_result IN c_jit_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END, -- 1
            to_hex(r_result.queryid), -- 2
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10), -- 3
            r_result.dbname, -- 4
            r_result.username, -- 5

            -- Sample 1
            -- JIT statistics
            round(CAST(r_result.total_jit_time1 AS numeric),2), -- 6
            r_result.jit_functions1, -- 7
            round(CAST(r_result.jit_generation_time1 AS numeric),2), -- 8
            r_result.jit_inlining_count1, -- 9
            round(CAST(r_result.jit_inlining_time1 AS numeric),2), -- 10
            r_result.jit_optimization_count1, -- 11
            round(CAST(r_result.jit_optimization_time1 AS numeric),2), -- 12
            r_result.jit_emission_count1, -- 13
            round(CAST(r_result.jit_emission_time1 AS numeric),2), -- 14

            -- Time
            round(CAST(r_result.total_plan_time1 + r_result.total_exec_time1 AS numeric),2), -- 15
            round(CAST(r_result.total_plan_time1 AS numeric),2),  -- 16
            round(CAST(r_result.total_exec_time1 AS numeric),2),  -- 17

            -- IO Time
            round(CAST(r_result.blk_read_time1 AS numeric),2), -- 18
            round(CAST(r_result.blk_write_time1 AS numeric),2), -- 19

            -- Sample 2
            -- JIT statistics
            round(CAST(r_result.total_jit_time2 AS numeric),2), -- 20
            r_result.jit_functions2, -- 21
            round(CAST(r_result.jit_generation_time2 AS numeric),2), -- 22
            r_result.jit_inlining_count2, -- 23
            round(CAST(r_result.jit_inlining_time2 AS numeric),2), -- 24
            r_result.jit_optimization_count2, -- 25
            round(CAST(r_result.jit_optimization_time2 AS numeric),2), -- 26
            r_result.jit_emission_count2, -- 27
            round(CAST(r_result.jit_emission_time2 AS numeric),2), -- 28

            -- Time
            round(CAST(r_result.total_plan_time2 + r_result.total_exec_time1 AS numeric),2), -- 29
            round(CAST(r_result.total_plan_time2 AS numeric),2),  -- 30
            round(CAST(r_result.total_exec_time2 AS numeric),2),  -- 31

            -- IO Time
            round(CAST(r_result.blk_read_time2 AS numeric),2), -- 32
            round(CAST(r_result.blk_write_time2 AS numeric),2), -- 33

            -- JIT ID
            format(
                'jit_%s_%s_%s_%s',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text)  -- 34
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

CREATE FUNCTION top_elapsed_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time_pct, 0) as total_time_pct,
        NULLIF(st.total_time, 0) as total_time,
        NULLIF(st.total_plan_time, 0) as total_plan_time,
        NULLIF(st.total_exec_time, 0) as total_exec_time,
        NULLIF(st.jit_generation_time + st.jit_inlining_time +
          st.jit_optimization_time + st.jit_emission_time, 0) as total_jit_time,
        st.jit_functions + st.jit_inlining_count + st.jit_optimization_count + st.jit_emission_count > 0 as jit_avail,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.user_time, 0.0) as user_time,
        NULLIF(st.system_time, 0.0) as system_time,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.plans, 0) as plans

    FROM top_statements1 st
    ORDER BY st.total_time DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(report_context, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2" title="Elapsed time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="3">Time (s)</th>'
            '{statements_jit_stats?jit_time_hdr}'
            '{io_times?iotime_hdr1}'
            '{kcachestatements?kcache_hdr1}'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by the statement">Elapsed</th>'
            '<th title="Time spent planning statement">Plan</th>'
            '<th title="Time spent executing statement">Exec</th>'
            '{io_times?iotime_hdr2}'
            '{kcachestatements?kcache_hdr2}'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '{statements_jit_stats?jit_time_row}'
          '{io_times?iotime_row}'
          '{kcachestatements?kcache_row}'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'statements_jit_stats?jit_time_hdr',
        '<th rowspan="2">JIT<br>time (s)</th>',
      'statements_jit_stats?jit_time_row',
        '<td {value}>%16$s</td>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row',
        '<td {value}>%10$s</td>'
        '<td {value}>%11$s</td>',
      'kcachestatements?kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcachestatements?kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcachestatements?kcache_row',
        '<td {value}>%12$s</td>'
        '<td {value}>%13$s</td>'
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
            round(CAST(r_result.total_time_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),2),
            round(CAST(r_result.total_plan_time AS numeric),2),
            round(CAST(r_result.total_exec_time AS numeric),2),
            round(CAST(r_result.blk_read_time AS numeric),2),
            round(CAST(r_result.blk_write_time AS numeric),2),
            round(CAST(r_result.user_time AS numeric),2),
            round(CAST(r_result.system_time AS numeric),2),
            r_result.plans,
            r_result.calls,
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time AS numeric),2)::text)
                ELSE ''
            END  -- 16
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

CREATE FUNCTION top_elapsed_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_elapsed_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.total_time_pct, 0.0) as total_time_pct1,
        NULLIF(st1.total_plan_time, 0.0) as total_plan_time1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.jit_generation_time + st1.jit_inlining_time +
          st1.jit_optimization_time + st1.jit_emission_time, 0) as total_jit_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.user_time, 0.0) as user_time1,
        NULLIF(st1.system_time, 0.0) as system_time1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.plans, 0) as plans1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.total_time_pct, 0.0) as total_time_pct2,
        NULLIF(st2.total_plan_time, 0.0) as total_plan_time2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.jit_generation_time + st2.jit_inlining_time +
          st2.jit_optimization_time + st2.jit_emission_time, 0) as total_jit_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.user_time, 0.0) as user_time2,
        NULLIF(st2.system_time, 0.0) as system_time2,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.plans, 0) as plans2,
        st1.jit_functions + st1.jit_inlining_count + st1.jit_optimization_count + st1.jit_emission_count > 0 OR
        st2.jit_functions + st2.jit_inlining_count + st2.jit_optimization_count + st2.jit_emission_count > 0 as jit_avail,
        row_number() over (ORDER BY st1.total_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_time DESC NULLS LAST) as rn_time2,
        left(md5(COALESCE(st1.userid,st2.userid)::text || COALESCE(st1.datid,st2.datid)::text || COALESCE(st1.queryid,st2.queryid)::text), 10) as hashed_ids
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    ORDER BY COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(report_context, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Elapsed time as a percentage of total cluster elapsed time">%Total</th>'
            '<th colspan="3">Time (s)</th>'
            '{statements_jit_stats?jit_time_hdr}'
            '{io_times?iotime_hdr1}'
            '{kcachestatements?kcache_hdr1}'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Time spent by the statement">Elapsed</th>'
            '<th title="Time spent planning statement">Plan</th>'
            '<th title="Time spent executing statement">Exec</th>'
            '{io_times?iotime_hdr2}'
            '{kcachestatements?kcache_hdr2}'
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
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '{statements_jit_stats?jit_time_row1}'
          '{io_times?iotime_row1}'
          '{kcachestatements?kcache_row1}'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '{statements_jit_stats?jit_time_row2}'
          '{io_times?iotime_row2}'
          '{kcachestatements?kcache_row2}'
          '<td {value}>%24$s</td>'
          '<td {value}>%25$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'statements_jit_stats?jit_time_hdr',
        '<th rowspan="2">JIT<br>time (s)</th>',
      'statements_jit_stats?jit_time_row1',
        '<td {value}>%26$s</td>',
      'statements_jit_stats?jit_time_row2',
        '<td {value}>%27$s</td>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row1',
        '<td {value}>%10$s</td>'
        '<td {value}>%11$s</td>',
      'io_times?iotime_row2',
        '<td {value}>%20$s</td>'
        '<td {value}>%21$s</td>',
      'kcachestatements?kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcachestatements?kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcachestatements?kcache_row1',
        '<td {value}>%12$s</td>'
        '<td {value}>%13$s</td>',
      'kcachestatements?kcache_row2',
        '<td {value}>%22$s</td>'
        '<td {value}>%23$s</td>'
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
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,  -- 1
            to_hex(r_result.queryid),  -- 2
            r_result.hashed_ids,  -- 3
            r_result.dbname,  -- 4
            r_result.username,  -- 5
            round(CAST(r_result.total_time_pct1 AS numeric),2),  -- 6
            round(CAST(r_result.total_time1 AS numeric),2),  -- 7
            round(CAST(r_result.total_plan_time1 AS numeric),2),  -- 8
            round(CAST(r_result.total_exec_time1 AS numeric),2),  -- 9
            round(CAST(r_result.blk_read_time1 AS numeric),2),  -- 10
            round(CAST(r_result.blk_write_time1 AS numeric),2),  -- 11
            round(CAST(r_result.user_time1 AS numeric),2),  -- 12
            round(CAST(r_result.system_time1 AS numeric),2),  -- 13
            r_result.plans1,  -- 14
            r_result.calls1,  -- 18
            round(CAST(r_result.total_time_pct2 AS numeric),2),  -- 16
            round(CAST(r_result.total_time2 AS numeric),2),  -- 17
            round(CAST(r_result.total_plan_time2 AS numeric),2),  -- 18
            round(CAST(r_result.total_exec_time2 AS numeric),2),  -- 19
            round(CAST(r_result.blk_read_time2 AS numeric),2),  -- 20
            round(CAST(r_result.blk_write_time2 AS numeric),2),  -- 21
            round(CAST(r_result.user_time2 AS numeric),2),  -- 22
            round(CAST(r_result.system_time2 AS numeric),2),  -- 23
            r_result.plans2,  -- 24
            r_result.calls2,  -- 25
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time1 AS numeric),2)::text)
                ELSE ''
            END,  -- 26
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time2 AS numeric),2)::text)
                ELSE ''
            END -- 27
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


CREATE FUNCTION top_plan_time_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by planning time
    c_plan_time CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.plans, 0) as plans,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.total_plan_time, 0.0) as total_plan_time,
        NULLIF(st.plan_time_pct, 0.0) as plan_time_pct,
        NULLIF(st.min_plan_time, 0.0) as min_plan_time,
        NULLIF(st.max_plan_time, 0.0) as max_plan_time,
        NULLIF(st.mean_plan_time, 0.0) as mean_plan_time,
        NULLIF(st.stddev_plan_time, 0.0) as stddev_plan_time
    FROM top_statements1 st
    ORDER BY st.total_plan_time DESC,
      st.total_exec_time DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when planning timing is available
    IF NOT jsonb_extract_path_text(report_context, 'report_features', 'planning_times')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2" title="Time spent planning statement">Plan elapsed (s)</th>'
            '<th rowspan="2" title="Plan elapsed as a percentage of statement elapsed time">%Elapsed</th>'
            '<th colspan="4" title="Planning time statistics">Plan times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_plan_time(
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
            round(CAST(r_result.total_plan_time AS numeric),2),
            round(CAST(r_result.plan_time_pct AS numeric),2),
            round(CAST(r_result.mean_plan_time AS numeric),3),
            round(CAST(r_result.min_plan_time AS numeric),3),
            round(CAST(r_result.max_plan_time AS numeric),3),
            round(CAST(r_result.stddev_plan_time AS numeric),3),
            r_result.plans,
            r_result.calls
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

CREATE FUNCTION top_plan_time_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_plan_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.plans, 0) as plans1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_plan_time, 0.0) as total_plan_time1,
        NULLIF(st1.plan_time_pct, 0.0) as plan_time_pct1,
        NULLIF(st1.min_plan_time, 0.0) as min_plan_time1,
        NULLIF(st1.max_plan_time, 0.0) as max_plan_time1,
        NULLIF(st1.mean_plan_time, 0.0) as mean_plan_time1,
        NULLIF(st1.stddev_plan_time, 0.0) as stddev_plan_time1,
        NULLIF(st2.plans, 0) as plans2,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_plan_time, 0.0) as total_plan_time2,
        NULLIF(st2.plan_time_pct, 0.0) as plan_time_pct2,
        NULLIF(st2.min_plan_time, 0.0) as min_plan_time2,
        NULLIF(st2.max_plan_time, 0.0) as max_plan_time2,
        NULLIF(st2.mean_plan_time, 0.0) as mean_plan_time2,
        NULLIF(st2.stddev_plan_time, 0.0) as stddev_plan_time2,
        row_number() over (ORDER BY st1.total_plan_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_plan_time DESC NULLS LAST) as rn_time2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    ORDER BY COALESCE(st1.total_plan_time,0) + COALESCE(st2.total_plan_time,0) DESC,
      COALESCE(st1.total_exec_time,0) + COALESCE(st2.total_exec_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent planning statement">Plan elapsed (s)</th>'
            '<th rowspan="2" title="Plan elapsed as a percentage of statement elapsed time">%Elapsed</th>'
            '<th colspan="4" title="Planning time statistics">Plan times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was planned">Plans</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
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
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '<td {value}>%9$s</td>'
          '<td {value}>%10$s</td>'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
          '<td {value}>%18$s</td>'
          '<td {value}>%19$s</td>'
          '<td {value}>%20$s</td>'
          '<td {value}>%21$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_plan_time(
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
            round(CAST(r_result.total_plan_time1 AS numeric),2),
            round(CAST(r_result.plan_time_pct1 AS numeric),2),
            round(CAST(r_result.mean_plan_time1 AS numeric),3),
            round(CAST(r_result.min_plan_time1 AS numeric),3),
            round(CAST(r_result.max_plan_time1 AS numeric),3),
            round(CAST(r_result.stddev_plan_time1 AS numeric),3),
            r_result.plans1,
            r_result.calls1,
            round(CAST(r_result.total_plan_time2 AS numeric),2),
            round(CAST(r_result.plan_time_pct2 AS numeric),2),
            round(CAST(r_result.mean_plan_time2 AS numeric),3),
            round(CAST(r_result.min_plan_time2 AS numeric),3),
            round(CAST(r_result.max_plan_time2 AS numeric),3),
            round(CAST(r_result.stddev_plan_time2 AS numeric),3),
            r_result.plans2,
            r_result.calls2
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

CREATE FUNCTION top_exec_time_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by execution time
    c_exec_time CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.total_exec_time, 0.0) as total_exec_time,
        NULLIF(st.total_exec_time_pct, 0.0) as total_exec_time_pct,
        NULLIF(st.exec_time_pct, 0.0) as exec_time_pct,
        NULLIF(st.jit_generation_time + st.jit_inlining_time +
          st.jit_optimization_time + st.jit_emission_time, 0) as total_jit_time,
        st.jit_functions + st.jit_inlining_count + st.jit_optimization_count + st.jit_emission_count > 0 as jit_avail,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.min_exec_time, 0.0) as min_exec_time,
        NULLIF(st.max_exec_time, 0.0) as max_exec_time,
        NULLIF(st.mean_exec_time, 0.0) as mean_exec_time,
        NULLIF(st.stddev_exec_time, 0.0) as stddev_exec_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.user_time, 0.0) as user_time,
        NULLIF(st.system_time, 0.0) as system_time
    FROM top_statements1 st
    ORDER BY st.total_exec_time DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
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
            '<th rowspan="2" title="Time spent executing statement">Exec (s)</th>'
            '{planning_times?elapsed_pct_hdr}'
            '<th rowspan="2" title="Exec time as a percentage of total cluster elapsed time">%Total</th>'
            '{statements_jit_stats?jit_time_hdr}'
            '{io_times?iotime_hdr1}'
            '{kcachestatements?kcache_hdr1}'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th colspan="4" title="Execution time statistics">Execution times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '{io_times?iotime_hdr2}'
            '{kcachestatements?kcache_hdr2}'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '<td {value}>%6$s</td>'
          '{planning_times?elapsed_pct_row}'
          '<td {value}>%7$s</td>'
          '{statements_jit_stats?jit_time_row}'
          '{io_times?iotime_row}'
          '{kcachestatements?kcache_row}'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row',
        '<td {value}>%8$s</td>'
        '<td {value}>%9$s</td>',
      'planning_times?elapsed_pct_hdr',
        '<th rowspan="2" title="Exec time as a percentage of statement elapsed time">%Elapsed</th>',
      'planning_times?elapsed_pct_row',
        '<td {value}>%18$s</td>',
      'statements_jit_stats?jit_time_hdr',
        '<th rowspan="2">JIT<br>time (s)</th>',
      'statements_jit_stats?jit_time_row',
        '<td {value}>%19$s</td>',
      'kcachestatements?kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcachestatements?kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcachestatements?kcache_row',
        '<td {value}>%10$s</td>'
        '<td {value}>%11$s</td>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_exec_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,  -- 1
            to_hex(r_result.queryid),  -- 2
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),  -- 3
            r_result.dbname,  -- 4
            r_result.username,  -- 5
            round(CAST(r_result.total_exec_time AS numeric),2),  -- 6
            round(CAST(r_result.total_exec_time_pct AS numeric),2),  -- 7
            round(CAST(r_result.blk_read_time AS numeric),2),  -- 8
            round(CAST(r_result.blk_write_time AS numeric),2),  -- 9
            round(CAST(r_result.user_time AS numeric),2),  -- 10
            round(CAST(r_result.system_time AS numeric),2),  -- 11
            r_result.rows,  -- 12
            round(CAST(r_result.mean_exec_time AS numeric),3),  -- 13
            round(CAST(r_result.min_exec_time AS numeric),3),  -- 14
            round(CAST(r_result.max_exec_time AS numeric),3),  -- 15
            round(CAST(r_result.stddev_exec_time AS numeric),3),  -- 16
            r_result.calls,  -- 17
            round(CAST(r_result.exec_time_pct AS numeric),2),  -- 18
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time AS numeric),2)::text)
                ELSE ''
            END  -- 19
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

CREATE FUNCTION top_exec_time_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by elapsed time
    c_exec_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.total_exec_time_pct, 0.0) as total_exec_time_pct1,
        NULLIF(st1.exec_time_pct, 0.0) as exec_time_pct1,
        NULLIF(st1.jit_generation_time + st1.jit_inlining_time +
          st1.jit_optimization_time + st1.jit_emission_time, 0) as total_jit_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.min_exec_time, 0.0) as min_exec_time1,
        NULLIF(st1.max_exec_time, 0.0) as max_exec_time1,
        NULLIF(st1.mean_exec_time, 0.0) as mean_exec_time1,
        NULLIF(st1.stddev_exec_time, 0.0) as stddev_exec_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.user_time, 0.0) as user_time1,
        NULLIF(st1.system_time, 0.0) as system_time1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.total_exec_time_pct, 0.0) as total_exec_time_pct2,
        NULLIF(st2.exec_time_pct, 0.0) as exec_time_pct2,
        NULLIF(st2.jit_generation_time + st2.jit_inlining_time +
          st2.jit_optimization_time + st2.jit_emission_time, 0) as total_jit_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.min_exec_time, 0.0) as min_exec_time2,
        NULLIF(st2.max_exec_time, 0.0) as max_exec_time2,
        NULLIF(st2.mean_exec_time, 0.0) as mean_exec_time2,
        NULLIF(st2.stddev_exec_time, 0.0) as stddev_exec_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.user_time, 0.0) as user_time2,
        NULLIF(st2.system_time, 0.0) as system_time2,
        st1.jit_functions + st1.jit_inlining_count + st1.jit_optimization_count + st1.jit_emission_count > 0 OR
        st2.jit_functions + st2.jit_inlining_count + st2.jit_optimization_count + st2.jit_emission_count > 0 as jit_avail,
        row_number() over (ORDER BY st1.total_exec_time DESC NULLS LAST) as rn_time1,
        row_number() over (ORDER BY st2.total_exec_time DESC NULLS LAST) as rn_time2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    ORDER BY COALESCE(st1.total_exec_time,0) + COALESCE(st2.total_exec_time,0) DESC,
      COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_time1,
        rn_time2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Elapsed time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent executing statement">Exec (s)</th>'
            '{planning_times?elapsed_pct_hdr}'
            '<th rowspan="2" title="Exec time as a percentage of total cluster elapsed time">%Total</th>'
            '{statements_jit_stats?jit_time_hdr}'
            '{io_times?iotime_hdr1}'
            '{kcachestatements?kcache_hdr1}'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th colspan="4" title="Execution time statistics">Execution times (ms)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '{io_times?iotime_hdr2}'
            '{kcachestatements?kcache_hdr2}'
            '<th>Mean</th>'
            '<th>Min</th>'
            '<th>Max</th>'
            '<th>StdErr</th>'
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
          '<td {value}>%6$s</td>'
          '{planning_times?elapsed_pct_row1}'
          '<td {value}>%7$s</td>'
          '{statements_jit_stats?jit_time_row1}'
          '{io_times?iotime_row1}'
          '{kcachestatements?kcache_row1}'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '<td {value}>%17$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%18$s</td>'
          '{planning_times?elapsed_pct_row2}'
          '<td {value}>%19$s</td>'
          '{statements_jit_stats?jit_time_row2}'
          '{io_times?iotime_row2}'
          '{kcachestatements?kcache_row2}'
          '<td {value}>%24$s</td>'
          '<td {value}>%25$s</td>'
          '<td {value}>%26$s</td>'
          '<td {value}>%27$s</td>'
          '<td {value}>%28$s</td>'
          '<td {value}>%29$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'io_times?iotime_hdr1',
        '<th colspan="2">I/O time (s)</th>',
      'io_times?iotime_hdr2',
        '<th title="Time spent reading blocks by statement">Read</th>'
        '<th title="Time spent writing blocks by statement">Write</th>',
      'io_times?iotime_row1',
        '<td {value}>%8$s</td>'
        '<td {value}>%9$s</td>',
      'io_times?iotime_row2',
        '<td {value}>%20$s</td>'
        '<td {value}>%21$s</td>',
      'planning_times?elapsed_pct_hdr',
        '<th rowspan="2" title="Exec time as a percentage of statement elapsed time">%Elapsed</th>',
      'planning_times?elapsed_pct_row1',
        '<td {value}>%30$s</td>',
      'planning_times?elapsed_pct_row2',
        '<td {value}>%31$s</td>',
      'statements_jit_stats?jit_time_hdr',
        '<th rowspan="2">JIT<br>time (s)</th>',
      'statements_jit_stats?jit_time_row1',
        '<td {value}>%32$s</td>',
      'statements_jit_stats?jit_time_row2',
        '<td {value}>%33$s</td>',
      'kcachestatements?kcache_hdr1',
        '<th colspan="2">CPU time (s)</th>',
      'kcachestatements?kcache_hdr2',
        '<th>Usr</th>'
        '<th>Sys</th>',
      'kcachestatements?kcache_row1',
        '<td {value}>%10$s</td>'
        '<td {value}>%11$s</td>',
      'kcachestatements?kcache_row2',
        '<td {value}>%22$s</td>'
        '<td {value}>%23$s</td>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by elapsed time
    FOR r_result IN c_exec_time(
        (report_context #>> '{report_properties,topn}')::integer
      )
    LOOP
        tab_row := format(
            jtab_tpl #>> ARRAY['stmt_tpl'],
            CASE WHEN NOT r_result.toplevel THEN jtab_tpl #>> ARRAY['nested_tpl'] ELSE '' END,  -- 1
            to_hex(r_result.queryid),  -- 2
            left(md5(r_result.userid::text || r_result.datid::text || r_result.queryid::text), 10),  -- 3
            r_result.dbname,  -- 4
            r_result.username,  -- 5
            round(CAST(r_result.total_exec_time1 AS numeric),2),  -- 6
            round(CAST(r_result.total_exec_time_pct1 AS numeric),2),  -- 7
            round(CAST(r_result.blk_read_time1 AS numeric),2),  -- 8
            round(CAST(r_result.blk_write_time1 AS numeric),2),  -- 9
            round(CAST(r_result.user_time1 AS numeric),2),  -- 10
            round(CAST(r_result.system_time1 AS numeric),2),  -- 11
            r_result.rows1,  -- 12
            round(CAST(r_result.mean_exec_time1 AS numeric),3),  -- 13
            round(CAST(r_result.min_exec_time1 AS numeric),3),  -- 14
            round(CAST(r_result.max_exec_time1 AS numeric),3),  -- 15
            round(CAST(r_result.stddev_exec_time1 AS numeric),3),  -- 16
            r_result.calls1,  -- 17
            round(CAST(r_result.total_exec_time2 AS numeric),2),  -- 18
            round(CAST(r_result.total_exec_time_pct2 AS numeric),2),  -- 19
            round(CAST(r_result.blk_read_time2 AS numeric),2),  -- 20
            round(CAST(r_result.blk_write_time2 AS numeric),2),  -- 21
            round(CAST(r_result.user_time2 AS numeric),2),  -- 22
            round(CAST(r_result.system_time2 AS numeric),2),  -- 23
            r_result.rows2,  -- 24
            round(CAST(r_result.mean_exec_time2 AS numeric),3),  -- 25
            round(CAST(r_result.min_exec_time2 AS numeric),3),  -- 26
            round(CAST(r_result.max_exec_time2 AS numeric),3),  -- 27
            round(CAST(r_result.stddev_exec_time2 AS numeric),3),  -- 28
            r_result.calls2,  -- 29
            round(CAST(r_result.exec_time_pct1 AS numeric),2),  -- 30
            round(CAST(r_result.exec_time_pct2 AS numeric),2),  -- 31
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time1 AS numeric),2)::text)
                ELSE ''
            END,  -- 34
            CASE WHEN r_result.jit_avail
                THEN format(
                '<a HREF="#jit_%s_%s_%s_%s">%s</a>',
                to_hex(r_result.queryid),
                r_result.datid::text,
                r_result.userid::text,
                r_result.toplevel::text,
                round(CAST(r_result.total_jit_time2 AS numeric),2)::text)
                ELSE ''
            END  -- 35
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

CREATE FUNCTION top_exec_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    -- Cursor for topn querues ordered by executions
    c_calls CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.calls, 0) as calls,
        NULLIF(st.calls_pct, 0.0) as calls_pct,
        NULLIF(st.total_exec_time, 0.0) as total_exec_time,
        NULLIF(st.min_exec_time, 0.0) as min_exec_time,
        NULLIF(st.max_exec_time, 0.0) as max_exec_time,
        NULLIF(st.mean_exec_time, 0.0) as mean_exec_time,
        NULLIF(st.stddev_exec_time, 0.0) as stddev_exec_time,
        NULLIF(st.rows, 0) as rows
    FROM top_statements1 st
    ORDER BY st.calls DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
            '<th title="Executions of this statement as a percentage of total executions of all statements in a cluster">%Total</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th>Mean(ms)</th>'
            '<th>Min(ms)</th>'
            '<th>Max(ms)</th>'
            '<th>StdErr(ms)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top 10 queries by executions
    FOR r_result IN c_calls(
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
            r_result.calls,
            round(CAST(r_result.calls_pct AS numeric),2),
            r_result.rows,
            round(CAST(r_result.mean_exec_time AS numeric),3),
            round(CAST(r_result.min_exec_time AS numeric),3),
            round(CAST(r_result.max_exec_time AS numeric),3),
            round(CAST(r_result.stddev_exec_time AS numeric),3),
            round(CAST(r_result.total_exec_time AS numeric),1)
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

CREATE FUNCTION top_exec_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    -- Cursor for topn querues ordered by executions
    c_calls CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.calls_pct, 0.0) as calls_pct1,
        NULLIF(st1.total_exec_time, 0.0) as total_exec_time1,
        NULLIF(st1.min_exec_time, 0.0) as min_exec_time1,
        NULLIF(st1.max_exec_time, 0.0) as max_exec_time1,
        NULLIF(st1.mean_exec_time, 0.0) as mean_exec_time1,
        NULLIF(st1.stddev_exec_time, 0.0) as stddev_exec_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.calls_pct, 0.0) as calls_pct2,
        NULLIF(st2.total_exec_time, 0.0) as total_exec_time2,
        NULLIF(st2.min_exec_time, 0.0) as min_exec_time2,
        NULLIF(st2.max_exec_time, 0.0) as max_exec_time2,
        NULLIF(st2.mean_exec_time, 0.0) as mean_exec_time2,
        NULLIF(st2.stddev_exec_time, 0.0) as stddev_exec_time2,
        NULLIF(st2.rows, 0) as rows2,
        row_number() over (ORDER BY st1.calls DESC NULLS LAST) as rn_calls1,
        row_number() over (ORDER BY st2.calls DESC NULLS LAST) as rn_calls2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    ORDER BY COALESCE(st1.calls,0) + COALESCE(st2.calls,0) DESC,
      COALESCE(st1.total_time,0) + COALESCE(st2.total_time,0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_calls1,
        rn_calls2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Executions sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
            '<th title="Executions of this statement as a percentage of total executions of all statements in a cluster">%Total</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th>Mean(ms)</th>'
            '<th>Min(ms)</th>'
            '<th>Max(ms)</th>'
            '<th>StdErr(ms)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top 10 queries by executions
    FOR r_result IN c_calls(
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
            r_result.calls1,
            round(CAST(r_result.calls_pct1 AS numeric),2),
            r_result.rows1,
            round(CAST(r_result.mean_exec_time1 AS numeric),3),
            round(CAST(r_result.min_exec_time1 AS numeric),3),
            round(CAST(r_result.max_exec_time1 AS numeric),3),
            round(CAST(r_result.stddev_exec_time1 AS numeric),3),
            round(CAST(r_result.total_exec_time1 AS numeric),1),
            r_result.calls2,
            round(CAST(r_result.calls_pct2 AS numeric),2),
            r_result.rows2,
            round(CAST(r_result.mean_exec_time2 AS numeric),3),
            round(CAST(r_result.min_exec_time2 AS numeric),3),
            round(CAST(r_result.max_exec_time2 AS numeric),3),
            round(CAST(r_result.stddev_exec_time2 AS numeric),3),
            round(CAST(r_result.total_exec_time2 AS numeric),1)
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

CREATE FUNCTION top_iowait_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by I/O Wait time
    c_iowait_time CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.io_time, 0.0) as io_time,
        NULLIF(st.blk_read_time, 0.0) as blk_read_time,
        NULLIF(st.blk_write_time, 0.0) as blk_write_time,
        NULLIF(st.io_time_pct, 0.0) as io_time_pct,
        NULLIF(st.shared_blks_read, 0) as shared_blks_read,
        NULLIF(st.local_blks_read, 0) as local_blks_read,
        NULLIF(st.temp_blks_read, 0) as temp_blks_read,
        NULLIF(st.shared_blks_written, 0) as shared_blks_written,
        NULLIF(st.local_blks_written, 0) as local_blks_written,
        NULLIF(st.temp_blks_written, 0) as temp_blks_written,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE st.io_time > 0
    ORDER BY st.io_time DESC,
      st.total_time DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
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
            '<th rowspan="2" title="Time spent by the statement reading and writing blocks">IO(s)</th>'
            '<th rowspan="2" title="Time spent by the statement reading blocks">R(s)</th>'
            '<th rowspan="2" title="Time spent by the statement writing blocks">W(s)</th>'
            '<th rowspan="2" title="I/O time of this statement as a percentage of total I/O time for all statements in a cluster">%Total</th>'
            '<th colspan="3" title="Number of blocks read by the statement">Reads</th>'
            '<th colspan="3" title="Number of blocks written by the statement">Writes</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of shared blocks read by the statement">Shr</th>'
            '<th title="Number of local blocks read by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks read by the statement (usually used for operations like sorts and joins)">Tmp</th>'
            '<th title="Number of shared blocks written by the statement">Shr</th>'
            '<th title="Number of local blocks written by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks written by the statement (usually used for operations like sorts and joins)">Tmp</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top 10 queries by I/O wait time
    FOR r_result IN c_iowait_time(
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
            round(CAST(r_result.io_time AS numeric),3),
            round(CAST(r_result.blk_read_time AS numeric),3),
            round(CAST(r_result.blk_write_time AS numeric),3),
            round(CAST(r_result.io_time_pct AS numeric),2),
            round(CAST(r_result.shared_blks_read AS numeric)),
            round(CAST(r_result.local_blks_read AS numeric)),
            round(CAST(r_result.temp_blks_read AS numeric)),
            round(CAST(r_result.shared_blks_written AS numeric)),
            round(CAST(r_result.local_blks_written AS numeric)),
            round(CAST(r_result.temp_blks_written AS numeric)),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.calls
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

CREATE FUNCTION top_iowait_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by I/O Wait time
    c_iowait_time CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.io_time, 0.0) as io_time1,
        NULLIF(st1.blk_read_time, 0.0) as blk_read_time1,
        NULLIF(st1.blk_write_time, 0.0) as blk_write_time1,
        NULLIF(st1.io_time_pct, 0.0) as io_time_pct1,
        NULLIF(st1.shared_blks_read, 0) as shared_blks_read1,
        NULLIF(st1.local_blks_read, 0) as local_blks_read1,
        NULLIF(st1.temp_blks_read, 0) as temp_blks_read1,
        NULLIF(st1.shared_blks_written, 0) as shared_blks_written1,
        NULLIF(st1.local_blks_written, 0) as local_blks_written1,
        NULLIF(st1.temp_blks_written, 0) as temp_blks_written1,
        NULLIF(st2.calls, 0) as calls2,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.io_time, 0.0) as io_time2,
        NULLIF(st2.blk_read_time, 0.0) as blk_read_time2,
        NULLIF(st2.blk_write_time, 0.0) as blk_write_time2,
        NULLIF(st2.io_time_pct, 0.0) as io_time_pct2,
        NULLIF(st2.shared_blks_read, 0) as shared_blks_read2,
        NULLIF(st2.local_blks_read, 0) as local_blks_read2,
        NULLIF(st2.temp_blks_read, 0) as temp_blks_read2,
        NULLIF(st2.shared_blks_written, 0) as shared_blks_written2,
        NULLIF(st2.local_blks_written, 0) as local_blks_written2,
        NULLIF(st2.temp_blks_written, 0) as temp_blks_written2,
        row_number() over (ORDER BY st1.io_time DESC NULLS LAST) as rn_iotime1,
        row_number() over (ORDER BY st2.io_time DESC NULLS LAST) as rn_iotime2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.io_time, 0.0) + COALESCE(st2.io_time, 0.0) > 0
    ORDER BY COALESCE(st1.io_time, 0.0) + COALESCE(st2.io_time, 0.0) DESC,
      COALESCE(st1.total_time, 0.0) + COALESCE(st2.total_time, 0.0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_iotime1,
        rn_iotime2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- IOWait time sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Time spent by the statement reading and writing blocks">IO(s)</th>'
            '<th rowspan="2" title="Time spent by the statement reading blocks">R(s)</th>'
            '<th rowspan="2" title="Time spent by the statement writing blocks">W(s)</th>'
            '<th rowspan="2" title="I/O time of this statement as a percentage of total I/O time for all statements in a cluster">%Total</th>'
            '<th colspan="3" title="Number of blocks read by the statement">Reads</th>'
            '<th colspan="3" title="Number of blocks written by the statement">Writes</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of shared blocks read by the statement">Shr</th>'
            '<th title="Number of local blocks read by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks read by the statement (usually used for operations like sorts and joins)">Tmp</th>'
            '<th title="Number of shared blocks written by the statement">Shr</th>'
            '<th title="Number of local blocks written by the statement (usually used for temporary tables)">Loc</th>'
            '<th title="Number of temp blocks written by the statement (usually used for operations like sorts and joins)">Tmp</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top 10 queries by I/O wait time
    FOR r_result IN c_iowait_time(
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
            round(CAST(r_result.io_time1 AS numeric),3),
            round(CAST(r_result.blk_read_time1 AS numeric),3),
            round(CAST(r_result.blk_write_time1 AS numeric),3),
            round(CAST(r_result.io_time_pct1 AS numeric),2),
            round(CAST(r_result.shared_blks_read1 AS numeric)),
            round(CAST(r_result.local_blks_read1 AS numeric)),
            round(CAST(r_result.temp_blks_read1 AS numeric)),
            round(CAST(r_result.shared_blks_written1 AS numeric)),
            round(CAST(r_result.local_blks_written1 AS numeric)),
            round(CAST(r_result.temp_blks_written1 AS numeric)),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.calls1,
            round(CAST(r_result.io_time2 AS numeric),3),
            round(CAST(r_result.blk_read_time2 AS numeric),3),
            round(CAST(r_result.blk_write_time2 AS numeric),3),
            round(CAST(r_result.io_time_pct2 AS numeric),2),
            round(CAST(r_result.shared_blks_read2 AS numeric)),
            round(CAST(r_result.local_blks_read2 AS numeric)),
            round(CAST(r_result.temp_blks_read2 AS numeric)),
            round(CAST(r_result.shared_blks_written2 AS numeric)),
            round(CAST(r_result.local_blks_written2 AS numeric)),
            round(CAST(r_result.temp_blks_written2 AS numeric)),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.calls2
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

CREATE FUNCTION top_shared_blks_fetched_htbl(IN report_context jsonb, IN sserver_id integer)
  RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared_blks_fetched
    c_shared_blks_fetched CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_fetched, 0) as shared_blks_fetched,
        NULLIF(st.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE shared_blks_fetched > 0
    ORDER BY st.shared_blks_fetched DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Shared blocks fetched (read and hit) by the statement">blks fetched</th>'
            '<th title="Shared blocks fetched by this statement as a percentage of all shared blocks fetched in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_shared_blks_fetched(
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
            r_result.shared_blks_fetched,
            round(CAST(r_result.shared_blks_fetched_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
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

CREATE FUNCTION top_shared_blks_fetched_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared_blks_fetched
    c_shared_blks_fetched CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_fetched, 0) as shared_blks_fetched1,
        NULLIF(st1.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_fetched, 0) as shared_blks_fetched2,
        NULLIF(st2.shared_blks_fetched_pct, 0.0) as shared_blks_fetched_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_fetched DESC NULLS LAST) as rn_shared_blks_fetched1,
        row_number() over (ORDER BY st2.shared_blks_fetched DESC NULLS LAST) as rn_shared_blks_fetched2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.shared_blks_fetched, 0) + COALESCE(st2.shared_blks_fetched, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_fetched, 0) + COALESCE(st2.shared_blks_fetched, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_shared_blks_fetched1,
        rn_shared_blks_fetched2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Fetched (blk) sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Shared blocks fetched (read and hit) by the statement">blks fetched</th>'
            '<th title="Shared blocks fetched by this statement as a percentage of all shared blocks fetched in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_shared_blks_fetched(
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
            r_result.shared_blks_fetched1,
            round(CAST(r_result.shared_blks_fetched_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_fetched2,
            round(CAST(r_result.shared_blks_fetched_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
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

CREATE FUNCTION top_shared_reads_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by reads
    c_sh_reads CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_read, 0) as shared_blks_read,
        NULLIF(st.read_pct, 0.0) as read_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE st.shared_blks_read > 0
    ORDER BY st.shared_blks_read DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Total number of shared blocks read by the statement">Reads</th>'
            '<th title="Shared blocks read by this statement as a percentage of all shared blocks read in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by reads
    FOR r_result IN c_sh_reads(
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
            r_result.shared_blks_read,
            round(CAST(r_result.read_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
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

CREATE FUNCTION top_shared_reads_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by reads
    c_sh_reads CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_read, 0.0) as shared_blks_read1,
        NULLIF(st1.read_pct, 0.0) as read_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_read, 0) as shared_blks_read2,
        NULLIF(st2.read_pct, 0.0) as read_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_read DESC NULLS LAST) as rn_reads1,
        row_number() over (ORDER BY st2.shared_blks_read DESC NULLS LAST) as rn_reads2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.shared_blks_read, 0) + COALESCE(st2.shared_blks_read, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_read, 0) + COALESCE(st2.shared_blks_read, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_reads1,
        rn_reads2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Reads sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks read by the statement">Reads</th>'
            '<th title="Shared blocks read by this statement as a percentage of all shared blocks read in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by reads
    FOR r_result IN c_sh_reads(
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
            r_result.shared_blks_read1,
            round(CAST(r_result.read_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_read2,
            round(CAST(r_result.read_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
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

CREATE FUNCTION top_shared_dirtied_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared dirtied
    c_sh_dirt CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_dirtied, 0) as shared_blks_dirtied,
        NULLIF(st.dirtied_pct, 0.0) as dirtied_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.wal_bytes, 0) as wal_bytes,
        NULLIF(st.wal_bytes_pct, 0.0) as wal_bytes_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE st.shared_blks_dirtied > 0
    ORDER BY st.shared_blks_dirtied DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Shared blocks dirtied by this statement as a percentage of all shared blocks dirtied in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '{statement_wal_bytes?wal_header}'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'statement_wal_bytes?wal_header',
        '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
        '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%5$s</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{statement_wal_bytes?wal_row}'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'statement_wal_bytes?wal_row',
        '<td {value}>%9$s</td>'
        '<td {value}>%10$s</td>'
    );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by shared dirtied
    FOR r_result IN c_sh_dirt(
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
            r_result.shared_blks_dirtied,
            round(CAST(r_result.dirtied_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            pg_size_pretty(r_result.wal_bytes),
            round(CAST(r_result.wal_bytes_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
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

CREATE FUNCTION top_shared_dirtied_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared dirtied
    c_sh_dirt CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_dirtied, 0) as shared_blks_dirtied1,
        NULLIF(st1.dirtied_pct, 0.0) as dirtied_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.wal_bytes, 0) as wal_bytes1,
        NULLIF(st1.wal_bytes_pct, 0.0) as wal_bytes_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_dirtied, 0) as shared_blks_dirtied2,
        NULLIF(st2.dirtied_pct, 0.0) as dirtied_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.wal_bytes, 0) as wal_bytes2,
        NULLIF(st2.wal_bytes_pct, 0.0) as wal_bytes_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_dirtied DESC NULLS LAST) as rn_dirtied1,
        row_number() over (ORDER BY st2.shared_blks_dirtied DESC NULLS LAST) as rn_dirtied2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.shared_blks_dirtied, 0) + COALESCE(st2.shared_blks_dirtied, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_dirtied, 0) + COALESCE(st2.shared_blks_dirtied, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_dirtied1,
        rn_dirtied2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Dirtied sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Shared blocks dirtied by this statement as a percentage of all shared blocks dirtied in a cluster">%Total</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '{statement_wal_bytes?wal_hdr}'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'statement_wal_bytes?wal_hdr',
        '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
        '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%5$s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%6$s</td>'
          '<td {value}>%7$s</td>'
          '<td {value}>%8$s</td>'
          '{statement_wal_bytes?wal_row1}'
          '<td {value}>%11$s</td>'
          '<td {value}>%12$s</td>'
          '<td {value}>%13$s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%14$s</td>'
          '<td {value}>%15$s</td>'
          '<td {value}>%16$s</td>'
          '{statement_wal_bytes?wal_row2}'
          '<td {value}>%19$s</td>'
          '<td {value}>%20$s</td>'
          '<td {value}>%21$s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>',
      'statement_wal_bytes?wal_row1',
        '<td {value}>%9$s</td>'
        '<td {value}>%10$s</td>',
      'statement_wal_bytes?wal_row2',
        '<td {value}>%17$s</td>'
        '<td {value}>%18$s</td>'
    );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by shared dirtied
    FOR r_result IN c_sh_dirt(
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
            r_result.shared_blks_dirtied1,
            round(CAST(r_result.dirtied_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            pg_size_pretty(r_result.wal_bytes1),
            round(CAST(r_result.wal_bytes_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_dirtied2,
            round(CAST(r_result.dirtied_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            pg_size_pretty(r_result.wal_bytes2),
            round(CAST(r_result.wal_bytes_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
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

CREATE FUNCTION top_shared_written_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by shared written
    c_sh_wr CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.shared_blks_written, 0) as shared_blks_written,
        NULLIF(st.tot_written_pct, 0.0) as tot_written_pct,
        NULLIF(st.backend_written_pct, 0.0) as backend_written_pct,
        NULLIF(st.shared_hit_pct, 0.0) as shared_hit_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE st.shared_blks_written > 0
    ORDER BY st.shared_blks_written DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Total number of shared blocks written by the statement">Written</th>'
            '<th title="Shared blocks written by this statement as a percentage of all shared blocks written in a cluster (sum of pg_stat_bgwriter fields buffers_checkpoint, buffers_clean and buffers_backend)">%Total</th>'
            '<th title="Shared blocks written by this statement as a percentage total buffers written directly by a backends (buffers_backend of pg_stat_bgwriter view)">%BackendW</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by shared written
    FOR r_result IN c_sh_wr(
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
            r_result.shared_blks_written,
            round(CAST(r_result.tot_written_pct AS numeric),2),
            round(CAST(r_result.backend_written_pct AS numeric),2),
            round(CAST(r_result.shared_hit_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
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

CREATE FUNCTION top_shared_written_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) queries ordered by shared written
    c_sh_wr CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.shared_blks_written, 0) as shared_blks_written1,
        NULLIF(st1.tot_written_pct, 0.0) as tot_written_pct1,
        NULLIF(st1.backend_written_pct, 0.0) as backend_written_pct1,
        NULLIF(st1.shared_hit_pct, 0.0) as shared_hit_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.shared_blks_written, 0) as shared_blks_written2,
        NULLIF(st2.tot_written_pct, 0.0) as tot_written_pct2,
        NULLIF(st2.backend_written_pct, 0.0) as backend_written_pct2,
        NULLIF(st2.shared_hit_pct, 0.0) as shared_hit_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY st1.shared_blks_written DESC NULLS LAST) as rn_written1,
        row_number() over (ORDER BY st2.shared_blks_written DESC NULLS LAST) as rn_written2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.shared_blks_written, 0) + COALESCE(st2.shared_blks_written, 0) > 0
    ORDER BY COALESCE(st1.shared_blks_written, 0) + COALESCE(st2.shared_blks_written, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_written1,
        rn_written2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Shared written sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Total number of shared blocks written by the statement">Written</th>'
            '<th title="Shared blocks written by this statement as a percentage of all shared blocks written in a cluster (sum of pg_stat_bgwriter fields buffers_checkpoint, buffers_clean and buffers_backend)">%Total</th>'
            '<th title="Shared blocks written by this statement as a percentage total buffers written directly by a backends (buffers_backend field of pg_stat_bgwriter view)">%BackendW</th>'
            '<th title="Shared blocks hits as a percentage of shared blocks fetched (read + hit)">Hits(%)</th>'
            '<th title="Time spent by the statement">Elapsed(s)</th>'
            '<th title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by shared written
    FOR r_result IN c_sh_wr(
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
            r_result.shared_blks_written1,
            round(CAST(r_result.tot_written_pct1 AS numeric),2),
            round(CAST(r_result.backend_written_pct1 AS numeric),2),
            round(CAST(r_result.shared_hit_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.shared_blks_written2,
            round(CAST(r_result.tot_written_pct2 AS numeric),2),
            round(CAST(r_result.backend_written_pct2 AS numeric),2),
            round(CAST(r_result.shared_hit_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
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

CREATE FUNCTION top_wal_size_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for queries ordered by WAL bytes
    c_wal_size CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.wal_bytes, 0) as wal_bytes,
        NULLIF(st.wal_bytes_pct, 0.0) as wal_bytes_pct,
        NULLIF(st.shared_blks_dirtied, 0) as shared_blks_dirtied,
        NULLIF(st.wal_fpi, 0) as wal_fpi,
        NULLIF(st.wal_records, 0) as wal_records
    FROM top_statements1 st
    WHERE st.wal_bytes > 0
    ORDER BY st.wal_bytes DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
    LIMIT topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when WAL stats is available
    IF NOT jsonb_extract_path_text(report_context, 'report_features', 'statement_wal_bytes')::boolean THEN
      RETURN '';
    END IF;

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {stattbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
            '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Total number of WAL full page images generated by the statement">WAL FPI</th>'
            '<th title="Total number of WAL records generated by the statement">WAL records</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by elapsed time
    FOR r_result IN c_wal_size(
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
            pg_size_pretty(r_result.wal_bytes),
            round(CAST(r_result.wal_bytes_pct AS numeric),2),
            r_result.shared_blks_dirtied,
            r_result.wal_fpi,
            r_result.wal_records
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

CREATE FUNCTION top_wal_size_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top queries ordered by WAL bytes
    c_wal_size CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.wal_bytes, 0) as wal_bytes1,
        NULLIF(st1.wal_bytes_pct, 0.0) as wal_bytes_pct1,
        NULLIF(st1.shared_blks_dirtied, 0) as shared_blks_dirtied1,
        NULLIF(st1.wal_fpi, 0) as wal_fpi1,
        NULLIF(st1.wal_records, 0) as wal_records1,
        NULLIF(st2.wal_bytes, 0) as wal_bytes2,
        NULLIF(st2.wal_bytes_pct, 0.0) as wal_bytes_pct2,
        NULLIF(st2.shared_blks_dirtied, 0) as shared_blks_dirtied2,
        NULLIF(st2.wal_fpi, 0) as wal_fpi2,
        NULLIF(st2.wal_records, 0) as wal_records2,
        row_number() over (ORDER BY st1.wal_bytes DESC NULLS LAST) as rn_wal1,
        row_number() over (ORDER BY st2.wal_bytes DESC NULLS LAST) as rn_wal2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.wal_bytes, 0) + COALESCE(st2.wal_bytes, 0) > 0
    ORDER BY COALESCE(st1.wal_bytes, 0) + COALESCE(st2.wal_bytes, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_wal1,
        rn_wal2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- This report section is meaningful only when WAL stats is available
    IF NOT jsonb_extract_path_text(report_context, 'report_features', 'statement_wal_bytes')::boolean THEN
      RETURN '';
    END IF;

    -- WAL sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Query ID</th>'
            '<th>Database</th>'
            '<th>User</th>'
            '<th>I</th>'
            '<th title="Total amount of WAL bytes generated by the statement">WAL</th>'
            '<th title="WAL bytes of this statement as a percentage of total WAL bytes generated by a cluster">%Total</th>'
            '<th title="Total number of shared blocks dirtied by the statement">Dirtied</th>'
            '<th title="Total number of WAL full page images generated by the statement">WAL FPI</th>'
            '<th title="Total number of WAL records generated by the statement">WAL records</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);
    -- Reporting on top queries by shared_blks_fetched
    FOR r_result IN c_wal_size(
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
            pg_size_pretty(r_result.wal_bytes1),
            round(CAST(r_result.wal_bytes_pct1 AS numeric),2),
            r_result.shared_blks_dirtied1,
            r_result.wal_fpi1,
            r_result.wal_records1,
            pg_size_pretty(r_result.wal_bytes2),
            round(CAST(r_result.wal_bytes_pct2 AS numeric),2),
            r_result.shared_blks_dirtied2,
            r_result.wal_fpi2,
            r_result.wal_records2
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

CREATE FUNCTION top_temp_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by temp usage
    c_temp CURSOR(topn integer) FOR
    SELECT
        st.datid,
        st.dbname,
        st.userid,
        st.username,
        st.queryid,
        st.toplevel,
        NULLIF(st.total_time, 0.0) as total_time,
        NULLIF(st.rows, 0) as rows,
        NULLIF(st.local_blks_fetched, 0) as local_blks_fetched,
        NULLIF(st.local_hit_pct, 0.0) as local_hit_pct,
        NULLIF(st.temp_blks_written, 0) as temp_blks_written,
        NULLIF(st.temp_write_total_pct, 0.0) as temp_write_total_pct,
        NULLIF(st.temp_blks_read, 0) as temp_blks_read,
        NULLIF(st.temp_read_total_pct, 0.0) as temp_read_total_pct,
        NULLIF(st.local_blks_written, 0) as local_blks_written,
        NULLIF(st.local_write_total_pct, 0.0) as local_write_total_pct,
        NULLIF(st.local_blks_read, 0) as local_blks_read,
        NULLIF(st.local_read_total_pct, 0.0) as local_read_total_pct,
        NULLIF(st.calls, 0) as calls
    FROM top_statements1 st
    WHERE COALESCE(st.temp_blks_read, 0) + COALESCE(st.temp_blks_written, 0) +
        COALESCE(st.local_blks_read, 0) + COALESCE(st.local_blks_written, 0) > 0
    ORDER BY COALESCE(st.temp_blks_read, 0) + COALESCE(st.temp_blks_written, 0) +
        COALESCE(st.local_blks_read, 0) + COALESCE(st.local_blks_written, 0) DESC,
      st.queryid ASC,
      st.toplevel ASC,
      st.datid ASC,
      st.userid ASC,
      st.dbname ASC,
      st.username ASC
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
            '<th rowspan="2" title="Number of local blocks fetched (hit + read)">Local fetched</th>'
            '<th rowspan="2" title="Local blocks hit percentage">Hits(%)</th>'
            '<th colspan="4" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th colspan="4" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of written local blocks">Write</th>'
            '<th title="Percentage of all local blocks written">%Total</th>'
            '<th title="Number of read local blocks">Read</th>'
            '<th title="Percentage of all local blocks read">%Total</th>'
            '<th title="Number of written temp blocks">Write</th>'
            '<th title="Percentage of all temp blocks written">%Total</th>'
            '<th title="Number of read temp blocks">Read</th>'
            '<th title="Percentage of all temp blocks read">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td {mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td>%4$s</td>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by temp usage
    FOR r_result IN c_temp(
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
            r_result.local_blks_fetched,
            round(CAST(r_result.local_hit_pct AS numeric),2),
            r_result.local_blks_written,
            round(CAST(r_result.local_write_total_pct AS numeric),2),
            r_result.local_blks_read,
            round(CAST(r_result.local_read_total_pct AS numeric),2),
            r_result.temp_blks_written,
            round(CAST(r_result.temp_write_total_pct AS numeric),2),
            r_result.temp_blks_read,
            round(CAST(r_result.temp_read_total_pct AS numeric),2),
            round(CAST(r_result.total_time AS numeric),1),
            r_result.rows,
            r_result.calls
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

CREATE FUNCTION top_temp_diff_htbl(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    report      text := '';
    tab_row     text := '';
    jtab_tpl    jsonb;

    --Cursor for top(cnt) querues ordered by temp usage
    c_temp CURSOR(topn integer) FOR
    SELECT * FROM (SELECT
        COALESCE(st1.datid,st2.datid) as datid,
        COALESCE(st1.dbname,st2.dbname) as dbname,
        COALESCE(st1.userid,st2.userid) as userid,
        COALESCE(st1.username,st2.username) as username,
        COALESCE(st1.queryid,st2.queryid) as queryid,
        COALESCE(st1.toplevel,st2.toplevel) as toplevel,
        NULLIF(st1.total_time, 0.0) as total_time1,
        NULLIF(st1.rows, 0) as rows1,
        NULLIF(st1.local_blks_fetched, 0) as local_blks_fetched1,
        NULLIF(st1.local_hit_pct, 0.0) as local_hit_pct1,
        NULLIF(st1.temp_blks_written, 0) as temp_blks_written1,
        NULLIF(st1.temp_write_total_pct, 0.0) as temp_write_total_pct1,
        NULLIF(st1.temp_blks_read, 0) as temp_blks_read1,
        NULLIF(st1.temp_read_total_pct, 0.0) as temp_read_total_pct1,
        NULLIF(st1.local_blks_written, 0) as local_blks_written1,
        NULLIF(st1.local_write_total_pct, 0.0) as local_write_total_pct1,
        NULLIF(st1.local_blks_read, 0) as local_blks_read1,
        NULLIF(st1.local_read_total_pct, 0.0) as local_read_total_pct1,
        NULLIF(st1.calls, 0) as calls1,
        NULLIF(st2.total_time, 0.0) as total_time2,
        NULLIF(st2.rows, 0) as rows2,
        NULLIF(st2.local_blks_fetched, 0) as local_blks_fetched2,
        NULLIF(st2.local_hit_pct, 0.0) as local_hit_pct2,
        NULLIF(st2.temp_blks_written, 0) as temp_blks_written2,
        NULLIF(st2.temp_write_total_pct, 0.0) as temp_write_total_pct2,
        NULLIF(st2.temp_blks_read, 0) as temp_blks_read2,
        NULLIF(st2.temp_read_total_pct, 0.0) as temp_read_total_pct2,
        NULLIF(st2.local_blks_written, 0) as local_blks_written2,
        NULLIF(st2.local_write_total_pct, 0.0) as local_write_total_pct2,
        NULLIF(st2.local_blks_read, 0) as local_blks_read2,
        NULLIF(st2.local_read_total_pct, 0.0) as local_read_total_pct2,
        NULLIF(st2.calls, 0) as calls2,
        row_number() over (ORDER BY COALESCE(st1.temp_blks_read, 0)+ COALESCE(st1.temp_blks_written, 0)+
          COALESCE(st1.local_blks_read, 0)+ COALESCE(st1.local_blks_written, 0)DESC NULLS LAST) as rn_temp1,
        row_number() over (ORDER BY COALESCE(st2.temp_blks_read, 0)+ COALESCE(st2.temp_blks_written, 0)+
          COALESCE(st2.local_blks_read, 0)+ COALESCE(st2.local_blks_written, 0)DESC NULLS LAST) as rn_temp2
    FROM top_statements1 st1
        FULL OUTER JOIN top_statements2 st2 USING (server_id, datid, userid, queryid, toplevel)
    WHERE COALESCE(st1.temp_blks_read, 0) + COALESCE(st1.temp_blks_written, 0) +
        COALESCE(st1.local_blks_read, 0) + COALESCE(st1.local_blks_written, 0) +
        COALESCE(st2.temp_blks_read, 0) + COALESCE(st2.temp_blks_written, 0) +
        COALESCE(st2.local_blks_read, 0) + COALESCE(st2.local_blks_written, 0) > 0
    ORDER BY COALESCE(st1.temp_blks_read, 0) + COALESCE(st1.temp_blks_written, 0) +
        COALESCE(st1.local_blks_read, 0) + COALESCE(st1.local_blks_written, 0) +
        COALESCE(st2.temp_blks_read, 0) + COALESCE(st2.temp_blks_written, 0) +
        COALESCE(st2.local_blks_read, 0) + COALESCE(st2.local_blks_written, 0) DESC,
      COALESCE(st1.queryid,st2.queryid) ASC,
      COALESCE(st1.datid,st2.datid) ASC,
      COALESCE(st1.userid,st2.userid) ASC,
      COALESCE(st1.toplevel,st2.toplevel) ASC
    ) t1
    WHERE least(
        rn_temp1,
        rn_temp2
      ) <= topn;

    r_result RECORD;
BEGIN
    -- Temp usage sorted list TPLs
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th rowspan="2">Query ID</th>'
            '<th rowspan="2">Database</th>'
            '<th rowspan="2">User</th>'
            '<th rowspan="2">I</th>'
            '<th rowspan="2" title="Number of local blocks fetched (hit + read)">Local fetched</th>'
            '<th rowspan="2" title="Local blocks hit percentage">Hits(%)</th>'
            '<th colspan="4" title="Number of blocks, used for temporary tables">Local (blk)</th>'
            '<th colspan="4" title="Number of blocks, used in operations (like sorts and joins)">Temp (blk)</th>'
            '<th rowspan="2" title="Time spent by the statement">Elapsed(s)</th>'
            '<th rowspan="2" title="Total number of rows retrieved or affected by the statement">Rows</th>'
            '<th rowspan="2" title="Number of times the statement was executed">Executions</th>'
          '</tr>'
          '<tr>'
            '<th title="Number of written local blocks">Write</th>'
            '<th title="Percentage of all local blocks written">%Total</th>'
            '<th title="Number of read local blocks">Read</th>'
            '<th title="Percentage of all local blocks read">%Total</th>'
            '<th title="Number of written temp blocks">Write</th>'
            '<th title="Percentage of all temp blocks written">%Total</th>'
            '<th title="Number of read temp blocks">Read</th>'
            '<th title="Percentage of all temp blocks read">%Total</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr_mono}><p><a HREF="#%2$s">%2$s</a></p>'
          '<p><small>[%3$s]</small>%1$s</p></td>'
          '<td {rowtdspanhdr}>%4$s</td>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>',
      'nested_tpl',
        ' <small title="Nested level">(N)</small>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    -- Reporting on top queries by temp usage
    FOR r_result IN c_temp(
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
            r_result.local_blks_fetched1,
            round(CAST(r_result.local_hit_pct1 AS numeric),2),
            r_result.local_blks_written1,
            round(CAST(r_result.local_write_total_pct1 AS numeric),2),
            r_result.local_blks_read1,
            round(CAST(r_result.local_read_total_pct1 AS numeric),2),
            r_result.temp_blks_written1,
            round(CAST(r_result.temp_write_total_pct1 AS numeric),2),
            r_result.temp_blks_read1,
            round(CAST(r_result.temp_read_total_pct1 AS numeric),2),
            round(CAST(r_result.total_time1 AS numeric),1),
            r_result.rows1,
            r_result.calls1,
            r_result.local_blks_fetched2,
            round(CAST(r_result.local_hit_pct2 AS numeric),2),
            r_result.local_blks_written2,
            round(CAST(r_result.local_write_total_pct2 AS numeric),2),
            r_result.local_blks_read2,
            round(CAST(r_result.local_read_total_pct2 AS numeric),2),
            r_result.temp_blks_written2,
            round(CAST(r_result.temp_write_total_pct2 AS numeric),2),
            r_result.temp_blks_read2,
            round(CAST(r_result.temp_read_total_pct2 AS numeric),2),
            round(CAST(r_result.total_time2 AS numeric),1),
            r_result.rows2,
            r_result.calls2
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

CREATE FUNCTION collect_queries(IN userid oid, IN datid oid, queryid bigint)
RETURNS integer SET search_path=@extschema@ AS $$
BEGIN
    INSERT INTO queries_list(
      userid,
      datid,
      queryid
    )
    VALUES (
      collect_queries.userid,
      collect_queries.datid,
      collect_queries.queryid
    )
    ON CONFLICT DO NOTHING;

    RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION report_queries(IN report_context jsonb, IN sserver_id integer)
RETURNS text SET search_path=@extschema@ AS $$
DECLARE
    c_queries_aggr CURSOR(start1_id integer, end1_id integer,
      start2_id integer, end2_id integer, topn integer)
    FOR
    SELECT
      queryid,
      ord,
      row_span,
      query
    FROM (
      SELECT
      queryid,
      row_number() OVER (PARTITION BY queryid
        ORDER BY
          last_sample_id DESC NULLS FIRST,
          queryid_md5 DESC NULLS FIRST
        ) ord,
      -- Calculate a value for statement rowspan atribute
      least(count(*) OVER (PARTITION BY queryid),3) row_span,
      query
      FROM (
        SELECT DISTINCT
          server_id,
          ('x' || left(queryid_md5, 16))::bit(64)::bigint queryid,
          queryid_md5
        FROM
          queries_list ql
          JOIN sample_statements ss
		  ON ql.datid = ss.datid AND ql.userid = ss.userid AND ql.queryid = ('x' || left(ss.queryid_md5, 16))::bit(64)::bigint
        WHERE
          ss.server_id = sserver_id
          AND (
            sample_id BETWEEN start1_id AND end1_id
            OR sample_id BETWEEN start2_id AND end2_id
          )
      ) queryids
      JOIN stmt_list USING (server_id, queryid_md5)
    ) ord_stmt_v
    WHERE ord <= 3
    ORDER BY
      queryid ASC,
      ord ASC;

    c_queries CURSOR(start1_id integer, end1_id integer,
      start2_id integer, end2_id integer, topn integer)
    FOR
    SELECT
      queryid,
      ord,
      row_span,
      query
    FROM (
      SELECT
      queryid,
      row_number() OVER (PARTITION BY queryid
        ORDER BY
          last_sample_id DESC NULLS FIRST,
          queryid_md5 DESC NULLS FIRST
        ) ord,
      -- Calculate a value for statement rowspan atribute
      least(count(*) OVER (PARTITION BY queryid),3) row_span,
      query
      FROM (
        SELECT DISTINCT
          server_id,
          queryid,
          queryid_md5
        FROM
          queries_list ql
          JOIN sample_statements ss USING (datid, userid, queryid)
        WHERE
          ss.server_id = sserver_id
          AND (
            sample_id BETWEEN start1_id AND end1_id
            OR sample_id BETWEEN start2_id AND end2_id
          )
      ) queryids
      JOIN stmt_list USING (server_id, queryid_md5)
    ) ord_stmt_v
    WHERE ord <= 3
    ORDER BY
      queryid ASC,
      ord ASC;

    qr_result   RECORD;
    report      text := '';
    query_text  text := '';
    qlen_limit  integer;
    jtab_tpl    jsonb;
  	aggregate_queries_by_text boolean;
BEGIN
    -- Getting aggregate_queries_by_text setting
    BEGIN
        aggregate_queries_by_text := current_setting('pg_profile.aggregate_queries_by_text')::boolean;
    EXCEPTION
        WHEN OTHERS THEN aggregate_queries_by_text := false;
    END;
	
    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table class="stmtlist">'
          '<tr>'
            '<th>QueryID</th>'
            '<th>Query Text</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'stmt_tpl',
        '<tr>'
          '<td class="mono hdr" id="%1$s" rowspan="%3$s">%1$s</td>'
          '<td {mono}>%2$s</td>'
        '</tr>',
      'substmt_tpl',
        '<tr>'
          '<td {mono}>%1$s</td>'
        '</tr>'
      );
    -- apply settings to templates
    jtab_tpl := jsonb_replace(report_context, jtab_tpl);

    qlen_limit := (report_context #>> '{report_properties,max_query_length}')::integer;

	IF aggregate_queries_by_text THEN
		FOR qr_result IN c_queries_aggr(
			(report_context #>> '{report_properties,start1_id}')::integer,
			(report_context #>> '{report_properties,end1_id}')::integer,
			(report_context #>> '{report_properties,start2_id}')::integer,
			(report_context #>> '{report_properties,end2_id}')::integer,
			(report_context #>> '{report_properties,topn}')::integer
		  )
		LOOP
			query_text := replace(qr_result.query,'<','&lt;');
			query_text := replace(query_text,'>','&gt;');
			IF qr_result.ord = 1 THEN
			  report := report||format(
				  jtab_tpl #>> ARRAY['stmt_tpl'],
				  to_hex(qr_result.queryid),
				  left(query_text,qlen_limit),
				  qr_result.row_span
			  );
			ELSE
			  report := report||format(
				  jtab_tpl #>> ARRAY['substmt_tpl'],
				  left(query_text,qlen_limit)
			  );
			END IF;
		END LOOP;
	ELSE
		FOR qr_result IN c_queries(
			(report_context #>> '{report_properties,start1_id}')::integer,
			(report_context #>> '{report_properties,end1_id}')::integer,
			(report_context #>> '{report_properties,start2_id}')::integer,
			(report_context #>> '{report_properties,end2_id}')::integer,
			(report_context #>> '{report_properties,topn}')::integer
		  )
		LOOP
			query_text := replace(qr_result.query,'<','&lt;');
			query_text := replace(query_text,'>','&gt;');
			IF qr_result.ord = 1 THEN
			  report := report||format(
				  jtab_tpl #>> ARRAY['stmt_tpl'],
				  to_hex(qr_result.queryid),
				  left(query_text,qlen_limit),
				  qr_result.row_span
			  );
			ELSE
			  report := report||format(
				  jtab_tpl #>> ARRAY['substmt_tpl'],
				  left(query_text,qlen_limit)
			  );
			END IF;
		END LOOP;
	END IF;

    IF report != '' THEN
        RETURN replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    ELSE
        RETURN '';
    END IF;
END;
$$ LANGUAGE plpgsql;
