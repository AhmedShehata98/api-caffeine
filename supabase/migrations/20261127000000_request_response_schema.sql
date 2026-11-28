alter table public.requests
    add column response_schema_enabled boolean not null default false,
    add column response_schema_source text not null default '';

-- Include the test configuration when cloning a collection's requests.
create or replace function public.duplicate_collection(source_id uuid, new_name text)
returns public.collections
language plpgsql
security invoker
set search_path = ''
as $$
declare
    source public.collections;
    copy public.collections;
begin
    select * into source from public.collections where id = source_id;
    if not found then
        raise exception 'Collection not found' using errcode = 'P0002';
    end if;

    insert into public.collections (workspace_id, name, position)
    values (
        source.workspace_id,
        new_name,
        (select coalesce(max(c.position), -1) + 1
         from public.collections c
         where c.workspace_id = source.workspace_id)
    )
    returning * into copy;

    insert into public.requests (
        collection_id, name, method, url, params, headers, auth, body_type, body, position,
        response_schema_enabled, response_schema_source
    )
    select copy.id, r.name, r.method, r.url, r.params, r.headers, r.auth, r.body_type, r.body, r.position,
           r.response_schema_enabled, r.response_schema_source
    from public.requests r
    where r.collection_id = source_id;

    return copy;
end;
$$;
