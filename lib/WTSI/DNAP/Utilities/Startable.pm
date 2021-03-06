package WTSI::DNAP::Utilities::Startable;

use strict;
use warnings;
use English qw(-no_match_vars);
use IPC::Run;
use Moose::Role;
use Try::Tiny;

our $VERSION = '';

with 'WTSI::DNAP::Utilities::Loggable', 'WTSI::DNAP::Utilities::Executable';

has 'started' =>
  (is      => 'rw',
   isa     => 'Bool',
   default => 0);

has 'harness' =>
  (is  => 'rw',
   isa => 'IPC::Run');

sub BUILD {
  my ($self) = @_;

  my @cmd = ($self->executable, @{$self->arguments});
  $self->harness(IPC::Run::harness(\@cmd,
                                   $self->stdin,
                                   $self->stdout,
                                   $self->stderr));
  return $self;
}

=head2 start

  Example    : WTSI::DNAP::Utilities::Startable->new
                   (executable => 'cat',
                    arguments  => ['-N'])->start
  Description: Starts the executable via its IPC::Run harness.
  Returntype : WTSI::DNAP::Utilities::Startable

=cut

sub start {
  my ($self) = @_;

  if ($self->started) {
    $self->logwarn($self->executable, " has started; cannot restart it");
    return $self;
  }

  my @cmd = ($self->executable, @{$self->arguments});
  my $command = join q{ }, @cmd;
  $self->debug("Starting '$command'");

  {
    local %ENV = %{$self->environment};
    IPC::Run::start($self->harness);
  }

  $self->started(1);

  return $self;
}

=head2 start

  Example    : $program->stop
  Description: Stops the executable via its IPC::Run harness.
  Returntype : WTSI::DNAP::Utilities::Startable

=cut

sub stop {
  my ($self) = @_;

  if (not $self->started) {
    $self->logconfess($self->executable, " has not started; cannot stop it");
    return $self;
  }

  my @cmd = ($self->executable, @{$self->arguments});
  my $command = join q{ }, @cmd;
  $self->debug("Stopping '$command'");

  my $harness = $self->harness;
  my $success;

  try {
    $success = $harness->finish;
  } catch {
    $harness->kill_kill;
    $self->error($_);
  } finally {
    $self->started(0);
  };

  if (not $success) {
    my $stderr = defined $self->stderr ? $self->stderr : q[];
    if (ref $stderr eq 'SCALAR') {
      $stderr = $$stderr;
    }

    $self->logconfess("Execution of '$command' exited with code ",
                      $harness->result, " and STDERR '$stderr'");
  }

  return $self;
}

sub DEMOLISH {
  my ($self, $in_global_destruction) = @_;

  # Only do try to stop cleanly if the object is not already being
  # destroyed by Perl (as indicated by the flag passed in by Moose).
  # Adding the in_global_destruction test resolved a bug where the
  # Perl process was hanging while trying to log the stop call.

  if (not $in_global_destruction and $self->started) {
    $self->stop;
  }

  return;
}

no Moose;

1;

__END__

=head1 NAME

WTSI::DNAP::Utilities::Startable

=head1 DESCRIPTION

An instance of this class enables an external program to be run (using
IPC::Run::start / IPC::Run::finish).

=head1 AUTHOR

Keith James <kdj@sanger.ac.uk>

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2013, 2014, 2015, 2016 Genome Research Limited. All
Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
