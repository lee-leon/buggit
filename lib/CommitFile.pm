package Bugzilla::Extension::Svndiy::CommitFile;
use strict;
use base qw(Bugzilla::Object);

use Bugzilla::Error;
use Bugzilla::Util qw(detaint_natural);

use constant DB_TABLE => 'vcs_commit_file';

use constant DB_COLUMNS => qw(
    added
    commit_id
    id
    name
    removed
);

use constant VALIDATORS => {
    added     => \&_check_int,
    removed   => \&_check_int,
    name      => \&_check_required,
};

use constant REQUIRED_CREATE_FIELDS => qw(name);

####################
# Simple Accessors #
####################

sub added   { $_[0]->{added}   }
sub removed { $_[0]->{removed} }

##############
# Validators #
##############

sub _check_int {
    my ($invocant, $value, $field) = @_;
    my $original_value = $value;

    detaint_natural($value)
        || ThrowCodeError('param_must_be_numeric',
                          { function => "$invocant->create",
                            param => "$field: $original_value" });
    return $value;
}

sub _check_required {
    my ($invocant, $value, $field) = @_;
    if (!$value) {
        ThrowCodeError('param_required',
                       { function => "$invocant->create",
                         param => $field });
    }
    return $value;
}

1;
