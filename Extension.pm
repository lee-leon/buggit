package Bugzilla::Extension::Svndiy;
use strict;
use base qw(Bugzilla::Extension);
use Data::Dumper;

# This code for this is in /go1978/bugzilla/extensions/Svndiy/lib/Util.pm


use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Group;
use Bugzilla::User;
use Bugzilla::User::Setting;
use Bugzilla::Status qw(is_open_state);
use Bugzilla::Install::Filesystem;

use Bugzilla::Bug;
use Bugzilla::Install::Util qw(install_string);
use Bugzilla::Util qw(diff_arrays html_quote);


use Bugzilla::Extension::Svndiy::Util;

our $VERSION = '1.0';

BEGIN{ *Bugzilla::Bug::vcs_commits = \&_bug_vcs_commits; }



# See the documentation of Bugzilla::Hook ("perldoc Bugzilla::Hook" 
# in the bugzilla directory) for a list of all available hooks.
sub db_schema_abstract_schema {
    my ($class, $args) = @_;
    my $schema = $args->{schema};
    $schema->{vcs_commit} = {
        FIELDS => [
            id          => {TYPE => 'MEDIUMSERIAL', NOTNULL => 1,
                            PRIMARYKEY => 1},
            bug_id      => {TYPE => 'INT3', NOTNULL => 1,
                            REFERENCES => {TABLE  => 'bugs',
                                           COLUMN => 'bug_id',
                                           DELETE => 'CASCADE'}},
            revision   => {TYPE => 'varchar(255)', NOTNULL => 1},
            creator     => {TYPE => 'INT3', NOTNULL => 1,
                            REFERENCES => {TABLE  => 'profiles',
                                           COLUMN => 'userid'}},
            revno       => {TYPE => 'varchar(255)', NOTNULL => 1},
            commit_time => {TYPE => 'DATETIME', NOTNULL => 1},
            author      => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            message     => {TYPE => 'LONGTEXT', NOTNULL => 1},
            project     => {TYPE => 'varchar(255)', NOTNULL => 1},
            repo        => {TYPE => 'varchar(255)', NOTNULL => 1},
            type        => {TYPE => 'varchar(16)',  NOTNULL => 1},
            uuid        => {TYPE => 'varchar(255)', NOTNULL => 1},
            vci         => {TYPE => 'varchar(10)',  NOTNULL => 1},
        ],
        INDEXES => [
            vcs_commit_bug_id_idx => ['bug_id'],
            vcs_commit_time_idx   => ['commit_time'],
            vcs_commit_revno_idx   => {
                FIELDS => [qw(revno bug_id)], TYPE => 'UNIQUE' },
        ],
    };
    
    $schema->{vcs_commit_file} = {
        FIELDS => [
            id        => {TYPE => 'INTSERIAL', NOTNULL => 1, PRIMARYKEY => 1},
            commit_id => {TYPE => 'INT3', NOTNULL => 1,
                          REFERENCES => {TABLE  => 'vcs_commit',
                                         COLUMN => 'id',
                                         DELETE => 'CASCADE'}},
            name      => {TYPE => 'MEDIUMTEXT', NOTNULL => 1},
            added     => {TYPE => 'INT3', NOTNULL => 1},
            removed   => {TYPE => 'INT3', NOTNULL => 1},
        ],
    };
}

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;
    
    my $field = new Bugzilla::Field({ name => 'vcs_commits' });
    if (!$field) {
        Bugzilla::Field->create({
            name => 'vcs_commits', description => 'Commits',
        });
    }
    
    $dbh->bz_add_column('vcs_commit', 'vci',
                        {TYPE => 'varchar(10)',  NOTNULL => 1}, "VCI");
 #   _add_uuid_column();
    $dbh->bz_drop_index('vcs_commit', 'vcs_commit_revision_idx');
}

sub install_before_final_checks {
    my ($self, $args) = @_;
    print "Install-before_final_checks hook\n" unless $args->{silent};
    
    # Add a new user setting like this:
    #
    # add_setting('product_chooser',           # setting name
    #             ['pretty', 'full', 'small'], # options
    #             'pretty');                   # default
    #
    # To add descriptions for the setting and choices, add extra values to 
    # the hash defined in global/setting-descs.none.tmpl. Do this in a hook: 
    # hook/global/setting-descs-settings.none.tmpl .
}

sub _bug_vcs_commits {
    my ($self) = @_;
    require Bugzilla::Extension::Svndiy::Commit;
    $self->{vcs_commits} ||= Bugzilla::Extension::Svndiy::Commit->match(
                                 { bug_id => $self->id });
    return $self->{vcs_commits};
}

sub template_before_create {

    my ($self, $args) = @_;
    my $variables = $args->{config}->{VARIABLES};
    $variables->{vcs_commit_link} = \&_create_commit_link;
    
    my $filters = $args->{config}->{FILTERS};
    my $html_filter = $filters->{html};
    $filters->{vcs_br} = \&_filter_br;

}

sub _create_commit_link {
    my ($commit) = @_;
    
    my $web_view = Bugzilla->params->{'vcs_web'};
    my $web_url;
    foreach my $line (split "\n", $web_view) {
        $line = trim($line);
        next if !$line;
        my ($repo, $url) = split(/\s+/, $line, 2);
        if (lc($repo) eq lc($commit->repo)) {
            $web_url = $url;
            last;
        }
    }
   
    my $revno = html_quote($commit->revno);
    return $revno if !$web_url;
    
    # We don't url_quote the replacements because they might be used
    # in the URL path in an important way (like with %project%).
    my @replace_fields = ($web_url =~ /\%(.+?)\%/g);
    foreach my $field (@replace_fields) {
        my $value = $commit->$field;
        $web_url =~ s/\%\Q$field\E\%/$value/g;
    }
    $web_url = html_quote($web_url);
    return "<a class=\"vcs_commit_link\" href=\"$web_url\">$revno</a>";
}

sub _filter_br {
    my ($value) = @_;
    $value =~ s/\r//g;
    $value =~ s/\s+$//sg;
    $value =~ s/\n/<br>/sg;
    return $value;
}

sub webservice {
    my ($self, $args) = @_;

    my $dispatch = $args->{dispatch};
    $dispatch->{Svndiy} = "Bugzilla::Extension::Svndiy::WebService";
}

sub webservice_error_codes {
    my ($self, $args) = @_;
    
    my $error_map = $args->{error_map};
    $error_map->{'example_my_error'} = 10001;
}

__PACKAGE__->NAME;