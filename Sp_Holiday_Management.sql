USE [TxCard]
GO

/****** Object:  StoredProcedure [dbo].[sp_holiday_management]    Script Date: 12/20/2017 23:19:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[sp_holiday_management]
--@parameter_name AS scalar_data_type ( = default_value ), ...
-- WITH ENCRYPTION, RECOMPILE, EXECUTE AS CALLER|SELF|OWNER| 'user_name'
as --年假计算
    begin
        if object_id('#empinfo') > 0
            drop table #empinfo;
    
    
    --declare @serviceYears int; 
        declare @firstDay datetime;
        declare @lastDay datetime;
    
        select  @firstDay = convert(datetime, cast(datepart(year, getdate()) as varchar(4)) + '-01-01', 120) ,
                @lastDay = convert(datetime, cast(datepart(year, getdate()) as varchar(4)) + '-12-31 23:59:59', 120);
        select  ID empid ,
                Code code ,
                @firstDay beginDate ,
                @lastDay endDate ,
                convert(datetime, isnull(G_wdate,getdate()), 120) workDate ,
                PyDate hireDate ,
                floor(datediff(day, convert(datetime, isnull(G_wdate,getdate()), 120), getdate()) / 365.0) totalYear
        into    #empinfo
        from    ZlEmployee
        where   State = 0; 
    
        alter table #empinfo add NjHoursByWorkDay int; --按国家规定的年假天数
        alter table #empinfo add NjHoursByHireDay int; --按公司规定的年假天数
        alter table #empinfo add NjHours int; --实际年假天数
        alter table #empinfo add ServiceYears int; -- 已在公司服务年份 按年统计
    
    
    
    --更新国家规定的年假天数
        update  #empinfo
        set     NjHoursByWorkDay = case when totalYear >= 20 then 15 * 8
                                        when totalYear >= 10 then 10 * 8
                                        when totalYear >= 1 then 5 * 8
                                        else 0
                                   end ,
                ServiceYears = datediff(year, hireDate, getdate());
    
    
    --更新当年入职的国家规定的年假天数（当年入职）        
        update  #empinfo
        set     NjHoursByWorkDay = round(NjHoursByWorkDay * datediff(day, hireDate, @lastDay) / 365, 0) ,
                ServiceYears = datediff(year, hireDate, getdate())
        where   datediff(year, hireDate, getdate()) = 0;
    
    
    --更新公司规定的年假天数（非当年入职）
        update  #empinfo
        set     NjHoursByHireDay = ( 12 + ServiceYears - 1 ) * 8 + round(datediff(day, hireDate,
                                                                                  convert(datetime, cast(datepart(year, hireDate) as varchar(4)) + '-12-31', 120))
                                                                         / 365.0 * 8, 0)
        from    #empinfo
        where   datediff(year, hireDate, getdate()) > 0;
    
    --更新公司规定的年假天数（当年入职）
        update  #empinfo
        set     NjHoursByHireDay = case when datepart(day, hireDate) <= 15 then ( 12 - datepart(month, hireDate) + 1 ) * 8
                                        else ( 12 - datepart(month, hireDate) ) * 8
                                   end
        from    #empinfo
        where   datediff(year, hireDate, getdate()) = 0;
    
    --更新实际应有年假
        update  #empinfo
        set     NjHours = case when NjHoursByWorkDay <= NjHoursByHireDay then NjHoursByHireDay
                               else NjHoursByWorkDay
                          end;
    
    --年假最多为18天 144小时
        update  #empinfo
        set     NjHours = case when isnull(NjHours, 0) > 144 then 144
                               else isnull(NjHours, 0)
                          end;
    
    
    --select * from #empinfo
    
    --更新到假期管控表
    --当期年假存在则更新
        update  dbo.Kq_HolidayMng
        set     HolidayType = 'G_nj' ,
                TotalHoliday = i.NjHours ,
                TotalDay = isnull(i.NjHours, 0) / 8.0,
                NjHoursLaw=ISNULL(i.NjHoursByWorkDay,0),
                NjDaysLaw=ISNULL(i.NjHoursByWorkDay,0)/8.0,
                NjHoursLaw_Rest=case when ISNULL(i.NjHoursByWorkDay,0)-ISNULL(HavedRest,0)<0 then 0 else ISNULL(i.NjHoursByWorkDay,0)-ISNULL(HavedRest,0) end
        from    dbo.Kq_HolidayMng k
                join #empinfo i on k.HolidayType = 'G_nj'
                                   and k.EmpID = i.empid
                                   and k.BeginDate = i.beginDate
                                   and isnull(k.Note, 'N') = 'N';
    --AND k.EndDate = i.endDate;
    
    --当期年假不存在则插入
        insert  dbo.Kq_HolidayMng
                ( EmpID ,
                  BeginDate ,
                  EndDate ,
                  HolidayType ,
                  TotalDay ,
                  TotalHoliday,
                  Rest,
                  RestDay,
                  NjHoursLaw,
                  NjDaysLaw,
                  NjHoursLaw_Rest )
                select  empid ,
                        beginDate ,
                        endDate ,
                        'G_nj' ,
                        isnull(NjHours, 0) / 8.0 ,
                        isnull(NjHours, 0),
                        ISNULL(njhours,0),
                        ISNULL(NjHours,0)/8.0,
                        ISNULL(i.NjHoursByWorkDay,0),
                        ISNULL(i.NjHoursByWorkDay,0)/8.0,
                        ISNULL(i.NjHoursByWorkDay,0)
                from    #empinfo i
                where   not exists ( select 1
                                     from   dbo.Kq_HolidayMng k
                                     where  k.EmpID = i.empid
                                            and k.BeginDate = i.beginDate
                      --AND k.EndDate = i.endDate
                                            and k.HolidayType = 'G_nj' );
    
    
    --更新剩余假期
    --已休假时数通过缺勤管理更新已休假期       

        update  dbo.Kq_HolidayMng
        set     Rest = isnull(k.TotalHoliday,0) - isnull(k.Havedrest,0) ,
                RestDay = (isnull(k.TotalHoliday,0) - isnull(k.Havedrest,0)) / 8.0
        from    Kq_HolidayMng k
        --        join ( select   EmpID ,
        --                        @firstDay firstDay ,
        --                        @lastDay lastDay ,
        --                        sum(isnull(G_njxs, 0)) Havedrest
        --               from     dbo.Kq_Result
        --               where    FDate between @firstDay and @lastDay
        --               group by EmpID
        --             ) n on k.EmpID = n.EmpID
        --                    and k.BeginDate = n.firstDay
        --                    and k.EndDate = n.lastDay;
    end;


/***********************************************************
--IWC调休计算，按考勤结果实际的加班数据转入调休
--G_ps 平时加班
--G_zm 周末加班
--G_jr 法定假日加班
*************************************************************/
    begin
        if object_id('#tx') > 0
            drop table #tx;
    
    --插入临时表
        select  EmpID ,
                FDate ,
                sum(isnull(G_ps, 0) + isnull(G_zm, 0) + isnull(G_jr, 0)) txxs
        into    #tx
        from    Kq_Result
        where   FDate between dateadd(day, -20, convert(datetime, getdate(), 120)) and getdate()  --处理近20天的考勤调休记录
                and EmpID in (
                select  ID
                from    ZlEmployee
                where   G_etype = 'Indirect WC'
                        and isnull(LzDate, getdate()) between dateadd(day, -10, convert(datetime, getdate(), 120))
                                                      and     getdate() )
                and ( isnull(G_ps, 0) > 0
                      or isnull(G_zm, 0) > 0
                      or isnull(G_jr, 0) > 0 )
        group by EmpID ,
                FDate;
    
    --插入IWC调休数据
    --存在则更新，不存在则插入，调休有效期90天
        update  dbo.Kq_HolidayMng
        set     HolidayType = 'G_txj' ,
                TotalHoliday = i.txxs ,
                TotalDay = isnull(i.txxs, 0) / 8.0
        from    dbo.Kq_HolidayMng k
                join #tx i on k.HolidayType = 'G_txj'
                              and k.EmpID = i.EmpID
                              and k.BeginDate = dateadd(day,1,i.FDate)
                              and isnull(k.Note, 'N') = 'N'; --通过备注栏位判断是否自动更新 N 更新   Y 不更新
    
        insert  dbo.Kq_HolidayMng
                ( EmpID ,
				  Auditing,
				  Czy,
                  BeginDate ,
                  EndDate ,
                  HolidayType ,
                  TotalDay ,
                  TotalHoliday,
                  Rest,
                  RestDay,
                  HavedDay,
                  HavedRest)
                select  EmpID ,
                        '系统生成',
                        '同鑫',
                        dateadd(day, 1, FDate) ,
                        dateadd(day, 91, FDate) ,
                        'G_txj' ,
                        isnull(txxs, 0) / 8.0 ,
                        isnull(txxs, 0),
                        isnull(txxs, 0),
                        ISNULL(txxs,0) / 8.0,
                        0,
                        0
                from    #tx i
                where   not exists ( select 1
                                     from   dbo.Kq_HolidayMng k
                                     where  k.EmpID = i.EmpID
                                            and k.BeginDate = dateadd(day,1,i.FDate)
                                            and k.HolidayType = 'G_txj' );
    
    ----更新已休调休时数和剩余调休时数
    --    update  dbo.Kq_HolidayMng
    --    set     HavedDay = n.Havedrest / 8.0 ,
    --            HavedRest = n.Havedrest ,
    --            Rest = k.TotalHoliday - n.Havedrest ,
    --            RestDay = k.TotalDay - n.Havedrest / 8.0
    --    from    Kq_HolidayMng k
    --            join ( select   EmpID ,
    --                            @firstDay firstDay ,
    --                            @lastDay lastDay ,
    --                            sum(isnull(G_txjxs, 0)) Havedrest
    --                   from     dbo.Kq_Result
    --                   where    FDate between @firstDay and @lastDay
    --                   group by EmpID
    --                 ) n on k.EmpID = n.EmpID
    --                        and k.BeginDate = n.firstDay
    --                        and k.EndDate = n.lastDay;
    end;	

GO

