### This is the main script to process go-plus.obo file
### By Haiming Tang, modified 06/08/2018

#use strict;
#use warnings;
use 5.10.1;
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

my $goplusfile = "../rawData/go-plus.obo";

my %termName; # $TermName{$id} = $name 
my %alter; # $Alter{$alter_id} = $id
my %strictRelation; # strict relationships: is_a, part_of, occurs_in 
my %otherRelation; # 2 level, first level is from term type to term type
my %relationCount; # inlcuding counts of relationships, from term type to type, counts
my %termCount; # counts of each differnt type of terms

############# PARSE FROM GO-PLUS ###########################

my %termName; # $TermName{$id} = $name 
my %alter; # $Alter{$alter_id} = $id
my %strictRelation; # strict relationships: is_a, part_of, occurs_in 
my %otherRelation; # 2 level, first level is from term type to term type
my %relationCount; # inlcuding counts of relationships, from term type to type, counts
my %termType; # counts of each differnt type of terms

my $name;
my @goterm;
my $type;

open IN, "< $goplusfile" or die "cannot open $goplusfile\n";
while(<IN>){
    my $line = $_;
    chomp($line);
    
    if ($line =~ /\[Term\]/){
        if ($name){ 
            foreach my $goterm (@goterm){
                $termName{$goterm} = $name;
            }
        }
        @goterm = ();
    }
    
    elsif ($_ =~ /^id: (([A-Za-z]+):[0-9]+)/){
	$type = $2;
	$termType{$type} ++;
	push(@goterm,$1);
    }
    elsif ($_ =~ /name: (.*)/){
        $name = $1;
    }
    elsif ($_ =~ /alt_id: ([A-Za-z]:[0-9]+)/){
        $alter{$1} = $goterm[0];  # is the direction wrong??? CHECK LATER 
        push(@goterm,$1);
	$termType{$type}++;
    }
    elsif ($_ =~ /is_a:.* (([A-Za-z]+):[0-9]+)/){
        foreach my $goterm (@goterm){
	    my $relation = "is_a:$type:$2";
	    $strictRelation{$relation}{$goterm}{$1} =1;
	    $relationCount{$relation} ++;
        }
    }
    elsif ($line =~ /relationship: (\w+) (([A-Za-z]+):[0-9]+)/){
      my $relation = "$1:$type:$3";
      $relationCount{$relation}++;
            
      foreach my $goterm (@goterm){
	  if (($1 eq 'part_of') or ($1 eq 'occurs_in')){
	      $strictRelation{$relation}{$goterm}{$2} = 1;
	  }
	  else{
	      $otherRelation{$relation}{$goterm}{$2} =1;
	  }
      }
    }
}
close IN;

my $termSta = "../statistics/termStatistics.txt";
unless (-e $termSta){
    open OUT, "> $termSta" or die "cannot open $termSta\n";
    print OUT Dumper(\%termType);
    close OUT;
}

my $nameSta = "../statistics/termName.txt";
unless (-e $nameSta){
    open OUT, "> $nameSta" or die "cannot open $nameSta\n";
    print OUT Dumper(\%termName);
    close OUT;
}

my $typeSta = "../statistics/relationTypeStatistics.txt";
unless (-e $typeSta){
    open OUT, "> $typeSta" or die "cannot open $typeSta\n";
    print OUT Dumper(\%relationCount);
    close OUT;
}



=pod

################################

$isa{'NCBITaxon:5476'} = 'NCBITaxon:4892';
$isa{'NCBITaxon:5833'} = 'NCBITaxon:5820';
$isa{'NCBITaxon:3055'} = 'NCBITaxon:33090';


my %isachildren;
foreach my $goterm (keys %isa){
  next unless $goterm =~ /GO/;
  my $line = $isa{$goterm};
  while($line =~ /(\w+:\w+)/g){
    my $term = $1;
    if ($term =~ /GO/){
      $isachildren{$term}{$goterm} =1 ;
    }
  }
}

open ISA, "> isachildren.txt" or die;
print ISA Dumper(\%isachildren);
close ISA;


my %pthr_NCBI;

open PN, "< pthr_NCBI.txt" or die;
while(<PN>){
  chomp;
  my @array = split(/\t| +/);
  my $size = @array;
  $pthr_NCBI{lc($array[0])} = "NCBITaxon:".$array[$size-1];
}
close PN;

