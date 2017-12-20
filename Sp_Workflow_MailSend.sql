USE [msdb]
GO

/****** Object:  StoredProcedure [dbo].[Sp_Workflow_MailSend]    Script Date: 12/20/2017 23:23:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[Sp_Workflow_MailSend]
As
	Declare	@msg Varchar(Max);

	Declare	@mailAddr Varchar(100);


--邮件内容数据字段
	Declare	@CategoryName Varchar(20)
	  , @CreateTime Varchar(50)
	  , @Creator Varchar(100)
	  , @TaskName Varchar(20);


	Declare	@template Varchar(Max);
	Declare	@partmsg Varchar(Max);
	Declare	@siteUrl Varchar(Max);

	Select	@template = '<html><header></header><body>{{CONTENT}}{{siteUrl}}</body></html>';
	Select	@siteUrl = '<p>系统登陆地址: http://10.221.1.62:8090</p>';

--查询出要发送的资料
	Select	CategoryName
		  , CreateTime
		  , Creator
		  , TaskName
		  , email
	Into	#tbl
	From	T9IMS..v_processinstance_notice;

--查询邮件列表
	Select	Distinct
			email
	Into	#addr
	From	#tbl
	Where	email Is Not Null
			Or email = '';


--按邮件列表循环要发送的数据
	Declare cur_mail Cursor
	For
		Select	email
		From	#addr;

	Open cur_mail;
	Fetch Next From cur_mail Into @mailAddr;

	While @@fetch_status = 0
		Begin
			Set @partmsg = '<table><tr><th>申请类型</th><th>申请时间</th><th>申请人</th><th>流程类别</th></tr>';
			Declare cur_data Cursor
			For
				Select	CategoryName
					  , CreateTime
					  , Creator
					  , TaskName
				From	T9IMS..v_processinstance_notice
				Where	IsNull(email , '') = @mailAddr;
			Open cur_data;
			Fetch Next From cur_data Into @CategoryName , @CreateTime , @Creator , @TaskName;
			While @@fetch_status = 0
				Begin 
					Select	@partmsg = @partmsg + '<tr>' + '<td>' + IsNull(@CategoryName , '') + '</td>' + '<td>' + IsNull(@CreateTime , '') + '</td>' + '<td>'
							+ IsNull(@Creator , '') + '</td>' + '<td>' + IsNull(@TaskName , '') + '</td>' + '</tr>';
					Fetch Next From cur_data Into @CategoryName , @CreateTime , @Creator , @TaskName;
				End;
		
		
			Close cur_data;
			Deallocate cur_data;
		
			Select	@partmsg = @partmsg + '</table>';
		
			
			Select	@msg = Replace(@template , '{{CONTENT}}' , @partmsg);
			Select	@msg = Replace(@msg , '{{siteUrl}}' , @siteUrl);
		
			Begin Try
				Exec sp_send_dbmail @profile_name = 'HRMail' , --配置文件名称
					@recipients = @mailAddr , @subject = '[系统提醒]您有待办事项需要审批,请及时处理' , @body_format = 'HTML' , @body = @msg;
		
				Fetch Next From cur_mail Into @mailAddr;
			End Try	
			Begin Catch
				Insert	Into TxCard..Mail_log
						( code
						, logtime
						, error )
				Values	( @CategoryName
						, GetDate()
						, Error_Message() );
			End Catch;

	
		End;
	
	
	Close	cur_mail;
	Deallocate cur_mail;
	
	
if OBJECT_ID('#tbl')>0
	drop table #tbl

if OBJECT_ID('#addr')>0
	drop table #tbl




GO

