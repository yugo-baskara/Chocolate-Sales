-- ================ --
-- Create Raw Table --
-- ================ --

create table if not exists portofolio.chocolate_data_raw
(
Raw_id bigint unsigned not null auto_increment,
Sales_Person varchar (100) null,
Country varchar (70) null,
Product varchar (100) null,
Order_Date varchar (50) null,		-- raw date as string
Amount varchar (50) null,			-- raw amount with $ and commas
Boxes_Shipped varchar (50) null,
Source_File varchar (150) null,
Load_Timestamp timestamp not null default current_timestamp,
primary key (raw_id)
)
;



-- ======================= --
-- Loading Data Into Table --
-- ======================= --

load data infile
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Chocolate_Sales.csv'
into table
portofolio.chocolate_data_raw
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 lines
(
	Sales_Person,
	Country,
    Product,
    Order_Date,
    @Amount,
    Boxes_Shipped
)
set
	Amount = replace(replace(@Amount, '$', ''), ',', ''),
	source_file = 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Chocolate_Sales.csv'
;


-- ===================== --
-- Create Clean Database --
-- ===================== --

create table if not exists portofolio.chocolate_data_clean
(
	Sales_id bigint unsigned not null auto_increment,
    Raw_id bigint unsigned not null,
    Sales_Person varchar (100) not null,
	Country varchar (75) not null,
    Product varchar (100) not null,
    Order_Date date not null,
    Amount_USD decimal (12,2) not null,
    Boxes_Shipped int not null,
    Load_Timestamp timestamp not null default current_timestamp,
    primary key (Sales_id),
    key idx_clean_date (Order_Date),
    key idx_clean_country (Country),
    key idx_clean_product (Product),
    key idx_clean_sales_person (Sales_Person)
)
;


-- ============================= --
-- Loading Data Into Clean Table --
-- ============================= --

insert into portofolio.chocolate_data_clean
(
    Raw_id,
    Sales_Person,
	Country,
    Product,
    Order_Date,
    Amount_USD,
    Boxes_Shipped
)
select
	r.Raw_id,
    trim(r.Sales_Person) as Sales_Person,
	trim(r.Country) as Country,
    trim(r.Product) as Product,
    str_to_date(r.Order_Date, '%d/%m/%Y') as Order_Date,
    cast(r.Amount as decimal(12,2)) as Amount_USD,
    cast(r.Boxes_Shipped as signed) as Boxes_Shipped
from
	portofolio.chocolate_data_raw r
where
	r.Raw_id is not null
;


-- ================== --
-- Create Audit Table --
-- ================== --

create table if not exists portofolio.chocolate_data_audit
(
Audit_id bigint unsigned not null auto_increment,
Audit_ts timestamp not null default current_timestamp,
Check_Name varchar(100) not null,
status varchar(10) not null,		-- pass / fail
Metric_Value decimal(18,4) null,
Notes varchar(255) null,
primary key (Audit_id),
key idx_audit_ts (Audit_Ts)
)
;


-- ============================= --
-- Loading Data Into Audit Table --
-- ============================= --

insert into portofolio.chocolate_data_audit
(
	Check_Name,
    Status,
    Metric_Value,
    Notes
)
select
	'row_count_clean' as Check_Name,
    case when count(*) > 0 then 'PASS' else 'FAIL' end as status,
    count(*) as Metric_Value,
    'clean table row count' as Notes
from
	portofolio.chocolate_data_clean
;


insert into portofolio.chocolate_data_audit
(
Check_Name,
Status,
Metric_Value,
Notes
)
select
	'invalid_order_Date' as Check_Name,
case when
	sum(case when Order_Date is null then 1 else 0 end) = 0 then 'PASS' else 'FAIL' end,
	sum(case when Order_Date is null then 1 else 0 end),
    'null dates after parsing' as Notes
from
	portofolio.chocolate_data_clean
;


insert into portofolio.chocolate_data_audit
(
Check_Name,
Status,
Metric_Value,
Notes
)
select
	'negative_value' as Check_Name,
case when
	sum(case when Amount_USD < 0 or Boxes_Shipped < 0 then 1 else 0 end) = 0 then 'PASS' else 'FAIL' end,
    sum(case when Amount_USD < 0 or Boxes_Shipped < 0 then 1 else 0 end),
    'negative amount or boxes' as Notes