$pthr_NCBI{'gain'} = 'Gain';
$pthr_NCBI{'loss'} = '>Loss';

#print Dumper(\%pthr_NCBI);

my %goCons;
my %uberonCon;
my %chebiCon;
my @rounts;
&constructUBERON;


&UBERON_go;
&ONLYIN_NEVERIN_go;


my $goterm;
open IN, "< chebi.go_ancestor.txt" or die;
while(<IN>){
  if ($_ =~ /(GO:[0-9]+)/){
    $goterm = $1;
  }
  my %single = eval($_);
  my $key = (keys %single)[0];
  if ($key =~ /:/){
    $goCons{$goterm}{4} = ">Chebi|".$single{$key};
  }
}
close IN;


open SUM, "< Haiming_summary.csv" or die;
while(<SUM>){
  chomp;
  my @array = split(/,/);
  my $go = $array[1];
  my $info = $array[2];
  $info = lc $info;

  my $out;

  while( $info =~ /([A-Za-z-]+)/g){
    my $target = $pthr_NCBI{$1};
 #   print $1."\t";
    if (($target =~ /Gain/) or ($target =~/Loss/)){
      $out .= $target."\|";
    }
    else{
      $out .= $target.";";
    }
  }
  # print "\n";
  $goCons{$go}{3} = $out;
}
close SUM;

my %allchildren;

my $child_file = "goterm_children.extra.csv";
open IN, "< $child_file" or die;
while(<IN>){
  chomp;
  my @arr = split(/,/);
  my $size = @arr;
  foreach my $i (1..$size-1){
    $allchildren{$arr[0]}{$arr[$i]} =1;
  }
}
close IN;

my %combineCons;
my %combine_construct;

open COM, "> goCons1.txt" or die;
print COM Dumper(\%goCons);
close COM;


&combine_construct_sub;

open COM, "> goCons2.txt" or die;
print COM Dumper(\%goCons);
close COM;

&combine_construct_sub;
open COM, "> goCons3.txt" or die;
print COM Dumper(\%goCons);
close COM;

&combine_construct_sub;

open COM, "> goCons4.txt" or die;
print COM Dumper(\%goCons);
close COM;


open COM, "> combineCons.txt" or die;
print COM Dumper(\%combineCons);
close COM;

open COM, "> combine_construct.txt" or die;
print COM Dumper(\%combine_construct);
close COM;


# ***************************************

# then do a touch up
my $line;
my $GOterm;
my $value;

foreach my $key (keys %combineCons){
  if ($key =~ /GO/){
    $GOterm = $key;
    my $name = $name{$key};
    my $goname = $name{$key};

    if ($key =~ /GO:0009432/){
      $value = ">Gain|NCBITaxon:2;";
      $goCons{$key}{5} = $key;
      next;
    }

    if ($key =~ /GO:0060361/){
      $value = ">Gain|NCBITaxon:50557;";
      $goCons{$key}{5} = $key;
      next;
    }
    if ($key =~ /GO:0090632/){
      $value = ">Gain|NCBITaxon:40674;>Loss|NCBITaxon:9606";
      $goCons{$key}{5} = $key;
      next;
    }
    

    if ($goname =~ /response to/){
      &process_res($name,$value);
    }
    elsif ($goname =~ /bacteri/){ # be careful of antibacterial
      &process_bac($name,$value);
    }
    elsif ($goname =~ /cellular bud/){
      &process_cel($name,$value);
    }
    elsif ($goname =~ /ukary/){ 
      &process_euk($name,$value);
    }
    elsif ($goname =~ /nuclear/){ # be careful of mononuclear
      &process_nuc($name,$value);
    }
    elsif ($goname =~ /(photosynthe)|(photosystem)/){
      &process_pho($name,$value);
    }
    elsif ($value =~ /NCBI/){
      $goCons{$key}{5} = $key;
    }
    else{
      my $l = $line;
      print "Missing constraint: $l"."\t$name\n";
    }
  }
}

open COM, "> goCons5.txt" or die;
print COM Dumper(\%goCons);
close COM;


&combine_construct_sub;

open COM, "> goCons6.txt" or die;
print COM Dumper(\%goCons);
close COM;


