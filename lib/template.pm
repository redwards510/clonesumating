package template;
use strict;
 
#use Memoize;
use Exporter;
#use profiles;
use bbDates;
use CONFIG;

use Apache2::Const qw(REDIRECT OK);

#memoize('loadTemplate');

our @ISA    = qw(Exporter);
our @EXPORT = qw(processTemplate showVars);

our %templates;

our $templateDir;

my $debugMode = 0;


sub debug {
	my ($msg)  = @_;

	if ($debugMode) {
		warn $msg;
	}
}



sub showVars {
	my ($variables,$depth) = @_;
	no strict "refs";

	my $str = '';
	foreach my $key (keys %{ $variables }) {

		if (%{ $$variables{$key}  }) {
			if ($key =~ /\d+/){
				$str .= "$depth (multi-record item)\n";
			} else {
				$str .= "$depth Type = $key\n";
			}
			$str .= showVars( \%{ $$variables{$key} },"   $depth")
		} else {
			$str .= "$depth name=$key              $$variables{$key}\n";
		}
	}
	return $str;
}




sub processRawTemplate {
	my ($variables,$raw) = @_;
	return processTemplate($variables,"",1,"",$raw);
}


sub doTokenReplacements {
	my ($html,$variables) = @_;

        $html =~ s/<cms::var type="global" name="(\w+)">/$$variables{global}{$1}/egs;
        $html =~ s/<cms::var type="global" name="(\w+)" nohtml>/striphtml($$variables{global}{$1})||""/egs;
        $html =~ s/<cms::var type="global" name="(\w+)" paragraphs>/pbreak($$variables{global}{$1})||""/egs;
        $html =~ s/<cms::var type="global" name="(\w+)" date>/dateformat($$variables{global}{$1})||""/egs;
        $html =~ s/<cms::var type="global" name="(\w+)" datetime>/timeformat($$variables{global}{$1})||""/egs;

        #$html =~ s/<cms::module name="(.*?)">/$$variables{modules}{$1}/gs;
        $html =~ s/<cms::list over="(\w+)">(.*?)<\/cms::list>/listit($variables,$1,$2)/egs;
		$html =~ s^<cms::ifloop type="\w+">(.*?)</cms::ifloop>^$1^gs;
        $html =~ s/<cms::fancylist over="(\w+)" limit="(\d+)" offset="(\d+)">(.*?)<\/cms::fancylist>/debug "Fancylist over $1 limit $2 offset $3\n$4"; fancylistit($variables,$1,$4,$2,$3)/egs;
        #$html =~ s/<cms::randomlist over="(\w+)" limit="(\d+)">(.*?)<\/cms::randomlist>/randomlistit($variables,$1,$3,$2)/egs;
        $html =~ s/<cms::fancylist over="(\w+)">(.*?)<\/cms::fancylist>/fancylistit($variables,$1,$2,5000,0)/egs;
        $html =~  s/\<cms::if type="(\w+)" name="(\w+)" equals="(.*?)" nest>(.*?)\<\/cms::if type="\1" name="\2">/debug "IFEN $1\n$2\n$3\n$4"; ife($$variables{$1}{$2},$3,$4,$variables)/egs;
        $html =~  s/\<cms::if type="(\w+)" name="(\w+)" equals="(.*?)">(.*?)\<\/cms::if>/debug "IFE $1 $2 $3 $4";ife($$variables{$1}{$2},$3,$4,$variables)/egs;
        $html =~  s/\<cms::if type="(\w+)" name="(\w+)" nest>(.*?)\<\/cms::if type="\1" name="\2">/debug "IFN $1 $2 $3"; ifn($$variables{$1}{$2},$3,$variables)/egs;
        $html =~  s/\<cms::if type="(\w+)" name="(\w+)">(.*?)\<\/cms::if>/ifn($$variables{$1}{$2},$3,$variables)/egs;

        $html =~  s/\<cms::ifnot type="(\w+)" name="(\w+)" equals="(.*?)" nest>(.*?)\<\/cms::ifnot type="\1" name="\2">/debug "IFNOTEN $1\n$2\n$3\n$4"; ifnote($$variables{$1}{$2},$3,$4,$variables)/egs;
        $html =~  s/\<cms::ifnot type="(\w+)" name="(\w+)" equals="(.*?)">(.*?)\<\/cms::ifnot>/debug "IFNOTE $1\n$2\n$3\n$4"; ifnote($$variables{$1}{$2},$3,$4,$variables)/egs;
        $html =~  s/\<cms::ifnot type="(\w+)" name="(\w+)" nest>(.*?)\<\/cms::ifnot type="\1" name="\2">/debug "IFNOTN $1\n$2\n$3"; ifnot($$variables{$1}{$2},$3,$variables)/egs;
        $html =~  s/\<cms::ifnot type="(\w+)" name="(\w+)">(.*?)\<\/cms::ifnot>/debug "IFNOT $1\n$2\n$3"; ifnot($$variables{$1}{$2},$3,$variables)/egs;
        #$html =~  s/\<cms::truncate type="(\w+)" name="(\w+)" length="(.*?)"\>/trunc($$variables{$1}{$2},$3)/egs;
        $html =~ s/\<cms::var type="(\w+)" name="(\w+)">/$$variables{$1}{$2}/egs;
		$html =~ s/\<cms::wc type="(\w+)" name="(\w+)" s="(.*?)" p="(.*?)"\>/wordchoice($$variables{$1}{$2},$3,$4)/egs;

        $html =~ s/\<cms::var type="(\w+)" name="(\w+)" nohtml>/striphtml($$variables{$1}{$2})||""/egs;
        $html =~ s/\<cms::var type="(\w+)" name="(\w+)" paragraphs>/pbreak($$variables{$1}{$2})||""/egs;
        $html =~ s/\<cms::var type="(\w+)" name="(\w+)" date>/dateformat($$variables{$1}{$2})||""/egs;
        $html =~ s/\<cms::var type="(\w+)" name="(\w+)" datetime>/timeformat($$variables{$1}{$2})||""/egs;
 
	
	return $html;

}

