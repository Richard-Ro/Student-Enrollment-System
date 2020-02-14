set echo on
set serveroutput on
spool e:setup.txt

create or replace package ENROLL is

procedure proc_validate_snum(
p_snum IN students.snum%type,
p_errortxt OUT varchar2);

Function func_validate_callnum(
p_callnum schclasses.callnum%type)
return varchar2;

Function func_capacity(
p_callnum schclasses.callnum%type)
return varchar2;

procedure proc_validate_15credits(
p_snum IN enrollments.snum%type,
p_callnum IN schclasses.callnum%type,
p_errortxt OUT varchar2);

procedure proc_undeclared_major(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
P_errortxt OUT varchar2);

procedure proc_repeat_enrollment(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
P_errortxt OUT varchar2);

procedure proc_double_enrollment(
p_snum IN students.snum%type,
P_callnum IN enrollments.callnum%type,
p_errortxt OUT varchar2);

procedure proc_standing_requirement(
p_snum IN enrollments.snum%type,
p_callnum IN enrollments.callnum%type,
p_errortxt OUT varchar2);

procedure already_graded(
p_snum IN enrollments.snum%type,
p_callnum IN enrollments.callnum%type,
p_errortxt OUT varchar2); 

procedure proc_waitlist(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
p_errormsg OUT varchar2);

procedure not_enrolled(
p_snum IN enrollments.snum%type,
p_callnum IN enrollments.callnum%type,
p_errortxt OUT varchar2);

procedure AddMe(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
p_errormsg OUT varchar2);

procedure DropMe(
p_snum IN enrollments.snum%type,
p_callnum IN enrollments.callnum%type); 

END ENROLL;
/




/* Body */

CREATE or REPLACE package body ENROLL is

procedure proc_validate_snum(
p_snum IN students.snum%type,
p_errortxt OUT varchar2) AS
v_count number(3);

BEGIN
     Select count(*) into v_count
     from students
     where snum = p_snum;
     
     IF v_count = 0 THEN
       p_errortxt:= 'Sorry, '||p_snum||' is not valid. ';
     END IF;
END;

Function func_validate_callnum(
p_callnum schclasses.callnum%type)
return varchar2 AS
v_count number (3);

BEGIN
     Select count(*) into v_count
     from schclasses
     where callnum = p_callnum;

     IF v_count = 0 THEN
      return 'Sorry, '||p_callnum||' is not valid ';

     ELSE
      return NULL;
     END IF;
END;

procedure proc_undeclared_major(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
P_errortxt OUT varchar2) AS
v_stand number(1);
v_count number(3);

BEGIN
	Select standing into v_stand
	from students 
	where snum = p_snum;

	Select count(*) into v_count
	from students 
	where major is NULL
	and snum = p_snum
	and standing = 3 
	OR standing = 4;

	IF v_count != 0  THEN
	p_errortxt:= 'Sorry, students standing is '||v_stand|| ' and must declare major';
     	END IF;
END;	



Function func_capacity(
p_callnum schclasses.callnum%type)
return varchar2 AS
v_snum number(3);
v_cap number(3);

BEGIN
	Select capacity into v_cap
	from schclasses sch
	where p_callnum = sch.callnum;

	Select count(*) into v_snum
	from enrollments e
	where grade is null 
	and e.callnum = p_callnum;

	IF v_snum < v_cap THEN
	 return null;
	ELSE
	 return 'Sorry, the class capacity has been reached ';
	END IF;
END;


procedure proc_repeat_enrollment(
p_snum IN students.snum%type,
p_callnum IN enrollments.callnum%type,
P_errortxt OUT varchar2) AS
v_count number(3);

BEGIN

     Select count(*) into v_count
     from enrollments
     where snum = p_snum
     and callnum = p_callnum;

     IF v_count != 0 THEN
	p_errortxt:= 'Sorry, student '||p_snum||' is already enrolled in '||p_callnum||' and cannot be enrolled again ';
     END IF;
END;	