&combine_construct_sub;

open COM, "> goCons7.txt" or die;
print COM Dumper(\%goCons);
close COM;


open COM, "> combineCons_afterTouch.txt" or die;
print COM Dumper(\%combineCons);
close COM;

open COM, "> combine_construct_afterTouch.txt" or die;
print COM Dumper(\%combine_construct);
close COM;



sub process_cel{
  my ($name,$value) = @_;
  unless ($value =~ /;/){
    $value .= ";";
  }
  if ($value =~ /4751[^0-9]/){
    return;
  }
  else{
    print "CHECK process_cel !! $name ; $value \n";

    $value = ">Gain|NCBITaxon:4751;";
    $goCons{$GOterm}{5} = $value;
  }
}

sub process_pho{
  my ($name,$value) = @_;

  $value = ">Gain|NCBITaxon:33090;NCBITaxon:1117";
  $goCons{$GOterm}{5} = $value;
  
}

sub process_euk{
  my ($name,$value) = @_;
  unless ($value =~ /;/){
    $value .= ";";
  }
  if ($value =~ /:2759[^0-9]/){
    return;
  }
  elsif ($value =~ /(:1[^0-9])|(:131567[^0-9])/){
    print "check process_euk LUCA!! $name ; $value \n";
    $value = ">Gain|NCBITaxon:2759;";
    $goCons{$GOterm}{5} = $value;
  }
  elsif ($value){
    print "check process_euk OTHER CONS!! $name ; $value \n";
    $value = ">Gain|NCBITaxon:2759;";
    $goCons{$GOterm}{5} = $value;    
  }
  else{
    print "check process_euk NO CONS!! $name ; $value \n";
    $value = ">Gain|NCBITaxon:2759;";
    $goCons{$GOterm}{5} = $value;
  }
}

sub process_nuc{
  my ($name,$value) = @_;
  unless ($value =~ /;/){
    $value .= ";";
  }
  if ($value =~ /:2759[^0-9]/){
    return;
  }
  else{

    if ($value =~ /(:1[^0-9])|(:131567[^0-9])/){
      print "CHECK process_nuc !! LUCA $name ; $value \n";
      $value = ">Gain|NCBITaxon:2759;";
      $goCons{$GOterm}{5} = $value;
    }
    else{
      print "CHECK process_nuc!! OTHER $name ; $value \n";
      #$value = ">Gain|NCBITaxon:2759;";
      # $goCons{$GOterm}{5} = $value;
    }
  }
}

sub process_res{
  my ($name,$value) = @_;
  unless ($value =~ /;/){
    $value .= ";";
  }

  if (($value =~ /NCBITaxon:1[^0-9]/ ) or ($value =~ /NCBITaxon:131567[^0-9]/)){
    
    print "response to!!  $name".  $line;
    return;
  }
  elsif ($value =~ /NCBITaxon/){
    $goCons{$GOterm}{5} = $value;
  }
  else{
    print "repsonse to process_res!! no constraint! $name , $line";
  }
}

sub process_bac{
  my ($name,$value) = @_;
  unless ($value =~ /;/){
    $value .= ";";
  }
  if ($name =~ /antibacter/){
    return;
  }
  elsif ($name =~ /archaeal/){
    return;
  }
  elsif (($name =~ /type/) or ($name =~ /bacterial /) or ($name =~ /bacterium/) or ($name =~ /bacterio/)){
    unless ($value){
      $value = ">Gain|NCBITaxon:2;";
      $goCons{$GOterm}{5} = $value;

    }
    elsif ($value =~ /NCBITaxon:2[^0-9]/){
      return;
    }
    elsif ($value =~ /NCBITaxon:1[^0-9]/){
      $value = ">Gain|NCBITaxon:2;";
      $goCons{$GOterm}{5} = $value;
    }    
    elsif ($value =~ /NCBITaxon:131567[^0-9]/){
      $value = ">Gain|NCBITaxon:2;";
      $goCons{$GOterm}{5} = $value;
    }
    else{
      print "check for $name: $line";
      $goCons{$GOterm}{5} = $value;
    }
  }
  else{
    print "process_bac CHECK!! other condition: ".$name."\t".$line;
  }
}



