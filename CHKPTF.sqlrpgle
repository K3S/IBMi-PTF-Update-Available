      //***********************************************************
      //*
      //*   Name: MK_CHKPTF --  Check for PTF updates
      //*   Type: Embedded SQL RPG program
      //*   Desc: Check SYSTOOLS.GROUP_PTF_CURRENCY
      //*   Auth: Thomas Reynolds
      //*
      //***********************************************************
      /FREE
       Ctl-Opt DFTACTGRP(*NO)
               ACTGRP(*NEW)
               BNDDIR('QC2LE');

       Dcl-C EMADDR   'king4@k3s.com';
       Dcl-C FNAME    '/home/TOM/ptfupd.txt';
       Dcl-C F_OK            0;
       Dcl-DS File_Temp Qualified Template;
         PathFile  CHAR(128);
         RtvData   CHAR(256);
         OpenMode  CHAR(5);
         FilePtr   POINTER INZ;
       END-DS;

       Dcl-DS PTFupdFile LikeDS(File_Temp);

       Dcl-PR Cmd Int(10) ExtProc('system');
                cmdstring Pointer Value Options(*String);
       END-PR;

       Dcl-s errmsgid CHAR(7) Import('_EXCP_MSGID');

       Dcl-PR access Int(10) ExtProc('access');
               path     Pointer Value Options(*String);
               amode    INT(10) Value;
       END-PR;

       Dcl-PR unlink Int(10) ExtProc('unlink');
               path     Pointer Value Options(*String);
       END-PR;

       Dcl-PR OpenFile POINTER ExtProc('_C_IFS_fopen');
         fname   POINTER VALUE;
         fmode   POINTER VALUE;
       END-PR;

       Dcl-PR WriteFile POINTER ExtProc('_C_IFS_fwrite');
         wdata   POINTER VALUE;
         dsize   INT(10) VALUE;
         bsize   INT(10) VALUE;
         mptr    POINTER VALUE;
       END-PR;

       Dcl-PR CloseFile ExtProc('_C_IFS_fclose');
         mptr    POINTER VALUE;
       END-PR;

       Dcl-DS PTFINF  Qualified;
                CRNCY   VARCHAR(46);
                TITLE   VARCHAR(1000);
                SYSST   VARCHAR(20);
                SYSLVL  INT(10);
                IBMLVL  INT(10);
       END-DS;

       Dcl-PR printf Int(10) ExtProc('printf');
         format Pointer Value Options(*String);
       END-PR;


      //**********************************************************
      //* Change the character code for the job to 37
      //**********************************************************
       IF (Cmd('CHGJOB CCSID(037)') = 1);
         printf('Error : ' + errmsgid + x'25');
       ENDIF;
      // Declare a cursor for the result set determined by the select
       EXEC SQL DECLARE PTF_Cur CURSOR FOR
           SELECT ptf_group_currency,
                  ptf_group_title,
                  ptf_group_status_on_system,
                  ptf_group_level_installed,
                  ptf_group_level_available
             FROM systools.group_ptf_currency
            WHERE ptf_group_currency = 'UPDATE AVAILABLE'
         ORDER BY ptf_group_level_available - ptf_group_level_installed DESC;
      // Open the cursor
       EXEC SQL Open PTF_Cur;

       IF (SQLSTATE = '00000');
      // Fetch the data and store it in the DS PTFINF
          EXEC SQL Fetch PTF_cur
                   INTO :PTFINF.CRNCY,
                        :PTFINF.TITLE,
                        :PTFINF.SYSST,
                        :PTFINF.SYSLVL,
                        :PTFINF.IBMLVL;

       // As long as no errors occur, Write the data to file
          DOW (SQLSTATE = '00000');
            WriteData(FNAME
                     :PTFINF.CRNCY
                     :PTFINF.TITLE
                     :PTFINF.SYSST);

       // Print the Title to the terminal, mostly for debugging
              Print(%TRIM(PTFINF.TITLE));
              Print('>' + x'20' + %TRIM(PTFINF.CRNCY));
              Print('>' + x'20' + %TRIM(PTFINF.SYSST));
       // Get the next row, repeat
              EXEC SQL Fetch PTF_cur
                       INTO :PTFINF.CRNCY,
                            :PTFINF.TITLE,
                            :PTFINF.SYSST,
                            :PTFINF.SYSLVL,
                            :PTFINF.IBMLVL;
          ENDDO;
       ENDIF;
      // Close the cursor
       EXEC SQL Close PTF_Cur;

         SendUpdate(EMADDR);
         RemoveFile(FNAME);

       *InLr = *On;
       Return;

      //***********************************************************
      //* Print a string: credit to Liam (WorksOfBarry)
      //***********************************************************
       Dcl-PROC Print;
         Dcl-PI Print;
           pValue CHAR(132) VALUE;
         END-PI;

         pValue = %TrimR(pValue) + x'25';   //Adds a line break
         printf(%Trim(pValue));

       END-PROC;
      //***********************************************************
      //* RemoveFile: delete a file if it exists, otherwise do nothing
      //***********************************************************
       Dcl-PROC RemoveFile;
         Dcl-PI RemoveFile;
           path CHAR(200) VALUE;
         END-PI;
         IF not (access(%TrimR(path):F_OK) < 0); // IF the file exists
             unlink(%TrimR(path));               // delete it
         ENDIF;
       END-PROC;
      //***********************************************************
      //* WriteData: write a date and time to a log file
      //***********************************************************
       Dcl-PROC WriteData;
         Dcl-PI WriteData;
            path    CHAR(200)  VALUE;
            CRNCY   CHAR(46)   VALUE;
            TITLE   CHAR(1000) VALUE;
            SYSST   CHAR(20)   VALUE;
         END-PI;

         Dcl-s Sep   CHAR(1) Inz(x'25');
         Dcl-s Arrow CHAR(2);

         Arrow = '>' + x'20';


         CRNCY  = %Trim(CRNCY);
         TITLE  = %Trim(TITLE);
         SYSST  = %Trim(SYSST);


         PTFupdFile.OpenMode = 'ab' +  x'00';
         PTFupdFile.PathFile = %Trim(path) + x'00';
         PTFupdFile.FilePtr  = OpenFile(%addr(PTFupdFile.PathFile)
                                       :%addr(PTFupdFile.OpenMode));

         WriteFile(%addr(TITLE)
                  :%Len(TITLE)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(Sep)
                  :%Len(Sep)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(Arrow)
                  :%Len(Arrow)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(CRNCY)
                  :%Len(CRNCY)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(Sep)
                  :%Len(Sep)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(Arrow)
                  :%Len(Arrow)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(SYSST)
                  :%Len(SYSST)
                  :1
                  :PTFupdFile.FilePtr);

         WriteFile(%addr(Sep)
                  :%Len(Sep)
                  :1
                  :PTFupdFile.FilePtr);

         CloseFile(PTFupdFile.FilePtr); // Close the file

       END-PROC;
      //***********************************************************
      //* SendAlert: send an email to the tech support email
      //***********************************************************
       Dcl-PROC SendUpdate;
         Dcl-PI SendUpdate;
           rcp  CHAR(128) VALUE;
         END-PI;
         Dcl-s email CHAR(500);


         IF (access(%TrimR(FNAME):F_OK) < 0); // IF the file doesn't exist
         Eval email = 'SNDSMTPEMM RCP((' + %Trim(rcp) + ' *PRI)) ' +
                       'SUBJECT(''' +
                      'No PTF Updates Available' + ''') NOTE(''' +
                      '<p>DATE: ' + %Char(%Date():*USA) +
                      '</p><p>TIME: ' + %Char(%Time():*USA) + '</p>' +
                      ''') CONTENT(*HTML)';
         ELSE;
         Eval email = 'SNDSMTPEMM RCP((' + %Trim(rcp) + ' *PRI)) ' +
                       'SUBJECT(''' +
                      'PTF Updates Available' + ''') NOTE(''' +
                      '<p>DATE: ' + %Char(%Date():*USA) +
                      '</p><p>TIME: ' + %Char(%Time():*USA) + '</p>' +
                      ''') CONTENT(*HTML)' +
                      ' ATTACH((''' + FNAME +  ''' *PLAIN *TXT))';
         ENDIF;

        IF (Cmd(email) = 1);
           Print('Email error: ' + errmsgid);
           Print('Email : ' + email);
        ENDIF;
       END-PROC;
      /END-FREE
 