sub wordchoice {
	my ($number,$singular,$plural) = @_;

	if ($number eq "1") {
		return $singular;
	} else {
		return $plural;
	}
}

sub processTemplate {

	my ($vars,$template_file_name,$skipwrapper,$alternateTemplate,$raw) = @_;


	my %localhash = %{ $vars };
	my $variables = \%localhash;
	
	if ($$variables{form}{showVariables}) {

		my $str;
		$str= "<PRE>";
		$str.=showVars($variables,"");
		$str.="</PRE>";
		return $str;

	}

	if (!$skipwrapper) { $skipwrapper = 0; }
	my $body = "";
	my $template = "";

	loadTemplate($template_file_name,\$body);

	if ($raw ne "") {
		$body = $raw;
	}


	$body = doTokenReplacements($body,$variables);

	if ($raw eq "") {
		$$variables{system}{body} = $body;
	}

	if ($skipwrapper == 1) {
		return $body;
	}

	if (-e "$templateDir/cobrands/$$variables{global}{cobrand}/outside.html") {
		$alternateTemplate = "cobrands/$$variables{global}{cobrand}/outside.html";
	}

	if ($alternateTemplate) {
		loadTemplate("$alternateTemplate",\$template);
	} else {
		loadTemplate("outside.html",\$template);
	}


	$template = doTokenReplacements($template,$variables);

	%localhash = undef;

	return $template;

}

sub striphtml {
	my ($txt) = @_;
	$txt =~ s/<.*?>//gsm;
	return $txt;
}



sub fancylistit {
	my ($variables,$section,$code,$limit,$offset) = @_;

	$limit = $limit * 1;
	$offset = $offset * 1;

	my $results = "";
	my $count = -1;

	foreach my $key (sort {$a <=> $b} keys %{$$variables{$section}}) {

		$count++;

		if ($count == 0) {
			$$variables{$section}{$key}{list}{first} = 1;
		} 
		if ($count == scalar(keys(%{$$variables{$section}})-1)) {
			$$variables{$section}{$key}{list}{last} = 1;
		}
		if ($count % 2 == 0) {
			$$variables{$section}{$key}{list}{even} = 1;
			$$variables{$section}{$key}{list}{evenodd} = "even";
		} else {
			$$variables{$section}{$key}{list}{odd} = 1;
			$$variables{$section}{$key}{list}{evenodd} = "odd";
		}

		if ($count < $offset) {
			next; 
		}	
		if ($count >= $limit) {
			next;
		}	
				my $tmp = $code;


		debug "TOKEN REPLACEMENT FOR $section -> $key";
		$tmp = doTokenReplacements($tmp, \%{ $$variables{$section}{$key}  });
		
		$results .= $tmp;
	}

	return $results;

}


