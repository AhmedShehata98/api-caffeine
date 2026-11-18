-- Workspace catalog only. Actual secret values remain in device secure storage.
create table public.mcp_servers (
    id uuid primary key default gen_random_uuid(),
    workspace_id uuid not null references public.workspaces (id) on delete cascade,
    name text not null check (length(btrim(name)) > 0),
    transport text not null check (transport in ('stdio', 'http', 'sse')),
    command text,
    url text,
    args jsonb not null default '[]'::jsonb,
    cwd text,
    env jsonb not null default '{}'::jsonb,
    headers jsonb not null default '{}'::jsonb,
    secret_keys jsonb not null default '[]'::jsonb,
    settings jsonb not null default '{}'::jsonb,
    position integer,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint mcp_servers_target check (
        (transport = 'stdio' and command is not null
            and length(btrim(command)) > 0 and url is null)
        or (transport in ('http', 'sse') and command is null
            and url is not null and url ~* '^https?://[^/?#[:space:]]+'
            and url !~* '^https?://[^/?#]*@')
    ),
    constraint mcp_servers_json_containers check (
        jsonb_typeof(args) = 'array'
        and jsonb_typeof(env) = 'object'
        and jsonb_typeof(headers) = 'object'
        and jsonb_typeof(secret_keys) = 'array'
        and jsonb_typeof(settings) = 'object'
    ),
    constraint mcp_servers_string_values check (
        not jsonb_path_exists(args, '$[*] ? (@.type() != "string")')
        and not jsonb_path_exists(secret_keys, '$[*] ? (@.type() != "string")')
        and not jsonb_path_exists(env, '$.* ? (@.type() != "string")')
        and not jsonb_path_exists(headers, '$.* ? (@.type() != "string")')
    )
);

create index mcp_servers_workspace_id_idx on public.mcp_servers (workspace_id);

create trigger set_updated_at before update on public.mcp_servers
    for each row execute function public.set_updated_at();

alter table public.mcp_servers enable row level security;

create policy mcp_servers_all_member on public.mcp_servers
    for all to authenticated
    using (public.is_workspace_member(workspace_id))
    with check (public.is_workspace_member(workspace_id));