sub  constructUBERON{
  foreach my $term (keys %name){
    if ($term =~ /PO:/) {
      $uberonCon{$term} = 'NCBITaxon:3193';   
    }
    elsif ($term =~ /FAO:/){
      $uberonCon{$term} = 'NCBITaxon:451864';
    }
    next unless $term =~ /UBERON/;
    if (exists $othercons{$term}){
     #  print "$term\n";
      if ($othercons{$term} =~ /(NCBITaxon:[0-9]+)/){
	$uberonCon{$term} = $1;
      }
    }        
  }

  open UBER, "> uberonConstraint1.txt" or die;
  print UBER Dumper(\%uberonCon);
  close UBER;

  &uberonCycle;
  &uberonCycle;
  &uberonCycle;

  open UBER, "> uberonConstraint1.5.txt" or die;
  print UBER Dumper(\%uberonCon);
  close UBER;

  foreach my $term (keys %name){
    next unless $term =~ /UBERON/;
    if (exists $uberonCon{$term}){
      next;
    }
    else{
      $uberonCon{$term} = 'NCBITaxon:33213';
    }
  }
  open UBER, "> uberonConstraint1.6.txt" or die;
  print UBER Dumper(\%uberonCon);
  close UBER;


  foreach my $term (keys %name){
    @rounts = ();
#    next unless $term =~ /CL:/;
    next if $term =~ /(GO:)|(PO:)|(UBERON:)|(FAO:)|(CHEBI:)/ ;
    if (exists $othercons{$term}){      
      while ($othercons{$term} =~ /([A-Za-z]+:[0-9]+)/g){
	my $taxonc = $uberonCon{$1};
	if ($taxonc){
	  push(@rounts,$taxonc);
	}
      }
      my $theTaxon = &mostTaxon(\@rounts);
      if ($theTaxon){
	$uberonCon{$term} = $theTaxon;
      }
    }
  }

  open UBER, "> uberonConstraint2.txt" or die;
  print UBER Dumper(\%uberonCon);
  close UBER;

}

sub uberonCycle{
  foreach my $term (%othercons){
    next if (exists $uberonCon{$term});
    my $key = $othercons{$term};
    @rounts = ();
    while ($key =~ /([A-Za-z]+:[0-9]+)/g){
      my $taxonc = $uberonCon{$1};
      if ($taxonc){
	push(@rounts,$taxonc);
      }
    }
    my $theTaxon = &mostTaxon(\@rounts);
    if ($theTaxon){
      $uberonCon{$term} = $theTaxon;
    }
  }
}

sub UBERON_go{

  foreach my $thisterm (keys %uberon){
    if ($thisterm =~ $limit){
      print "check point for $goterm\n";
    }
    my $uberonterm = $uberon{$thisterm};
    my %taxons;
    while($uberonterm =~ /([A-Za-z]+:[0-9]+)/g){
      my $taxon = $uberonCon{$1};
      if ($taxon){
	$taxons{$taxon} = 1;
      }
    }
    my @taxons = keys %taxons;
    my $taxon;
    my $size = @taxons;
    if ($size > 1){
      print "UBERON LIMIT: $goterm\n";
      print Dumper(\@taxons);
    }
    if ($taxons[0]){
      $taxon = &mostTaxonLoss(\@taxons);
    }
    if ($taxon){
      $taxon = ">Uberon|".$taxon;
      $goCons{$thisterm}{1} = $taxon;
    }
  }
}

sub ONLYIN_NEVERIN_go{
  foreach my $goterm (keys %onlyin){
    my $con;
    foreach my $type (keys %{$onlyin{$goterm}}){
      if ($type =~ 'only_in'){
	my $value = $onlyin{$goterm}{$type};
	$con .= ">Gain|".$value.";"; 
      }
      elsif ($type =~ 'never_in'){
	my $value = $onlyin{$goterm}{$type};
	$con .= ">Loss|".$value.";"; 
      }
    }
    if ($con){
      $goCons{$goterm}{2} = $con;
    }
  }
}