sub pbreak {
	
	my ($txt) = @_;

	$txt =~ s/\r//gs;
	$txt =~ s/\n\n/<\/p>\n<P>/gs;

	return $txt;
}

sub dateformat {
	my ($txt) = @_;

	my ($date,$time) = split(/\s+/,$txt);
	
	my ($year,$month);
	($year,$month,$date) = split(/\-/,$date);

	$month =~ s/^0//gs;
	$date =~ s/^0//gs;

	$month = $months[$month -1];


	return "$month $date, $year";

}

sub timeformat {
	my ($txt) = @_;

	my ($date,$time) = split(/\s+/,$txt);
	$date = dateformat($date);

	my ($hour,$min,$sec) = split(/\:/,$time);
	if ($hour > 12) {
		$hour -= 12;
	}

	return "$date at $hour:$min";

}

sub randomlistit {
        my ($variables,$section,$code,$limit) = @_;

	my %used;
	$limit = $limit * 1;

	my $total = keys(%{$$variables{$section}});
	if ($total < $limit) {
		$limit = $total;
	}	



	my $results = "";
	for (0 .. $limit-1) {

		my $key;
		do {
			$key = int(rand(keys(%{$$variables{$section}})));
		} until (!$used{$key});

		$used{$key} = 1;

		my $tmp = $code;

		$tmp =~ s/<cms::var type="(.*?)" name="(.*?)">/$$variables{$section}{$key}{$1}{$2} || $$variables{$1}{$2}/egs;

		$results .= $tmp;

		last if (scalar keys %used == scalar keys %{$variables->{$section}});
	}

        return $results;

}



sub listit {
   	my ($variables,$section,$code) = @_;

	my $results = "";
	foreach my $key (sort keys %{$$variables{$section}}) {
		
		my $tmp = $code;

		$tmp =~ s/<cms::key>/$key/gs;
		$tmp =~ s/<cms::value>/$$variables{$section}{$key}/gs;
	
		$results .= $tmp;

	}

	return $results;

}


sub trunc {
	my ($val,$length)  = @_;

	my ($i,@chunks,$ret);

	my $type = $length =~ /p/i ? 'p' : 'w';



	$length =~ s/(\d+).*/$1/gs;

	$length = $length * 1;

	$val =~ s/\r//gs;

	if ($type eq "w") {
		@chunks = split(/\s+/,$val);
	} else {
		@chunks = split(/\n\n/,$val);
	}

	foreach $i (0 .. $length -1) {


		if ($i > $#chunks) { last; }

		$ret .= $chunks[$i];

		if ($type eq "w") { 
			$ret .= " ";
		 } else { 
			$ret .= "\n\n";
		 }
	}

	if ($length < $#chunks && $type eq 'w') {
		$ret .= "...";
	}

	return $ret;
}

sub ifn {
	my ($val,$code,$variables) = @_;


	if ($val ne "") {
		return processRawTemplate($variables,$code);
	} else {
		return "";
	}
}

sub ifnot {
        my ($val,$code,$variables) = @_;
        
        if ($val eq "") {
                return processRawTemplate($variables,$code);
        } else {
                return "";
        }
}
sub ifnote {

        my ($val,$test,$code,$variables) = @_;
        

        
        if ($val ne $test) { 
                return processRawTemplate($variables,$code);
        } else {
                return "";
        }



}
sub ife {
        my ($val,$test,$code,$variables) = @_;



        if ($val eq $test) {
                return processRawTemplate($variables,$code);
        } else {
                return "";
        }
}

sub loadTemplate {
	
	my ($template_file_name,$res) = @_;

		$templateDir = $templatePath;

	local $/=undef;

	open(IN,"$templateDir/$template_file_name");
	$$res = <IN>;
	close(IN);

	return $res;
}



1;
