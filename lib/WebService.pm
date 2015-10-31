package Bugzilla::Extension::Svndiy::WebService;
use strict;
use warnings;
use base qw(Bugzilla::WebService);
use Bugzilla::Comment;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Field;
use Bugzilla::WebService::Constants;
use Bugzilla::WebService::Util qw(filter filter_wants validate);
use Bugzilla::Bug;
use Bugzilla::BugMail;
use Bugzilla::Util qw(trick_taint trim diff_arrays);
use Bugzilla::Version;
use Bugzilla::Milestone;
use Bugzilla::Status;
use Bugzilla::Token qw(issue_hash_token);
use Data::Dumper;
use Bugzilla::DB;
use utf8;
use Encode;
sub update_cvs{ 
	my ($self, $params) = validate(@_, 'ids');
	my $user = Bugzilla->login(LOGIN_REQUIRED);
	my $bug_ids = $params->{ids}[0];
	my $bug_author = $params->{author}[0];
	my $bug_revision = $params->{revision}[0];
	my $bug_revno = $params->{revno}[0];
	my $bug_commit_time = $params->{commit_time}[0];
	my $bug_message = $params->{message}[0];
	my $bug_project = $params->{project}[0];
	my $bug_repo= $params->{repo}[0];
	my $bug_type = $params->{type}[0];
	my $bug_uuid = $params->{uuid}[0];
	my $bug_vci = $params->{vci}[0];
	
	#Untaint $bug_author
	if ($bug_author =~ /^(.+)$/) {
  		$bug_author = $1;
	}
	if ($bug_ids =~ /^(.+)$/) {
  		$bug_ids = $1;
	}
	if ($bug_revision =~ /^(.+)$/) {
  		$bug_revision = $1;
	}
	if ($bug_revno =~ /^(.+)$/) {
  		$bug_revno = $1;
	}
	if ($bug_commit_time =~ /^(.+)$/) {
  		$bug_commit_time = $1;
	}
	if ($bug_message =~ /^(.+)$/) {
   		$bug_message = $1;
	}
	if ($bug_project =~ /^(.+)$/) {
   		$bug_project = $1;
	}	
	if ($bug_repo =~ /^(.+)$/) {
   		$bug_repo = $1;
	}	
	if ($bug_type =~ /^(.+)$/) {
   		$bug_type = $1;
	}	
	if ($bug_uuid =~ /^(.+)$/) {
   		$bug_uuid = $1;
	}	
	if ($bug_vci =~ /^(.+)$/) {
   		$bug_vci = $1;
	}	

	$bug_message = decode("utf-8", $bug_message);
	my $dbh = Bugzilla->dbh;
	my $sth = $dbh->prepare("SELECT userid from profiles where realname='$bug_author'");
	$sth->execute;
	my $bug_creator = $sth->fetchrow_array;
	if ($bug_creator =~ /^(.+)$/) {
  		$bug_creator = $1;
	}	
	my $sth1 = $dbh->prepare("insert into vcs_commit(bug_id, revision, creator, revno, commit_time, author, message, project, repo, type, uuid, vci) values ($bug_ids, '$bug_revision', $bug_creator, '$bug_revno', '$bug_commit_time', '$bug_author', '$bug_message', '$bug_project', '$bug_repo', '$bug_type', '$bug_uuid', '$bug_vci')");
	$sth1->execute;	
 }

sub update_cvs_file{ 
	my ($self, $params) = validate(@_, 'revno');
	my $user = Bugzilla->login(LOGIN_REQUIRED);
	my $bug_revno = $params->{revno}[0];
	my $bug_name = $params->{name}[0];
	my $bug_added = $params->{added}[0];
	my $bug_removed = $params->{removed}[0];
	
	
	#Untaint scalar
	if ($bug_revno =~ /^(.+)$/) {
   		$bug_revno = $1;
	}
	if ($bug_name =~ /^(.+)$/) {
   		$bug_name = $1;
	}	
	if ($bug_added =~ /^(.+)$/) {
   		$bug_added = $1;
	}	
	if ($bug_removed =~ /^(.+)$/) {
   		$bug_removed = $1;
	}	

	$bug_name = decode("utf-8", $bug_name);
	my $dbh = Bugzilla->dbh;
	my $sth = $dbh->prepare("select id from vcs_commit where revno='$bug_revno'");
	$sth->execute;
	my $vcs_id = $sth->fetchrow_array;
	if ($vcs_id =~ /^(.+)$/) {
  		$vcs_id = $1;
	}	
	my $sth1 = $dbh->prepare("insert into vcs_commit_file(commit_id, name, added, removed) values ($vcs_id, '$bug_name', $bug_added, $bug_removed)");
	$sth1->execute;
 }



 
 
sub throw_an_error { ThrowUserError('example_my_error') }

1;
