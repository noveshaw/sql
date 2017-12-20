USE [msdb]
GO

/****** Object:  StoredProcedure [dbo].[Sp_Attendance_MailSend]    Script Date: 12/20/2017 23:22:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[Sp_Attendance_MailSend]
As
	Declare	@msg Varchar(Max);

	Declare	@mailAddr Varchar(100);


--邮件内容数据字段
	Declare	@code Varchar(20)
	  , @name Varchar(50)
	  , @dept Varchar(100)
	  , @fdate Varchar(20)
	  , @extype varchar(20)
	  , @sbtime varchar(10)
	  , @xbtime varchar(10)

	Declare	@template Varchar(Max);
	declare @tips varchar(max);
	Declare	@partmsg Varchar(Max);

	Select	@template = '<html><header></header><body>{{CONTENT}}{{TIPS}}</body></html>';
	Select	@tips = '<p>考勤数据可能存在延迟，如有请假等流程审批，请及时处理完毕！';


--查询出要发送的资料
Select	x.Code,x.Name,x.mail, x.DeptName,x.fdate,x.ExType,x.b1sbtime,x.b1xbtime
into #tbl
From	( Select	Code = E.code
				  , Name = E.name
				  , mail = E.G_mail
				  , DeptName = D.Name
				  , fdate = Convert(Varchar(10) , Q.FDate , 120)
				  , ExType = Case When Q.ChiDaoCs > 0 Then '迟到'
								  When Q.ZaoTuiCs > 0 Then '早退'
								  When Q.KgCs > 0 Then '旷工'
								  Else ''
							 End
				  , b1sbtime = Case	When B1SbTime = 0 Then ''
									Else Case When B1SbTime >= 24 * 60 Then 'T' + Convert(Varchar(5) , DateAdd(Minute , B1SbTime , Q.FDate) , 108)
											  Else Convert(Varchar(5) , DateAdd(Minute , B1SbTime , Q.FDate) , 108)
										 End
							   End
				  , b1xbtime = Case	When B1XbTime = 0 Then ''
									Else Case When B1XbTime >= 24 * 60 Then 'T' + Convert(Varchar(5) , DateAdd(Minute , B1XbTime , Q.FDate) , 108)
											  Else Convert(Varchar(5) , DateAdd(Minute , B1XbTime , Q.FDate) , 108)
										 End
							   End
		  From		( Select	EmpID
							  , FDate = FDate
							  , B1SbTime = Sum(IsNull(B1SbTime , 0))
							  , B1XbTime = Sum(IsNull(B1XbTime , 0))
							  , ChiDaoSj = Sum(IsNull(ChiDaoSj , 0))
							  , ChiDaoCs = Sum(IsNull(ChiDaoCs , 0))
							  , ZaoTuiSj = Sum(IsNull(ZaoTuiSj , 0))
							  , ZaoTuiCs = Sum(IsNull(ZaoTuiCs , 0))
							  , KgSj = Sum(IsNull(KgSj , 0))
							  , KgCs = Sum(IsNull(KgCs , 0))
							  , YcqSj = Sum(IsNull(YcqSj , 0))
							  , SjcqSj = Sum(IsNull(SjcqSj , 0))
					  From		TxCard..Kq_Result Q
					  Where		Q.FDate Between DATEADD(DAY,-30,GETDATE()) And DATEADD(day,-1,getdate())
								And ( ChiDaoCs > 0
									  Or ZaoTuiCs > 0
									  Or KgCs > 0
									  Or KgCs_cd > 0
									  Or KgCs_zt > 0 )
					  Group By	EmpID
							  , FDate
					) As Q
					Inner Join TxCard..Zlemployee E On Q.EmpID = E.ID
													   And E.G_etype = 'Indirect WC'
					Inner Join TxCard..ZlDept D On E.Dept = D.Code
		  Union
		  Select	Code = e.code
				  , Name = e.name
				  , mail = t.G_mail
				  , DeptName = D.Name
				  , fdate = Convert(Varchar(10) , Q.FDate , 120)
				  , ExType = Case When Q.ChiDaoCs > 0 Then '迟到'
								  When Q.ZaoTuiCs > 0 Then '早退'
								  When Q.KgCs > 0 Then '旷工'
								  Else ''
							 End
				  , b1sbtime = Case	When B1SbTime = 0 Then ''
									Else Case When B1SbTime >= 24 * 60 Then 'T' + Convert(Varchar(5) , DateAdd(Minute , B1SbTime , Q.FDate) , 108)
											  Else Convert(Varchar(5) , DateAdd(Minute , B1SbTime , Q.FDate) , 108)
										 End
							   End
				  , b1xbtime = Case	When B1XbTime = 0 Then ''
									Else Case When B1XbTime >= 24 * 60 Then 'T' + Convert(Varchar(5) , DateAdd(Minute , B1XbTime , Q.FDate) , 108)
											  Else Convert(Varchar(5) , DateAdd(Minute , B1XbTime , Q.FDate) , 108)
										 End
							   End
		  From		( Select	EmpID
							  , FDate = FDate
							  , B1SbTime = Sum(IsNull(B1SbTime , 0))
							  , B1XbTime = Sum(IsNull(B1XbTime , 0))
							  , ChiDaoSj = Sum(IsNull(ChiDaoSj , 0))
							  , ChiDaoCs = Sum(IsNull(ChiDaoCs , 0))
							  , ZaoTuiSj = Sum(IsNull(ZaoTuiSj , 0))
							  , ZaoTuiCs = Sum(IsNull(ZaoTuiCs , 0))
							  , KgSj = Sum(IsNull(KgSj , 0))
							  , KgCs = Sum(IsNull(KgCs , 0))
							  , YcqSj = Sum(IsNull(YcqSj , 0))
							  , SjcqSj = Sum(IsNull(SjcqSj , 0))
					  From		TxCard..Kq_Result Q
					  Where		Q.FDate Between DATEADD(DAY,-30,GETDATE()) And DATEADD(day,-1,getdate())
								And ( ChiDaoCs > 0
									  Or ZaoTuiCs > 0
									  Or KgCs > 0
									  Or KgCs_cd > 0
									  Or KgCs_zt > 0 )
					  Group By	EmpID
							  , FDate
					) As Q
					Inner Join TxCard..Zlemployee e On Q.EmpID = e.ID
													   And e.G_etype In ( 'Direct BC' , 'Indirect BC' )
					Inner Join ( Select	e.G_mail
									  , c.QxDept
								 From	TxCard..Zlemployee e
										Join TxCard..Czy c On e.ID = c.EmpID
															  And IsNull(c.QxDept , '') <> ''
															  And IsNull(e.g_mail , '') <> ''
															  And IsNull(e.G_isAsst , '') = '是'
							   ) t On Len(Replace(',' + t.QxDept + ',' , ',' + e.Dept + ',' , '')) <> Len(',' + t.QxDept + ',')
					Inner Join TxCard..ZlDept D On e.Dept = D.Code
		) x
Order By x.Code
	  , x.fdate;
--查询邮件列表
	Select	distinct mail
	Into	#addr
	From	#tbl
	Where	mail Is Not Null
			Or mail = '';


--按邮件列表循环要发送的数据
	Declare cur_mail Cursor
	For
		Select	mail
		From	#addr;

	Open cur_mail;
	Fetch Next From cur_mail Into @mailAddr;

	While @@fetch_status = 0
		Begin
			Set @partmsg = '<table><tr><th>工号</th><th>姓名</th><th>部门</th><th>日期</th><th>异常类型</th><th>上班时间</th><th>下班时间</th></tr>';
			Declare cur_data Cursor
			For
				Select	code,name,deptname,fdate,extype,b1xbtime,b1xbtime
				From	#tbl
				Where	IsNull(mail , '') = @mailAddr;
			Open cur_data;
			Fetch Next From cur_data Into @code , @name , @dept , @fdate , @extype , @sbtime , @xbtime;
			While @@fetch_status = 0
				Begin 
					Select	@partmsg=@partmsg + '<tr>' + '<td>' + ISNULL(@code,'') + '</td>' + '<td>' +ISNULL(@name,'') + '</td>' + '<td>' + ISNULL(@dept,'') + '</td>' + '<td>' + ISNULL(@fdate,'') + '</td>'
							+ '<td>' + isnull(@extype,'') + '</td>' + '<td>' + isnull(@sbtime,'') + '</td>' + '<td>' + isnull(@xbtime,'') + '</td>' + '</tr>';
					Fetch Next From cur_data Into  @code , @name , @dept , @fdate , @extype , @sbtime , @xbtime;
				End;
		
		
			Close cur_data;
			Deallocate cur_data;
		
			Select	@partmsg = @partmsg + '</table>';
		
			
			Select	@msg = Replace(@template , '{{CONTENT}}' , @partmsg);
			Select	@msg = Replace(@msg , '{{TIPS}}' , @tips);

			Begin Try
				Exec sp_send_dbmail @profile_name = 'HRMail' , --配置文件名称
					@recipients = @mailAddr , @subject = '[系统提醒]考勤异常提醒' ,@body_format='HTML', @body = @msg;
				Fetch Next From cur_mail Into @mailAddr;
			End Try	
			Begin Catch
				Insert Into TxCard..Mail_log(code,logtime,error) Values(@code,GetDate(),Error_Message())
			End Catch;

	
		End;
	
	
	Close	cur_mail;
	Deallocate cur_mail;
	
if OBJECT_ID('#tbl')>0
	drop table #tbl
	
if OBJECT_ID('#addr')>0
	drop table #tbl

	



GO

