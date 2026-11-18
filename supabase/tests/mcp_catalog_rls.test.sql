-- Run with `supabase test db`. All users, memberships and catalogs roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(33);

select has_table('public', 'mcp_servers', 'MCP catalog exists after migration replay');
select ok((select relrowsecurity from pg_class where oid = 'public.mcp_servers'::regclass),
    'MCP catalog has RLS enabled');
select ok(not (select rolbypassrls from pg_roles where rolname = 'authenticated'),
    'authenticated role does not bypass RLS');

insert into auth.users (id) values
    ('a0000000-0000-0000-0000-000000000001'),
    ('a0000000-0000-0000-0000-000000000002'),
    ('a0000000-0000-0000-0000-000000000003');
insert into public.organizations (id, name) values
    ('b0000000-0000-0000-0000-000000000001', 'MCP RLS A'),
    ('b0000000-0000-0000-0000-000000000002', 'MCP RLS B');
insert into public.organization_members (organization_id, user_id, role) values
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner'),
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member'),
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'owner');
insert into public.workspaces (id, organization_id, name) values
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'A1'),
    ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'A2'),
    ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'B1');
insert into public.mcp_servers (id, workspace_id, name, transport, command) values
    ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'A1 server', 'stdio', 'dart'),
    ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'A2 server', 'stdio', 'dart'),
    ('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'B1 server', 'stdio', 'dart');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is(current_user::text, 'authenticated', 'Catalog operations use the RLS application role');
select is((select count(*) from public.mcp_servers), 2::bigint, 'Owner sees both workspaces in their organization');
select is((select count(*) from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000003'),
    0::bigint, 'Owner cannot read another organization');
select lives_ok($$insert into public.mcp_servers (id, workspace_id, name, transport, command)
    values ('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'new', 'stdio', 'dart')$$,
    'Owner can insert in a member workspace');
select lives_ok($$update public.mcp_servers set name = 'owner edited' where id = 'd0000000-0000-0000-0000-000000000004'$$,
    'Owner can update a visible catalog row');
select is((select name from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000004'),
    'owner edited', 'Owner update persisted');
select lives_ok($$delete from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000004'$$,
    'Owner can delete a visible catalog row');
select is((select count(*) from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000004'),
    0::bigint, 'Owner delete removed the row');
select throws_ok($$insert into public.mcp_servers (workspace_id, name, transport, command)
    values ('c0000000-0000-0000-0000-000000000003', 'forbidden', 'stdio', 'dart')$$,
    '42501', null, 'Cross-organization insert is denied');
select throws_ok($$update public.mcp_servers set workspace_id = 'c0000000-0000-0000-0000-000000000003'
    where id = 'd0000000-0000-0000-0000-000000000001'$$,
    '42501', null, 'WITH CHECK denies transfer into another organization');
update public.mcp_servers set name = 'stolen' where id = 'd0000000-0000-0000-0000-000000000003';
delete from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000003';
reset role;
select is((select name from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000003'),
    'B1 server', 'Invisible cross-organization update changed nothing');
select is((select count(*) from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000003'),
    1::bigint, 'Invisible cross-organization delete changed nothing');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*) from public.mcp_servers), 2::bigint, 'A second organization member sees both workspaces');
select lives_ok($$update public.mcp_servers set name = 'member edited' where id = 'd0000000-0000-0000-0000-000000000002'$$,
    'A non-owner member can edit a shared catalog');
select is((select name from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000002'),
    'member edited', 'Shared member update persisted');
select throws_ok($$insert into public.mcp_servers (workspace_id, name, transport, command)
    values ('c0000000-0000-0000-0000-000000000003', 'forbidden', 'stdio', 'dart')$$,
    '42501', null, 'Shared membership does not grant access to another organization');
select throws_ok($$insert into public.organization_members (organization_id, user_id)
    values ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002')$$,
    '42501', null, 'A member cannot self-grant another organization membership');
select throws_ok($$update public.workspaces set organization_id = 'b0000000-0000-0000-0000-000000000002'
    where id = 'c0000000-0000-0000-0000-000000000001'$$,
    '42501', null, 'A member cannot move a workspace into an inaccessible organization');
reset role;
insert into public.organization_members (organization_id, user_id) values
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002');
set local role authenticated;
select is((select count(*) from public.mcp_servers), 3::bigint, 'An explicitly authorized multi-organization member sees both catalogs');
reset role;
delete from public.organization_members where organization_id = 'b0000000-0000-0000-0000-000000000002'
    and user_id = 'a0000000-0000-0000-0000-000000000002';
set local role authenticated;
select is((select count(*) from public.mcp_servers), 2::bigint, 'Removing one membership immediately hides only that organization');
reset role;
delete from public.organization_members where organization_id = 'b0000000-0000-0000-0000-000000000001'
    and user_id = 'a0000000-0000-0000-0000-000000000002';
set local role authenticated;
select is((select count(*) from public.mcp_servers), 0::bigint, 'Revocation hides shared catalogs without changing the JWT subject');
update public.mcp_servers set name = 'revoked edit' where id = 'd0000000-0000-0000-0000-000000000001';
delete from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000001';
select throws_ok($$insert into public.mcp_servers (workspace_id, name, transport, command)
    values ('c0000000-0000-0000-0000-000000000001', 'revoked insert', 'stdio', 'dart')$$,
    '42501', null, 'Revocation blocks new catalog writes');
reset role;
select is((select name from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000001'),
    'A1 server', 'Revoked member update changed nothing');
select is((select count(*) from public.mcp_servers where id = 'd0000000-0000-0000-0000-000000000001'),
    1::bigint, 'Revoked member delete changed nothing');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*) from public.mcp_servers), 2::bigint, 'Removing another member does not revoke the owner');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*) from public.mcp_servers), 0::bigint, 'Unauthenticated anon role sees no catalog rows');
select throws_ok($$insert into public.mcp_servers (workspace_id, name, transport, command)
    values ('c0000000-0000-0000-0000-000000000001', 'anonymous', 'stdio', 'dart')$$,
    '42501', null, 'Unauthenticated anon role cannot insert');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
delete from public.workspaces where id = 'c0000000-0000-0000-0000-000000000002';
reset role;
select is((select count(*) from public.mcp_servers where workspace_id = 'c0000000-0000-0000-0000-000000000002'),
    0::bigint, 'Deleting an authorized workspace cascades its MCP catalog');
select is((select count(*) from public.mcp_servers where workspace_id = 'c0000000-0000-0000-0000-000000000003'),
    1::bigint, 'Workspace cascade leaves another organization catalog intact');
set local role anon;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"anon"}', true);
select is((select count(*) from public.mcp_servers), 0::bigint, 'Anon database role cannot inherit authenticated policy via claims alone');

select * from finish();
rollback;
