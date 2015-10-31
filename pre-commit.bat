@echo off
setlocal
set SVN_BINDIR=C:/Program Files (x86)/VisualSVN Server/bin/
set REPOS=%1
set TXN=%2
rem check that logmessage contains at least 10 characters
svnlook log "%REPOS%" -t "%TXN%"| findstr "^\[BugID\:[0-9]*\]" > nul
endlocal
if %errorlevel% gtr 0 goto err
exit 0
:err
echo Your message should look like [BugID:XXX]XXXX. Commit aborted! Please enter again. 1>&2
exit 1