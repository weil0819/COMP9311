--
-- check.sql ... checking functions
--
--

--
-- Helper functions
--

create or replace function
	proj2_table_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='r';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_view_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='v';
	return (_check = 1);
end;
$$ language plpgsql;

create or replace function
	proj2_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

-- proj2_check_result:
-- * determines appropriate message, based on count of
--   excess and missing tuples in user output vs expected output

create or replace function
	proj2_check_result(nexcess integer, nmissing integer) returns text
as $$
begin
	if (nexcess = 0 and nmissing = 0) then
		return 'correct';
	elsif (nexcess > 0 and nmissing = 0) then
		return 'too many result tuples';
	elsif (nexcess = 0 and nmissing > 0) then
		return 'missing result tuples';
	elsif (nexcess > 0 and nmissing > 0) then
		return 'incorrect result tuples';
	end if;
end;
$$ language plpgsql;

-- proj2_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
begin
	if (_type = 'view' and not proj2_view_exists(_name)) then
		return 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (not proj2_table_exists(_res)) then
		return _res||': No expected results!';
	else
		excessQ := 'select count(*) '||
			   'from (('||_query||') except '||
			   '(select * from '||_res||')) as X';
		-- raise notice 'Q: %',excessQ;
		execute excessQ into nexcess;
		missingQ := 'select count(*) '||
			    'from ((select * from '||_res||') '||
			    'except ('||_query||')) as X';
		-- raise notice 'Q: %',missingQ;
		execute missingQ into nmissing;
		return proj2_check_result(nexcess,nmissing);
	end if;
	return '???';
end;
$$ language plpgsql;

-- proj2_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results

create or replace function
	proj2_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not proj2_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (_res is null) then
		_sql := 'select ('||_query||') is null';
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	else
		_sql := 'select ('||_query||') = '||quote_literal(_res);
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	end if;
	if (_chk) then
		return 'correct';
	else
		return 'incorrect result';
	end if;
end;
$$ language plpgsql;

-- check_all:
-- * run all of the checks and return a table of results

drop type if exists TestingResult cascade;
create type TestingResult as (test text, result text);

create or replace function
	check_all() returns setof TestingResult
as $$
declare
	i int;
	testQ text;
	result text;
	out TestingResult;
	tests text[] := array[
				'q1', 'q2_1', 'q2_2', 'q3_1', 'q3_2'
				];
begin
	for i in array_lower(tests,1) .. array_upper(tests,1)
	loop
		testQ := 'select check_'||tests[i]||'()';
		execute testQ into result;
		out := (tests[i],result);
		return next out;
	end loop;
	return;
end;
$$ language plpgsql;


--
-- Check functions for specific test-cases in Project 2
--


create or replace function check_q1() returns text
as $chk$
select proj2_check('function','q1','q1_expected',
                   $$select * from q1(52491)$$)
$chk$ language sql;

create or replace function check_q2_1() returns text
as $chk$
select proj2_check('function','q2','q2_expected_1',
                   $$select * from q2(50413833)$$)
$chk$ language sql;

create or replace function check_q2_2() returns text
as $chk$
select proj2_check('function','q2','q2_expected_2',
                   $$select * from q2(5032703)$$)
$chk$ language sql;

create or replace function check_q3_1() returns text
as $chk$
select proj2_check('function','q3','q3_expected_1',
                   $$select * from q3(52,35,100)$$)
$chk$ language sql;

create or replace function check_q3_2() returns text
as $chk$
select proj2_check('function','q3','q3_expected_2',
                   $$select * from q3(0,56,100)$$)
$chk$ language sql;

--
-- Tables of expected results for test cases
--

drop table if exists q1_expected;
create table q1_expected (
    valid_room_number integer,
    bigger_room_number integer
);

drop table if exists q2_expected_1;
create table q2_expected_1 (
    cid integer,
    term  char(4),
    code  char(8),
    name  text,
    uoc  integer,
    average_mark  integer,
    highest_mark  integer,
    median_mark  integer,
    totalEnrols  integer
);


drop table if exists q2_expected_2;
create table q2_expected_2 (
    cid integer,
    term  char(4),
    code  char(8),
    name  text,
    uoc  integer,
    average_mark  integer,
    highest_mark  integer,
    median_mark  integer,
    totalEnrols  integer
);


drop table if exists q3_expected_1;
create table q3_expected_1 (
    unswid integer, 
	name text, 
	records text
);

drop table if exists q3_expected_2;
create table q3_expected_2 (
    unswid integer, 
	name text, 
	records text
);

COPY q1_expected (valid_room_number, bigger_room_number) FROM stdin;
29	29
\.

COPY q2_expected_1 (cid, term, code, name, uoc, average_mark, highest_mark, median_mark, totalEnrols) FROM stdin;
48548	10s1	JURD7281	Property, Equity & Trusts 1	6	72	82	73	6
48642	10s1	LAWS2381	Property, Equity & Trusts 1	6	69	88	69	93
65702	12s2	JURD7281	Property, Equity & Trusts 1	6	69	75	70	5
65703	12s2	JURD7282	Property and Equity 2	6	70	90	72	44
65837	12s2	LAWS2382	Property and Equity 2	6	70	88	71	84
\.

