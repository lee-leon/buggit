#!/usr/bin/perl -w
use strict;
use utf8;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw(dirname);
use File::Spec;
use HTTP::Cookies;
use XMLRPC::Lite;
use Encode qw/from_to/;

my $help;
my $Bugzilla_uri;
my $Bugzilla_login;
my $Bugzilla_password;
my $Bugzilla_remember;
my $bug_id;
my $bug_rev;
my $bug_repo;
my $revision;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

GetOptions('help|h|?'       => \$help,
           'uri=s'          => \$Bugzilla_uri,
           'login:s'        => \$Bugzilla_login,
           'password=s'     => \$Bugzilla_password,
           'rememberlogin!' => \$Bugzilla_remember,
           'bug_id:s'       => \$bug_id,
           'bug_rev:s'      => \$bug_rev,
           'bug_repo:s'     => \$bug_repo
          ) or pod2usage({'-verbose' => 0, '-exitval' => 1});
  
$bug_repo = qx(echo $bug_repo | sed 's[\:Repositories[\:\/Repositories\/[g');
my $bug_revision = qx(svnlook changed -r $bug_rev $bug_repo);
$bug_revision =~ s/\n/ \| /g;
my $bug_revno ="Rev.".$bug_rev;
my $bug_commit_time = qx(svnlook date -r $bug_rev $bug_repo);
$bug_commit_time =~ s/\+.*//;
my $bug_author = qx(svnlook author -r $bug_rev $bug_repo);
my $bug_message = qx(svnlook log -r $bug_rev $bug_repo);
$bug_message =~ s/\[.*\]//;
my $bug_project = qx(svnlook dirs-changed -r $bug_rev $bug_repo);
$bug_project =~ s/\n.*//g;
$bug_project ="/".$bug_project;
my $bug_uuid = qx(svnlook uuid $bug_repo);
my $bug_vci = "VCI field";
my $bug_type = "Type";

my @file_changed = ();
my @line_added = ();
my @line_removed = ();
my $i = 0;
my @rev_changed = qx(svnlook diff -r $bug_rev $bug_repo);
$bug_repo =~ s/D\:\/Repositories/https\:\/\/192\.168\.3\.15\/svn/g;   # Repositories in URL format
foreach (@rev_changed)
{
if ($_ =~ m/Added|Modified|Deleted/) 
  {
  $file_changed[$i] = $_;
  $line_added[$i] = 0;
  $line_removed[$i] = 0;
  $i++;
  }
if ($_ =~ m/^\+\+\+|^\-\-\-/)
  {
   next;
  }
if ($_ =~ m/^\+/)
  {
  $line_added[$i-1]++;
  }
if ($_ =~ m/^\-/)
  {
  $line_removed[$i-1]++;
  }
}

=head1 OPTIONS

=over

=item --help, -h, -?

Print a short help message and exit.

=item --uri

URI to Bugzilla's C<xmlrpc.cgi> script, along the lines of
C<http://your.bugzilla.installation/path/to/bugzilla/xmlrpc.cgi>.

=item --login

Bugzilla login name. Specify this together with B<--password> in order to log in.

Specify this without a value in order to log out.

=item --password

Bugzilla password. Specify this together with B<--login> in order to log in.

=item --rememberlogin

Gives access to Bugzilla's  ugzilla_remember option.
Specify this option while logging in to do the same thing as ticking the
C<Bugzilla_remember> box on Bugilla's log in form.
Don't specify this option to do the same thing as unchecking the box.

See Bugzilla's rememberlogin parameter for details.

=item --bug_id

Pass a bug ID to have C<svn_bug.pl> do some bug-related test calls.

=item --rev_svn

Pass a revision number to update into the database.

=back

=head1 DESCRIPTION
=cut

pod2usage({'-verbose' => 1, '-exitval' => 0}) if $help;
_syntaxhelp('URI unspecified') unless $Bugzilla_uri;

# We will use this variable for SOAP call results.
my $soapresult;
my $result;


my $cookie_jar =
    new HTTP::Cookies('file' => File::Spec->catdir(dirname($0), 'cookies.txt'),
                      'autosave' => 1);
my $proxy = XMLRPC::Lite->proxy($Bugzilla_uri,
                                'cookie_jar' => $cookie_jar);
                                                                  
if ($bug_id && $bug_revno) {
    $soapresult = $proxy->call('Bug.get', { login => $Bugzilla_login,
                                            password => $Bugzilla_password,
                                            remember => $Bugzilla_remember,
                                            ids => [$bug_id]});
    _die_on_fault($soapresult);
    $result = $soapresult->result;
    my $bug = $result->{bugs}->[0];
    my $rev_db = $$bug{cf_revision};
    $revision = $rev_db." ".$bug_revno;
  $soapresult = $proxy->call('Bug.update',{ login => $Bugzilla_login,
                                              password => $Bugzilla_password,
                                              remember => $Bugzilla_remember,
                                              ids => [$bug_id],
                                              cf_revision => [$revision]});
    _die_on_fault($soapresult);
}

$soapresult = $proxy->call('Svndiy.update_cvs',{ login => $Bugzilla_login,
												  password => $Bugzilla_password,
												  remember => $Bugzilla_remember,
												  ids => [$bug_id],
												  revision => [$bug_revision],  
												  revno => [$bug_revno],
												  commit_time => [$bug_commit_time],
												  author => [$bug_author],
												  message => [$bug_message],
												  project => [$bug_project],
												  repo => [$bug_repo],
												  type => [$bug_type],
												  uuid => [$bug_uuid],
												  vci => [$bug_vci]});
_die_on_fault($soapresult);

$i = 0;
foreach (@file_changed)
{
$soapresult = $proxy->call('Svndiy.update_cvs_file',{ login => $Bugzilla_login,
													 password => $Bugzilla_password,
												     remember => $Bugzilla_remember,
												     revno => [$bug_revno],
												     name => [$file_changed[$i]],
												     added => [$line_added[$i]],
												     removed => [$line_removed[$i]]});
_die_on_fault($soapresult);
$i++;
}

sub _die_on_fault {
    my $soapresult = shift;

    if ($soapresult->fault) {
        my ($package, $filename, $line) = caller;
        die $soapresult->faultcode . ' ' . $soapresult->faultstring .
            " in SOAP call near $filename line $line.\n";
    }
}

sub _syntaxhelp {
    my $msg = shift;

    print "Error: $msg\n";
    pod2usage({'-verbose' => 0, '-exitval' => 1});
}
