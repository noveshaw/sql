USE [TxCard]
GO

/****** Object:  StoredProcedure [dbo].[sp_holiday_calc]    Script Date: 12/20/2017 23:20:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--SET QUOTED_IDENTIFIER ON|OFF
--SET ANSI_NULLS ON|OFF
--GO

CREATE procedure [dbo].[sp_holiday_calc]
/*
	此存储过程由IIS attendCalc站点调用，参数不可调整
*/	@beginDate varchar(30) ,
	@endDate varchar(30) ,
	@hours varchar(10) ,
	@empCode varchar(10) ,
	@typeID varchar(10)    --T9假期ID  年假 1  调休 10   哺乳假 5
as
	declare	@date0 datetime;
	declare	@date1 datetime;
	declare	@hour float;
	declare	@canused float;
	declare	@id int;    --假期管控id 年假为id， 调休为统计可调休记录笔数
	
	declare	@hoursInProcess float; --正在流程中的请假时数
  
       --返回变量
	declare	@errCode varchar(1) ,
		@message varchar(50) ,
		@holidaytype varchar(10) ,
		@restHours varchar(50) ,
		@havedHours varchar(10) ,
		@totalHours varchar(10);
	
	
	--获取正在流程中的请假时数
	select	@hoursInProcess = isnull(sum(a.TotalHour), 0)
	from	T9IMS..T_HR_Absence a
			join T9IMS..T_WF_Task t on convert(varchar(10), a.ID) = t.FormDataId
									   and t.Status != '1'
									   and a.EmpID = ( select	ID
													   from		Zlemployee
													   where	code = @empCode
													 )
									   and t.FlowCode in ( select	FlowCode
														   from		T9IMS..T_WF_Flow
														   where	CategoryCode = 'QJ01' )
			join T9IMS..T_HR_AbsenceType h on h.ID = a.TypeID
											  and a.AppStatus = '3'  --AppStatus  Remark	[0 否决]	[1已审核]	[2反审核]	[3 审核中]	[5 否决]	[6 作废]  
											  and h.ID = @typeID;

	

	
	--年假处理
	if isnull(@typeID, '') = '3'
		begin
			select	@date0 = convert(datetime, @beginDate, 120);
			select	@date1 = convert(datetime, @endDate, 120);
			select	@hour = convert(float, @hours);
	
			select	top 1 @id = ID ,
					@canused = isnull(Rest, 0)-isnull(@hoursInProcess,0)  --minus absence hours on processing
			from	Kq_HolidayMng
			where	@date0 between BeginDate and EndDate
					and @date1 between BeginDate and EndDate
					and getdate() between BeginDate and EndDate
					and HolidayType = ( select	AbsenceCode
										from	T9IMS..T_HR_AbsenceType
										where	ID = @typeID
									  )
					and EmpID = ( select	ID
								  from		Zlemployee
								  where		code = @empCode
											and State = 0
											and isnull(zzdate, convert(datetime, getdate(), 120)) <= getdate()
								);
       
       --根据假期管控id 判断是否有可休记录
       --返回字符串格式：errCode|message|type|restHours|havedHours|totalHours

			if isnull(@id, '') <> ''
				begin
					if ( @hours <= @canused )
						begin
							select	@errCode = '0' ,
									@message = 'ok' ,
									@holidaytype = HolidayType ,
									@restHours = convert(varchar(5),Rest-isnull(@hoursInProcess,0))+' <含法定:'+convert(varchar(5),case when ISNULL(NjHoursLaw_Rest,0)-@hoursInProcess<0 then 0 else ISNULL(NjHoursLaw_Rest,0)-@hoursInProcess end )+'H>' ,
									@havedHours = HavedRest+isnull(@hoursInProcess,0) ,
									@totalHours = TotalHoliday
							from	dbo.Kq_HolidayMng
							where	ID = @id
									and HolidayType = ( select	AbsenceCode
														from	T9IMS..T_HR_AbsenceType
														where	ID = @typeID
													  )
									and EmpID = ( select	ID
												  from		dbo.Zlemployee
												  where		code = @empCode
												);
						end;
					else
						begin
							select	@errCode = '1' ,
									@message = '请假时数超过当前剩余可休时数，无法申请' ,
									@holidaytype = 'G_nj' ,
									@restHours = '0' ,
									@havedHours = '0' ,
									@totalHours = '0';
						end;
                                
				end;
			else
				begin
					select	@errCode = '1' ,
							@message = '当前请假时段内没有有效的可休时数' ,
							@holidaytype = 'G_nj' ,
							@restHours = '0' ,
							@havedHours = '0' ,
							@totalHours = '0';

				end;
        
			select	@errCode + '|' + @message + '|' + isnull(@holidaytype, '') + '|' + isnull(@restHours, '') + '|' + isnull(@havedHours, '') + '|'
					+ isnull(@totalHours, '');
		end;
    
    --调休处理   
	if isnull(@typeID, '') = '10'
		begin
			select	@date0 = convert(datetime, @beginDate, 120);
			select	@date1 = convert(datetime, @endDate, 120);
			select	@hour = convert(float, @hours);
	
			select	@id = count(1) ,
					@canused = sum(Rest)-isnull(@hoursInProcess,0) ,
					@havedHours = sum(HavedRest)+isnull(@hoursInProcess,0) ,
					@totalHours = sum(TotalHoliday)
			from	Kq_HolidayMng
			where	@date0 between BeginDate and EndDate
					and @date1 between BeginDate and EndDate
					and getdate() between BeginDate and EndDate
					and Rest > 0
					and HolidayType = ( select	AbsenceCode
										from	T9IMS..T_HR_AbsenceType
										where	ID = @typeID
									  )
					and EmpID = ( select	ID
								  from		Zlemployee
								  where		code = @empCode
								);
							
			if isnull(@id, 0) > 0
				begin
					if ( @hours <= @canused )
						begin
							select	@errCode = '0' ,
									@message = 'ok' ,
									@holidaytype = 'G_txj' ,
									@restHours = @canused ,
									@havedHours = @havedHours ,
									@totalHours = @totalHours;
							--from	dbo.Kq_HolidayMng
							--where	ID = @id
							--		and HolidayType = ( select	AbsenceCode
							--							from	T9IMS..T_HR_AbsenceType
							--							where	ID = @typeID
							--						  )
							--		and EmpID = ( select	ID
							--					  from		dbo.ZlEmployee
							--					  where		Code = @empCode
							--					);
						end;
					else
						begin
							select	@errCode = '1' ,
									@message = '请假时数超过当前剩余可休时数，无法申请' ,
									@holidaytype = 'G_txj' ,
									@restHours = '0' ,
									@havedHours = '0' ,
									@totalHours = '0';
						end;
                                
				end;
			else
				begin
					select	@errCode = '0' ,
							@message = '当前请假时段内没有有效的可休时数' ,
							@holidaytype = 'G_txj' ,
							@restHours = '0' ,
							@havedHours = '0' ,
							@totalHours = '0';

				end;
        
			select	@errCode + '|' + @message + '|' + isnull(@holidaytype, '') + '|' + isnull(@restHours, '') + '|' + isnull(@havedHours, '') + '|'
					+ isnull(@totalHours, '');


		end; 
        
	if isnull(@typeID, '') = '5'
		begin
			select	@date0 = convert(datetime, @beginDate, 120);
			select	@date1 = convert(datetime, @endDate, 120);
			select	@hour = convert(float, @hours);
	
			select	@id = ID ,
					@canused = isnull(Rest, 0)-isnull(@hoursInProcess,0)
			from	Kq_HolidayMng
			where	@date0 between BeginDate and EndDate
					and @date1 between BeginDate and EndDate
					and getdate() between BeginDate and EndDate
					and HolidayType = ( select	AbsenceCode
										from	T9IMS..T_HR_AbsenceType
										where	ID = @typeID
									  )
					and EmpID = ( select	ID
								  from		Zlemployee
								  where		code = @empCode
								);
       
       --根据假期管控id 判断是否有可休记录
       --返回字符串格式：errCode|message|type|restHours|havedHours|totalHours

			if isnull(@id, '') <> ''
				begin
					if ( @hours <= @canused )
						begin
							select	@errCode = '0' ,
									@message = 'ok' ,
									@holidaytype = HolidayType ,
									@restHours = Rest-isnull(@hoursInProcess,0) ,
									@havedHours = HavedRest+isnull(@hoursInProcess,0) ,
									@totalHours = TotalHoliday
							from	dbo.Kq_HolidayMng
							where	ID = @id
									and HolidayType = ( select	AbsenceCode
														from	T9IMS..T_HR_AbsenceType
														where	ID = @typeID
													  )
									and EmpID = ( select	ID
												  from		dbo.Zlemployee
												  where		code = @empCode
												);
						end;
					else
						begin
							select	@errCode = '1' ,
									@message = '请假时数超过当前剩余可休时数，无法申请' ,
									@holidaytype = 'G_brj' ,
									@restHours = '0' ,
									@havedHours = '0' ,
									@totalHours = '0';
						end;
                                
				end;
			else
				begin
					select	@errCode = '0' ,
							@message = '当前请假时段内没有有效的可休时数' ,
							@holidaytype = 'G_brj' ,
							@restHours = '0' ,
							@havedHours = '0' ,
							@totalHours = '0';

				end;
        
			select	@errCode + '|' + @message + '|' + isnull(@holidaytype, '') + '|' + isnull(@restHours, '') + '|' + isnull(@havedHours, '') + '|'
					+ isnull(@totalHours, '');
	
		end;
	
	

GO

