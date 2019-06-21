-- COMP9311 18s1 Project 1
--
-- MyMyUNSW Solutions

-- Q1: 
create or replace view Q1(unswid, name)
as
select p.unswid,p.name
from   People p
        join Course_enrolments e on (p.id=e.student)
        join Students sn on (p.id=sn.id)
where e.mark >= 85 and sn.stype = 'intl'
group  by p.unswid,p.name
having count(e.course) > 20
;

--Q2
create or replace view Q2(unswid, name)
as
select r.unswid,r.longname
from Buildings b
     join Rooms r on (b.id=r.building)
	 join Room_types t on (r.rtype=t.id)
where t.description='Meeting Room'
	and b.name='Computer Science Building'
	and r.capacity >= 20
;

-- Q3
create or replace view Q3(unswid,name)
as
select p.unswid, p.name
from People p
	join Staff on (Staff.id = p.id)
	join Course_staff on (Course_staff.staff=Staff.id)
	join Courses on (Courses.id=Course_staff.course)
	join Course_enrolments on (Course_enrolments.course=Courses.id)
	join Students on (Students.id=Course_enrolments.student)
where Students.id = (select id from People where name='Stefan Bilek')
;

--Q4
create or replace view a(id,unswid,name)
as
	(select People.id, People.unswid, People.name
	from People)
except
	(select People.id, People.unswid, People.name
	from People
	join Students on (Students.id=People.id)
	join Course_enrolments on (Course_enrolments.student=Students.id)
	join Courses on (Courses.id=Course_enrolments.course)
	where Courses.subject=(select id from Subjects where Subjects.code='COMP3231')
	)
;

create or replace view Q4(unswid,name)
as
select a.unswid,a.name
from a
	join Students on (Students.id=a.id)
	join Course_enrolments on (Course_enrolments.student=Students.id)
	join Courses on (Courses.id=Course_enrolments.course)
	where Courses.subject in (select id from Subjects where Subjects.code='COMP3331')
;

-- Q5:
create or replace view all_stream_enrolments
as
select p.unswid, t.year, t.term, st.name, sn.stype
from People p
     join Program_enrolments pe on (p.id=pe.student)
     join Stream_enrolments se on (pe.id=se.partof)
     join Streams st on (se.stream=st.id)
     join Semesters t on (t.id=pe.semester)
     join Students sn on (p.id=sn.id)
;

create or replace view all_program_enrolments
as
select p.unswid, t.year, t.term, pr.id, pr.code, u.longname as unit, sn.stype
from People p
     join Program_enrolments e on (p.id=e.student)
     join Programs pr on (pr.id=e.program)
     join Semesters t on (t.id=e.semester)
     join OrgUnits u on (pr.offeredby=u.id)
     join Students sn on (p.id=sn.id)
;

create or replace view Q5a(num)
as
select count(distinct unswid)
from all_stream_enrolments
where name = 'Chemistry' and year=2011 and term='S1' and stype='local'
;

create or replace view Q5b(num)
as
select count(distinct unswid)
from all_program_enrolments
where unit='School of Computer Science and Engineering' and year=2011 and term='S1' and stype='intl'
;

--Q6:
create or replace function
    Q6(text) returns text
as
$$
select CONCAT(code, ' ', name, ' ', uoc) 
from Subjects s
where s.code = $1
$$ language sql
;

--Q7
create or replace view Program_total(pid,total)
as
select Program_enrolments.program,count(*)
from Program_enrolments
group by Program_enrolments.program
;

create or replace view Program_intl(pid,intl)
as
select Program_enrolments.program,count(*)
from Program_enrolments
	join Students on (Students.id=Program_enrolments.student)
where Students.stype='intl'
group by Program_enrolments.program
;

create or replace view Program_percent(pid,percent)
as
select Program_total.pid,(Program_intl.intl::float / Program_total.total::float)
from Program_intl
	join Program_total on (Program_intl.pid=Program_total.pid)
;

create or replace view Q7(code,name)
as
select Programs.code,Programs.name
from Programs
	join Program_percent on (Program_percent.pid=Programs.id)
where Program_percent.percent>0.5
;

--Q8
create or replace view Course_valid_student_num(id,num)
as 
select Course_enrolments.course,count (*)
from Course_enrolments
where Course_enrolments.mark is not null
group by Course_enrolments.course
;

create or replace view Qualified_course(id,num)
as 
select id,num
from Course_valid_student_num
where num >= 15
;

create or replace view Course_avg_mark(id,avg_mark)
as 
select Qualified_course.id,avg(mark)
from Qualified_course
	join Course_enrolments on (Course_enrolments.course=Qualified_course.id)
group by Qualified_course.id
;

create or replace view Q8(code,name,semester)
as
select Subjects.code, Subjects.name, Semesters.name
from Courses
	join Subjects on (Subjects.id=Courses.subject)
	join Semesters on (Semesters.id=Courses.semester)
where Courses.id in (select id from Course_avg_mark where avg_mark=(select max(avg_mark) from Course_avg_mark))
;

-- Q9:
create or replace view Q9_head(id, name, school, email, starting)
as
select p.id, p.name, u.longname, p.email, a.starting
from   people p
         join affiliations a on (a.staff=p.id)
         join staff_roles r on (a.role = r.id)
         join orgunits u on (a.orgunit = u.id)
         join orgunit_types t on (u.utype = t.id)
where  r.name = 'Head of School'
         and (a.ending is null or a.ending > now()::date)
         and t.name = 'School' 
         and a.isPrimary
;

create or replace view Q9(name, school, email, starting, num_subjects)
as
select h.name, h.school, h.email, h.starting, count(distinct s.code)
from   Q9_head h
         join course_staff cs on (h.id=cs.staff)
         join courses c on (cs.course = c.id)
         join subjects s on (c.subject = s.id)
group by h.id, h.name, h.school, h.email, h.starting
;

-- Q10:
create or replace view Q10_CourseInfo(id, code, name, year, term, courseId)
as
select sub.id, sub.code, sub.name, sem.year, sem.term, c.id
from   subjects sub, courses c, semesters sem
where  sub.id = c.subject
and c.semester = sem.id
;

create or replace view Q10_MajorSemesters(year, term)
as
select distinct semesters.year, semesters.term
from   courses, semesters
where courses.semester = semesters.id
and  (semesters.year between 2003 and 2012) 
and semesters.term like 'S%'
;


create or replace view Q10_GoodSubjects(id, code, name, year, term, courseId)
as
select *
from   Q10_CourseInfo c
where  c.code like 'COMP93%'
    and not exists(
        (select year,term from Q10_MajorSemesters)
        except
        (select year,term from Q10_CourseInfo where code = c.code)
        )
;


create or replace view Q10(code, name, year, s1_HD_rate, s2_HD_rate)
as
select code, name, year,
       (s1npass::float / s1n::float)::numeric(4,2),
       (s2npass::float / s2n::float)::numeric(4,2)
from ( select code, name, substr(year::text,3,2) as year,
              sum(case when term='S1' and mark >= 85 then 1 else 0 end) as s1npass,
              sum(case when term='S1' then 1 else 0 end) as s1n,
              sum(case when term='S2' and mark >= 85 then 1 else 0 end) as s2npass,
              sum(case when term='S2' then 1 else 0 end) as s2n
       from ( select s.code, s.name, ce.mark, s.year, s.term
              from Q10_GoodSubjects s 
                join course_enrolments ce on (s.courseId=ce.course)
                where ce.mark >= 0
            ) as A
       group by code, name, year
     ) as B
    order by code, year
;