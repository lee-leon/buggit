:: begin of post-commit.bat
 
@echo off

rem Add path to Cygwin if it was not be added
set path=%path%;D:\leon_dir\cygwin\bin

setlocal

SET REPOS=%1
SET REV=%2
::SET REPOS="D:\Repositories\Documentation"
::SET REV=162


SET PREFIX=REV.
SET LOG_FILE=%TEMP%.\svn.log

svnlook log -r %REV% %REPOS% | grep 'BugID:'| sed 's/.*\[//g' |sed 's/\].*//g'|sed 's/.*\://g'>%LOG_FILE%
for /f %%i in (%LOG_FILE%) do SET BUG_ID=%%i

bash.exe --login -i -c "perl /home/Administrator/hook.pl --uri=http://bz.123go.net.cn/xmlrpc.cgi  --login=leon@tpages.com --password=123456 --rememberlogin --bug_id=%BUG_ID% --bug_repo=%REPOS% --bug_rev=%REV%"


:: end of post-commit.bat