=head1 NAME

Tails::IUK::UpgradeDescriptionFile::Download - download and verify an upgrade description file

=cut

package Tails::IUK::UpgradeDescriptionFile::Download;

no Moo::sification;
use Moo;
use MooX::HandlesVia;

use 5.10.1;
use strictures 2;

extends 'Tails::Download::HTTPS';

use autodie qw(:all);
use Carp;
use Carp::Assert;
use Carp::Assert::More;
use Function::Parameters;
use Path::Tiny;
use Tails::RunningSystem;
use Tails::IUK::Utils;
use Types::Standard qw{InstanceOf Str};
use Types::Path::Tiny qw{AbsDir};
use YAML::Any;

use namespace::clean;

use MooX::Options;

=head1 ATTRIBUTES

=cut

option "$_" => (
    is         => 'ro',
    format     => 's',
    isa        => Str,
    predicate  => 1,
) for (qw{override_baseurl override_build_target override_os_release_file
          override_initial_install_os_release_file});

option trusted_gnupg_homedir => (
    is         => 'lazy',
    format     => 's',
    isa        => AbsDir,
    coerce     => AbsDir->coercion,
    predicate  => 1,
);

has 'running_system' => (
    is      => 'lazy',
    isa     => InstanceOf['Tails::RunningSystem'],
    handles => [
        qw{upgrade_description_file_url upgrade_description_sig_url},
        qw{product_name initial_install_version build_target channel}
    ],
);


=head1 CONSTRUCTORS AND BUILDERS

=cut

method _build_trusted_gnupg_homedir () {
    my $trusted_gnupg_homedir = path('/var/lib/tails-upgrade-frontend/.gnupg');
    assert(-d $trusted_gnupg_homedir);
    return $trusted_gnupg_homedir;
}

method _build_running_system () {
    my @args;
    for (qw{baseurl build_target os_release_file initial_install_os_release_file}) {
        my $attribute = "override_$_";
        my $predicate = "has_$attribute";
        if ($self->$predicate) {
            push @args, ($_ => $self->$attribute)
        }
    }
    Tails::RunningSystem->new(@args);
}


=head1 METHODS

=cut

method matches_running_system (Str $description_str) {
    my $description = YAML::Any::Load($description_str);
    assert_hashref($description);
    foreach (qw{product_name initial_install_version build_target channel}) {
        my $accessor = my $field = $_;
        $field =~ s{_}{-}gxms;
        exists  $description->{$field}             or return;
        defined $description->{$field}             or return;
        if ($description->{$field} ne $self->$accessor) {
            warn "Expected for field $field: ", $self->$accessor, ", got: ", $description->{$field};
            return;
        }
    }
    return 1;
}

method run () {
    my $description = $self->get_url($self->upgrade_description_file_url);
    my $signature   = $self->get_url($self->upgrade_description_sig_url );

    verify_signature($description, $signature, $self->trusted_gnupg_homedir)
        or croak("Invalid signature");
    $self->matches_running_system($description)
        or croak("Does not match running system");
    print $description;
    return;
}

no Moo;
1;