sub combine_construct_sub{
  foreach my $goterm (keys %allchildren){
    next unless $goterm =~ /GO:/;
    
    my %children;
    my @set1 = keys %{$allchildren{$goterm}};
    my @set2 = keys %{$isachildren{$goterm}};
    foreach my $go (@set1){
      $children{$go}++;
    }
    foreach my $go (@set2){
      $children{$go}++;
    }
    my @children = keys %children;
    foreach my $type (1..5){
      my $con = $goCons{$goterm}{$type};
      if ($con =~ /NCBITaxon:[0-9]+/){
	foreach my $child (@children){
	  if ($limit){
	    next unless( $child =~ /$limit/);
	  }
	  $combine_construct{$child} .= "From $goterm: ".$con.";";
	}
      }
    }
  }

  foreach my $goterm (keys %goCons){

    if ($limit){
      next unless( $goterm =~ /$limit/ );
    }

#    next if (exists $combine_construct{$goterm});
    foreach my $type (1..5){
      my $con = $goCons{$goterm}{$type};
      if ($con =~ /NCBITaxon:[0-9]+/){
	$combine_construct{$goterm} .= "From $goterm: ".$con.";";
      }
    } 
  }

  foreach my $goterm (keys %combine_construct){
    if ($limit){
      next unless( $goterm =~ /$limit/ );
    }
    my $infoline = $combine_construct{$goterm};
    my $newline = &processline($infoline);
    $combineCons{$goterm} = $newline;

    $goCons{$goterm}{5} = $newline;
    print "\n*****\nWorking on $goterm infoline: $infoline\n";
    print "Workong on $goterm newline: $newline\n";
  }
}

sub processline{
  my $infoline = shift;
  my %info;
  while ($infoline =~ /([a-zA-z_]+)\|([NCBITaxon:;0-9]+)/g){
    my $type = $1;
    my $string = $2;
    while ($string =~ /(NCBITaxon:[0-9]+)/g){
      $info{$type}{$1} = 1;
    }
  }
  my $gain;
  my %all;
  foreach my $t1 (keys %{$info{'Gain'}}){
    $all{$t1} =1;
  }
  my @arr = keys %all;
  $gain = &mostTaxon(\@arr);


  my $loss;
  %all = {};
  foreach my $t1 (keys %{$info{'Loss'}}){
    $all{$t1} =1;
  }
  my @arr = keys %all;
  $loss = &mostTaxonLoss(\@arr);
  my @gain;
  my @loss;

  while ($gain =~ /(NCBITaxon:[0-9]+)/g){
    push(@gain,$1);
  }
  while ($loss =~ /(NCBITaxon:[0-9]+)/g){
    push(@loss,$1);
  }
  
  my $uberon;
  my %all;
  foreach my $t1 (keys %{$info{'Uberon'}}){
    $all{$t1} =1;
  }
  my @arr = keys %all;
  $uberon = &mostTaxon(\@arr);
  my @uberon;
  while ($uberon =~ /(NCBITaxon:[0-9]+)/g){
    push(@uberon,$1);
  }

  my %gh;
  my @gain_keep;
  my %visited;
  if (($uberon[0]) and ($gain[0]) ){
    foreach my $gain_c (@gain){
      my $I;
      foreach my $uberon_c (@uberon){
	my $i = &Taxoncompare($gain_c,$uberon_c); 
	if ($i == 1){ # if uberon_c is mom of gain_c
	  $gh{$gain_c} =1 ;
	  $I = 1;
	  $visited{$uberon_c} = 1;
	  last;
	}
	elsif ($i == 2) {# if uberon_c is child of gain_c
	  $gh{$uberon_c} = 1;
	  $I = 2;
	  $visited{$uberon_c} = 1;
	  last;
	}
      }
      if (($I ne 1) and ($I ne 2)){
	$gh{$gain_c} = 1;
      }
    }
    foreach my $uberon_c (@uberon){
      next if (exists $visited{$uberon_c});
      $gh{$uberon_c} = 1;
    }
  }
  @gain_keep = keys %gh;

  unless ($uberon[0]){
    @gain_keep = @gain;
  }
  unless ($gain[0]){
    @gain_keep = @uberon;
  }


  my @loss_keep;
  foreach my $loss_c (@loss){
    foreach my $gain_c (@gain_keep){
      my $i = &Taxoncompare($loss_c,$gain_c);
      if ($i == 1) { # if gain_c is mom of loss_c
	push(@loss_keep,$loss_c);
	print "for $goterm, we keep LOSS $loss_c\n";
      }
      elsif (($i == -1) or ($i == 2)){
	print " while processing $goterm, Strange LOSS: $loss_c GAIN: $gain_c \n";
      }
    }
  }

  my $combined;
  if ($gain_keep[0]){
    $combined = ">Gain|";
    foreach my $gain (@gain_keep){
      $combined .= $gain.";" ;
    }
    if ($loss_keep[0]){
      $combined .= ">Loss|";
      foreach my $loss (@loss_keep){
	$combined .= $loss.";";
      }
    }
  }

  my $chebi;
  my %all;
  foreach my $t1 (keys %{$info{'Chebi'}}){
    $all{$t1} =1;
  }
  my @arr = keys %all;
  $chebi = &mostTaxonLoss(\@arr);
  
  if ($combined){
    return $combined;
  }
  else{
    if ($chebi){
      return ">Chebi|".$chebi;
    }
  }
}


