package Wengan::SSG::LG;

=head1 NAME

Wengan::SSG::LG

=head1 DESCRIPTION

This object call B<liger> to build the  Synthetic Scaffolding Graph,  compute approximate long-read Overlaps,
build an assembly Backbone, validate the assembly Backbone, build the Gap sequence and Polish the gap sequences.

=head2 Available methods


=cut

use strict;
use Wengan::Common::GlobalConfig qw(LIGER_BIN);

sub new{
  my ($packagename,%opts) = @_;

  if (!defined LIGER_BIN ){
		die "Liger binary not found\n";
	}

  #minimum variables for liger
  my $self = {contigs=>undef,lreads=>undef,dependency=>undef,pipeline=>$opts{a},cores=>$opts{t},prefix=>$opts{p}, preset=>$opts{x},opts=>\%opts};
  #we ask if the contigs are passed
  if(defined $opts{c}){
    $self->{contigs}=$opts{c};
  }
  bless ($self, $packagename);
  return ($self);
}

#methods for controling the dependencies between tools
sub set_init_dependency{
      my ($self,$dep)=@_;
      $self->{contigs}=@$dep[0];#contigs
      $self->{lreads}=@$dep[1];#fasta file from
      $self->{ccoverage}=@$dep[0];#file with contig coverage from short-reads
      $self->{ccoverage}=~s/.fa/.cov.txt/;
      push(@{$self->{dependency}},@{$dep});
}

sub has_dependency{
   return 1;
}

sub main_target{
     my $self=shift;
    return $self->{main_target};
}

#generic function is called from the WenganM pipeline
sub create_jobs{
  my ($self,$reads)=@_;

  my $job=();
  #final assembly file produced by liger in fasta format
  push(@{$self->{main_target}},$self->{prefix}.".SPolished.asm.wengan.fasta");
  push(@{$job->{target}},$self->{prefix}.".SPolished.asm.wengan.fasta");
  push(@{$job->{deps}},@{$self->{dependency}});
  my @sams=@{$self->{dependency}}[2 .. (scalar(@{$self->{dependency}}) - 1)];
  my $c=1;
  my $param=$self->_def_parameters(undef);
  foreach my $s (@sams){
          my $insert=$s;
          #we get the insert size
          if($s=~m/\.I(\d+)\./){
            $insert=$1;
          }
          if($c == 1){
            push(@{$job->{cmds}},join(" ","\@echo",$s," > ",$self->{prefix}.".sams.txt"));
          }else{
            if($insert < $self->{maxgis}){
                push(@{$job->{cmds}},join(" ","\@echo",$s," >> ",$self->{prefix}.".sams.txt"));
              }else{
                push(@{$job->{cmds}},join(" ","\@echo \"$s	$insert\""," >> ",$self->{prefix}.".sams.txt"));
            }
          }
    $c++;
  }

  my @mopt=($param,
  "-t",$self->{cores},
  "-c ",$self->{contigs},
  "-l ",$self->{lreads},
  "-d",$self->{ccoverage},
  "-p",$self->{prefix},
  "-s",$self->{prefix}.".sams.txt",
  "2>".$self->{prefix}.".liger.err",
  ">".$self->{prefix}.".liger.log");
  #all done for the moment
  push(@{$job->{cmds}},join(" ",LIGER_BIN,@mopt));
  push(@{$self->{jobs}},$job);
}

#current parameters for liger
sub _def_parameters{
      my $self=shift;
      my  $param = "";
      #FastMin-SG presets
      if($self->{preset} eq "pacccs"){
           $param = (defined $self->{opts}->{M}) ? " --mcs ".$self->{opts}->{M}:" --mcs 1000";
           $param .= (defined $self->{opts}->{P}) ? " --mlp ".$self->{opts}->{P}:" --mlp 10000";
           $param .= (defined $self->{opts}->{N}) ? " --nlm ".$self->{opts}->{N}:"";
           $param .= (defined $self->{opts}->{L}) ? " --lme ".$self->{opts}->{L}:"";
           $param .= (defined $self->{opts}->{R}) ? " --rcn ".$self->{opts}->{R}:"";
           $self->{maxgis}=10000;#set the insert size that are not inferred 10% of the synthetic
      }elsif($self->{preset} eq "ontlon"){
         #$param = "--mlp 20000";
         $param = (defined $self->{opts}->{M}) ? " --mcs ".$self->{opts}->{M}:"";
         $param .= (defined $self->{opts}->{P}) ? " --mlp ".$self->{opts}->{P}:" --mlp 20000";
         $param .= (defined $self->{opts}->{N}) ? " --nlm ".$self->{opts}->{N}:"";
         $param .= (defined $self->{opts}->{L}) ? " --lme ".$self->{opts}->{L}:"";
         $param .= (defined $self->{opts}->{R}) ? " --rcn ".$self->{opts}->{R}:"";
         $self->{maxgis}=16000;
      }elsif($self->{preset} eq "pacraw"){
            #$param = "--mlp 10000";
            $param = (defined $self->{opts}->{M}) ? " --mcs ".$self->{opts}->{M}:"";
            $param .= (defined $self->{opts}->{P}) ? " --mlp ".$self->{opts}->{P}:" --mlp 10000";
            $param .= (defined $self->{opts}->{N}) ? " --nlm ".$self->{opts}->{N}:"";
            $param .= (defined $self->{opts}->{L}) ? " --lme ".$self->{opts}->{L}:"";
            $param .= (defined $self->{opts}->{R}) ? " --rcn ".$self->{opts}->{R}:"";
            $self->{maxgis}=8000;

      }elsif($self->{preset} eq "ontraw"){
        #$param = "--mlp 10000";
        $param = (defined $self->{opts}->{M}) ? " --mcs ".$self->{opts}->{M}:"";
        $param .= (defined $self->{opts}->{P}) ? " --mlp ".$self->{opts}->{P}:" --mlp 10000";
        $param .= (defined $self->{opts}->{N}) ? " --nlm ".$self->{opts}->{N}:"";
        $param .= (defined $self->{opts}->{L}) ? " --lme ".$self->{opts}->{L}:"";
        $param .= (defined $self->{opts}->{R}) ? " --rcn ".$self->{opts}->{R}:"";
        $self->{maxgis}=16000;

      }elsif($self->{preset} eq "pacraw" and $self->{pipeline} eq "M"){
            #$param = "--mlp 10000 --mcs 1000";
            $param = (defined $self->{opts}->{M}) ? " --mcs ".$self->{opts}->{M}:" --mcs 1000";
            $param .= (defined $self->{opts}->{P}) ? " --mlp ".$self->{opts}->{P}:" --mlp 10000";
            $param .= (defined $self->{opts}->{N}) ? " --nlm ".$self->{opts}->{N}:"";
            $param .= (defined $self->{opts}->{L}) ? " --lme ".$self->{opts}->{L}:"";
            $param .= (defined $self->{opts}->{R}) ? " --rcn ".$self->{opts}->{R}:"";
            $self->{maxgis}=7000;
      }

      return $param;
}

1;