from
	portofolio.chocolate_data_clean
;


-- =============== --
-- Duplicate Check --
-- =============== --

select
	Sales_Person,
    Country,
    Product,
    Order_Date,
    Amount_USD,
    count(*) as Duplicate_Count
from
	portofolio.chocolate_data_clean
group by
	1,2,3,4,5
having count(*) > 1
;


-- ========= --
-- KPI Total --
-- ========= --

select
	count(*) as transaction,
    sum(Amount_USD) as Total_Revenue_USD,
    sum(Boxes_Shipped) as Total_Boxes,
    sum(Amount_USD) / nullif(sum(Boxes_Shipped),0) as Revenue_Per_Box
from
	portofolio.chocolate_data_clean
;


-- ============= --
-- Monthly Trend --
-- ============= --

select
	date_format(Order_Date, '%Y-%m-01') as Month_Start,
    sum(Amount_USD) as Revenue_USD
from
	portofolio.chocolate_data_clean
group by
	date_format(Order_Date, '%Y-%m-01')
order by
	Month_Start
;


-- =========== --
-- TOP Country --
-- =========== --

select
	Country,
    sum(Amount_USD) as Revenue_USD
from
	portofolio.chocolate_data_clean
group by
	Country
order by
	Revenue_USD desc
;


-- =========== --
-- TOP Product --
-- =========== --

select
	Product,
    sum(Amount_USD) as Revenue_USD
from
	portofolio.chocolate_data_clean
group by
	Product
order by
	Revenue_USD desc
;


-- ================ --
-- TOP Sales Person --
-- ================ --

select
	Sales_Person,
    sum(Amount_USD) as Revenue_USD
from
	portofolio.chocolate_data_clean
group by
	Sales_Person
order by
	Revenue_USD desc
;


-- ============================ --
-- Sales Performance By Country --
-- ============================ --

select
	Sales_Person,
    Country,
    sum(Amount_USD) as Total_Sales,
    rank() over(partition by Country order by sum(Amount_USD) desc) as Sales_Rank
from
	portofolio.chocolate_data_clean
group by
	1,2
;


-- ============================= --
-- Sales Month Over Month Growth --
-- ============================= --

with Monthly_Sales as
(
select
	date_format(Order_Date, '%Y-%m-01') as Month_Period,
	sum(Amount_USD) as Revenue
from
	portofolio.chocolate_data_clean
group by
	1
)

select
	Month_Period,
    Revenue,
    lag(Revenue) over(order by Month_Period) as Last_Month_Revenue,
    round(((Revenue - lag(Revenue) over(order by Month_Period))
    / lag(Revenue) over(order by Month_Period) * 100), 2) as Growth_Percentage
from
	Monthly_Sales
;


-- ============ --
-- Indexing DDL --
-- ============ --

create index
	idx_clean_country_date
on
	portofolio.chocolate_data_clean(country, order_date)
;


-- ============================= --
-- Automation on Event Scheduler --
-- ============================= --

delimiter $$
	create procedure sp_refresh_chocolate_sales()
begin 
    start transaction; 

-- full refresh clean
truncate table portofolio.chocolate_data_clean;

insert into portofolio.chocolate_data_clean
(
Raw_id,
Sales_Person,
Country,
Product,
Order_Date,
Amount_USD,
Boxes_Shipped
)
select
	r.Raw_id,
	trim(r.Sales_Person),
    trim(r.Country),
    trim(r.Product),
    str_to_date(r.Order_Date, '%d/%m/%Y'),
    cast(r.Amount as decimal(12,2)),
    cast(r.Boxes_Shipped as signed)
from
	portofolio.chocolate_data_raw r  -- audit row count
;

insert into portofolio.chocolate_data_audit
(
Check_Name,
Status,
Metric_Value,
Notes
)
select
	'row_count_clean_after_refresh',
case when
	count(*) > 0 then 'PASS' else 'FAIL' end,
    count(*),
    'after sp_fresh'
from
	portofolio.chocolate_data_clean
;

commit;
end$$
delimiter ;


-- =============== --
-- Event Scheduler --
-- =============== --

set global event_scheduler = on;

create event if not exists ev_refresh_chocolate_daily
on schedule every 1 day
starts (timestamp(current_date) + interval 2 hour)
do
call sp_refresh_chocolate_sales()
;
