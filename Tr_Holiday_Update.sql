USE [TxCard]
GO

/****** Object:  Trigger [dbo].[tr_holiday_update]    Script Date: 12/20/2017 23:21:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE trigger [dbo].[tr_holiday_update] on [dbo].[Kq_Djqq]
	for insert
as
	begin
		set nocount on;
		--OA年假申请单审批完毕后更新假期管控表剩余时数
		if exists ( select	1
					from	Inserted i
					where	i.QqType = 'G_nj' )
			begin
				update	dbo.Kq_HolidayMng
				set		HavedRest = isnull(k.HavedRest, 0) + i.TotalHour ,
						HavedDay = ( isnull(k.HavedRest, 0) + i.TotalHour ) / 8.0 ,
						Rest = isnull(k.TotalHoliday, 0) - isnull(k.HavedRest, 0) - isnull(i.TotalHour, 0) ,
						RestDay = ( isnull(k.TotalHoliday, 0) - isnull(k.HavedRest, 0) - isnull(i.TotalHour, 0) ) / 8.0 ,
						OperateDate = getdate(),
						NjHoursLaw_Rest= case when isnull(k.NjHoursLaw,0)-isnull(k.HavedRest,0)-i.TotalHour>=0 then isnull(k.NjHoursLaw,0)-isnull(k.HavedRest,0)-i.TotalHour else 0 end,
						NjDaysLaw_Rest=case when isnull(k.NjHoursLaw,0)-isnull(k.HavedRest,0)-i.TotalHour>=0 then (isnull(k.NjHoursLaw,0)-isnull(k.HavedRest,0)-i.TotalHour) / 8.0 else 0 end
				from	dbo.Kq_HolidayMng k
						join Inserted i on k.EmpID = i.EmpID
										   and k.HolidayType = i.QqType
										   and i.QqType = 'G_nj'
										   and i.FDatetime0 between k.BeginDate and k.EndDate
										   and i.FDatetime1 between k.BeginDate and k.EndDate;
			end;
        
   		--OA调休申请单审批完毕后更新假期管控表剩余时数
		if exists ( select	1
					from	Inserted i
					where	i.QqType = 'G_txj' )
			begin
				declare	@approveHours decimal(18,2);
				declare	@existHours decimal(18,2);
				declare	@id int;
				declare	@count int;
				
				select	@approveHours = convert(decimal(18,2),TotalHour)
				from	Inserted;
				
				--查出所有有剩余时数的调休
				select	k.ID ,
						k.EmpID ,
						k.BeginDate ,
						k.EndDate ,
						k.TotalHoliday ,
						k.Rest ,
						k.HavedRest ,
						'0' flag
				into	#txTemp
				from	dbo.Kq_HolidayMng k
						join Inserted i on k.EmpID = i.EmpID
										   and k.TotalHoliday > k.HavedRest
										   and k.HolidayType = i.QqType
										   and i.QqType = 'G_txj'
										   and k.BeginDate <= i.FDatetime0
										   and k.EndDate >= i.FDatetime1
				order by k.BeginDate;
				
				select	@count = count(1)
				from	#txTemp;
				
				--循环更新剩余调休假列表
				while @count > 0
					and @approveHours > 0
					begin
						select	@existHours = convert(decimal(18,2),Rest) ,
								@id = ID
						from	#txTemp
						where	BeginDate = ( select	min(BeginDate)
									   from		#txTemp
									   where	flag = '0'
									 );
						if @existHours >= @approveHours
							begin
								update	#txTemp
								set		Rest = Rest - @approveHours ,
										HavedRest = HavedRest + @approveHours ,
										flag = '1'
								where	ID = @id;
								set @count = 0;
								set @approveHours = 0;
							end;
						else
							begin
								update	#txTemp
								set		Rest = 0 ,
										HavedRest = TotalHoliday ,
										flag = '1'
								where	ID = @id;
                                
								set @count = @count - 1;
								set @approveHours = @approveHours - @existHours;
                                
							end;
					end;
                    
                    --更新#txTemp数据到kq_HolidayMng
				update	dbo.Kq_HolidayMng
				set		Rest = t.Rest ,
						RestDay = t.Rest / 8.0 ,
						HavedRest = t.HavedRest ,
						HavedDay = t.HavedRest / 8.0 ,
						OperateDate = getdate()
				from	dbo.Kq_HolidayMng k
						join #txTemp t on k.EmpID = t.EmpID
										  and t.flag = '1'
										  and k.ID = t.ID
										  and k.HolidayType = 'G_txj';         
                    
				
			end;
		
		--OA哺乳假申请单审批完毕后更新假期管控表剩余时数
		if exists ( select	1
					from	Inserted i
					where	i.QqType = 'G_brj' )
			begin
				update	dbo.Kq_HolidayMng
				set		HavedRest = isnull(k.HavedRest, 0) + i.TotalHour ,
						HavedDay = ( isnull(k.HavedRest, 0) + i.TotalHour ) / 8.0 ,
						Rest = isnull(k.TotalHoliday, 0) - isnull(k.HavedRest, 0) - isnull(i.TotalHour, 0) ,
						RestDay = ( isnull(k.TotalHoliday, 0) - isnull(k.HavedRest, 0) - isnull(i.TotalHour, 0) ) / 8.0 ,
						OperateDate = getdate()
				from	dbo.Kq_HolidayMng k
						join Inserted i on k.EmpID = i.EmpID
										   and k.HolidayType = i.QqType
										   and i.QqType = 'G_brj'
										   and i.FDatetime0 between k.BeginDate and k.EndDate
										   and i.FDatetime1 between k.BeginDate and k.EndDate;
			end;


		if object_id('#txTemp') > 0
			drop table #txTemp;
	end;

GO