procedure proc_double_enrollment(
p_snum IN students.snum%type,
P_callnum IN enrollments.callnum%type,
p_errortxt OUT varchar2) AS
v_count number(3);
v_sct number(3);
v_cnum schclasses.cnum%type;
v_dpt schclasses.dept%type;

BEGIN
     Select cnum, dept into v_cnum, v_dpt
     from schclasses
     where callnum = p_callnum;


    Select count(*) into v_count
    from enrollments e, schclasses sch
    where e.callnum = sch.callnum
    and cnum = v_cnum
    and snum = p_snum
    and dept = v_dpt;
 
    IF v_count !=0 THEN
	p_errortxt:= 'Sorry, Student cannot be enrolled in other sections of the same course. ';
    END IF;
END;

procedure proc_validate_15credits(
p_snum  enrollments.snum%type,
p_callnum schclasses.callnum%type,
p_errortxt OUT varchar2) AS
v_credhr number(3);
v_count number (3);

BEGIN
	Select crhr into v_count
	from courses c, schclasses sch
	where sch.cnum = c.cnum
	and sch.callnum = p_callnum
	and sch.dept = c.dept;

	Select nvl(sum(crhr),0) into v_credhr
	from courses c, enrollments e, schclasses sch
	where e.callnum = sch.callnum
	and sch.dept = c.dept
	and e.snum = p_snum
	and grade is null
	and sch.cnum = c.cnum;
	IF v_credhr + v_count <= 15 THEN
	 p_errortxt := null;
	ELSE
	 p_errortxt:= 'Sorry, the number of units has already been reached. ';
	END IF;
END;


procedure proc_standing_requirement(
p_snum enrollments.snum%type,
p_callnum enrollments.callnum%type,
p_errortxt OUT varchar2) AS
v_dpt schclasses.dept%type;
v_cnum schclasses.cnum%type;
v_stand number(1);
v_call_stand number(1);

BEGIN

	Select standing into v_stand
	from students
	where snum = p_snum;
	Select c.cnum,standing, c.dept into v_cnum, v_call_stand, v_dpt
	from schclasses sch, courses c
	where c.cnum = sch.cnum
	and c.dept = sch.dept
	and sch.callnum = p_callnum;
	IF v_stand < v_call_stand THEN
	 p_errortxt:= 'Sorry, Student does not meet the standing requirement. ';
	END IF;
END;

procedure proc_waitlist(
p_snum students.snum%type,
p_callnum enrollments.callnum%type,
p_errormsg OUT varchar2)AS
v_count number(3);
v_errortxt varchar2(999);

BEGIN
	Select count(*) into v_count
	from waitlist
	where p_callnum = callnum
	and p_snum = snum;
	IF v_count != 0 THEN
	 p_errormsg:= 'Student is waitlisted';
	END IF;
END;


procedure already_graded(
p_snum enrollments.snum%type,
p_callnum enrollments.callnum%type,
p_errortxt OUT varchar2) AS
v_studentgrade enrollments.grade%type;

BEGIN

	Select grade into v_studentgrade
	from enrollments e
	where p_snum = snum
	and p_callnum = callnum;
	IF v_studentgrade is not NULL THEN
	 p_errortxt:='Student has already received a grade';
	END IF;
END;


procedure not_enrolled(
p_snum enrollments.snum%type,
p_callnum enrollments.callnum%type,
p_errortxt OUT varchar2) as
v_count number(8);
BEGIN
    select count(*) into v_count
    from enrollments
    where p_callnum = callnum
    and p_snum = snum;
    if v_count = 0 then
      p_errortxt := 'Sorry, the student is not enrolled';
    end if;
END;

procedure AddMe(
p_snum students.snum%type,
p_callnum enrollments.callnum%type,
p_errormsg OUT varchar2) AS
v_count number(3);
v_sec number(3);
v_cnum varchar2(99);
v_dpt varchar2(99);
v_errortxt varchar2(9999);