COPY q2_expected_2 (cid, term, code, name, uoc, average_mark, highest_mark, median_mark, totalEnrols) FROM stdin;
5976	03s1	EURO1000	The New Europe A	6	73	82	76	7
8192	03s2	EURO1001	The New Europe B	6	71	84	72	6
19624	06s1	EURO2311	The Attractions of Communism	6	84	84	84	1
20035	06s1	HIST2489	The Attractions of Communism	6	74	74	74	1
23216	06s2	EURO1001	The New Europe B	6	72	79	71	4
27373	07s1	HIST2486	The Attractions of Fascism	6	69	85	75	5
30180	07s2	EURO2302	The Messiah Complex	6	59	59	59	1
30541	07s2	HIST2487	The Messiah Complex	6	85	89	85	2
33906	08s1	EURO2311	The Attractions of Communism	6	77	92	77	2
34282	08s1	HIST2489	The Attractions of Communism	6	77	95	80	3
37343	08s2	EURO2300	The German - Jewish Experience	6	74	88	74	2
37669	08s2	HIST2485	The German Jewish Experience	6	76	82	76	2
\.

COPY q3_expected_1 (unswid, name, records) FROM stdin;
3206256	Nye Cavallo	OPTM5271, Research Project 5B, Sem2 2012, Optometry and Vision Science, School of, 100\nBABS1201, Molecules, Cells and Genes, Sem1 2008, Biotechnology and Biomolecular Sciences, School of, 95\nPSYC4111, Psych and Stats for Optometry, Sem1 2011, Psychology, School of, 94\nVISN1211, Vision Science 1, Sem2 2008, Optometry and Vision Science, School of, 93\nOPTM4151, Ocular Therapeutics 4A, Sem1 2011, Optometry and Vision Science, School of, 91\n
3219926	Ningbo Su	OPTM5171, Research Project 5A, Sem1 2012, Optometry and Vision Science, School of, 100\nPSYC4111, Psych and Stats for Optometry, Sem1 2011, Psychology, School of, 95\nVISN2231, Introduction to Ocular Disease, Sem2 2009, Optometry and Vision Science, School of, 87\nOPTM3131, Ocular Disease 3A, Sem1 2010, Optometry and Vision Science, School of, 86\nOPTM4291, Optom Med, Sem1 2011, Optometry and Vision Science, School of, 85\n
3227561	Nicholas Barry	VISN2111, Physiology of the Ocular Syste, Sem1 2009, Optometry and Vision Science, School of, 100\nOPTM5171, Research Project 5A, Sem1 2012, Optometry and Vision Science, School of, 100\nVISN3111, Aging of the Visual System, Sem1 2010, Optometry and Vision Science, School of, 99\nVISN2131, Optics and the Eye, Sem1 2009, Optometry and Vision Science, School of, 98\nOPTM3131, Ocular Disease 3A, Sem1 2010, Optometry and Vision Science, School of, 98\n
\.

COPY q3_expected_2 (unswid, name, records) FROM stdin;
3000010	Tamsin Rockwell	MECH1300, Engineering Mechanics 1, Sem1 2004, Mechanical and Manufacturing Engineering, School of, 100\nMECH2612, Fluid Mechanics B, Sem2 2004, Mechanical and Manufacturing Engineering, School of, 100\nPHYS3230, Electromagnetism, Sem1 2005, Physics, School of, 100\nMECH2412, Mechanics of Solids 2B, Sem2 2005, Mechanical and Manufacturing Engineering, School of, 100\nPHYS3050, Nuclear Physics, Sem2 2005, Physics, School of, 100\n
3092300	Tianxing You Jia	CVEN4225, Geotechnical Engineering 4, Sem1 2006, Civil and Environmental Engineering, School of, 100\nCVEN3222, Geotechnical Engineering 2, Sem1 2005, Civil and Environmental Engineering, School of, 99\nCVEN1023, Statics, Sem1 2003, Civil and Environmental Engineering, School of, 98\nCVEN1026, Engineering Materials 1, Sem2 2003, Civil and Environmental Engineering, School of, 98\nLAWS1072, Contracts 2, Sem2 2004, Faculty of Law, 98\n
3102214	Huihong Leng	MECH4001, Comm. for Professional Eng., Sem2 2009, Mechanical and Manufacturing Engineering, School of, 100\nPHYS3720, Optoelectronics, Sem1 2008, Physics, School of, 93\nNANO1001, Nanotechnology 1, Sem2 2004, Materials Science & Engineering, School of, 90\nMECH2712, Thermodynamics B, Sem2 2006, Mechanical and Manufacturing Engineering, School of, 89\nAERO4620, Aerospace Vehicle Dynam & Avi, Sem2 2008, Mechanical and Manufacturing Engineering, School of, 89\n
\.





























