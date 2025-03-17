--use master;
--CREATE DATABASE Zomato_DB;


--creating the necessary tables
drop table if exists goldusers_signup;
CREATE TABLE goldusers_signup(userid integer,gold_signup_date date); 

INSERT INTO goldusers_signup(userid,gold_signup_date) 
 VALUES (1,'09-22-2017'),
(3,'04-21-2017');

drop table if exists users;
CREATE TABLE users(userid integer,signup_date date); 

INSERT INTO users(userid,signup_date) 
 VALUES (1,'09-02-2014'),
(2,'01-15-2015'),
(3,'04-11-2014');

drop table if exists sales;
CREATE TABLE sales(userid integer,created_date date,product_id integer); 

INSERT INTO sales(userid,created_date,product_id) 
 VALUES (1,'04-19-2017',2),
(3,'12-18-2019',1),
(2,'07-20-2020',3),
(1,'10-23-2019',2),
(1,'03-19-2018',3),
(3,'12-20-2016',2),
(1,'11-09-2016',1),
(1,'05-20-2016',3),
(2,'09-24-2017',1),
(1,'03-11-2017',2),
(1,'03-11-2016',1),
(3,'11-10-2016',1),
(3,'12-07-2017',2),
(3,'12-15-2016',2),
(2,'11-08-2017',2),
(2,'09-10-2018',3);


drop table if exists product;
CREATE TABLE product(product_id integer,product_name text,price integer); 

INSERT INTO product(product_id,product_name,price) 
 VALUES
(1,'p1',980),
(2,'p2',870),
(3,'p3',330);


select * from sales;
select * from product;
select * from goldusers_signup;
select * from users;







-- 1. What is the total amount each customer spent on zomato?

select userid, sum(price) total_amount_spent
from sales s join product p
on s.product_id = p.product_id
group by userid





-- 2. How many days has each customer visited zomato

select userid, count(Distinct created_date) as visited_days
from sales
group by userid





-- 3. What was the first product purchased by each customer?

select userid, product_id, created_date
from 
(
	select *,
		   (rank() over (partition by userid order by created_date)) as rnk
	from sales
) ranked_subquery
where rnk = 1


--another way of solving it
/*
select s.userid, 
	   product_id,
	   f.first_purchased_date
from sales s
inner join
( 
	select userid, min(created_date) first_purchased_date
	from sales
	group by userid
) f
on s.userid = f.userid and s.created_date = f.first_purchased_date
order by userid;
*/





-- 4. what is the most purchased item on the menu AND how many times was it purchased by each customer?

-- the most purchased item on the menu
select top 1 with ties product_id, count(product_id) purchase_count
from sales
group by product_id
order by purchase_count desc


-- how many times was it purchased by all customers
select userid, count(*) purchase_count_per_user
from sales 
where product_id =
(
	select top 1 product_id
	from sales
	group by product_id
	order by count(product_id) desc
	--from this subquery we knew that the most purchased product with product_id = 2
)
group by userid;





-- 5. which item was the most popular for each customer?

select * from
(
	select *, rank() over (partition by userid order by cnt desc) as rnk
	from 
	(
		select userid, product_id, count(*) cnt
		from sales
		group by userid, product_id
	) inner_subquery
) ranked_query
where rnk = 1





-- 6. which item was purchased first by the customer after they became a gold member?

select * from
(
	select 
		s.userid,
		product_id,
		created_date,
		gold_signup_date,
		rank() over (partition by s.userid order by created_date asc) as rnk
	from goldusers_signup gu 
	inner join sales s
	on gu.userid = s.userid and s.created_date >= gu.gold_signup_date
) ranked_query
where rnk = 1



-- 7. which item was purchased just before the customer became a member?

select * from
(
	select 
		s.userid,
		product_id,
		created_date,
		gold_signup_date,
		rank() over (partition by s.userid order by created_date desc) as rnk
	from goldusers_signup gu 
	inner join sales s
	on gu.userid = s.userid and s.created_date < gu.gold_signup_date
) ranked_query 
where rnk = 1



-- 8. what is the total orders and amount spent for each member before they became a member?

select userid, count(*) total_orders, sum(price) amount_spent
from
(
	select 
		s.userid,
		s.product_id,
		price
	from goldusers_signup gu 
	inner join sales s
	on gu.userid = s.userid and s.created_date < gu.gold_signup_date
	inner join product p
	on s.product_id = p.product_id
) pre_gold_member_subquery
group by userid





-- 9. If buying each product generates points for eg 5rs = 2 zomnato point and each product has different purchasing points:  
--	for (p1) 5rs = 1 zomato point ,
--	    (p2) 10rs = 5 zomato point and, >> (p2) 2rs = 1 zomato point
--	    (p3) 5rs = 1 Zomato point.
-- so by knowing this, calculate points collected by each customer and for which product most points have been given till now.

-- 9.1 the first part of the question >>  calculate points collected by each customer

select 
    s.userid,
    sum(
        case 
            when p.product_id = 1 then price / 5
            when p.product_id = 2 then price / 2
            when p.product_id = 3 then price / 5
        end
    ) as total_points
from sales s
inner join product p
    on s.product_id = p.product_id
group by s.userid;


-- 9.2 the second part of the question >> for which product most points have been given till now

select top 1
	s.product_id,
	sum(
		case
			when s.product_id = 1 then price / 5
			when s.product_id = 2 then price / 2
			when s.product_id = 3 then price / 5
		end 
	) as total_points_per_product
from sales s
INNER JOIN product p
ON s.product_id = p.product_id
group by s.product_id
order by total_points_per_product desc





--10. In the first one year after a customer joins the gold program (including their join date) irrespective
--of what the customer has purchased they earn 5 zomato points for every 10 rs spent 
--who earned more 1 or 3 and what was their points earnings in thier first yr?

select 
	s.userid,
	s.product_id,
	s.created_date,
	gu.gold_signup_date,
	price,
	price / 2 as zomato_points
from goldusers_signup gu 
inner join sales s
on gu.userid = s.userid 
and s.created_date >= gu.gold_signup_date 
and DATEDIFF(year, gu.gold_signup_date, s.created_date) <= 1
inner join product p
on s.product_id = p.product_id
order by zomato_points desc





-- 11. rank all the transactions of the customers
select * , rank() over (partition by userid order by created_date) as rnk
from sales





-- 12. rank all the transactions for each member whenever they are a zomato gold member and for every non gold member transction mark as na

select 
	s.* ,
	gold_signup_date,
	case
		when gold_signup_date is null then 'na'
		else cast(rank() over (partition by s.userid order by created_date desc) as varchar)
	end as rnk
from sales s
left join
goldusers_signup gu
on s.userid = gu.userid and s.created_date >= gu.gold_signup_date