BEGIN
    
    proc_validate_snum(p_snum, v_errortxt);
    p_errormsg:=v_errortxt;
   
    v_errortxt:=func_validate_callnum(p_callnum);
    p_errormsg:=p_errormsg || v_errortxt;
    IF p_errormsg is null THEN
      
      select c.dept, c.cnum, sch.section into v_dpt, v_cnum, v_sec
      from courses c, schclasses sch
      where p_callnum = callnum
      and sch.dept = c.dept
      and sch.cnum = c.cnum;
      
      proc_repeat_enrollment(p_snum, p_callnum, v_errortxt);
      p_errormsg:=p_errormsg || v_errortxt;
     
      IF p_errormsg is null then      
        proc_double_enrollment(p_snum, p_callnum, v_errortxt);
        p_errormsg:=p_errormsg || v_errortxt;
      END IF;
      
      proc_standing_requirement(p_snum, p_callnum, v_errortxt);
      p_errormsg:=p_errormsg || v_errortxt;
      
      proc_undeclared_major(p_snum, p_callnum, v_errortxt);
      p_errormsg:=p_errormsg || v_errortxt;

      proc_validate_15credits(p_snum, p_callnum, v_errortxt);
      p_errormsg:=p_errormsg || v_errortxt;
      IF p_errormsg is null THEN
       
        v_errortxt:=func_capacity(p_callnum);
        p_errormsg:=p_errormsg || v_errortxt;
        IF p_errormsg is null then
          insert into enrollments values(p_snum, p_callnum, null);
          dbms_output.put_line('Congrats, you are now enrolled in class.');
          commit;
        ELSE
          proc_waitlist(p_snum, p_callnum, v_errortxt);
          p_errormsg:=v_errortxt;
          IF p_errormsg is null then
            INSERT into waitlist values(p_snum, p_callnum, sysdate);        
            commit;
            dbms_output.put_line('Sorry the class  is already full.');
          else
            dbms_output.put_line('Student is already on waitlist');
          end if;
        	end if;
     		 else
        	 dbms_output.put_line(p_errormsg);
      		 end if;
    			else
      			dbms_output.put_line(p_errormsg);
    			end if;
END;


procedure DropMe(
p_snum enrollments.snum%type,
p_callnum enrollments.callnum%type) AS
v_errormsg varchar2(999);
v_errortxt varchar2(999);
v_count number(3);

CURSOR cwaitlist is
Select * from waitlist
where p_callnum = callnum
ORDER BY requesttime;

BEGIN

proc_validate_snum(p_snum,v_errortxt);
v_errormsg:= v_errortxt;
v_errortxt:= func_validate_callnum(p_callnum);
v_errormsg:= v_errortxt;
	IF v_errormsg is null THEN 
	   not_enrolled(p_snum, p_callnum, v_errortxt);
	   v_errormsg:= v_errortxt;
	  IF v_errormsg is null THEN
	     already_graded(p_snum,p_callnum,v_errortxt);
	     v_errormsg:= v_errortxt;
		IF v_errormsg is null THEN
		 dbms_output.put_line('Student has successfully dropped a class and has received a W');
		 update enrollments
	         set grade = 'W'
		 where p_callnum = callnum
		 and p_snum = snum;
		 commit;

	Select count(*) into v_count
	from waitlist
	where p_callnum = callnum;
	
	IF v_count != 0 THEN
	FOR student in cwaitlist LOOP
	proc_standing_requirement(student.snum,student.callnum,v_errortxt);
	v_errormsg:= v_errortxt;
	proc_double_enrollment(student.snum,student.callnum,v_errortxt);
	v_errormsg:= v_errortxt;
	proc_validate_15credits(student.snum,student.callnum,v_errortxt);
	v_errormsg:= v_errortxt;
	IF v_errormsg is null THEN
	INSERT into enrollments values(student.snum,student.callnum,null);
	commit;
	DELETE from waitlist
	where snum = student.snum
	and callnum = student.callnum;
	commit;
	exit;
	END IF;
	END LOOP;
	END IF;
	ELSE
	 dbms_output.put_line(v_errormsg);
	END IF;
	 ELSE
	   dbms_output.put_line(v_errormsg);
	  END IF;
	    ELSE
	      dbms_output.put_line(v_errormsg);
	       END IF;
END;
END ENROLL;
/
spool off


/* show compiling errors and pause */
show err
Pause