sub mostTaxonLoss{
  my $ref = shift;
  my @taxons = @$ref;
  my $size = @taxons;

  if ($size ==1){
    return $taxons[0];
  }

  else{
    my $rest;
    %skip = {};
    foreach my $i (0..$size-2){
      foreach my $j ($i+1..$size-1){
	if ((exists $skip{$i}) or (exists $skip{$j})){
          next;
	}
        else{
          my $skip_n = &Taxoncompare($taxons[$i],$taxons[$j]);
          if ($skip_n ==1){
            $skip{$i} =1;
            #say "skipping $taxons[$i]";
          }
          elsif ($skip_n ==2){
            $skip{$j} =1;
            #say "skipping $taxons[$j]";
          }
        }
      }
    }

    foreach my $i (0..$size-1){
      next if (exists $skip{$i});
      my $taxon = $taxons[$i];
      $rest .= $taxon.";";
    }
    return $rest;
  }
}

sub mostTaxon{
  my $aref = shift;
  my @arr = @$aref;
  my %taxons;
  
  foreach my $line (@arr){
    while ($line =~ /(NCBITaxon:[0-9]+)/g){
      $taxons{$1} =1;
    }
  }
  my @taxons = keys %taxons;
  my $size = @taxons;
  if ($size ==1){
    return $taxons[0];
  }
  else{
    my $rest;
    %skip = ();
    foreach my $i (0..$size-2){
      foreach my $j ($i+1..$size-1){
        if ((exists $skip{$i}) or (exists $skip{$j})){
          next;
        }
        else{
          my $skip_n = &Taxoncompare($taxons[$i],$taxons[$j]);
          if ($skip_n ==1){
            $skip{$j} =1;
#            say "skipping $taxons[$j], mom of $taxons[$i]";
          }
          elsif ($skip_n ==2){
            $skip{$i} =1;
 #           say "skipping $taxons[$i], mom of $taxons[$j]";
          }
        }
      }
    }
    foreach my $i (0..$size-1){
      next if (exists $skip{$i});
      my $taxon = $taxons[$i];
      $rest .= $taxon.";";
    }
    return $rest;
  }
}
sub Taxoncompare{
  my $taxon1 = shift;
  my $taxon2 = shift;

  my $mum1;
  my $mum2;

  my $taxon = $taxon1;
  my $current;

  if ($taxon1 eq $taxon2){
    return -1;
  }

  while(1){
    if ($current){
      $taxon = $current;
    }
    if (exists $isa{$taxon}){
      $current = $isa{$taxon};
      $current =~ /(NCBITaxon:[0-9]+)/;
      $current = $1;
      $mum1 .= $current.";";
    }
    else{
      last;
    }
  }

  my $taxon = $taxon2;
  my $current;
  
  while(1){
    if ($current){
      $taxon = $current;
    }
    
    if (exists $isa{$taxon}){
      $current = $isa{$taxon};
      $current =~ /(NCBITaxon:[0-9]+)/;
      $current = $1;
      $mum2 .= $current.";";
    }
    else{
      last;
    }
  }
  
  if ($mum1 =~ /$taxon2[^0-9]/){
    return 1;
  }
  elsif ($mum2 =~ /$taxon1[^0-9]/){
    return 2;
  }
  else{
#    print STDERR "$taxon1 mom: $mum1\n";
 #   print STDERR "$taxon2 mom: $mum2\n\n";
    return 3;
  }
}
